import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:sqlite3/sqlite3.dart';

/// The trips table as version 17 shipped it: the hottest probe nullable since
/// 16, and no resistance yet. Written out longhand, like the older schemas, so
/// the step runs against what is on the phone rather than the current classes.
const _v17Trips = '''
  CREATE TABLE trips (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    started_at INTEGER NOT NULL,
    ended_at INTEGER NOT NULL,
    distance_km REAL NOT NULL,
    moving_seconds INTEGER NOT NULL,
    total_seconds INTEGER NOT NULL,
    max_speed_kmh REAL NOT NULL,
    energy_out_wh REAL NOT NULL,
    energy_in_wh REAL NOT NULL,
    start_soc REAL NOT NULL,
    end_soc REAL NOT NULL,
    min_pack_voltage REAL NOT NULL,
    max_pack_voltage REAL NOT NULL,
    max_discharge_current REAL NOT NULL,
    max_temperature REAL,
    max_delta_volts REAL NOT NULL,
    climb_m REAL NOT NULL,
    descent_m REAL NOT NULL,
    note TEXT NOT NULL DEFAULT '',
    demo INTEGER NOT NULL DEFAULT 0 CHECK (demo IN (0, 1)),
    device_id TEXT,
    wh_per_km_before REAL,
    wh_per_km_after REAL,
    learned_km REAL,
    range_km_at_end REAL,
    confidence TEXT,
    ah_out REAL,
    energy_source TEXT,
    representative INTEGER CHECK (representative IN (0, 1)),
    summary_seen INTEGER NOT NULL DEFAULT 0 CHECK (summary_seen IN (0, 1))
  )''';

Database _populatedV17() {
  final raw = sqlite3.openInMemory()..execute(_v17Trips);
  final t = DateTime.utc(2026, 9, 20, 9).millisecondsSinceEpoch ~/ 1000;
  raw.execute(
    'INSERT INTO trips (started_at, ended_at, distance_km, moving_seconds, '
    'total_seconds, max_speed_kmh, energy_out_wh, energy_in_wh, start_soc, '
    'end_soc, min_pack_voltage, max_pack_voltage, max_discharge_current, '
    'max_delta_volts, climb_m, descent_m, device_id, energy_source) '
    "VALUES (?, ?, 23.4, 3000, 3700, 48, 410, 0, 90, 50, 70.1, 81.2, 41, "
    "0.03, 40, 40, 'JK:01', 'coulombCount')",
    [t, t + 3700],
  );
  raw.execute('PRAGMA user_version = 17');
  return raw;
}

void main() {
  group('upgrading from 17, when a ride had no resistance', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.opened(_populatedV17()));
    });

    tearDown(() async => db.close());

    test('every ride is kept, with no resistance rather than a made-up one',
        () async {
      final trips = await db.recentTrips('JK:01', limit: 10);
      expect(trips, hasLength(1));
      expect(trips.single.distanceKm, 23.4);
      expect(trips.single.energySource, 'coulombCount');
      // Null, not 0: "no figure" and "no resistance" are different things,
      // and the trends screen works old rides out from their readings.
      expect(trips.single.packResistanceMilliohms, isNull);
    });

    test('and a new ride stores what it measured', () async {
      final id = await db.insertTrip(
        TripsCompanion.insert(
          deviceId: const Value('JK:01'),
          startedAt: DateTime.utc(2026, 9, 25),
          endedAt: DateTime.utc(2026, 9, 25, 1),
          distanceKm: 10,
          movingSeconds: 1500,
          totalSeconds: 1800,
          maxSpeedKmh: 40,
          energyOutWh: 180,
          energyInWh: 0,
          startSoc: 80,
          endSoc: 60,
          minPackVoltage: 72,
          maxPackVoltage: 80,
          maxDischargeCurrent: 30,
          maxDeltaVolts: 0.02,
          climbM: 0,
          descentM: 0,
          packResistanceMilliohms: const Value(22.5),
        ),
      );
      expect((await db.tripById(id))!.packResistanceMilliohms, 22.5);
    });
  });
}
