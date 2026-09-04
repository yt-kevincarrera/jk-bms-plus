import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../inspection/inspection_result.dart';
import '../inspection/inspection_series.dart';
import '../metrics/capacity_cycle_detector.dart';
import '../metrics/trip_energy_repair.dart';
import '../metrics/trip_recorder.dart';
import '../model/bms_snapshot.dart';
import '../protocol/jk_frame.dart';
import 'database.dart';

/// Everything that writes to disk.
///
/// Buffered rather than row-at-a-time: at 1 Hz a write per reading would wake
/// the storage constantly for no benefit. Batches flush on a timer, and always
/// on the way out, so a crash costs at most one interval.
class BmsRepository {
  BmsRepository({
    AppDatabase? database,
    this.flushInterval = const Duration(seconds: 5),
  }) : db = database ?? AppDatabase() {
    _flushTimer = Timer.periodic(flushInterval, (_) => flush());
  }

  final AppDatabase db;
  final Duration flushInterval;

  /// How long raw frames are kept. Roughly 25 MB a day of active use, so this
  /// is the difference between a useful safety net and a full phone.
  static const Duration rawFrameRetention = Duration(days: 30);

  final List<SnapshotsCompanion> _pendingSnapshots = [];
  final List<RawFramesCompanion> _pendingFrames = [];
  Timer? _flushTimer;

  /// Set while a trip is being recorded, so readings can be attributed to it.
  int? currentTripId;

  /// The pack everything is currently being recorded against, and read back
  /// for.
  ///
  /// Null when nothing is connected, and in that case readings are dropped
  /// rather than stored without a pack: a row that cannot say which battery it
  /// came from is worse than no row, because it still counts in every average.
  String? activeDeviceId;

  /// True when the active pack is the simulated one.
  bool activeIsDemo = false;

  /// Raw frame capture can be turned off, but the default is on and it should
  /// stay on: it is what makes a wrongly-decoded offset recoverable.
  bool recordRawFrames = true;

  /// Queues one decoded reading.
  void addSnapshot(BmsSnapshot s) {
    final device = activeDeviceId;
    if (device == null) return;
    final temps = <double>[
      ...s.plausibleTemperatures,
      if (s.mosfetTemp != null) s.mosfetTemp!,
    ];
    _pendingSnapshots.add(
      SnapshotsCompanion.insert(
        timestamp: s.timestamp,
        tripId: Value(currentTripId),
        deviceId: Value(device),
        packVoltage: s.packVoltage,
        current: s.current,
        soc: s.soc,
        soh: s.soh,
        remainingAh: s.remainingCapacityAh,
        cycleCount: s.cycleCount.toDouble(),
        cycleCapacityAh: Value(s.cycleCapacityAh),
        deltaVolts: s.deltaCellVoltage,
        minCellVoltage: s.minCellVoltage,
        maxCellVoltage: s.maxCellVoltage,
        maxTemperature: temps.isEmpty
            ? 0
            : temps.reduce((a, b) => a > b ? a : b),
        mosfetTemp: Value(s.mosfetTemp),
        warningsMask: s.warnings.raw,
        balancerActive: s.balancerActive,
        cellVoltagesJson: encodeCellVoltages(s.cellVoltages),
      ),
    );
  }

  /// Queues one raw frame, exactly as it arrived.
  void addRawFrame(JkFrame frame) {
    if (!recordRawFrames) return;
    final device = activeDeviceId;
    if (device == null) return;
    _pendingFrames.add(
      RawFramesCompanion.insert(
        timestamp: frame.receivedAt,
        recordType: frame.rawType,
        bytes: frameBytes(frame.bytes),
        deviceId: Value(device),
      ),
    );
  }

