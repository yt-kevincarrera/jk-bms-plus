import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:sqlite3/sqlite3.dart';

/// The schema exactly as version 3 shipped, so the upgrade is exercised against
/// what is actually on the phone rather than against a fresh database.
///
/// Written out longhand on purpose. Generating it from the current classes
/// would test the migration against itself and pass no matter what.
const _v3Schema = [
  '''
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
    max_temperature REAL NOT NULL,
    max_delta_volts REAL NOT NULL,
    climb_m REAL NOT NULL,
    descent_m REAL NOT NULL,
    note TEXT NOT NULL DEFAULT '',
    demo INTEGER NOT NULL DEFAULT 0 CHECK (demo IN (0, 1))
  )''',
  '''
  CREATE TABLE trip_points (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    trip_id INTEGER NOT NULL REFERENCES trips (id) ON DELETE CASCADE,
    timestamp INTEGER NOT NULL,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    speed_kmh REAL NOT NULL,
    altitude_m REAL NOT NULL,
    pack_voltage REAL NOT NULL,
    current REAL NOT NULL,
    soc REAL NOT NULL
  )''',
  '''
  CREATE TABLE snapshots (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    timestamp INTEGER NOT NULL,
    trip_id INTEGER,
    pack_voltage REAL NOT NULL,
    current REAL NOT NULL,
    soc REAL NOT NULL,
    soh REAL NOT NULL,
    remaining_ah REAL NOT NULL,
    cycle_count REAL NOT NULL,
    delta_volts REAL NOT NULL,
    min_cell_voltage REAL NOT NULL,
    max_cell_voltage REAL NOT NULL,
    max_temperature REAL NOT NULL,
    mosfet_temp REAL,
    warnings_mask INTEGER NOT NULL,
    balancer_active INTEGER NOT NULL CHECK (balancer_active IN (0, 1)),
    cell_voltages_json TEXT NOT NULL
  )''',
  '''
  CREATE TABLE raw_frames (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    timestamp INTEGER NOT NULL,
    record_type INTEGER NOT NULL,
    bytes BLOB NOT NULL
  )''',
  '''
  CREATE TABLE capacity_tests (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    started_at INTEGER NOT NULL,
    ended_at INTEGER,
    start_soc REAL NOT NULL,
    end_soc REAL NOT NULL,
    start_pack_voltage REAL NOT NULL,
    end_pack_voltage REAL NOT NULL,
    measured_ah REAL NOT NULL,
    measured_wh REAL NOT NULL,
    catalogue_ah REAL NOT NULL,
    completed INTEGER NOT NULL DEFAULT 0 CHECK (completed IN (0, 1)),
    automatic INTEGER NOT NULL DEFAULT 0 CHECK (automatic IN (0, 1)),
    gap_seconds INTEGER NOT NULL DEFAULT 0,
    note TEXT NOT NULL DEFAULT ''
  )''',
];

