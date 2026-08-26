import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

part 'database.g.dart';

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

  /// What the pack was sold as, so the comparison survives a settings change.
  RealColumn get catalogueAh => real()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  /// True when the app found this cycle in the history rather than the rider
  /// starting it by hand. Both are real measurements; the distinction matters
  /// because an automatic one may have gaps where the app was not connected.
  BoolColumn get automatic => boolean().withDefault(const Constant(false))();

  /// Seconds of the discharge that were not observed. Zero on a clean run.
  IntColumn get gapSeconds => integer().withDefault(const Constant(0))();
  TextColumn get note => text().withDefault(const Constant(''))();
}

@DriftDatabase(
  tables: [Trips, TripPoints, Snapshots, RawFrames, CapacityTests],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

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
        },
      );

  // --- Trips ---

  Future<int> insertTrip(TripsCompanion trip) =>
      into(trips).insert(trip);

  Future<void> insertTripPoints(List<TripPointsCompanion> points) =>
      batch((b) => b.insertAll(tripPoints, points));

  /// Most recent first.
  Future<List<Trip>> recentTrips({int limit = 50}) =>
      (select(trips)
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
            ..limit(limit))
          .get();

  Stream<List<Trip>> watchTrips({int limit = 50}) =>
      (select(trips)
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

  Future<List<Snapshot>> snapshotsBetween(DateTime from, DateTime to) =>
      (select(snapshots)
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

  Future<List<RawFrame>> rawFramesSince(DateTime from) =>
      (select(rawFrames)
            ..where((f) => f.timestamp.isBiggerOrEqualValue(from))
            ..orderBy([(f) => OrderingTerm.asc(f.timestamp)]))
          .get();

  Future<int> countRawFrames() async {
    final row = await (selectOnly(rawFrames)
          ..addColumns([rawFrames.id.count()]))
        .getSingle();
    return row.read(rawFrames.id.count()) ?? 0;
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

  Future<List<CapacityTest>> allCapacityTests() =>
      (select(capacityTests)
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
