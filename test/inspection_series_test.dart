import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/inspection/inspection_result.dart';
import 'package:jk_bms/src/inspection/inspection_series.dart';
import 'package:jk_bms/src/metrics/advice_engine.dart';

/// A test result with everything at sensible values, and one cell dragged
/// down as far as the caller asks.
InspectionResult run({
  int weakCell = 7,
  double weakSag = 0.30,
  double medianSag = 0.08,
  double restDelta = 0.015,
  double currentStep = 37.0,
  double medianResistance = 0.0021,
  int? cycles = 12,
  double? soh = 100,
  double? configuredAh = 40,
  String serial = 'SN-1',
  DateTime? at,
}) {
  final cells = [
    for (var i = 1; i <= 16; i++)
      CellInspection(
        index: i,
        restVolts: 3.900 - i * 0.001,
        lightSagVolts: 0.010,
        heavySagVolts: i == weakCell ? weakSag : medianSag,
        resistanceOhms: i == weakCell
            ? weakSag / currentStep
            : medianResistance,
        recoverySeconds: i == weakCell ? 22 : 4,
        recovered: true,
      ),
  ];
  return InspectionResult(
    at: at ?? DateTime.utc(2026, 5, 4),
    cells: cells,
    restDeltaVolts: restDelta,
    restCurrentAmps: 0.2,
    lightLoadAmps: 1.8,
    peakDischargeAmps: currentStep + 0.5,
    currentStepAmps: currentStep,
    medianHeavySagVolts: medianSag,
    medianResistanceOhms: medianResistance,
    medianRecoverySeconds: 4,
    maxTemperature: 30,
    faultsSeen: const [],
    caveats: const [],
    reported: ReportedFigures(
      model: 'JK-BD6A20S10P',
      serialNumber: serial,
      softwareVersion: '11.26',
      cycleCount: cycles,
      configuredCapacityAh: configuredAh,
      soc: 78,
      soh: soh,
    ),
    durationSeconds: 96,
    readings: 180,
  );
}

PastInspection past(
  DateTime at, {
  String bmsId = 'AA:BB',
  int weakCell = 7,
  double weakSag = 0.30,
  double restDelta = 0.015,
  double currentStep = 37.0,
  double medianResistance = 0.0021,
  int? cycles = 12,
  double? soh = 100,
  double? configuredAh = 40,
  String serial = 'SN-1',
  int? id,
}) => PastInspection(
  at: at,
  bmsId: bmsId,
  id: id,
  result: run(
    at: at,
    weakCell: weakCell,
    weakSag: weakSag,
    restDelta: restDelta,
    currentStep: currentStep,
    medianResistance: medianResistance,
    cycles: cycles,
    soh: soh,
    configuredAh: configuredAh,
    serial: serial,
  ),
);

bool has(List<Advice> advice, AdviceCode code) =>
    advice.any((a) => a.code == code);

Advice of(List<Advice> advice, AdviceCode code) =>
    advice.firstWhere((a) => a.code == code);