int _epoch(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

/// A version 3 database with a ride, a track, readings, frames and a
/// measurement already in it.
Database _populatedV3() {
  final raw = sqlite3.openInMemory();
  for (final statement in _v3Schema) {
    raw.execute(statement);
  }

  final started = _epoch(DateTime.utc(2026, 5, 1, 9));
  raw.execute(
    'INSERT INTO trips (started_at, ended_at, distance_km, moving_seconds, '
    'total_seconds, max_speed_kmh, energy_out_wh, energy_in_wh, start_soc, '
    'end_soc, min_pack_voltage, max_pack_voltage, max_discharge_current, '
    'max_temperature, max_delta_volts, climb_m, descent_m) '
    'VALUES (?, ?, 12.5, 1500, 1600, 58, 310, 4, 100, 68, 70.2, 82.1, 34, '
    '31, 0.021, 45, 40)',
    [started, started + 1600],
  );
  raw.execute(
    'INSERT INTO trip_points (trip_id, timestamp, latitude, longitude, '
    'speed_kmh, altitude_m, pack_voltage, current, soc) '
    'VALUES (1, ?, 23.11, -82.36, 31.0, 24.0, 78.4, -19.2, 88.0)',
    [started + 60],
  );
  raw.execute(
    'INSERT INTO snapshots (timestamp, trip_id, pack_voltage, current, soc, '
    'soh, remaining_ah, cycle_count, delta_volts, min_cell_voltage, '
    'max_cell_voltage, max_temperature, warnings_mask, balancer_active, '
    'cell_voltages_json) '
    "VALUES (?, 1, 78.4, -19.2, 88.0, 97.0, 39.6, 61.0, 0.012, 3.905, 3.917, "
    "29.0, 0, 0, '[3.91]')",
    [started + 60],
  );
  raw.execute(
    'INSERT INTO raw_frames (timestamp, record_type, bytes) VALUES (?, 2, ?)',
    [started + 60, Uint8List.fromList(List<int>.filled(300, 0x55))],
  );
  raw.execute(
    'INSERT INTO capacity_tests (started_at, ended_at, start_soc, end_soc, '
    'start_pack_voltage, end_pack_voltage, measured_ah, measured_wh, '
    'catalogue_ah, completed) '
    'VALUES (?, ?, 100, 3, 84.0, 60.1, 39.8, 2860, 45, 1)',
    [started, started + 7200],
  );

  raw.execute('PRAGMA user_version = 3');
  return raw;
}

void main() {
  group('upgrading a database that already has history', () {
    late Database raw;
    late AppDatabase db;

    setUp(() {
      raw = _populatedV3();
      db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    });

    tearDown(() async => db.close());

    test('the migration runs and the schema lands on the current version', () async {
      // Any query forces drift to open the database and run the upgrade.
      await db.allDevices();
      expect(raw.userVersion, 7);
    });

    test('nothing that was stored is lost', () async {
      await db.allDevices();

      expect(raw.select('SELECT * FROM trips'), hasLength(1));
      expect(raw.select('SELECT * FROM trip_points'), hasLength(1));
      expect(raw.select('SELECT * FROM snapshots'), hasLength(1));
      expect(raw.select('SELECT * FROM raw_frames'), hasLength(1));
      expect(raw.select('SELECT * FROM capacity_tests'), hasLength(1));

      // And the values survived intact, not just the row count.
      final trip = raw.select('SELECT * FROM trips').single;
      expect(trip['distance_km'], 12.5);
      expect(trip['energy_out_wh'], 310);
    });

    test('the old rows become unattached rather than being guessed at',
        () async {
      final counts = await db.orphanCounts();
      expect(counts['trips'], 1);
      expect(counts['snapshots'], 1);
      expect(counts['rawFrames'], 1);
      expect(counts['capacityTests'], 1);

      // And they belong to no pack until the rider says otherwise.
      expect(await db.recentTrips('AA:BB'), isEmpty);
    });

    test('a pack can be created afterwards and adopt them', () async {
      final now = DateTime.utc(2026, 8, 26);
      await db.upsertDevice(
        DevicesCompanion.insert(
          id: 'AA:BB:CC:DD:EE:FF',
          name: const Value('Yoazaky 72V'),
          firstSeenAt: now,
          lastSeenAt: now,
        ),
      );
      await db.adoptOrphans('AA:BB:CC:DD:EE:FF');

      final trips = await db.recentTrips('AA:BB:CC:DD:EE:FF');
      expect(trips.single.distanceKm, 12.5);
      expect(await db.allCapacityTests('AA:BB:CC:DD:EE:FF'), hasLength(1));
      expect((await db.orphanCounts()).values.every((c) => c == 0), isTrue);
    });

    test('writing still works after the upgrade', () async {
      final now = DateTime.utc(2026, 8, 26);
      await db.upsertDevice(
        DevicesCompanion.insert(
          id: 'AA:BB',
          firstSeenAt: now,
          lastSeenAt: now,
        ),
      );
      await db.insertSnapshots([
        SnapshotsCompanion.insert(
          timestamp: now,
          deviceId: const Value('AA:BB'),
          packVoltage: 80,
          current: -10,
          soc: 90,
          soh: 100,
          remainingAh: 40,
          cycleCount: 62,
          deltaVolts: 0.01,
          minCellVoltage: 3.99,
          maxCellVoltage: 4.0,
          maxTemperature: 28,
          warningsMask: 0,
          balancerActive: false,
          cellVoltagesJson: '[4.0]',
        ),
      ]);

      final stored = await db.snapshotsBetween(
        'AA:BB',
        DateTime.utc(2026, 8, 1),
        DateTime.utc(2026, 9, 1),
      );
      expect(stored, hasLength(1));
      expect(stored.single.soc, 90);
    });
  });

  group('upgrading from version 4, where every pack held 45 Ah', () {
    late Database raw;
    late AppDatabase db;

    setUp(() {
      raw = sqlite3.openInMemory();
      for (final statement in _v3Schema) {
        raw.execute(statement);
      }
      // The v4 shape: a devices table, and deviceId on the observation tables.
      raw.execute('''
        CREATE TABLE devices (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL DEFAULT '',
          serial_number TEXT NOT NULL DEFAULT '',
          model TEXT NOT NULL DEFAULT '',
          catalogue_capacity_ah REAL NOT NULL DEFAULT 45,
          first_seen_at INTEGER NOT NULL,
          last_seen_at INTEGER NOT NULL,
          demo INTEGER NOT NULL DEFAULT 0 CHECK (demo IN (0, 1))
        )''');
      for (final table in ['trips', 'snapshots', 'raw_frames', 'capacity_tests']) {
        raw.execute('ALTER TABLE $table ADD COLUMN device_id TEXT');
      }
      final now = _epoch(DateTime.utc(2026, 6, 1));
      // Two bikes. One really is 45 Ah; the other is 35 and was never told so,
      // which is exactly the case that went wrong.
      raw.execute(
        "INSERT INTO devices (id, name, catalogue_capacity_ah, first_seen_at, "
        "last_seen_at) VALUES ('AA:BB', 'Moto', 45, ?, ?)",
        [now, now],
      );
      raw.execute(
        "INSERT INTO devices (id, name, catalogue_capacity_ah, first_seen_at, "
        "last_seen_at) VALUES ('CC:DD', 'La otra', 45, ?, ?)",
        [now, now],
      );
      raw.execute('PRAGMA user_version = 4');
      db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    });

    tearDown(() async => db.close());

    test('clears the capacity on every pack rather than trusting it', () async {
      // Nothing recorded whether 45 was entered or defaulted, so both are
      // cleared. Losing a figure the rider can re-enter in one tap beats
      // keeping one that might be fiction and silently rescales every health
      // number for that battery.
      final devices = await db.allDevices();
      expect(devices, hasLength(2));
      expect(devices.every((d) => d.catalogueCapacityAh == null), isTrue);
    });

    test('keeps everything else about the packs', () async {
      final devices = await db.allDevices();
      expect(
        devices.map((d) => d.name).toSet(),
        {'Moto', 'La otra'},
      );
    });

    test('a capacity can be set again afterwards, per pack', () async {
      await db.updateDevice(
        'CC:DD',
        const DevicesCompanion(catalogueCapacityAh: Value(35)),
      );
      expect((await db.device('CC:DD'))!.catalogueCapacityAh, 35);
      expect((await db.device('AA:BB'))!.catalogueCapacityAh, isNull);
    });
  });

  group('upgrading from version 5, which is what 1.2.0 shipped', () {
    late Database raw;
    late AppDatabase db;

    setUp(() {
      raw = sqlite3.openInMemory();
      for (final statement in _v3Schema) {
        raw.execute(statement);
      }
      // v5: devices exist, catalogue is already nullable, and there is no
      // column recording where the figure came from.
      raw.execute('''
        CREATE TABLE devices (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL DEFAULT '',
          serial_number TEXT NOT NULL DEFAULT '',
          model TEXT NOT NULL DEFAULT '',
          catalogue_capacity_ah REAL,
          first_seen_at INTEGER NOT NULL,
          last_seen_at INTEGER NOT NULL,
          demo INTEGER NOT NULL DEFAULT 0 CHECK (demo IN (0, 1))
        )''');
      for (final table in ['trips', 'snapshots', 'raw_frames', 'capacity_tests']) {
        raw.execute('ALTER TABLE $table ADD COLUMN device_id TEXT');
      }
      final now = _epoch(DateTime.utc(2026, 8, 31));
      raw.execute(
        "INSERT INTO devices (id, name, catalogue_capacity_ah, first_seen_at, "
        "last_seen_at) VALUES ('AA:BB', 'Moto', 45, ?, ?)",
        [now, now],
      );
      raw.execute(
        "INSERT INTO devices (id, name, catalogue_capacity_ah, first_seen_at, "
        "last_seen_at) VALUES ('CC:DD', 'La otra', NULL, ?, ?)",
        [now, now],
      );
      raw.execute('PRAGMA user_version = 5');
      db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    });

    tearDown(() async => db.close());

    test('adds the provenance column without disturbing the figures', () async {
      final devices = await db.allDevices();
      expect(devices, hasLength(2));

      final stated = devices.firstWhere((d) => d.id == 'AA:BB');
      expect(stated.catalogueCapacityAh, 45);
      // Anything already there was entered by the rider under v1.2.0, where
      // the app had no way to fill it in. Treating it as stated is correct,
      // and it is what stops the BMS overwriting it on the next connection.
      expect(stated.catalogueFromBms, isFalse);

      final blank = devices.firstWhere((d) => d.id == 'CC:DD');
      expect(blank.catalogueCapacityAh, isNull);
      expect(blank.catalogueFromBms, isFalse);
    });

    test('a blank pack can then be filled from the BMS', () async {
      final repo = BmsRepository(database: db);
      expect(await repo.adoptDeviceCatalogueFromBms('CC:DD', 35), isTrue);
      expect((await db.device('CC:DD'))!.catalogueCapacityAh, 35);
    });

    test('and a stated one is still protected from it', () async {
      final repo = BmsRepository(database: db);
      expect(await repo.adoptDeviceCatalogueFromBms('AA:BB', 40), isFalse);
      expect((await db.device('AA:BB'))!.catalogueCapacityAh, 45);
    });
  });
}
