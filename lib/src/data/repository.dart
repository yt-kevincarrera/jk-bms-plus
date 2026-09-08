import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../inspection/inspection_result.dart';
import '../pack/pack_baseline.dart';
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
    // Rides the old repair gave up on are retried, once. That is what
    // [EnergySource.unmeasurable] was written down for: it marks a ride as
    // examined so every connection stops re-reading it, while staying findable
    // for a repair that knows something the last one did not. Whatever happens
    // below, they settle on a terminal marker and are not looked at again.
    // A ride the recorder called integrated that integrated nothing. Rides
    // recorded from now on say [EnergySource.unmeasurable] instead, but the
    // ones already on disk say this, and they are the rides this repair was
    // written for: the blackout ride that prompted all of it was stored this
    // way and the repair never once looked at it. Guarded on the energy
    // rather than the marker alone, so a ride that really was integrated,
    // which by definition had readings and therefore has energy, is left with
    // the measurement it made.
    bool integratedNothing(Trip t) =>
        t.energySource == EnergySource.integrated.name && t.energyOutWh <= 0;

    // A ride the recorder itself flagged as measured across only part of its
    // length. It carries an amp-hour figure of null and an energy of zero, so
    // it would not be caught by the clause above on its own, and it is worth
    // catching: the readings are on disk and the brackets either side of the
    // ride can still measure it.
    bool partiallyMeasured(Trip t) =>
        t.energySource == EnergySource.partialCoulombCount.name;

    final stale = [
      for (final t in trips)
        if (t.distanceKm > 0 &&
            (partiallyMeasured(t) ||
                (t.ahOut == null &&
                    (t.energySource == null ||
                        t.energySource == EnergySource.unmeasurable.name ||
                        integratedNothing(t)))))
          t,
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
      // Reaching past the ride, because a ride nothing was received during is
      // measured from the readings either side of it. Bounded by the repair's
      // own reach, so this stays a fixed cost rather than the unbounded read
      // that used to hold up every connection.
      final margin = repairer.bracketReach + const Duration(minutes: 1);
      final readings = await db.snapshotsBetween(
        deviceId,
        earliest.subtract(margin),
        latest.add(margin),
      );

      for (final t in group) {
        if (await _applyRepair(t, readings, repairer)) {
          repaired++;
        } else {
          unrepairable++;
        }
      }
    }

    return TripRepairReport(
      examined: stale.length,
      repaired: repaired,
      unrepairable: unrepairable,
    );
  }

  /// Whether a ride's stored energy figure was never a measurement of it: no
  /// source recorded, nothing arrived during it, the counter covered only part
  /// of it, or it claimed to have integrated and integrated nothing.
  ///
  /// Close to the staleness filter in [repairTripEnergy] but not the same
  /// question, which is why they are not shared. That one asks what is worth a
  /// cheap look on every connection, and guards on a null `ahOut` so a ride
  /// that really was integrated is passed over. This one asks whether there is
  /// anything in the row worth protecting from a demotion.
  static bool _wasNeverProperlyMeasured(Trip t) =>
      t.energySource == null ||
      t.energySource == EnergySource.unmeasurable.name ||
      t.energySource == EnergySource.partialCoulombCount.name ||
      (t.energySource == EnergySource.integrated.name && t.energyOutWh <= 0);

  /// Measures one ride again and writes what it finds. True if it could.
  Future<bool> _applyRepair(
    Trip t,
    List<Snapshot> readings,
    TripEnergyRepair repairer,
  ) async {
    final fixed = repairer.recompute(t, readings);
    if (fixed == null) {
      // Nothing could be measured. Whether to say so in the row depends on
      // what the row already claims, and getting that wrong costs real data.
      //
      // A ride that never had an honest figure settles on the terminal
      // marker, so it is never examined again -- left blank it stayed stale
      // forever and every connection paid for it -- and so it stops teaching
      // the estimator a number nobody can back up.
      //
      // A ride that *was* measured properly keeps everything. Readings are
      // thinned to one a minute after thirty days and eventually go, so a
      // ride old enough has nothing left to re-measure from; marking that
      // unmeasurable would drop a perfectly good ride out of the range
      // estimate for no reason other than the rider having pressed the button
      // out of curiosity. The automatic pass never reaches these rides, but
      // [repairTrip] is offered on every one.
      if (_wasNeverProperlyMeasured(t)) {
        // The energy it already has is left alone even so. A poor measurement
        // is still a measurement, and overwriting it with a zero would be
        // inventing a figure rather than admitting to a bad one. What stops it
        // teaching the estimator is the marker.
        await db.updateTrip(
          t.id,
          TripsCompanion(
            energySource: Value(EnergySource.unmeasurableBracketed.name),
          ),
        );
      }
      return false;
    }
    await db.updateTrip(
      t.id,
      TripsCompanion(
        energyOutWh: Value(fixed.outWh),
        energyInWh: Value(fixed.inWh),
        ahOut: Value(fixed.ahOut),
        energySource: Value(fixed.source.name),
        // Only present when the repair had to reach outside the ride, and
        // then only because the ride has none of its own.
        startSoc: fixed.startSoc == null
            ? const Value.absent()
            : Value(fixed.startSoc!),
        endSoc: fixed.endSoc == null
            ? const Value.absent()
            : Value(fixed.endSoc!),
      ),
    );
    return true;
  }

  /// Measures one ride again on demand, whatever its row currently claims.
  ///
  /// The automatic pass deliberately looks only at rides whose own row admits
  /// something is missing, because it runs on the first decoded frame of every
  /// connection and reading a week of history there once held up the live
  /// screen for the pack in front of the rider. That cheapness is also a
  /// blind spot: the two rides that prompted all of this were stored as
  /// [EnergySource.coulombCount] with an amp-hour figure and high confidence,
  /// so nothing in the row hinted at the problem and no pass would ever look
  /// again.
  ///
  /// This is the way back in. It is a rider asking about one ride they can see
  /// is wrong, so it can afford the read the automatic pass cannot, and it
  /// ignores the staleness filter entirely.
  Future<TripRepairReport> repairTrip(
    int tripId, {
    TripEnergyRepair repairer = const TripEnergyRepair(),
  }) async {
    await flush();
    final trip = await db.tripById(tripId);
    if (trip == null || trip.deviceId == null) return TripRepairReport.none;

    final margin = repairer.bracketReach + const Duration(minutes: 1);
    final readings = await db.snapshotsBetween(
      trip.deviceId!,
      trip.startedAt.subtract(margin),
      trip.endedAt.add(margin),
    );

    final repaired = await _applyRepair(trip, readings, repairer);
    return TripRepairReport(
      examined: 1,
      repaired: repaired ? 1 : 0,
      unrepairable: repaired ? 0 : 1,
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

  /// Sources whose energy figure is not a measurement of the ride, so nothing
  /// may be learned from it.
  ///
  /// This is the guard that was missing when a ride whose link died nine
  /// minutes in taught the estimator 4.3 Wh/km and had it quote 225 km of
  /// range. The estimator does reject the physically absurd -- anything under
  /// 2 Wh/km -- but 4.3 is not absurd in the abstract, only against this bike,
  /// and a threshold tuned to catch it would be a guess. The row already knows
  /// it was never measured properly; asking it is a fact rather than a guess.
  static const Set<String> _unmeasuredSources = {
    'partialCoulombCount',
    'unmeasurable',
    'unmeasurableBracketed',
  };

  Future<List<Trip>> tripsForLearning(String deviceId) async {
    final all = await db.recentTrips(deviceId, limit: 500);
    final usable =
        all
            .where(
              (t) =>
                  t.distanceKm >= 0.2 &&
                  t.energyOutWh > t.energyInWh &&
                  !_unmeasuredSources.contains(t.energySource) &&
                  // Null is not false: a ride nobody was asked about counts,
                  // which keeps the behaviour of every ride recorded before
                  // the question existed. Only an explicit no takes one out.
                  t.representative != false,
            )
            .toList()
          ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return usable;
  }

  Future<void> setTripRepresentative(int tripId, bool? value) =>
      db.setTripRepresentative(tripId, value);

  Future<void> markTripSummarySeen(int tripId) =>
      db.markTripSummarySeen(tripId);

  /// The most recent finished ride on this pack whose summary was never
  /// shown, or null.
  ///
  /// Only the latest one: a week of unseen rides queuing up on opening the
  /// app would be a punishment for having gone riding, not a feature. Demo
  /// rides are excluded for the same reason they are excluded from learning
  /// -- a made-up ride announcing itself would be the app talking about
  /// nothing. An open ride (no distance yet, [Trip.endedAt] still equal to
  /// its start) is skipped rather than offered half-finished.
  Future<Trip?> pendingSummaryTrip(String deviceId) async {
    final recent = await db.recentTrips(deviceId, limit: 20);
    for (final t in recent) {
      if (t.demo || t.summarySeen) continue;
      if (t.distanceKm <= 0) continue;
      return t;
    }
    return null;
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

  // --- The day-one baseline ---
  //
  // Written once per pack and then left alone. Overwriting it is offered as
  // a deliberate act elsewhere, never as a side effect of connecting: a
  // baseline that quietly follows the pack around measures nothing.

  Future<void> saveBaseline(
    String deviceId,
    PackBaseline baseline, {
    String note = '',
  }) => db.saveBaseline(
    BaselinesCompanion.insert(
      deviceId: deviceId,
      capturedAt: baseline.capturedAt,
      json: jsonEncode(baseline.toJson()),
      note: Value(note),
    ),
  );

  Future<PackBaseline?> baseline(String deviceId) async {
    final row = await db.baselineRow(deviceId);
    return _decodeBaseline(row);
  }

  Stream<PackBaseline?> watchBaseline(String deviceId) =>
      db.watchBaselineRow(deviceId).map(_decodeBaseline);

  Future<String> baselineNote(String deviceId) async =>
      (await db.baselineRow(deviceId))?.note ?? '';

  Future<void> setBaselineNote(String deviceId, String note) =>
      db.setBaselineNote(deviceId, note);

  Future<void> deleteBaseline(String deviceId) => db.deleteBaseline(deviceId);

  /// A row written by a newer version, or a corrupted one, reads as no
  /// baseline rather than as a crash on the screen that asked for it.
  static PackBaseline? _decodeBaseline(Baseline? row) {
    if (row == null) return null;
    try {
      return PackBaseline.fromJson(
        (jsonDecode(row.json) as Map).cast<String, Object?>(),
      );
    } on Object {
      return null;
    }
  }

  /// What the rider said about the pack itself, rather than about a reading.
  Future<void> setPackProfile(
    String id, {
    String? chemistry,
    DateTime? acquiredAt,
    bool clearAcquiredAt = false,
  }) => db.updateDevice(
    id,
    DevicesCompanion(
      chemistry: chemistry == null ? const Value.absent() : Value(chemistry),
      acquiredAt: clearAcquiredAt
          ? const Value(null)
          : (acquiredAt == null ? const Value.absent() : Value(acquiredAt)),
    ),
  );

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
