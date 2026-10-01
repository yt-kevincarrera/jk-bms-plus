import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/metrics/capacity_endpoints.dart';
import 'package:sqlite3/sqlite3.dart';

/// The tables the steps from 16 touch, as version 16 shipped them: the two
/// the from < 17 step changes, and trips, which the from < 18 step adds a
/// column to (added here when that step arrived).
/// Written out longhand, like the older schemas, so the step runs against
/// what is on the phone rather than against the current classes.
const _v16Schema = [
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
    catalogue_ah REAL,
    completed INTEGER NOT NULL DEFAULT 0 CHECK (completed IN (0, 1)),
    automatic INTEGER NOT NULL DEFAULT 0 CHECK (automatic IN (0, 1)),
    gap_seconds INTEGER NOT NULL DEFAULT 0,
    note TEXT NOT NULL DEFAULT '',
    device_id TEXT
  )''',
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
  )''',
];

int _epoch(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

/// A version 16 database with one pack, a detected cycle and a manual test
/// that both finished on the old 97 % to 3 % rule, and a manual test still
/// running when the app was updated.
Database _populatedV16() {
  final raw = sqlite3.openInMemory();
  for (final statement in _v16Schema) {
    raw.execute(statement);
  }
  final t = _epoch(DateTime.utc(2026, 9, 20, 9));
  raw.execute(
    'INSERT INTO devices (id, first_seen_at, last_seen_at, brand) '
    "VALUES ('JK:01', ?, ?, 'jk')",
    [t, t],
  );
  for (final (completed, automatic, ah) in [
    (1, 1, 37.6),
    (1, 0, 37.4),
    (0, 0, 12.0),
  ]) {
    raw.execute(
      'INSERT INTO capacity_tests (started_at, ended_at, start_soc, end_soc, '
      'start_pack_voltage, end_pack_voltage, measured_ah, measured_wh, '
      'catalogue_ah, completed, automatic, gap_seconds, device_id) '
      "VALUES (?, ?, 97, 3, 83.0, 64.0, ?, ?, 40, ?, ?, 0, 'JK:01')",
      [t, completed == 1 ? t + 7200 : null, ah, ah * 72, completed, automatic],
    );
  }
  raw.execute('PRAGMA user_version = 16');
  return raw;
}

void main() {
  group('upgrading from 16, when every test closed on the percentage', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.opened(_populatedV16()));
    });

    tearDown(() async => db.close());

    test('every finished test is kept, and marked as the old rule', () async {
      final tests = await db.allCapacityTests('JK:01');
      expect(tests, hasLength(3));
      final finished = tests.where((t) => t.completed).toList();
      expect(finished, hasLength(2));
      expect(finished.every((t) => t.endReason == 'legacy'), isTrue);
      // Kept, not believed: 97 % to 3 % of a 40 Ah setting is 37.6 Ah
      // whatever the cells hold.
      expect(finished.any((t) => t.isTrustworthy), isFalse);
      expect(finished.map((t) => t.measuredAh), containsAll([37.6, 37.4]));
    });

    test('a test still running is left open to be resumed', () async {
      final open = (await db.allCapacityTests(
        'JK:01',
      )).singleWhere((t) => !t.completed);
      expect(open.endReason, isNull);
      expect(open.chargedDuringRun, isFalse);
      expect(open.measuredAh, 12.0);
    });

    test('the pack keeps its row and has no charge report yet', () async {
      final device = await db.device('JK:01');
      expect(device, isNotNull);
      expect(device!.brand, 'jk');
      expect(device.lastChargeJson, isNull);
    });

    test('and new tests write what closed them', () async {
      await db.insertCapacityTest(
        CapacityTestsCompanion.insert(
          startedAt: DateTime.utc(2026, 9, 25),
          endedAt: Value(DateTime.utc(2026, 9, 25, 3)),
          startSoc: 100,
          endSoc: 0,
          startPackVoltage: 83,
          endPackVoltage: 61,
          measuredAh: 43.1,
          measuredWh: 3100,
          completed: const Value(true),
          endReason: Value(CapacityEndReason.cellCutoff.name),
          deviceId: const Value('JK:01'),
        ),
      );
      final fresh = (await db.allCapacityTests(
        'JK:01',
      )).singleWhere((t) => t.measuredAh == 43.1);
      expect(fresh.isTrustworthy, isTrue);
    });
  });
}