  /// Writes whatever has piled up.
  Future<void> flush() async {
    if (_pendingSnapshots.isEmpty && _pendingFrames.isEmpty) return;

    final snapshots = List<SnapshotsCompanion>.from(_pendingSnapshots);
    final frames = List<RawFramesCompanion>.from(_pendingFrames);
    _pendingSnapshots.clear();
    _pendingFrames.clear();

    try {
      if (snapshots.isNotEmpty) await db.insertSnapshots(snapshots);
      if (frames.isNotEmpty) await db.insertRawFrames(frames);
    } on Exception catch (_) {
      // A failed write must not take the live view down with it. The readings
      // are already on screen; losing an interval of history is the cheaper
      // failure.
    }
  }

  /// Opens a trip row as soon as recording starts.
  ///
  /// The row exists from the first second so every reading taken during the
  /// ride can be attributed to it, and so a ride that ends in a crash or a flat
  /// phone still leaves something behind instead of vanishing.
  Future<int> beginTrip(DateTime startedAt, {bool demo = false}) async {
    final id = await db.insertTrip(
      TripsCompanion.insert(
        demo: Value(demo),
        deviceId: Value(activeDeviceId),
        startedAt: startedAt,
        endedAt: startedAt,
        distanceKm: 0,
        movingSeconds: 0,
        totalSeconds: 0,
        maxSpeedKmh: 0,
        energyOutWh: 0,
        energyInWh: 0,
        startSoc: 0,
        endSoc: 0,
        minPackVoltage: 0,
        maxPackVoltage: 0,
        maxDischargeCurrent: 0,
        maxTemperature: 0,
        maxDeltaVolts: 0,
        climbM: 0,
        descentM: 0,
      ),
    );
    currentTripId = id;
    return id;
  }

  /// Fills in the row opened by [beginTrip] and stores the track.
  /// Stores the finished ride, and what the app made of it.
  ///
  /// [conclusions] is optional so a caller with nothing to say stores nothing
  /// rather than zeroes: a ride whose conclusions read 0 Wh/km would be
  /// indistinguishable from one where the estimate collapsed.
  Future<void> finishTrip(
    int tripId,
    TripSummary summary,
    List<TrackPoint> points, {
    TripConclusions? conclusions,
  }) async {
    await flush();
    await db.updateTrip(
      tripId,
      TripsCompanion(
        endedAt: Value(DateTime.now().toUtc()),
        distanceKm: Value(summary.distanceKm),
        movingSeconds: Value(summary.movingDuration.inSeconds),
        totalSeconds: Value(summary.totalDuration.inSeconds),
        maxSpeedKmh: Value(summary.maxSpeedKmh),
        energyOutWh: Value(summary.energyOutWh),
        energyInWh: Value(summary.energyInWh),
        startSoc: Value(summary.startSoc),
        endSoc: Value(summary.endSoc),
        minPackVoltage: Value(summary.minPackVoltage),
        maxPackVoltage: Value(summary.maxPackVoltage),
        maxDischargeCurrent: Value(summary.maxDischargeCurrent),
        maxTemperature: Value(summary.maxTemperature),
        maxDeltaVolts: Value(summary.maxDeltaVolts),
        climbM: Value(summary.climbM),
        descentM: Value(summary.descentM),
        ahOut: Value(summary.ahOut),
        energySource: Value(summary.energySource.name),
        whPerKmBefore: Value(conclusions?.whPerKmBefore),
        whPerKmAfter: Value(conclusions?.whPerKmAfter),
        learnedKm: Value(conclusions?.learnedKm),
        rangeKmAtEnd: Value(conclusions?.rangeKmAtEnd),
        confidence: Value(conclusions?.confidence.name),
      ),
    );

    if (points.isNotEmpty) {
      await db.insertTripPoints([
        for (final p in points)
          TripPointsCompanion.insert(
            tripId: tripId,
            timestamp: p.timestamp,
            latitude: p.latitude,
            longitude: p.longitude,
            speedKmh: p.speedKmh,
            altitudeM: p.altitudeM,
            packVoltage: p.packVoltage,
            current: p.current,
            soc: p.soc,
          ),
      ]);
    }
    currentTripId = null;
  }

