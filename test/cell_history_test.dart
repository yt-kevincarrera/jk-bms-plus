import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/l10n/app_localizations_es.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/metrics/cell_history.dart';
import 'package:jk_bms/src/ui/cell_history_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';
import 'support/stored_readings.dart';

/// Every reading's cell voltages are stored, and nothing drew them over time.
void main() {
  late AppDatabase db;
  late BmsRepository repo;
  final t0 = DateTime.utc(2026, 9, 20, 10);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = BmsRepository(database: db);
  });

  tearDown(() async {
    await repo.dispose();
    await db.close();
  });

  CellHistoryRow row(int second, List<double> cells, {int? first, int? last}) =>
      CellHistoryRow(
        at: t0.add(Duration(seconds: second)),
        firstAt: t0.add(Duration(seconds: first ?? second)),
        lastAt: t0.add(Duration(seconds: last ?? second)),
        cellVoltagesJson: encodeCellVoltages(cells),
      );

  group('the points', () {
    test('break where nothing was read for more than thirty seconds', () {
      final h = CellHistory.from([
        row(0, cellsAt(3.9)),
        row(10, cellsAt(3.9)),
        // Bucket from 40 to 60: thirty seconds after the last reading at 10
        // is the edge, and 41 is past it.
        row(60, cellsAt(3.9), first: 41),
        row(70, cellsAt(3.9), first: 65),
      ]);
      expect(
        [for (final p in h.points) p.gapBefore],
        [false, false, true, false],
      );
    });

    test('leave out a reading with another number of cells', () {
      final h = CellHistory.from([
        row(0, cellsAt(3.9)),
        row(1, [3.9, 3.9, 3.9]),
        row(2, cellsAt(3.9)),
      ]);
      expect(h.points, hasLength(2));
      expect(h.cellCount, 20);
    });

    test('pick out the cells lowest and highest on average', () {
      final h = CellHistory.from([
        row(0, cellsAt(3.9, {7: -0.030, 3: 0.010})),
        // One reading with cell 12 lowest does not make it the low one.
        row(1, cellsAt(3.9, {7: -0.010, 12: -0.040, 3: 0.010})),
        row(2, cellsAt(3.9, {7: -0.030, 3: 0.010})),
      ]);
      final e = h.extremes();
      expect(e.lowest, 7);
      expect(e.highest, 3);
    });

    test('a week is bucketed to no more than five hundred points', () {
      final b = CellHistory.bucketFor(t0, t0.add(const Duration(days: 7)));
      expect(
        const Duration(days: 7).inSeconds / b.inSeconds,
        lessThanOrEqualTo(500),
      );
      expect(
        CellHistory.bucketFor(t0, t0.add(const Duration(minutes: 1))),
        const Duration(seconds: 1),
      );
    });
  });

  test(
    'the database keeps one real reading a bucket, and the gap between them',
    () async {
      await db.insertSnapshots([
        // Two hours at one a second, with a ten-minute hole in the middle.
        for (var i = 0; i < 7200; i++)
          if (i < 3000 || i >= 3600)
            storedReading(
              deviceId: 'A',
              at: t0.add(Duration(seconds: i)),
              cells: cellsAt(3.0 + (i % 1000) / 1000),
            ),
        storedReading(deviceId: 'B', at: t0, cells: cellsAt(3.5)),
      ]);
      final h = await repo.cellHistory(
        'A',
        t0,
        t0.add(const Duration(hours: 2)),
      );
      expect(h.points.length, lessThanOrEqualTo(500));
      expect(h.points.length, greaterThan(400));
      expect(h.points.where((p) => p.gapBefore), hasLength(1));
      // A real reading, not an average: its cells are one of the rows stored.
      final p = h.points[10];
      final second = p.at.difference(t0).inSeconds;
      expect(p.cells.first, closeTo(3.0 + (second % 1000) / 1000, 1e-9));
    },
  );

  testWidgets('draws a ride\'s cells, the low one picked out, with the note', (
    tester,
  ) async {
    final t = AppL10nEs();
    await tester.runAsync(() async {
      await db.insertSnapshots([
        for (var i = 0; i < 600; i++)
          storedReading(
            deviceId: 'A',
            at: t0.add(Duration(seconds: i)),
            cells: cellsAt(3.9, {7: -0.030}),
            current: -20,
          ),
      ]);
      await db.insertTrip(
        TripsCompanion.insert(
          deviceId: const Value('A'),
          startedAt: t0,
          endedAt: t0.add(const Duration(minutes: 10)),
          distanceKm: 5,
          movingSeconds: 600,
          totalSeconds: 600,
          maxSpeedKmh: 40,
          energyOutWh: 90,
          energyInWh: 0,
          startSoc: 80,
          endSoc: 75,
          minPackVoltage: 76,
          maxPackVoltage: 78,
          maxDischargeCurrent: 30,
          maxDeltaVolts: 0.03,
          climbM: 0,
          descentM: 0,
        ),
      );
    });
    final trip = (await tester.runAsync(() => db.recentTrips('A')))!.single;
    final license = await unlockedLicense(tester);
    await tester.pumpWidget(
      harness(
        license,
        CellHistoryScreen(
          repository: repo,
          deviceId: 'A',
          packName: 'KevinJK',
          trip: trip,
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(find.text(t.cellHistoryTitle), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text(t.cellHistoryLowest(7)), findsOneWidget);
    // Ten minutes at one a second, one kept every two seconds.
    expect(find.text(t.cellHistoryPoints(300)), findsOneWidget);
    // The ride first, the pack's own windows beside it.
    final chip = tester.widget<ChoiceChip>(
      find.ancestor(
        of: find.text(t.cellHistoryRangeTrip),
        matching: find.byType(ChoiceChip),
      ),
    );
    expect(chip.selected, isTrue);

    await tester.tap(find.text(t.cellHistoryModeDeviation));
    await tester.pump();
    expect(find.text(t.cellHistoryAxisDeviation), findsOneWidget);
  });
}
