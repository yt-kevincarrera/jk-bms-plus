import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/protocol/bms_brand.dart';
import 'package:sqlite3/sqlite3.dart';

import 'fixtures/schema_v15_rides.dart';

/// The schema exactly as version 14 shipped: everything the from < 15 step
/// has to add the brand column to, and nothing it should touch twice.
///
/// Written out longhand, like the version 3 schema in migration_test.dart, so
/// the migration is exercised against what is actually on the phone rather
/// than against a fresh database built from the current classes.
const _v14Devices = '''
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
  demo INTEGER NOT NULL DEFAULT 0 CHECK (demo IN (0, 1))
)''';

const _v14RawFrames = '''
CREATE TABLE raw_frames (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  timestamp INTEGER NOT NULL,
  record_type INTEGER NOT NULL,
  bytes BLOB NOT NULL,
  device_id TEXT
)''';

int _epoch(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

/// A version 14 database with one device and one raw frame, neither of which
/// has ever heard of a brand.
Database _populatedV14() {
  final raw = sqlite3.openInMemory();
  raw.execute(_v14Devices);
  raw.execute(_v14RawFrames);
  // Unchanged by 15, and rebuilt by the step after it, which runs too.
  for (final table in v15RideTables) {
    raw.execute(table);
  }

  final now = _epoch(DateTime.utc(2026, 9, 1));
  raw.execute(
    "INSERT INTO devices (id, name, first_seen_at, last_seen_at) "
    "VALUES ('AA:BB', 'Moto', ?, ?)",
    [now, now],
  );
  raw.execute(
    'INSERT INTO raw_frames (timestamp, record_type, bytes, device_id) '
    'VALUES (?, 2, ?, ?)',
    [now, Uint8List.fromList(List<int>.filled(300, 0x55)), 'AA:BB'],
  );

  raw.execute('PRAGMA user_version = 14');
  return raw;
}

void main() {
  group('upgrading from 14, before the app knew a second brand', () {
    late Database raw;
    late AppDatabase db;

    setUp(() {
      raw = _populatedV14();
      db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    });

    tearDown(() async => db.close());

    test('14 to 15: existing devices and frames read as JK', () async {
      final device = await db.device('AA:BB');
      expect(device!.brand, isNull);
      expect(BmsBrand.fromStored(device.brand), BmsBrand.jk);
      final frames = await db.allRawFramesForBackup();
      expect(frames.single.brand, isNull);
    });
  });

  test('fresh 15 database stores the brand', () async {
    final repo = BmsRepository(database: AppDatabase.forTesting(NativeDatabase.memory()));
    addTearDown(repo.dispose);
    await repo.rememberDevice(
      id: 'X',
      name: 'ANT-BLE16ZMUB',
      demo: false,
      brand: BmsBrand.ant,
    );
    expect((await repo.db.device('X'))!.brand, 'ant');
    await repo.setDeviceBrand('X', BmsBrand.jk);
    expect((await repo.db.device('X'))!.brand, 'jk');
  });
}