  /// Every stored trip long enough to learn consumption from, oldest first.
  ///
  /// Filtered by which world you are in rather than by discarding demo rides.
  /// Demo mode keeps its own trips and learns from them, which is the only way
  /// to see for yourself that the learning works; real mode never sees them.
  /// One database with the two worlds kept apart, rather than two databases:
  /// same isolation, none of the duplicated schema, migrations and connections.
  ///
  /// The estimator is rebuilt from these rather than kept as a running tally,
  /// so deleting a bad trip actually removes its influence instead of leaving
  /// it baked into a number nobody can unpick.
  /// Mends every pack's rides, not just the one being connected to.
  ///
  /// This belongs at startup rather than on connect, and putting it on connect
  /// was a plain mistake: the saved-pack screen reads a pack's history with no
  /// radio involved, which is the whole point of it, so a repair that only
  /// happens on connect leaves that screen showing figures the app already
  /// knows how to fix. It reported "nothing learned yet" against rides it
  /// could have measured.
  ///
  /// Cheap to call at every start: it only looks at rides with no amp-hour
  /// figure, and after the first pass there are none.
  Future<TripRepairReport> repairAllTripEnergy() async {
    final devices = await db.allDevices();
    var examined = 0;
    var repaired = 0;
    var unrepairable = 0;
    for (final d in devices) {
      final report = await repairTripEnergy(d.id);
      examined += report.examined;
      repaired += report.repaired;
      unrepairable += report.unrepairable;
    }
    return TripRepairReport(
      examined: examined,
      repaired: repaired,
      unrepairable: unrepairable,
    );
  }

  /// Recomputes the energy of rides recorded before the integration bug.
  ///
  /// Only touches rides that have no amp-hour figure, which is exactly the set
  /// recorded by a build that could not produce one. Runs once per pack in
  /// practice, then finds nothing.
  /// How much time one reading query may cover while mending rides.
  ///
  /// An evening's worth, so rides taken together are still read together, and
  /// no query can reach back across the weeks that a single old unmeasurable
  /// ride used to drag in.
  static const Duration repairWindow = Duration(hours: 8);

  Future<TripRepairReport> repairTripEnergy(
    String deviceId, {
    TripEnergyRepair repairer = const TripEnergyRepair(),
  }) async {
    await flush();
    final trips = await db.recentTrips(deviceId, limit: 500);
    final stale = [
      for (final t in trips)
        if (t.ahOut == null && t.energySource == null && t.distanceKm > 0) t,
    ];
    if (stale.isEmpty) return TripRepairReport.none;

    // One window per run of nearby rides, rather than one window over all of
    // them. Reading them together is right for an evening's riding and ruinous
    // across weeks: a single unmeasurable ride from last month used to force
    // every reading since into memory, on the first decoded frame of every
    // connection.
    final groups = groupBySpan(
      stale,
      startOf: (t) => t.startedAt,
      endOf: (t) => t.endedAt,
      maxSpan: repairWindow,
    );

    var repaired = 0;
    var unrepairable = 0;
    for (final group in groups) {
      var earliest = group.first.startedAt;
      var latest = group.first.endedAt;
      for (final t in group) {
        if (t.startedAt.isBefore(earliest)) earliest = t.startedAt;
        if (t.endedAt.isAfter(latest)) latest = t.endedAt;
      }
      final readings = await db.snapshotsBetween(
        deviceId,
        earliest.subtract(const Duration(minutes: 1)),
        latest.add(const Duration(minutes: 1)),
      );

      for (final t in group) {
        final fixed = repairer.recompute(t, readings);
        if (fixed == null) {
          unrepairable++;
          // Recorded, so this ride is never examined again. Left blank it
          // stayed stale forever, and every connection paid for it.
          await db.updateTrip(
            t.id,
            TripsCompanion(energySource: Value(EnergySource.unmeasurable.name)),
          );
          continue;
        }
        await db.updateTrip(
          t.id,
          TripsCompanion(
            energyOutWh: Value(fixed.outWh),
            energyInWh: Value(fixed.inWh),
            ahOut: Value(fixed.ahOut),
            energySource: Value(fixed.source.name),
          ),
        );
        repaired++;
      }
    }

    return TripRepairReport(
      examined: stale.length,
      repaired: repaired,
      unrepairable: unrepairable,
    );
  }

