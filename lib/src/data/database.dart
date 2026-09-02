import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

part 'database.g.dart';

/// One BMS this phone has connected to.
///
/// Everything the app concludes -- capacity, degradation, which cell lags,
/// what a kilometre costs -- is about a specific pack. Pooling two packs into
/// one history does not average them, it produces a third set of numbers that
/// describes no battery that exists. So every row that records something
/// observed carries the pack it was observed on.
///
/// Keyed on the BLE address, which is what identifies the module before a
/// single frame has been parsed, and which does not rotate on a peripheral
/// like this one.
class Devices extends Table {
  TextColumn get id => text()();

  /// What the BMS advertises, or whatever the rider renames it to.
  TextColumn get name => text().withDefault(const Constant(''))();

  /// From the device info frame, once one has arrived.
  TextColumn get serialNumber => text().withDefault(const Constant(''))();
  TextColumn get model => text().withDefault(const Constant(''))();

  /// What *this* pack was sold as, or null when nobody has said.
  ///
  /// Nullable, with no default, because a default here is a claim about a
  /// battery nobody made. A new pack used to be born holding 45 Ah -- so
  /// connecting to a 35 Ah bike produced a health figure measured against a
  /// number this app invented, indistinguishable on screen from one the rider
  /// had entered. Unknown has to look like unknown.
  RealColumn get catalogueCapacityAh => real().nullable()();

  /// True when the figure above was taken from the BMS's own configuration
  /// rather than stated by the rider.
  ///
  /// Tracked rather than hidden. Adopting the BMS nominal makes the app useful
  /// the moment it connects, but it is still somebody else's number: whoever
  /// assembled the pack typed it. Keeping the provenance means the health
  /// figures can work immediately without the app ever passing that number off
  /// as what the pack was sold as -- which is the comparison the whole health
  /// section is built on, and the one place a borrowed figure would quietly
  /// erase a real finding.
  BoolColumn get catalogueFromBms => boolean().withDefault(const Constant(false))();

  DateTimeColumn get firstSeenAt => dateTime()();
  DateTimeColumn get lastSeenAt => dateTime()();

  /// True for the simulated pack, so demo data stays in its own world.
  BoolColumn get demo => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Something the rider did to a pack.
///
/// The point is the charts. A capacity that jumps, a delta that collapses or a
/// consumption that shifts all look like noise until you can see that a cell
/// was replaced that week. Without this the history records what the pack did
/// and forgets everything that was done to it, which is half the story.
class MaintenanceEvents extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Which pack it was done to. Not nullable: an event with no battery is a
  /// note about nothing.
  TextColumn get deviceId => text()();

  /// When it happened, which is the rider's answer and not necessarily when
  /// they wrote it down.
  DateTimeColumn get at => dateTime()();

  /// One of [MaintenanceKind], stored by name so a reordered enum cannot
  /// silently relabel history.
  TextColumn get kind => text()();

  TextColumn get note => text().withDefault(const Constant(''))();
}

/// One completed ride.
class Trips extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime()();
  RealColumn get distanceKm => real()();
  IntColumn get movingSeconds => integer()();
  IntColumn get totalSeconds => integer()();
  RealColumn get maxSpeedKmh => real()();
  RealColumn get energyOutWh => real()();
  RealColumn get energyInWh => real()();
  RealColumn get startSoc => real()();
  RealColumn get endSoc => real()();
  RealColumn get minPackVoltage => real()();
  RealColumn get maxPackVoltage => real()();
  RealColumn get maxDischargeCurrent => real()();
  RealColumn get maxTemperature => real()();
  RealColumn get maxDeltaVolts => real()();
  RealColumn get climbM => real()();
  RealColumn get descentM => real()();

  /// Free-text note the rider can add afterwards.
  TextColumn get note => text().withDefault(const Constant(''))();

  /// True for a ride recorded against the simulated pack.
  ///
  /// Kept and shown rather than discarded, because a demo ride is useful for
  /// checking the app works. But it is excluded from the range learning and
  /// from the totals: a made-up ride teaching the real range estimate is
  /// exactly the kind of quiet wrongness this app is built to avoid.
  BoolColumn get demo => boolean().withDefault(const Constant(false))();
  /// Which pack this was recorded on. Null for rows written before the app
  /// tracked packs at all -- see [BmsRepository.orphanCounts].
  TextColumn get deviceId => text().nullable()();

  // What the app concluded when this ride ended.
  //
  // These are stored rather than recomputed because they cannot be
  // recomputed. "The estimate moved from 41 to 39 Wh/km" is a statement about
  // a moment: by the time anybody looks again the estimator has learned from
  // every later ride, and asking it now returns today's answer to a question
  // that was asked months ago. The conclusions used to appear once, in a sheet
  // at the end of the ride, and be gone the moment it was dismissed.
  //
  // Null on every ride recorded before this was kept, which the screen says
  // rather than filling in with a plausible number.

  /// The learned consumption before this ride was folded in.
  RealColumn get whPerKmBefore => real().nullable()();

  /// And after, which is what the range was quoted from next.
  RealColumn get whPerKmAfter => real().nullable()();

  /// Kilometres of usable riding the estimate rested on at that point.
  RealColumn get learnedKm => real().nullable()();

  /// Range at the charge the ride ended on.
  RealColumn get rangeKmAtEnd => real().nullable()();

  /// How much the estimate was worth then, by name.
  TextColumn get confidence => text().nullable()();

}

