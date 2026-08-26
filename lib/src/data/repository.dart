import 'dart:async';

import 'package:drift/drift.dart';

import '../metrics/capacity_cycle_detector.dart';
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
  BmsRepository({AppDatabase? database, this.flushInterval = const Duration(seconds: 5)})
      : db = database ?? AppDatabase() {
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

  /// Raw frame capture can be turned off, but the default is on and it should
  /// stay on: it is what makes a wrongly-decoded offset recoverable.
  bool recordRawFrames = true;

  /// Queues one decoded reading.
  void addSnapshot(BmsSnapshot s) {
    final temps = <double>[
      ...s.temperatures,
      if (s.mosfetTemp != null) s.mosfetTemp!,
    ];
    _pendingSnapshots.add(
      SnapshotsCompanion.insert(
        timestamp: s.timestamp,
        tripId: Value(currentTripId),
        packVoltage: s.packVoltage,
        current: s.current,
        soc: s.soc,
        soh: s.soh,
        remainingAh: s.remainingCapacityAh,
        cycleCount: s.cycleCount.toDouble(),
        deltaVolts: s.deltaCellVoltage,
        minCellVoltage: s.minCellVoltage,
        maxCellVoltage: s.maxCellVoltage,
        maxTemperature:
            temps.isEmpty ? 0 : temps.reduce((a, b) => a > b ? a : b),
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
    _pendingFrames.add(
      RawFramesCompanion.insert(
        timestamp: frame.receivedAt,
        recordType: frame.rawType,
        bytes: frameBytes(frame.bytes),
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
  Future<void> finishTrip(
    int tripId,
    TripSummary summary,
    List<TrackPoint> points,
  ) async {
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
  Future<List<Trip>> tripsForLearning({required bool demo}) async {
    final all = await db.recentTrips(limit: 500);
    final usable = all
        .where((t) =>
            t.demo == demo &&
            t.distanceKm >= 0.2 &&
            t.energyOutWh > t.energyInWh)
        .toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return usable;
  }

  /// Trips for one world, newest first.
  Stream<List<Trip>> watchTrips({required bool demo, int limit = 100}) =>
      db.watchTrips(limit: limit).map(
            (trips) => trips.where((t) => t.demo == demo).toList(),
          );

  Future<List<TripPoint>> pointsFor(int tripId) => db.pointsFor(tripId);

  Future<void> deleteTrip(int tripId) => db.deleteTrip(tripId);

  Future<void> setTripNote(int tripId, String note) =>
      db.setTripNote(tripId, note);

  /// Drops raw frames past their retention window. Cheap, and worth doing on
  /// every start rather than waiting for the phone to fill up.
  Future<int> pruneRawFrames() =>
      db.pruneRawFrames(keep: rawFrameRetention);

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
    required double catalogueAh,
  }) =>
      db.insertCapacityTest(
        CapacityTestsCompanion.insert(
          startedAt: startedAt,
          startSoc: startSoc,
          endSoc: startSoc,
          startPackVoltage: startPackVoltage,
          endPackVoltage: startPackVoltage,
          measuredAh: 0,
          measuredWh: 0,
          catalogueAh: catalogueAh,
        ),
      );

  /// Called as the run goes, so a closed app costs seconds rather than hours.
  Future<void> updateCapacityProgress(
    int id, {
    required double measuredAh,
    required double measuredWh,
    required double endSoc,
    required double endPackVoltage,
  }) =>
      db.updateCapacityTest(
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
  }) =>
      db.updateCapacityTest(
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

  Future<List<CapacityTest>> capacityTests() => db.allCapacityTests();

  Future<int> countCompletedCapacityTests() async {
    final all = await db.allCapacityTests();
    return all.where((t) => t.completed).length;
  }

  /// A run that was interrupted, if there is one, so it can be picked back up.
  Future<CapacityTest?> unfinishedCapacityTest() async {
    final all = await db.allCapacityTests();
    for (final t in all) {
      if (!t.completed) return t;
    }
    return null;
  }

  /// Records a discharge the app found in the history rather than being told
  /// about. Skips one it has already stored.
  Future<bool> recordDetectedCycle(DetectedCycle cycle, double catalogueAh) async {
    final existing = await db.allCapacityTests();
    // Matched on the start instant: the same discharge scanned twice must not
    // become two measurements.
    if (cycleAlreadyRecorded(cycle.startedAt, existing.map((t) => t.startedAt))) {
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
        catalogueAh: catalogueAh,
        completed: const Value(true),
        automatic: const Value(true),
        gapSeconds: Value(cycle.gapSeconds),
      ),
    );
    return true;
  }

  /// Every reading stored, oldest first, for the cycle scan to work over.
  Future<List<Snapshot>> allSnapshots({int days = 180}) => db.snapshotsBetween(
        DateTime.now().toUtc().subtract(Duration(days: days)),
        DateTime.now().toUtc(),
      );
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