  /// Stores, or corrects, what the app concluded about a finished ride.
  Future<void> recordTripConclusions(int tripId, TripConclusions conclusions) =>
      db.updateTrip(
        tripId,
        TripsCompanion(
          whPerKmBefore: Value(conclusions.whPerKmBefore),
          whPerKmAfter: Value(conclusions.whPerKmAfter),
          learnedKm: Value(conclusions.learnedKm),
          rangeKmAtEnd: Value(conclusions.rangeKmAtEnd),
          confidence: Value(conclusions.confidence.name),
        ),
      );

  Future<List<Trip>> tripsForLearning(String deviceId) async {
    final all = await db.recentTrips(deviceId, limit: 500);
    final usable =
        all
            .where((t) => t.distanceKm >= 0.2 && t.energyOutWh > t.energyInWh)
            .toList()
          ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return usable;
  }

  /// Trips for one pack, newest first.
  Stream<List<Trip>> watchTrips(String deviceId, {int limit = 100}) =>
      db.watchTrips(deviceId, limit: limit);

  Future<List<TripPoint>> pointsFor(int tripId) => db.pointsFor(tripId);

  Future<void> deleteTrip(int tripId) => db.deleteTrip(tripId);

  Future<void> setTripNote(int tripId, String note) =>
      db.setTripNote(tripId, note);

  /// Drops raw frames past their retention window. Cheap, and worth doing on
  /// every start rather than waiting for the phone to fill up.
  Future<int> pruneRawFrames() => db.pruneRawFrames(keep: rawFrameRetention);

  /// Thins readings older than a month down to one a minute.
  ///
  /// Cheap, and worth doing at every start rather than when the phone is
  /// already full: at 1 Hz this table is the second biggest thing the app
  /// writes, and nothing was ever removing from it.
  Future<int> compactSnapshots() => db.compactSnapshots();

  Future<StorageStats> storageStats() async => StorageStats(
    snapshots: await db.countSnapshots(),
    rawFrames: await db.countRawFrames(),
    bytes: await AppDatabase.fileSizeBytes(),
  );

  // --- Capacity tests ---

  Future<int> beginCapacityTest({
    required DateTime startedAt,
    required double startSoc,
    required double startPackVoltage,
    required double? catalogueAh,
  }) => db.insertCapacityTest(
    CapacityTestsCompanion.insert(
      startedAt: startedAt,
      startSoc: startSoc,
      endSoc: startSoc,
      startPackVoltage: startPackVoltage,
      endPackVoltage: startPackVoltage,
      measuredAh: 0,
      measuredWh: 0,
      catalogueAh: Value(catalogueAh),
    ),
  );

  /// Called as the run goes, so a closed app costs seconds rather than hours.
  Future<void> updateCapacityProgress(
    int id, {
    required double measuredAh,
    required double measuredWh,
    required double endSoc,
    required double endPackVoltage,
  }) => db.updateCapacityTest(
    id,
    CapacityTestsCompanion(
      measuredAh: Value(measuredAh),
      measuredWh: Value(measuredWh),
      endSoc: Value(endSoc),
      endPackVoltage: Value(endPackVoltage),
    ),
  );

  Future<void> finishCapacityTest(
    int id, {
    required DateTime endedAt,
    required double endSoc,
    required double endPackVoltage,
    required double measuredAh,
    required double measuredWh,
  }) => db.updateCapacityTest(
    id,
    CapacityTestsCompanion(
      endedAt: Value(endedAt),
      endSoc: Value(endSoc),
      endPackVoltage: Value(endPackVoltage),
      measuredAh: Value(measuredAh),
      measuredWh: Value(measuredWh),
      completed: const Value(true),
    ),
  );

