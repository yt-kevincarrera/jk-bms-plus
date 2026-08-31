import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/metrics/maintenance.dart';

void main() {
  late AppDatabase db;
  late MaintenanceLog log;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    log = MaintenanceLog(db);
    final now = DateTime.utc(2026, 1, 1);
    for (final id in ['AA:BB', 'CC:DD']) {
      await db.upsertDevice(
        DevicesCompanion.insert(id: id, firstSeenAt: now, lastSeenAt: now),
      );
    }
  });

  tearDown(() async => db.close());

  group('the log', () {
    test('keeps what was done, when, and to which pack', () async {
      await log.add(
        deviceId: 'AA:BB',
        at: DateTime.utc(2026, 5, 12),
        kind: MaintenanceKind.cellReplaced,
        note: 'celda 7',
      );

      final events = await log.forPack('AA:BB');
      expect(events, hasLength(1));
      expect(MaintenanceKind.parse(events.single.kind),
          MaintenanceKind.cellReplaced);
      expect(events.single.note, 'celda 7');
      // Another pack's log is untouched, like every other history here.
      expect(await log.forPack('CC:DD'), isEmpty);
    });

    test('is newest first', () async {
      await log.add(
        deviceId: 'AA:BB',
        at: DateTime.utc(2026, 1, 5),
        kind: MaintenanceKind.manualBalance,
      );
      await log.add(
        deviceId: 'AA:BB',
        at: DateTime.utc(2026, 6, 5),
        kind: MaintenanceKind.chargerChanged,
      );

      final events = await log.forPack('AA:BB');
      expect(MaintenanceKind.parse(events.first.kind),
          MaintenanceKind.chargerChanged);
    });

    test('stores the date the rider gave, in UTC', () async {
      // People write things down days after doing them, so the date is asked
      // for rather than assumed from when the note was typed.
      final when = DateTime.utc(2026, 3, 2, 15);
      await log.add(
        deviceId: 'AA:BB',
        at: when,
        kind: MaintenanceKind.other,
      );
      // Drift hands timestamps back in local time. Same instant, different
      // representation, so the assertion is on the instant.
      expect((await log.forPack('AA:BB')).single.at.toUtc(), when);
    });

    test('an entry can be removed', () async {
      final id = await log.add(
        deviceId: 'AA:BB',
        at: DateTime.utc(2026, 3, 2),
        kind: MaintenanceKind.other,
      );
      await log.remove(id);
      expect(await log.forPack('AA:BB'), isEmpty);
    });

    test('deleting a pack takes its log with it', () async {
      await log.add(
        deviceId: 'AA:BB',
        at: DateTime.utc(2026, 3, 2),
        kind: MaintenanceKind.other,
      );
      await db.deleteDevice('AA:BB');
      expect(await log.forPack('AA:BB'), isEmpty);
    });
  });

  group('the kind, stored by name', () {
    test('round trips', () {
      for (final k in MaintenanceKind.values) {
        expect(MaintenanceKind.parse(k.name), k);
      }
    });

    test('an unknown name becomes other rather than throwing', () {
      // A backup written by a newer build may carry a kind this one has never
      // heard of. Losing the label is survivable; losing the entry is not.
      expect(MaintenanceKind.parse('somethingNewer'), MaintenanceKind.other);
    });
  });

  group('dating the history that still applies', () {
    test('finds the last cell replacement', () async {
      // Readings from before a cell was swapped describe a battery that no
      // longer exists, and every long-term figure quietly includes them.
      await log.add(
        deviceId: 'AA:BB',
        at: DateTime.utc(2026, 2, 1),
        kind: MaintenanceKind.cellReplaced,
      );
      await log.add(
        deviceId: 'AA:BB',
        at: DateTime.utc(2026, 7, 1),
        kind: MaintenanceKind.cellReplaced,
      );
      await log.add(
        deviceId: 'AA:BB',
        at: DateTime.utc(2026, 8, 1),
        kind: MaintenanceKind.manualBalance,
      );

      final events = await log.forPack('AA:BB');
      final last = MaintenanceLog.lastOf(events, MaintenanceKind.cellReplaced);
      expect(last!.at.toUtc(), DateTime.utc(2026, 7, 1));
    });

    test('returns nothing when it never happened', () async {
      await log.add(
        deviceId: 'AA:BB',
        at: DateTime.utc(2026, 2, 1),
        kind: MaintenanceKind.chargerChanged,
      );
      final events = await log.forPack('AA:BB');
      expect(
        MaintenanceLog.lastOf(events, MaintenanceKind.cellReplaced),
        isNull,
      );
    });
  });

  group('picking the ones to draw on a chart', () {
    test('takes only what falls inside the window, oldest first', () async {
      for (final d in [
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2026, 5, 1),
        DateTime.utc(2026, 6, 1),
        DateTime.utc(2026, 12, 1),
      ]) {
        await log.add(
          deviceId: 'AA:BB',
          at: d,
          kind: MaintenanceKind.other,
        );
      }

      final within = MaintenanceLog.within(
        await log.forPack('AA:BB'),
        DateTime.utc(2026, 4, 1),
        DateTime.utc(2026, 7, 1),
      );
      expect(within, hasLength(2));
      expect(within.first.at.toUtc(), DateTime.utc(2026, 5, 1));
      expect(within.last.at.toUtc(), DateTime.utc(2026, 6, 1));
    });
  });
}