/// The track of a ride, one row per fix, with what the pack was doing at that
/// moment. Kept together so a hill and a voltage sag can be lined up later.
class TripPoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tripId =>
      integer().references(Trips, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get timestamp => dateTime()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get speedKmh => real()();

  /// Smoothed altitude, in metres. See [AltitudeTracker] for why it is not raw.
  RealColumn get altitudeM => real()();
  RealColumn get packVoltage => real()();
  RealColumn get current => real()();
  RealColumn get soc => real()();
}

/// Every decoded reading, at full resolution.
class Snapshots extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get timestamp => dateTime()();
  IntColumn get tripId => integer().nullable()();
  RealColumn get packVoltage => real()();
  RealColumn get current => real()();
  RealColumn get soc => real()();
  RealColumn get soh => real()();
  RealColumn get remainingAh => real()();
  RealColumn get cycleCount => real()();

  /// Total charge that has ever passed through the pack, in amp-hours.
  ///
  /// Stored because without it the honest cycle count cannot be worked out
  /// from history: throughput divided by capacity is the real figure, and the
  /// BMS's own counter increments on partial charges so it always reads
  /// higher. Missing this column meant the offline summary could only repeat
  /// the inflated number it exists to correct.
  RealColumn get cycleCapacityAh => real().withDefault(const Constant(0))();
  RealColumn get deltaVolts => real()();
  RealColumn get minCellVoltage => real()();
  RealColumn get maxCellVoltage => real()();
  RealColumn get maxTemperature => real()();
  RealColumn get mosfetTemp => real().nullable()();
  IntColumn get warningsMask => integer()();
  BoolColumn get balancerActive => boolean()();

  /// Cell voltages as a JSON array. A column per cell would mean a schema
  /// migration every time a pack with a different cell count turns up.
  TextColumn get cellVoltagesJson => text()();
  /// Which pack this was recorded on. Null for rows written before the app
  /// tracked packs at all -- see [BmsRepository.orphanCounts].
  TextColumn get deviceId => text().nullable()();

}

/// The raw 300-byte frames, exactly as they arrived.
///
/// This is not optional. Several byte offsets in this protocol are still
/// uncertain (see docs/PROTOCOL.md). When one of them turns out to be wrong —
/// and one will — these rows are the difference between reparsing months of
/// history and losing it.
class RawFrames extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get timestamp => dateTime()();
  IntColumn get recordType => integer()();
  BlobColumn get bytes => blob()();
  /// Which pack this was recorded on. Null for rows written before the app
  /// tracked packs at all -- see [BmsRepository.orphanCounts].
  TextColumn get deviceId => text().nullable()();

}

/// A guided full-discharge capacity measurement.
class CapacityTests extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  RealColumn get startSoc => real()();
  RealColumn get endSoc => real()();
  RealColumn get startPackVoltage => real()();
  RealColumn get endPackVoltage => real()();

  /// Amp-hours actually drawn out between the two ends.
  RealColumn get measuredAh => real()();
  RealColumn get measuredWh => real()();

  /// What the pack was sold as at the time, or null if it was never stated.
  ///
  /// The amp-hours measured are worth keeping either way: the measurement is
  /// the fact, the comparison is the opinion.
  RealColumn get catalogueAh => real().nullable()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  /// True when the app found this cycle in the history rather than the rider
  /// starting it by hand. Both are real measurements; the distinction matters
  /// because an automatic one may have gaps where the app was not connected.
  BoolColumn get automatic => boolean().withDefault(const Constant(false))();

  /// Seconds of the discharge that were not observed. Zero on a clean run.
  IntColumn get gapSeconds => integer().withDefault(const Constant(0))();
  TextColumn get note => text().withDefault(const Constant(''))();
  /// Which pack this was recorded on. Null for rows written before the app
  /// tracked packs at all -- see [BmsRepository.orphanCounts].
  TextColumn get deviceId => text().nullable()();

}