  Future<void> deleteCapacityTest(int id) => db.deleteCapacityTest(id);

  Future<List<CapacityTest>> capacityTests(String deviceId) =>
      db.allCapacityTests(deviceId);

  Future<int> countCompletedCapacityTests(String deviceId) async {
    final all = await db.allCapacityTests(deviceId);
    return all.where((t) => t.completed).length;
  }

  /// A run that was interrupted, if there is one, so it can be picked back up.
  Future<CapacityTest?> unfinishedCapacityTest(String deviceId) async {
    final all = await db.allCapacityTests(deviceId);
    for (final t in all) {
      if (!t.completed) return t;
    }
    return null;
  }

  /// Records a discharge the app found in the history rather than being told
  /// about. Skips one it has already stored.
  Future<bool> recordDetectedCycle(
    String deviceId,
    DetectedCycle cycle,
    double? catalogueAh,
  ) async {
    final existing = await db.allCapacityTests(deviceId);
    // Matched on the start instant: the same discharge scanned twice must not
    // become two measurements.
    if (cycleAlreadyRecorded(
      cycle.startedAt,
      existing.map((t) => t.startedAt),
    )) {
      return false;
    }

    await db.insertCapacityTest(
      CapacityTestsCompanion.insert(
        startedAt: cycle.startedAt,
        endedAt: Value(cycle.endedAt),
        startSoc: cycle.startSoc,
        endSoc: cycle.endSoc,
        startPackVoltage: cycle.startPackVoltage,
        endPackVoltage: cycle.endPackVoltage,
        measuredAh: cycle.measuredAh,
        measuredWh: cycle.measuredWh,
        catalogueAh: Value(catalogueAh),
        completed: const Value(true),
        automatic: const Value(true),
        gapSeconds: Value(cycle.gapSeconds),
        deviceId: Value(deviceId),
      ),
    );
    return true;
  }

  /// Every reading stored for one pack, oldest first, for the cycle scan.
  Future<List<Snapshot>> allSnapshots(String deviceId, {int days = 180}) =>
      db.snapshotsBetween(
        deviceId,
        DateTime.now().toUtc().subtract(Duration(days: days)),
        DateTime.now().toUtc(),
      );

  // --- Packs ---

  /// Records that this pack has been seen, creating it the first time.
  ///
  /// Returns the stored row, whose catalogue capacity is the figure every
  /// health number for this pack is measured against.
  Future<Device> rememberDevice({
    required String id,
    required String name,
    required bool demo,
    String serialNumber = '',
    String model = '',
  }) async {
    final now = DateTime.now().toUtc();
    final existing = await db.device(id);
    if (existing == null) {
      await db.upsertDevice(
        DevicesCompanion.insert(
          id: id,
          name: Value(name),
          serialNumber: Value(serialNumber),
          model: Value(model),
          firstSeenAt: now,
          lastSeenAt: now,
          demo: Value(demo),
        ),
      );
    } else {
      await db.updateDevice(
        id,
        DevicesCompanion(
          lastSeenAt: Value(now),
          // A renamed pack keeps the rider's name; the rest catches up as the
          // device info frame arrives.
          name: name.isEmpty ? const Value.absent() : Value(name),
          serialNumber: serialNumber.isEmpty
              ? const Value.absent()
              : Value(serialNumber),
          model: model.isEmpty ? const Value.absent() : Value(model),
        ),
      );
    }
    return (await db.device(id))!;
  }

  Future<List<Device>> devices() => db.allDevices();

  // --- Inspections of other people's packs ---
  //
  // Deliberately not scoped to the active pack: an inspection is not a
  // battery's history and the pack it looked at is never adopted.

  Future<int> saveInspection(InspectionsCompanion row) =>
      db.insertInspection(row);

  Future<List<Inspection>> inspections() => db.allInspections();

