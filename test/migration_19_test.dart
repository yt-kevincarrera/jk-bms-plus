import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:sqlite3/sqlite3.dart';

/// Every table as version 18 shipped it. Version 18 differs from today only
/// in the readings' SOH, which was NOT NULL, so the schema is taken from a
/// fresh database and that one column put back the way it was.
Future<List<String>> _v18Schema() async {
  final fresh = AppDatabase.forTesting(NativeDatabase.memory());
  final rows = await fresh
      .customSelect(
        "SELECT sql FROM sqlite_master WHERE type IN ('table', 'index') "
        "AND sql IS NOT NULL AND name NOT LIKE 'sqlite_%'",
      )
      .get();
  await fresh.close();
  final out = <String>[];
  for (final r in rows) {
    final sql = r.read<String>('sql');
    if (sql.contains('CREATE TABLE "snapshots"')) {
      expect(sql, contains('"soh" REAL NULL,'));
      out.add(sql.replaceFirst('"soh" REAL NULL,', '"soh" REAL NOT NULL,'));
    } else {
      out.add(sql);
    }
  }
  return out;
}

void main() {
  group('upgrading from 18, when every reading had to carry a SOH', () {
    late AppDatabase db;
    final t = DateTime.utc(2026, 9, 30, 12);

    setUp(() async {
      final raw = sqlite3.openInMemory();
      for (final s in await _v18Schema()) {
        raw.execute(s);
      }
      raw.execute(
        'INSERT INTO devices (id, first_seen_at, last_seen_at, brand) '
        "VALUES ('JK:01', ?, ?, 'jk')",
        [t.millisecondsSinceEpoch ~/ 1000, t.millisecondsSinceEpoch ~/ 1000],
      );
      raw.execute(
        'INSERT INTO snapshots (timestamp, pack_voltage, current, soc, soh, '
        'remaining_ah, cycle_capacity_ah, delta_volts, min_cell_voltage, '
        'max_cell_voltage, warnings_mask, balancer_active, cell_voltages_json, '
        'device_id) '
        "VALUES (?, 74.1, -3.2, 64, 97, 28.8, 2843.5, 0.004, 3.70, 3.704, 0, 0, "
        "'[3.7,3.704]', 'JK:01')",
        [t.millisecondsSinceEpoch ~/ 1000],
      );
      raw.execute('PRAGMA user_version = 18');
      db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    });

    tearDown(() async => db.close());

    test('the stored SOH survives the rebuild', () async {
      final last = await db.lastSnapshotFor('JK:01');
      expect(last, isNotNull);
      expect(last!.soh, 97);
      expect(last.packVoltage, 74.1);
    });

    test('and a reading without one can now be stored as none', () async {
      await db.insertSnapshots([
        SnapshotsCompanion.insert(
          deviceId: const Value('ANT:OLD'),
          timestamp: t.add(const Duration(minutes: 1)),
          packVoltage: 48.8,
          current: -8,
          soc: 41,
          soh: const Value(null),
          remainingAh: 68.77,
          deltaVolts: 0.041,
          minCellVoltage: 3.468,
          maxCellVoltage: 3.509,
          warningsMask: 0,
          balancerActive: false,
          cellVoltagesJson: '[3.468,3.509]',
        ),
      ]);
      final last = await db.lastSnapshotFor('ANT:OLD');
      expect(last!.soh, isNull);
    });
  });
}
