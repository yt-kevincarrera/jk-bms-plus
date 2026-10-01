import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/l10n/app_localizations_es.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/metrics/maintenance.dart';
import 'package:jk_bms/src/metrics/weak_cell_ranking.dart';
import 'package:jk_bms/src/ui/tabs/cells_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/captured_frames.dart';
import 'support/app_harness.dart';
import 'support/fakes.dart';
import 'support/stored_readings.dart';

/// The ranking used to count the current connection only, loaded readings
/// included: it started from nothing every time the pack was met again, and
/// under load the lowest cell is the one with the most lead resistance.
void main() {
  ({double current, String cellVoltagesJson}) row(
    List<double> cells, {
    double current = 0,
  }) => (current: current, cellVoltagesJson: encodeCellVoltages(cells));

  group('the rule', () {
    test('counts the clearly lowest cell at rest, and its share', () {
      final r = WeakCellRanking.from([
        for (var i = 0; i < 6; i++) row(cellsAt(3.90, {7: -0.015})),
        for (var i = 0; i < 3; i++) row(cellsAt(3.90, {3: -0.012})),
        row(cellsAt(3.90, {12: -0.020})),
      ]);
      expect(r.readings, 10);
      expect([for (final e in r.top) e.cell], [7, 3, 12]);
      expect(r.top.first.share, closeTo(0.6, 1e-9));
    });

    test('leaves out readings under load and on the charger', () {
      final r = WeakCellRanking.from([
        row(cellsAt(3.90, {7: -0.015}), current: -12),
        row(cellsAt(3.90, {7: -0.015}), current: 0.5),
        row(cellsAt(3.90, {7: -0.015}), current: -0.44),
      ]);
      // Only the lights-on reading is rest.
      expect(r.readings, 1);
    });

    test('leaves out cells too close together, and a tie', () {
      final r = WeakCellRanking.from([
        // 9 mV apart: below the line where "lowest" means anything.
        row(cellsAt(3.90, {7: -0.009})),
        // Two cells tied lowest, 1 mV between them and the next.
        row(cellsAt(3.90, {7: -0.015, 8: -0.014})),
        // Exactly 10 mV apart and 2 mV clear: counts.
        row(cellsAt(3.90, {5: -0.010, 6: -0.008})),
      ]);
      expect(r.readings, 1);
      expect(r.top.single.cell, 5);
    });

    test('is not enough below the readings the weak-cell finding asks for', () {
      final r = WeakCellRanking.from([
        for (var i = 0; i < 49; i++) row(cellsAt(3.90, {7: -0.015})),
      ]);
      expect(r.isEnough(50), isFalse);
      expect(WeakCellRanking.empty.isEnough(0), isFalse);
    });
  });

  group('from the stored month', () {
    late AppDatabase db;
    late BmsRepository repo;
    final now = DateTime.utc(2026, 10, 1, 12);

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = BmsRepository(database: db);
    });

    tearDown(() async {
      await repo.dispose();
      await db.close();
    });

    test(
      'reads a month back, thinned to one reading per ten seconds',
      () async {
        await db.insertSnapshots([
          // Three readings a second for a minute: six buckets, not 180.
          for (var i = 0; i < 180; i++)
            storedReading(
              deviceId: 'A',
              at: now
                  .subtract(const Duration(days: 2))
                  .add(Duration(milliseconds: 333 * i)),
              cells: cellsAt(3.90, {7: -0.015}),
            ),
          // Older than the month: not counted.
          storedReading(
            deviceId: 'A',
            at: now.subtract(const Duration(days: 40)),
            cells: cellsAt(3.90, {2: -0.015}),
          ),
          // Another pack: not counted.
          storedReading(
            deviceId: 'B',
            at: now.subtract(const Duration(days: 1)),
            cells: cellsAt(3.90, {2: -0.015}),
          ),
          // Under load: filtered in the query.
          storedReading(
            deviceId: 'A',
            at: now.subtract(const Duration(days: 1)),
            cells: cellsAt(3.90, {2: -0.015}),
            current: -20,
          ),
        ]);
        final r = await repo.weakCellRanking('A', now: now);
        expect(r.readings, inInclusiveRange(6, 7));
        expect(r.top.single.cell, 7);
      },
    );

    test('starts at the last cell replacement', () async {
      await db.insertSnapshots([
        storedReading(
          deviceId: 'A',
          at: now.subtract(const Duration(days: 10)),
          cells: cellsAt(3.90, {2: -0.015}),
        ),
        storedReading(
          deviceId: 'A',
          at: now.subtract(const Duration(days: 1)),
          cells: cellsAt(3.90, {9: -0.015}),
        ),
      ]);
      await MaintenanceLog(db).add(
        deviceId: 'A',
        at: now.subtract(const Duration(days: 5)),
        kind: MaintenanceKind.cellReplaced,
      );
      final r = await repo.weakCellRanking('A', now: now);
      expect(r.top.single.cell, 9);
    });
  });

  group('on the cells tab', () {
    late AppDatabase db;
    late BmsRepository repo;
    late BmsService service;
    final t = AppL10nEs();

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final link = FakeLink();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = BmsRepository(database: db);
      service = BmsService(transport: link, locationFactory: StubLocation.new)
        ..repository = repo;
      await service.connect('AA:BB', name: 'KevinJK');
      await link.deliver(deviceInfoFrames[1]);
      await link.deliver(cellInfo24s[0]);
    });

    tearDown(() async {
      service.dispose();
      await repo.dispose();
      await db.close();
    });

    Future<void> pump(WidgetTester tester) async {
      final license = await unlockedLicense(tester);
      await tester.pumpWidget(
        harness(license, Scaffold(body: WeakCellRankingRow(service: service))),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    }

    testWidgets('says it needs more history, with how far it has got', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text(t.balanceRankingNeedsHistory), findsOneWidget);
      expect(find.textContaining('0 de 50'), findsOneWidget);
    });

    testWidgets('ranks the top three with their shares and the count', (
      tester,
    ) async {
      final id = service.activeDeviceId!;
      final base = DateTime.now().toUtc().subtract(const Duration(days: 3));
      await tester.runAsync(
        () => db.insertSnapshots([
          for (var i = 0; i < 60; i++)
            storedReading(
              deviceId: id,
              at: base.add(Duration(minutes: i)),
              cells: cellsAt(3.90, {(i < 40 ? 7 : 3): -0.015}),
            ),
        ]),
      );
      await pump(tester);
      expect(find.text('celda 7: 67 %,  celda 3: 33 %'), findsOneWidget);
      expect(find.textContaining('De 60 lecturas en reposo'), findsOneWidget);
    });
  });
}
