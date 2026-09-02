import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/metrics/advice_engine.dart';
import 'package:jk_bms/src/metrics/cell_drift.dart';
import 'package:jk_bms/src/metrics/degradation.dart';
import 'package:jk_bms/src/metrics/pack_health_report.dart';
import 'package:jk_bms/src/metrics/range_estimator.dart';
import 'package:jk_bms/src/metrics/range_outlook.dart';

import 'fixtures/snapshot_builder.dart';

/// The sentences a person reads first, and the facts each one rests on.
void main() {
  const engine = AdviceEngine();
  final jan = DateTime.utc(2026, 1, 10);
  final jul = DateTime.utc(2026, 7, 10);

  Advice only(List<Advice> all, AdviceCode code) =>
      all.singleWhere((a) => a.code == code);

  bool has(List<Advice> all, AdviceCode code) => all.any((a) => a.code == code);

  group('health', () {
    test(
      'states capacity kept against the pack\'s own best, with the two figures',
      () {
        final wear = Degradation(
          baseline: CapacityPointOfRecord(
            ah: 40.0,
            at: jan,
            source: CapacitySource.measured,
          ),
          current: CapacityPointOfRecord(
            ah: 34.0,
            at: jul,
            source: CapacitySource.measured,
          ),
          observations: 2,
        );
        final v = only(
          engine.headlines(degradation: wear),
          AdviceCode.healthMeasured,
        );
        expect(v.value, closeTo(85, 0.01));
        expect(v.level, AdviceLevel.watch);
        final kinds = v.evidence.map((e) => e.kind).toList();
        expect(kinds, contains(EvidenceKind.baselineCapacity));
        expect(kinds, contains(EvidenceKind.currentCapacity));
        expect(
          v.evidence
              .firstWhere((e) => e.kind == EvidenceKind.baselineCapacity)
              .at,
          jan,
        );
      },
    );

    test(
      'a pack that kept nearly everything is good news, and a wasted one a problem',
      () {
        Degradation at(double now) => Degradation(
          baseline: CapacityPointOfRecord(
            ah: 40,
            at: jan,
            source: CapacitySource.measured,
          ),
          current: CapacityPointOfRecord(
            ah: now,
            at: jul,
            source: CapacitySource.measured,
          ),
          observations: 2,
        );
        expect(
          only(
            engine.headlines(degradation: at(38)),
            AdviceCode.healthMeasured,
          ).level,
          AdviceLevel.good,
        );
        expect(
          only(
            engine.headlines(degradation: at(30)),
            AdviceCode.healthMeasured,
          ).level,
          AdviceLevel.problem,
        );
      },
    );

    test('one measurement is a capacity, not a verdict on wear', () {
      final wear = Degradation(
        baseline: CapacityPointOfRecord(
          ah: 40,
          at: jan,
          source: CapacitySource.measured,
        ),
        current: CapacityPointOfRecord(
          ah: 40,
          at: jan,
          source: CapacitySource.measured,
        ),
        observations: 1,
      );
      final all = engine.headlines(degradation: wear);
      expect(has(all, AdviceCode.healthMeasured), isFalse);
      final v = only(all, AdviceCode.healthNotMeasurable);
      expect(v.value, 1);
      expect(v.evidence.first.kind, EvidenceKind.capacityTests);
    });

    test('says nothing about health when it was not asked to look', () {
      expect(engine.headlines(), isEmpty);
    });
  });

  group('cell drift', () {
    test('names the cell, how long, and how fast', () {
      final drift = [
        const CellDrift(
          index: 10,
          currentDeviationVolts: 0.022,
          earlyDeviationVolts: 0.002,
          changeVoltsPerMonth: 0.012,
          samples: 120,
          spanDays: 21,
        ),
      ];
      final v = only(engine.headlines(drift: drift), AdviceCode.cellDrifting);
      expect(v.cellIndex, 11, reason: '1-based on the label');
      expect(v.value, closeTo(3, 0.01), reason: 'weeks');
      expect(v.level, AdviceLevel.watch);
      expect(
        v.evidence.firstWhere((e) => e.kind == EvidenceKind.driftRate).value,
        0.012,
      );
    });

    test('a cell far under the pack is past watching', () {
      final drift = [
        const CellDrift(
          index: 3,
          currentDeviationVolts: 0.045,
          earlyDeviationVolts: 0.000,
          changeVoltsPerMonth: 0.020,
          samples: 200,
          spanDays: 60,
        ),
      ];
      expect(
        only(engine.headlines(drift: drift), AdviceCode.cellDrifting).level,
        AdviceLevel.problem,
      );
    });

    test('with enough history and nothing drifting, it says so', () {
      final drift = [
        const CellDrift(
          index: 5,
          currentDeviationVolts: 0.006,
          earlyDeviationVolts: 0.005,
          changeVoltsPerMonth: 0.0005,
          samples: 90,
          spanDays: 28,
        ),
      ];
      final v = only(engine.headlines(drift: drift), AdviceCode.noCellDrifting);
      expect(v.level, AdviceLevel.good);
      expect(v.value, closeTo(4, 0.01));
    });

    test(
      'with too little history, it says nothing rather than "all clear"',
      () {
        final all = engine.headlines(drift: const []);
        expect(has(all, AdviceCode.noCellDrifting), isFalse);
        expect(has(all, AdviceCode.cellDrifting), isFalse);
      },
    );
  });

  group('range', () {
    test('quotes kilometres left, with the consumption they rest on', () {
      final estimator = RangeEstimator();
      for (var i = 0; i < 6; i++) {
        estimator.addSegment(wh: 200, km: 10);
      }
      final outlook = RangeOutlook(
        nowKm: 23.4,
        nowBandKm: (20, 27),
        confidence: estimator.confidence,
        hasLearned: true,
      );
      final v = only(
        engine.headlines(outlook: outlook, estimator: estimator),
        AdviceCode.rangeNow,
      );
      expect(v.value, 23.4);
      expect(
        v.evidence.firstWhere((e) => e.kind == EvidenceKind.whPerKm).value,
        closeTo(20, 0.01),
      );
      final band = v.evidence.firstWhere(
        (e) => e.kind == EvidenceKind.rangeBand,
      );
      expect((band.value, band.value2), (20, 27));
    });

    test('says nothing until the estimator has learned from real riding', () {
      final all = engine.headlines(
        outlook: RangeOutlook.unknown,
        estimator: RangeEstimator(),
      );
      expect(has(all, AdviceCode.rangeNow), isFalse);
    });
  });

  group('delta under load', () {
    test('a delta that does not open under load is said to be normal', () {
      final v = only(
        engine.headlines(restingDelta: 0.012, loadedDelta: 0.030),
        AdviceCode.deltaUnderLoadNormal,
      );
      expect(v.level, AdviceLevel.good);
      expect(v.evidence, hasLength(2));
    });

    test('is not said about a session that never pulled current', () {
      expect(
        has(
          engine.headlines(restingDelta: 0.012),
          AdviceCode.deltaUnderLoadNormal,
        ),
        isFalse,
      );
    });

    test('is never said alongside an imbalance finding', () {
      // Wide at rest: the finding fires and the all-clear stays quiet.
      final all = engine.evaluate(
        snapshot: buildSnapshot(),
        report: PackHealthReport.from(
          snapshot: buildSnapshot(),
          catalogueCapacityAh: 45,
        ),
        estimator: RangeEstimator(),
        restingDelta: 0.050,
        loadedDelta: 0.060,
      );
      expect(has(all, AdviceCode.imbalanceAtRest), isTrue);
      expect(has(all, AdviceCode.deltaUnderLoadNormal), isFalse);

      // Opens under load: same.
      final loaded = engine.evaluate(
        snapshot: buildSnapshot(),
        report: PackHealthReport.from(
          snapshot: buildSnapshot(),
          catalogueCapacityAh: 45,
        ),
        estimator: RangeEstimator(),
        restingDelta: 0.010,
        loadedDelta: 0.080,
      );
      expect(has(loaded, AdviceCode.imbalanceUnderLoad), isTrue);
      expect(has(loaded, AdviceCode.deltaUnderLoadNormal), isFalse);
    });
  });

  group('evidence and order', () {
    test('every finding carries at least one fact behind it', () {
      final cells = List.filled(20, 3.90);
      cells[6] = 3.70;
      final all = engine.evaluate(
        snapshot: buildSnapshot(cells: cells, temperatures: [58.0]),
        report: PackHealthReport.from(
          snapshot: buildSnapshot(cells: cells),
          catalogueCapacityAh: 45,
        ),
        estimator: RangeEstimator(),
        restingDelta: 0.070,
        loadedDelta: 0.120,
        weakCellCounts: {7: 90, 3: 10},
        usableWh: 700,
        grossWh: 1000,
      );
      expect(all, isNotEmpty);
      for (final a in all) {
        expect(a.evidence, isNotEmpty, reason: a.code.name);
      }
    });

    test('problems first, good news last', () {
      final all = engine.evaluate(
        snapshot: buildSnapshot(temperatures: [58.0]),
        report: PackHealthReport.from(
          snapshot: buildSnapshot(),
          catalogueCapacityAh: 45,
        ),
        estimator: RangeEstimator(),
        restingDelta: 0.010,
        loadedDelta: 0.020,
      );
      expect(all.first.level, AdviceLevel.problem);
      expect(all.last.level, AdviceLevel.good);
      expect(all.last.code, AdviceCode.deltaUnderLoadNormal);
    });

    test('the live evaluation and the offline headlines agree', () {
      final wear = Degradation(
        baseline: CapacityPointOfRecord(
          ah: 40,
          at: jan,
          source: CapacitySource.measured,
        ),
        current: CapacityPointOfRecord(
          ah: 36,
          at: jul,
          source: CapacitySource.measured,
        ),
        observations: 2,
      );
      final live = only(
        engine.evaluate(
          snapshot: buildSnapshot(),
          report: PackHealthReport.from(
            snapshot: buildSnapshot(),
            catalogueCapacityAh: 45,
          ),
          estimator: RangeEstimator(),
          degradation: wear,
        ),
        AdviceCode.healthMeasured,
      );
      final offline = only(
        engine.headlines(degradation: wear),
        AdviceCode.healthMeasured,
      );
      expect(live.value, offline.value);
      expect(live.level, offline.level);
    });

    test('thresholds are one object, and moving one moves the verdict', () {
      const strict = AdviceEngine(
        thresholds: VerdictThresholds(healthGoodPercent: 99),
      );
      final wear = Degradation(
        baseline: CapacityPointOfRecord(
          ah: 40,
          at: jan,
          source: CapacitySource.measured,
        ),
        current: CapacityPointOfRecord(
          ah: 38,
          at: jul,
          source: CapacitySource.measured,
        ),
        observations: 2,
      );
      expect(
        only(
          engine.headlines(degradation: wear),
          AdviceCode.healthMeasured,
        ).level,
        AdviceLevel.good,
      );
      expect(
        only(
          strict.headlines(degradation: wear),
          AdviceCode.healthMeasured,
        ).level,
        AdviceLevel.watch,
      );
    });
  });
}
