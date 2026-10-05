import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:sqlite3/sqlite3.dart';

import 'fixtures/schema_v15_rides.dart';

/// The devices table as version 15 shipped it; the ride and reading tables
/// the from < 16 step rebuilds are in [v15RideTables].
const _v15Schema = [
  ...v15RideTables,
  '''
  CREATE TABLE devices (
    id TEXT NOT NULL PRIMARY KEY,
    name TEXT NOT NULL DEFAULT '',
    serial_number TEXT NOT NULL DEFAULT '',
    model TEXT NOT NULL DEFAULT '',
    catalogue_capacity_ah REAL,
    catalogue_from_bms INTEGER NOT NULL DEFAULT 0 CHECK (catalogue_from_bms IN (0, 1)),
    chemistry TEXT NOT NULL DEFAULT '',
    acquired_at INTEGER,
    first_seen_at INTEGER NOT NULL,
    last_seen_at INTEGER NOT NULL,
    demo INTEGER NOT NULL DEFAULT 0 CHECK (demo IN (0, 1)),
    brand TEXT
  )''',
];

int _epoch(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

/// A version 15 database with a JK and an ANT, a ride with its track, and a
/// reading from each pack. The ANT reading carries the filler 0 cycle count
/// version 15 wrote for a BMS that has no counter.
Database _populatedV15() {
  final raw = sqlite3.openInMemory();
  for (final statement in _v15Schema) {
    raw.execute(statement);
  }
  final t = _epoch(DateTime.utc(2026, 9, 20, 9));
  for (final (id, brand) in [('JK:01', 'jk'), ('ANT:01', 'ant')]) {
    raw.execute(
      'INSERT INTO devices (id, first_seen_at, last_seen_at, brand) '
      'VALUES (?, ?, ?, ?)',
      [id, t, t, brand],
    );
  }
  raw.execute(
    'INSERT INTO trips (started_at, ended_at, distance_km, moving_seconds, '
    'total_seconds, max_speed_kmh, energy_out_wh, energy_in_wh, start_soc, '
    'end_soc, min_pack_voltage, max_pack_voltage, max_discharge_current, '
    'max_temperature, max_delta_volts, climb_m, descent_m, device_id) '
    "VALUES (?, ?, 12.5, 1500, 1600, 58, 310, 4, 100, 68, 70.2, 82.1, 34, "
    "31, 0.021, 45, 40, 'JK:01')",
    [t, t + 1600],
  );
  raw.execute(
    'INSERT INTO trip_points (trip_id, timestamp, latitude, longitude, '
    'speed_kmh, altitude_m, pack_voltage, current, soc) '
    'VALUES (1, ?, 23.11, -82.36, 31.0, 24.0, 78.4, -19.2, 88.0)',
    [t + 60],
  );
  for (final (device, cycles) in [('JK:01', 3.0), ('ANT:01', 0.0)]) {
    raw.execute(
      'INSERT INTO snapshots (timestamp, trip_id, pack_voltage, current, soc, '
      'soh, remaining_ah, cycle_count, delta_volts, min_cell_voltage, '
      'max_cell_voltage, max_temperature, warnings_mask, balancer_active, '
      'cell_voltages_json, device_id) '
      "VALUES (?, NULL, 78.4, -19.2, 88.0, 97.0, 39.6, ?, 0.012, 3.905, "
      "3.917, 29.0, 0, 0, '[3.91]', ?)",
      [t + 60, cycles, device],
    );
  }
  raw.execute('PRAGMA user_version = 15');
  return raw;
}

void main() {
  group('upgrading from 15, when every reading claimed a temperature', () {
    late Database raw;
    late AppDatabase db;

    setUp(() {
      raw = _populatedV15();
      db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    });

    tearDown(() async => db.close());

    test('the ride, its track and both readings survive the rebuild', () async {
      final trips = await db.select(db.trips).get();
      expect(trips.single.distanceKm, 12.5);
      expect(trips.single.maxTemperature, 31);
      // The track hangs off the ride's id; a rebuild that renumbered rides
      // would orphan it.
      final points = await db.select(db.tripPoints).get();
      expect(points.single.tripId, trips.single.id);
      final readings = await db.select(db.snapshots).get();
      expect(readings, hasLength(2));
      expect(readings.every((r) => r.maxTemperature == 29.0), isTrue);
    });

    test("the ANT's filler cycle count is cleared, the JK's is kept", () async {
      final readings = await db.select(db.snapshots).get();
      final byDevice = {for (final r in readings) r.deviceId: r.cycleCount};
      expect(byDevice['JK:01'], 3.0);
      expect(byDevice['ANT:01'], isNull);
    });

    test('and the columns now take an honest nothing', () async {
      await db.insertSnapshots([
        SnapshotsCompanion.insert(
          timestamp: DateTime.utc(2026, 9, 21),
          deviceId: const Value('ANT:01'),
          packVoltage: 52,
          current: 0,
          soc: 50,
          soh: 100,
          remainingAh: 10,
          deltaVolts: 0.01,
          minCellVoltage: 3.7,
          maxCellVoltage: 3.71,
          warningsMask: 0,
          balancerActive: false,
          cellVoltagesJson: '[3.7]',
        ),
      ]);
      final stored = (await db.select(db.snapshots).get()).last;
      expect(stored.cycleCount, isNull);
      expect(stored.maxTemperature, isNull);
    });
  });
}