  /// The earlier runs on one pack, decoded and oldest first.
  ///
  /// [before] and [excludeId] are for rereading a saved run: the comparison
  /// then shows what was known that day rather than what is known now, which
  /// is the only reading of it that stays true.
  Future<List<PastInspection>> pastInspections({
    required String bmsId,
    String serialNumber = '',
    DateTime? before,
    int? excludeId,
  }) async {
    final rows = await db.inspectionsForPack(bmsId, serialNumber: serialNumber);
    final out = <PastInspection>[];
    for (final row in rows) {
      if (row.id == excludeId) continue;
      if (before != null && !row.at.isBefore(before)) continue;
      final InspectionResult result;
      try {
        result = InspectionResult.fromJson(
          (jsonDecode(row.resultJson) as Map).cast<String, Object?>(),
        );
      } on Object {
        // A row written by a newer version, or a corrupted one. A comparison
        // is worth less than a crash costs.
        continue;
      }
      out.add(
        PastInspection(
          at: row.at,
          result: result,
          id: row.id,
          bmsId: row.bmsId,
          note: row.note,
        ),
      );
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  Future<Map<String, int>> inspectionCountsByPack() =>
      db.inspectionCountsByPack();

  Stream<List<Inspection>> watchInspections() => db.watchInspections();

  Future<void> deleteInspection(int id) => db.deleteInspection(id);

  Future<void> setInspectionNote(int id, String note) =>
      db.setInspectionNote(id, note);

  Stream<List<Device>> watchDevices() => db.watchDevices();

  Future<Device?> device(String id) => db.device(id);

  Future<void> setDeviceName(String id, String name) =>
      db.updateDevice(id, DevicesCompanion(name: Value(name)));

  /// The rider stating what the pack was sold as. Sticks, and outranks the BMS.
  Future<void> setDeviceCatalogue(String id, double ah) => db.updateDevice(
    id,
    DevicesCompanion(
      catalogueCapacityAh: Value(ah),
      catalogueFromBms: const Value(false),
    ),
  );

  /// The app taking the BMS's configured nominal, so the health figures work
  /// on the first connection without anybody typing anything.
  ///
  /// Only ever fills a blank. It will not overwrite a figure the rider stated,
  /// because the disagreement between the two is itself a finding: a pack sold
  /// as 45 Ah whose BMS is set to 40 is telling you something, and silently
  /// adopting the 40 would erase it.
  Future<bool> adoptDeviceCatalogueFromBms(String id, double ah) async {
    if (ah <= 0 || ah > 2000) return false;
    final existing = await db.device(id);
    if (existing == null) return false;
    if (existing.catalogueCapacityAh != null && !existing.catalogueFromBms) {
      return false;
    }
    if (existing.catalogueCapacityAh == ah && existing.catalogueFromBms) {
      return false;
    }
    await db.updateDevice(
      id,
      DevicesCompanion(
        catalogueCapacityAh: Value(ah),
        catalogueFromBms: const Value(true),
      ),
    );
    return true;
  }

  Future<void> deleteDevice(String id) => db.deleteDevice(id);

  /// How many rows predate the app tracking packs at all.
  Future<Map<String, int>> orphanCounts() => db.orphanCounts();

  Future<int> totalOrphans() async {
    final counts = await db.orphanCounts();
    return counts.values.fold<int>(0, (a, b) => a + b);
  }

  Future<void> adoptOrphans(String deviceId) => db.adoptOrphans(deviceId);

  Future<void> discardOrphans() => db.discardOrphans();
  Future<void> dispose() async {
    _flushTimer?.cancel();
    await flush();
    await db.close();
  }
}

/// What the database is costing.
class StorageStats {
  const StorageStats({
    required this.snapshots,
    required this.rawFrames,
    required this.bytes,
  });

  final int snapshots;
  final int rawFrames;
  final int bytes;

  double get megabytes => bytes / (1024 * 1024);
}