@DriftDatabase(
  tables: [
    Devices,
    Trips,
    TripPoints,
    Snapshots,
    RawFrames,
    CapacityTests,
    MaintenanceEvents,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Demo rides used to be indistinguishable from real ones.
            await m.addColumn(trips, trips.demo);
          }
          if (from < 3) {
            // Capacity measurements used to be manual only.
            await m.addColumn(capacityTests, capacityTests.automatic);
            await m.addColumn(capacityTests, capacityTests.gapSeconds);
          }
          if (from < 4) {
            // Until now every reading landed in one pile regardless of which
            // pack produced it. Existing rows keep a null deviceId rather than
            // being guessed into a pack: the app can offer to adopt them, and
            // a wrong guess here would be indistinguishable from a measurement.
            await m.createTable(devices);
            await m.addColumn(trips, trips.deviceId);
            await m.addColumn(snapshots, snapshots.deviceId);
            await m.addColumn(rawFrames, rawFrames.deviceId);
            await m.addColumn(capacityTests, capacityTests.deviceId);
          }
          // Each step has to work from every older version, not just the one
          // before it. Recreating a table always builds it from the *current*
          // schema, so a later column has to be declared as new here or the
          // copy fails looking for a column the old table never had.
          if (from < 5) {
            // The catalogue capacity becomes nullable, and every existing row
            // is cleared. Nothing recorded whether a value had been entered or
            // was the old 45 Ah default, and a wrong catalogue does not fail
            // loudly -- it quietly rescales every health figure for that pack.
            // Asking once beats carrying a number that might be fiction.
            await m.alterTable(
              TableMigration(devices, newColumns: [devices.catalogueFromBms]),
            );
            await m.alterTable(TableMigration(capacityTests));
            await customStatement('UPDATE devices SET catalogue_capacity_ah = NULL');
          }
          // Only from exactly 5: anything older has already been handed the
          // column, either by createTable or by the recreation above. Adding
          // it twice fails with a duplicate-column error that stops the app
          // opening at all.
          if (from == 5) {
            await m.addColumn(devices, devices.catalogueFromBms);
          }
          if (from < 7) {
            await m.addColumn(snapshots, snapshots.cycleCapacityAh);
          }
          if (from < 8) {
            await m.createTable(maintenanceEvents);
          }
          if (from < 9) {
            // Rides recorded before this keep nulls. There is no honest way to
            // backfill what the estimate used to say.
            await m.addColumn(trips, trips.whPerKmBefore);
            await m.addColumn(trips, trips.whPerKmAfter);
            await m.addColumn(trips, trips.learnedKm);
            await m.addColumn(trips, trips.rangeKmAtEnd);
            await m.addColumn(trips, trips.confidence);
          }
        },
      );

  /// Thins old readings down to one per bucket.
  ///
  /// At 1 Hz an hour of riding a day is over a million rows a year, and
  /// nothing was ever removing them. The screens that read a pack's whole
  /// history would have taken seconds to open and eventually run out of
  /// memory.
  ///
  /// It thins rather than averages. An averaged row would be a reading that
  /// never happened, sitting in the same table as real ones, and this app does
  /// not do that anywhere else either. What survives is genuinely observed.
  ///
  /// The cost is that peaks between kept readings are lost once a period is
  /// compacted. That is acceptable because peaks are already preserved where
  /// they matter: every ride stores its own maximum delta, temperature and
  /// current in the trips table, and those rows are never thinned.
  ///
  /// Returns how many rows went.
  Future<int> compactSnapshots({
    Duration keepFullResolution = const Duration(days: 30),
    Duration bucket = const Duration(minutes: 1),
  }) async {
    final cutoff = DateTime.now().toUtc().subtract(keepFullResolution);
    final cutoffSeconds = cutoff.millisecondsSinceEpoch ~/ 1000;
    final bucketSeconds = bucket.inSeconds;
    if (bucketSeconds <= 0) return 0;

    // Drift stores DateTime as unix seconds, so integer division buckets them.
    // Grouping by device as well as bucket keeps two packs read in the same
    // minute from collapsing into one row.
    return customUpdate(
      'DELETE FROM snapshots WHERE timestamp < ?1 AND id NOT IN ('
      '  SELECT MAX(id) FROM snapshots WHERE timestamp < ?1'
      '  GROUP BY device_id, timestamp / ?2'
      ')',
      variables: [
        Variable<int>(cutoffSeconds),
        Variable<int>(bucketSeconds),
      ],
      updates: {snapshots},
    );
  }

  /// How many readings are stored for one pack, without loading any of them.
  Future<int> snapshotCountFor(String deviceId) async {
    final row = await (selectOnly(snapshots)
          ..addColumns([snapshots.id.count()])
          ..where(snapshots.deviceId.equals(deviceId)))
        .getSingle();
    return row.read(snapshots.id.count()) ?? 0;
  }

  /// The oldest reading for a pack, for saying how far the history goes back
  /// without reading the history.
  Future<DateTime?> firstSnapshotAt(String deviceId) async {
    final row = await (select(snapshots)
          ..where((s) => s.deviceId.equals(deviceId))
          ..orderBy([(s) => OrderingTerm.asc(s.timestamp)])
          ..limit(1))
        .getSingleOrNull();
    return row?.timestamp;
  }

  /// The most recent reading for a pack.
  Future<Snapshot?> lastSnapshotFor(String deviceId) => (select(snapshots)
        ..where((s) => s.deviceId.equals(deviceId))
        ..orderBy([(s) => OrderingTerm.desc(s.timestamp)])
        ..limit(1))
      .getSingleOrNull();

  // --- Maintenance ---

  Future<int> insertMaintenance(MaintenanceEventsCompanion e) =>
      into(maintenanceEvents).insert(e);

  Future<void> deleteMaintenance(int id) =>
      (delete(maintenanceEvents)..where((e) => e.id.equals(id))).go();

  Future<void> updateMaintenance(int id, MaintenanceEventsCompanion values) =>
      (update(maintenanceEvents)..where((e) => e.id.equals(id))).write(values);

  /// Newest first, for one pack.
  Future<List<MaintenanceEvent>> maintenanceFor(String deviceId) =>
      (select(maintenanceEvents)
            ..where((e) => e.deviceId.equals(deviceId))
            ..orderBy([(e) => OrderingTerm.desc(e.at)]))
          .get();

  Future<List<MaintenanceEvent>> allMaintenanceForBackup() =>
      select(maintenanceEvents).get();

  // --- Backup ---

  //
  // Unscoped on purpose, unlike every other read here: a backup is the whole
  // database, not one battery's history.

  Future<List<Trip>> allTripsForBackup() => select(trips).get();
  Future<List<TripPoint>> allTripPointsForBackup() => select(tripPoints).get();
  Future<List<Snapshot>> allSnapshotsForBackup() => select(snapshots).get();
  Future<List<RawFrame>> allRawFramesForBackup() => select(rawFrames).get();
  Future<List<CapacityTest>> allCapacityTestsForBackup() =>
      select(capacityTests).get();

  /// Empties every table, for a restore that is meant to replace rather than
  /// merge. Order matters only for the tracks, which reference their ride.
  Future<void> wipeEverything() async {
    await delete(tripPoints).go();
    await delete(trips).go();
    await delete(snapshots).go();
    await delete(rawFrames).go();
    await delete(capacityTests).go();
    await delete(maintenanceEvents).go();
    await delete(devices).go();
  }

  // --- Devices ---

  Future<void> upsertDevice(DevicesCompanion device) =>
      into(devices).insertOnConflictUpdate(device);

  Future<Device?> device(String id) =>
      (select(devices)..where((d) => d.id.equals(id))).getSingleOrNull();

  /// Most recently seen first, so the pack in your hand is at the top.
  Future<List<Device>> allDevices() =>
      (select(devices)..orderBy([(d) => OrderingTerm.desc(d.lastSeenAt)])).get();

  Stream<List<Device>> watchDevices() =>
      (select(devices)..orderBy([(d) => OrderingTerm.desc(d.lastSeenAt)]))
          .watch();

  Future<void> updateDevice(String id, DevicesCompanion values) =>
      (update(devices)..where((d) => d.id.equals(id))).write(values);

  /// Removes a pack and everything recorded on it.
  Future<void> deleteDevice(String id) async {
    final rides = await (select(trips)..where((t) => t.deviceId.equals(id)))
        .get();
    for (final ride in rides) {
      await (delete(tripPoints)..where((p) => p.tripId.equals(ride.id))).go();
    }
    await (delete(trips)..where((t) => t.deviceId.equals(id))).go();
    await (delete(snapshots)..where((s) => s.deviceId.equals(id))).go();
    await (delete(rawFrames)..where((f) => f.deviceId.equals(id))).go();
    await (delete(capacityTests)..where((t) => t.deviceId.equals(id))).go();
    await (delete(maintenanceEvents)..where((e) => e.deviceId.equals(id))).go();
    await (delete(devices)..where((d) => d.id.equals(id))).go();
  }

  // --- Rows written before the app knew about packs ---

  Future<int> _countOrphans(TableInfo<Table, dynamic> table, GeneratedColumn<String> col) async {
    final row = await customSelect(
      'SELECT COUNT(*) AS c FROM ${table.actualTableName} WHERE ${col.name} IS NULL',
      readsFrom: {table},
    ).getSingle();
    return row.read<int>('c');
  }

  /// How much history has no pack attached, per table.
  Future<Map<String, int>> orphanCounts() async => {
        'trips': await _countOrphans(trips, trips.deviceId),
        'snapshots': await _countOrphans(snapshots, snapshots.deviceId),
        'rawFrames': await _countOrphans(rawFrames, rawFrames.deviceId),
        'capacityTests':
            await _countOrphans(capacityTests, capacityTests.deviceId),
      };

  /// Assigns every unattached row to one pack.
  ///
  /// Only ever done because the rider said so. The app cannot work out which
  /// pack produced a row it recorded before it tracked packs, and inventing an
  /// answer would put fabricated provenance next to real measurements.
  Future<void> adoptOrphans(String deviceId) async {
    await customUpdate(
      'UPDATE trips SET device_id = ? WHERE device_id IS NULL',
      variables: [Variable<String>(deviceId)],
      updates: {trips},
    );
    await customUpdate(
      'UPDATE snapshots SET device_id = ? WHERE device_id IS NULL',
      variables: [Variable<String>(deviceId)],
      updates: {snapshots},
    );
    await customUpdate(
      'UPDATE raw_frames SET device_id = ? WHERE device_id IS NULL',
      variables: [Variable<String>(deviceId)],
      updates: {rawFrames},
    );
    await customUpdate(
      'UPDATE capacity_tests SET device_id = ? WHERE device_id IS NULL',
      variables: [Variable<String>(deviceId)],
      updates: {capacityTests},
    );
  }

  /// Discards unattached rows outright, for a rider who would rather start
  /// clean than guess.
  Future<void> discardOrphans() async {
    await customUpdate('DELETE FROM trip_points WHERE trip_id IN '
        '(SELECT id FROM trips WHERE device_id IS NULL)', updates: {tripPoints});
    await customUpdate('DELETE FROM trips WHERE device_id IS NULL',
        updates: {trips});
    await customUpdate('DELETE FROM snapshots WHERE device_id IS NULL',
        updates: {snapshots});
    await customUpdate('DELETE FROM raw_frames WHERE device_id IS NULL',
        updates: {rawFrames});
    await customUpdate('DELETE FROM capacity_tests WHERE device_id IS NULL',
        updates: {capacityTests});
  }

  // --- Trips ---

  Future<int> insertTrip(TripsCompanion trip) =>
      into(trips).insert(trip);

  Future<void> insertTripPoints(List<TripPointsCompanion> points) =>
      batch((b) => b.insertAll(tripPoints, points));

  /// Most recent first, for one pack.
  ///
  /// Every read here takes a pack. There is deliberately no unscoped variant:
  /// an accidental call to one would silently mix two batteries' histories,
  /// which is the exact failure this table structure exists to prevent.
  Future<List<Trip>> recentTrips(String deviceId, {int limit = 50}) =>
      (select(trips)
            ..where((t) => t.deviceId.equals(deviceId))
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
            ..limit(limit))
          .get();

  Stream<List<Trip>> watchTrips(String deviceId, {int limit = 50}) =>
      (select(trips)
            ..where((t) => t.deviceId.equals(deviceId))
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
            ..limit(limit))
          .watch();

  Future<List<TripPoint>> pointsFor(int tripId) =>
      (select(tripPoints)
            ..where((t) => t.tripId.equals(tripId))
            ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
          .get();

  Future<void> deleteTrip(int tripId) async {
    await (delete(tripPoints)..where((t) => t.tripId.equals(tripId))).go();
    await (delete(trips)..where((t) => t.id.equals(tripId))).go();
  }

  Future<void> updateTrip(int tripId, TripsCompanion values) =>
      (update(trips)..where((t) => t.id.equals(tripId))).write(values);

  Future<void> setTripNote(int tripId, String note) =>
      (update(trips)..where((t) => t.id.equals(tripId)))
          .write(TripsCompanion(note: Value(note)));

  // --- Snapshots ---

  Future<void> insertSnapshots(List<SnapshotsCompanion> rows) =>
      batch((b) => b.insertAll(snapshots, rows));

  Future<List<Snapshot>> snapshotsBetween(
    String deviceId,
    DateTime from,
    DateTime to,
  ) =>
      (select(snapshots)
            ..where((s) => s.deviceId.equals(deviceId))
            ..where((s) => s.timestamp.isBiggerOrEqualValue(from))
            ..where((s) => s.timestamp.isSmallerOrEqualValue(to))
            ..orderBy([(s) => OrderingTerm.asc(s.timestamp)]))
          .get();

  // --- Raw frames ---

  Future<void> insertRawFrames(List<RawFramesCompanion> rows) =>
      batch((b) => b.insertAll(rawFrames, rows));

  /// Drops frames older than [keep]. Roughly 25 MB a day of active use, so
  /// without rotation this would fill the phone in a couple of months.
  Future<int> pruneRawFrames({Duration keep = const Duration(days: 30)}) {
    final cutoff = DateTime.now().toUtc().subtract(keep);
    return (delete(rawFrames)..where((f) => f.timestamp.isSmallerThanValue(cutoff)))
        .go();
  }

  Future<List<RawFrame>> rawFramesSince(String deviceId, DateTime from) =>
      (select(rawFrames)
            ..where((f) => f.deviceId.equals(deviceId))
            ..where((f) => f.timestamp.isBiggerOrEqualValue(from))
            ..orderBy([(f) => OrderingTerm.asc(f.timestamp)]))
          .get();

  Future<int> countRawFrames() async {
    final row = await (selectOnly(rawFrames)
          ..addColumns([rawFrames.id.count()]))
        .getSingle();
    return row.read(rawFrames.id.count()) ?? 0;
  }

  /// Every ride on record, whatever pack it belongs to. Used for housekeeping
  /// rather than for anything a rider reads, since a count across packs is not
  /// a fact about any battery.
  Future<int> totalTripCount() async {
    final row = await (selectOnly(trips)..addColumns([trips.id.count()]))
        .getSingle();
    return row.read(trips.id.count()) ?? 0;
  }

  Future<int> countSnapshots() async {
    final row = await (selectOnly(snapshots)
          ..addColumns([snapshots.id.count()]))
        .getSingle();
    return row.read(snapshots.id.count()) ?? 0;
  }

  // --- Capacity tests ---

  Future<int> insertCapacityTest(CapacityTestsCompanion test) =>
      into(capacityTests).insert(test);

  Future<void> updateCapacityTest(int id, CapacityTestsCompanion values) =>
      (update(capacityTests)..where((t) => t.id.equals(id))).write(values);

  Future<void> deleteCapacityTest(int id) =>
      (delete(capacityTests)..where((t) => t.id.equals(id))).go();

  Future<List<CapacityTest>> allCapacityTests(String deviceId) =>
      (select(capacityTests)
            ..where((t) => t.deviceId.equals(deviceId))
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
          .get();

  /// Total bytes the database file occupies.
  static Future<int> fileSizeBytes() async {
    final file = await _databaseFile();
    return file.existsSync() ? file.lengthSync() : 0;
  }
}

Future<File> _databaseFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File(p.join(dir.path, 'jk_bms.sqlite'));
}

QueryExecutor _open() {
  return LazyDatabase(() async {
    final file = await _databaseFile();
    // Large batch writes spill to a temp file; without this sqlite3 picks a
    // directory Android will not let it write to.
    sqlite3.tempDirectory = (await getTemporaryDirectory()).path;
    return NativeDatabase.createInBackground(file);
  });
}

/// Helpers for the JSON cell voltage column.
List<double> decodeCellVoltages(String json) =>
    (jsonDecode(json) as List<dynamic>)
        .map((e) => (e as num).toDouble())
        .toList();

String encodeCellVoltages(List<double> volts) =>
    jsonEncode(volts.map((v) => double.parse(v.toStringAsFixed(3))).toList());

/// Frames are stored as-is; this just keeps the typing honest at the boundary.
Uint8List frameBytes(List<int> bytes) => Uint8List.fromList(bytes);