void main() {
  const series = InspectionSeries();

  group('picking the runs that are about this pack', () {
    final may = DateTime.utc(2026, 5, 1);
    final june = DateTime.utc(2026, 6, 1);

    test('matches the same address', () {
      final all = [
        past(may, bmsId: 'AA:BB'),
        past(june, bmsId: 'CC:DD', serial: 'OTHER'),
      ];
      final mine = InspectionSeries.forPack(all, bmsId: 'AA:BB');
      expect(mine, hasLength(1));
      expect(mine.single.at, may);
    });

    test('matches the same pack met on another address, by serial', () {
      final all = [past(may, bmsId: 'OLD:ADDRESS', serial: 'SN-9')];
      expect(
        InspectionSeries.forPack(
          all,
          bmsId: 'NEW:ADDRESS',
          serialNumber: 'SN-9',
        ),
        hasLength(1),
      );
    });

    test('an empty serial matches nothing, so anonymous packs stay apart', () {
      final all = [
        past(may, bmsId: 'AA:BB', serial: ''),
        past(june, bmsId: 'CC:DD', serial: ''),
      ];
      final mine = InspectionSeries.forPack(
        all,
        bmsId: 'EE:FF',
        serialNumber: '',
      );
      expect(mine, isEmpty);
    });

    test('rereading an old run only sees what came before it', () {
      final all = [
        past(may, id: 1),
        past(june, id: 2),
        past(DateTime.utc(2026, 7, 1), id: 3),
      ];
      final asOfJune = InspectionSeries.forPack(
        all,
        bmsId: 'AA:BB',
        before: june,
        excludeId: 2,
      );
      expect(asOfJune.map((p) => p.id), [1]);
    });

    test('comes back oldest first whatever order it was given', () {
      final all = [past(june), past(may)];
      final mine = InspectionSeries.forPack(all, bmsId: 'AA:BB');
      expect(mine.map((p) => p.at), [may, june]);
    });
  });

  group('a first run', () {
    test('has nothing to compare and says nothing', () {
      final c = series.compare(run(), const []);
      expect(c.isFirstRun, isTrue);
      expect(c.runNumber, 1);
      expect(series.evaluate(c), isEmpty);
    });
  });

  group('the same cell again', () {
    test('is called out with how many runs agree', () {
      final c = series.compare(run(weakCell: 7), [
        past(DateTime.utc(2026, 4, 1), weakCell: 7),
        past(DateTime.utc(2026, 4, 20), weakCell: 7),
      ]);

      expect(c.runNumber, 3);
      expect(c.timesSameWorstCell, 3);
      final advice = series.evaluate(c);
      expect(has(advice, AdviceCode.inspectionRepeatSameCell), isTrue);

      final found = of(advice, AdviceCode.inspectionRepeatSameCell);
      expect(found.level, AdviceLevel.problem);
      expect(found.cellIndex, 7);
      final times = found.evidence
          .firstWhere((e) => e.kind == EvidenceKind.timesSameCell)
          .value;
      expect(times, 3);
    });

    test(
      'a different cell each time is a measurement problem, not two faults',
      () {
        final c = series.compare(run(weakCell: 3), [
          past(DateTime.utc(2026, 4, 1), weakCell: 7),
        ]);

        final advice = series.evaluate(c);
        expect(has(advice, AdviceCode.inspectionRepeatCellMoved), isTrue);
        expect(has(advice, AdviceCode.inspectionRepeatSameCell), isFalse);
        expect(
          of(advice, AdviceCode.inspectionRepeatCellMoved).level,
          AdviceLevel.watch,
        );
      },
    );
  });

  group('what moved between two runs', () {
    test('a pack that sags further than last time is going backwards', () {
      final c = series.compare(run(weakSag: 0.40), [
        past(DateTime.utc(2026, 4, 1), weakSag: 0.30),
      ]);

      expect(c.loadComparable, isTrue);
      expect(c.sagExcessChange, closeTo(0.10, 1e-9));
      final advice = series.evaluate(c);
      expect(has(advice, AdviceCode.inspectionRepeatWorse), isTrue);
      expect(has(advice, AdviceCode.inspectionRepeatSteady), isFalse);
    });

    test('a resting spread that opened up counts as worse too', () {
      final c = series.compare(run(restDelta: 0.040), [
        past(DateTime.utc(2026, 4, 1), restDelta: 0.015),
      ]);
      expect(has(series.evaluate(c), AdviceCode.inspectionRepeatWorse), isTrue);
    });

    test('two runs inside the noise are steady, which is worth saying', () {
      final c = series.compare(run(weakSag: 0.31, restDelta: 0.016), [
        past(DateTime.utc(2026, 4, 1), weakSag: 0.30, restDelta: 0.015),
      ]);

      final advice = series.evaluate(c);
      expect(has(advice, AdviceCode.inspectionRepeatSteady), isTrue);
      expect(
        of(advice, AdviceCode.inspectionRepeatSteady).level,
        AdviceLevel.good,
      );
      expect(has(advice, AdviceCode.inspectionRepeatWorse), isFalse);
    });

    test('a pack that measures better is not reported as worse', () {
      final c = series.compare(run(weakSag: 0.15), [
        past(DateTime.utc(2026, 4, 1), weakSag: 0.30),
      ]);
      final advice = series.evaluate(c);
      expect(has(advice, AdviceCode.inspectionRepeatWorse), isFalse);
      expect(has(advice, AdviceCode.inspectionRepeatSteady), isFalse);
    });
  });

  group('two runs that did not pull alike', () {
    test('are flagged, and their sag is not compared at all', () {
      final c = series.compare(run(weakSag: 0.30, currentStep: 37), [
        past(DateTime.utc(2026, 4, 1), weakSag: 0.10, currentStep: 9),
      ]);

      expect(c.loadComparable, isFalse);
      expect(c.sagExcessChange, isNull);
      final advice = series.evaluate(c);
      expect(has(advice, AdviceCode.inspectionRepeatLoadDiffers), isTrue);
      // The sag tripled, and saying so would be wrong: three times the
      // current gives three times the sag on a healthy pack.
      expect(has(advice, AdviceCode.inspectionRepeatWorse), isFalse);
      expect(has(advice, AdviceCode.inspectionRepeatSteady), isFalse);
    });

    test('two runs with no real load at all are not compared either', () {
      final c = series.compare(run(currentStep: 2), [
        past(DateTime.utc(2026, 4, 1), currentStep: 2),
      ]);
      expect(c.loadComparable, isFalse);
      expect(
        has(series.evaluate(c), AdviceCode.inspectionRepeatLoadDiffers),
        isTrue,
      );
    });
  });

  group('counters that moved between visits', () {
    test('cycles cannot go down', () {
      final c = series.compare(run(cycles: 3), [
        past(DateTime.utc(2026, 4, 1), cycles: 180),
      ]);

      expect(c.counters.cyclesFell, isTrue);
      final advice = series.evaluate(c);
      expect(has(advice, AdviceCode.inspectionRepeatCountersReset), isTrue);
      expect(
        of(advice, AdviceCode.inspectionRepeatCountersReset).level,
        AdviceLevel.problem,
      );
      // Both figures are on the sentence, with the date of the old one.
      final before = of(
        advice,
        AdviceCode.inspectionRepeatCountersReset,
      ).evidence.firstWhere((e) => e.kind == EvidenceKind.previousCycles);
      expect(before.value, 180);
      expect(before.at, DateTime.utc(2026, 4, 1));
    });

    test('health cannot rise', () {
      final c = series.compare(run(soh: 100), [
        past(DateTime.utc(2026, 4, 1), soh: 86),
      ]);
      expect(c.counters.sohRose, isTrue);
      expect(
        has(series.evaluate(c), AdviceCode.inspectionRepeatCountersReset),
        isTrue,
      );
    });

    test('a rounding wobble in health is not an accusation', () {
      final c = series.compare(run(soh: 100), [
        past(DateTime.utc(2026, 4, 1), soh: 99.8),
      ]);
      expect(c.counters.sohRose, isFalse);
      expect(
        has(series.evaluate(c), AdviceCode.inspectionRepeatCountersReset),
        isFalse,
      );
    });

    test('a configured capacity that changed is a reconfigured pack', () {
      final c = series.compare(run(configuredAh: 50), [
        past(DateTime.utc(2026, 4, 1), configuredAh: 40),
      ]);
      expect(c.counters.capacityChanged, isTrue);
      expect(
        has(series.evaluate(c), AdviceCode.inspectionRepeatCountersReset),
        isTrue,
      );
    });

    test('counters that only went the way counters go say nothing', () {
      final c = series.compare(run(cycles: 190, soh: 84), [
        past(DateTime.utc(2026, 4, 1), cycles: 180, soh: 86),
      ]);
      expect(c.counters.anything, isFalse);
      expect(
        has(series.evaluate(c), AdviceCode.inspectionRepeatCountersReset),
        isFalse,
      );
    });
  });

  test('the worst news is first in the list', () {
    final c = series.compare(run(weakCell: 7, weakSag: 0.42, cycles: 3), [
      past(DateTime.utc(2026, 4, 1), weakCell: 7, weakSag: 0.30, cycles: 180),
    ]);
    final advice = series.evaluate(c);
    expect(advice.first.level, AdviceLevel.problem);
    expect(advice.length, greaterThanOrEqualTo(3));
  });

  test('the run number counts this run in', () {
    final c = series.compare(run(), [
      past(DateTime.utc(2026, 4, 1)),
      past(DateTime.utc(2026, 4, 20)),
      past(DateTime.utc(2026, 4, 28)),
    ]);
    expect(c.runNumber, 4);
    expect(c.previous!.at, DateTime.utc(2026, 4, 28));
  });
}
