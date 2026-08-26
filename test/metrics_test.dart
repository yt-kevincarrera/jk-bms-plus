import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/metrics/pack_health_report.dart';
import 'package:jk_bms/src/metrics/range_estimator.dart';
import 'package:jk_bms/src/model/bms_snapshot.dart';
import 'package:jk_bms/src/model/bms_warning.dart';
import 'package:jk_bms/src/protocol/protocol_variant.dart';

BmsSnapshot snapshot({
  List<double>? cells,
  double soc = 78,
  double remainingAh = 35.1,
  double nominalAh = 45,
  int cycles = 63,
  double cycleCapacityAh = 2843.5,
  double soh = 97,
  List<double>? resistances,
}) {
  final v = cells ?? List.filled(20, 3.90);
  return BmsSnapshot(
    timestamp: DateTime.utc(2026, 1, 1),
    variant: JkProtocolVariant.jk02_24s,
    frameCounter: 1,
    cellVoltages: v,
    cellResistances: resistances ?? List.filled(20, 0.0025),
    enabledCellMask: 0xFFFFF,
    packVoltage: v.reduce((a, b) => a + b),
    current: -20,
    temperatures: const [24, 23],
    temperatureSensorMask: 7,
    mosfetTemp: 27,
    soc: soc,
    soh: soh,
    remainingCapacityAh: remainingAh,
    nominalCapacityAh: nominalAh,
    cycleCount: cycles,
    cycleCapacityAh: cycleCapacityAh,
    balancingAction: 0,
    balanceCurrent: 0,
    chargeMosfetOn: true,
    dischargeMosfetOn: true,
    balancerActive: false,
    heatingOn: false,
    warnings: BmsWarnings.none,
    wireResistanceWarningMask: 0,
    heatingCurrent: 0,
    totalRuntimeSeconds: 3600,
  );
}

void main() {
  group('RangeEstimator', () {
    test('starts on its default and says it has learned nothing', () {
      final e = RangeEstimator();
      expect(e.hasLearned, isFalse);
      expect(e.whPerKm, 28.0);
      expect(e.confidence, RangeConfidence.low);
    });

    test('the first real segment replaces the default outright', () {
      final e = RangeEstimator()..addSegment(wh: 400, km: 10);
      expect(e.hasLearned, isTrue);
      expect(e.whPerKm, closeTo(40, 1e-9));
      expect(e.learnedKm, 10);
    });

    test('later segments pull the estimate toward recent riding', () {
      final e = RangeEstimator()
        ..addSegment(wh: 400, km: 10) // 40 Wh/km
        ..addSegment(wh: 200, km: 10); // 20 Wh/km

      // Between the two, and moved toward the newer sample.
      expect(e.whPerKm, lessThan(40));
      expect(e.whPerKm, greaterThan(20));
      expect(e.learnedKm, 20);
    });

    test('a long segment moves the estimate more than a short one', () {
      final slow = RangeEstimator()
        ..addSegment(wh: 400, km: 10)
        ..addSegment(wh: 20, km: 1);
      final fast = RangeEstimator()
        ..addSegment(wh: 400, km: 10)
        ..addSegment(wh: 600, km: 30);

      expect(40 - slow.whPerKm, lessThan((fast.whPerKm - 20).abs()));
    });

    test('confidence grows with distance', () {
      final e = RangeEstimator();
      e.addSegment(wh: 120, km: 4);
      expect(e.confidence, RangeConfidence.low);
      e.addSegment(wh: 600, km: 20);
      expect(e.confidence, RangeConfidence.medium);
      e.addSegment(wh: 1500, km: 50);
      expect(e.confidence, RangeConfidence.high);
    });

    test('the quoted band narrows as confidence grows', () {
      final young = RangeEstimator();
      final seasoned = RangeEstimator()..addSegment(wh: 2800, km: 100);

      double width(RangeEstimator e) {
        final (lo, hi) = e.rangeBandKm(1000);
        return hi - lo;
      }

      expect(width(seasoned), lessThan(width(young)));
    });

    test('rejects samples that cannot be real', () {
      final e = RangeEstimator()
        // GPS noise while stopped at a light.
        ..addSegment(wh: 50, km: 0.05)
        // Regenerated more than it used.
        ..addSegment(wh: -10, km: 5)
        // Physically absurd consumption.
        ..addSegment(wh: 5000, km: 1);

      expect(e.hasLearned, isFalse);
      expect(e.learnedKm, 0);
    });

    test('survives a save and reload', () {
      final e = RangeEstimator()..addSegment(wh: 500, km: 20);
      final restored = RangeEstimator.fromJson(e.toJson());

      expect(restored.whPerKm, closeTo(e.whPerKm, 1e-9));
      expect(restored.learnedKm, e.learnedKm);
      expect(restored.hasLearned, isTrue);
    });

    group('usable energy', () {
      test('a balanced pack can use nearly all of it', () {
        final wh = RangeEstimator.usableWh(
          remainingAh: 35,
          packVoltage: 78,
          cellCount: 20,
          minCellVoltage: 3.895,
          averageCellVoltage: 3.900,
          cutoffVoltagePerCell: 3.0,
        );
        expect(wh, closeTo(35 * 78, 35 * 78 * 0.01));
      });

      test('a dragging cell strands real energy', () {
        final balanced = RangeEstimator.usableWh(
          remainingAh: 35,
          packVoltage: 78,
          cellCount: 20,
          minCellVoltage: 3.90,
          averageCellVoltage: 3.90,
          cutoffVoltagePerCell: 3.0,
        );
        final imbalanced = RangeEstimator.usableWh(
          remainingAh: 35,
          packVoltage: 78,
          cellCount: 20,
          minCellVoltage: 3.60,
          averageCellVoltage: 3.90,
          cutoffVoltagePerCell: 3.0,
        );
        expect(imbalanced, lessThan(balanced));
        // 0.60 V of headroom against 0.90 V is two thirds usable.
        expect(imbalanced / balanced, closeTo(2 / 3, 0.01));
      });

      test('a cell already at cutoff means nothing is usable', () {
        final wh = RangeEstimator.usableWh(
          remainingAh: 35,
          packVoltage: 78,
          cellCount: 20,
          minCellVoltage: 3.0,
          averageCellVoltage: 3.6,
          cutoffVoltagePerCell: 3.0,
        );
        expect(wh, 0);
      });
    });
  });

  group('PackHealthReport', () {
    test('implies capacity from remaining over charge', () {
      final r = PackHealthReport.from(
        snapshot: snapshot(soc: 80, remainingAh: 32),
        catalogueCapacityAh: 45,
      );
      expect(r.impliedCapacityAh, closeTo(40, 1e-9));
      // 40 against a 45 Ah sticker is an 11% shortfall.
      expect(r.capacityLossFraction, closeTo(1 - 40 / 45, 1e-9));
    });

    test('refuses the capacity maths near the ends of the range', () {
      for (final soc in [4.0, 99.0]) {
        final r = PackHealthReport.from(
          snapshot: snapshot(soc: soc),
          catalogueCapacityAh: 45,
        );
        expect(r.capacityMeaningful, isFalse);
        expect(r.impliedCapacityAh, isNull);
      }
    });

    test('converts charge throughput into honest full cycles', () {
      final r = PackHealthReport.from(
        // 2843.5 Ah through a 45 Ah pack is about 63 full cycles...
        snapshot: snapshot(cycles: 63, cycleCapacityAh: 2843.5, nominalAh: 45),
      );
      expect(r.equivalentFullCycles, closeTo(63.2, 0.1));
      expect(r.cycleInflation, closeTo(1.0, 0.02));
    });

    test('catches a cycle counter that flatters the pack', () {
      final r = PackHealthReport.from(
        // The BMS claims 200 cycles, but only 45 pack-fulls have gone through.
        snapshot: snapshot(cycles: 200, cycleCapacityAh: 2025, nominalAh: 45),
      );
      expect(r.equivalentFullCycles, closeTo(45, 0.1));
      expect(r.cycleInflation, closeTo(200 / 45, 0.05));
    });

    test('prices the imbalance in amp-hours', () {
      final cells = List.filled(20, 3.90);
      cells[6] = 3.60;
      final r = PackHealthReport.from(
        snapshot: snapshot(cells: cells, remainingAh: 30),
        cutoffVoltagePerCell: 3.0,
      );
      expect(r.weakestCellIndex, 7);
      expect(r.imbalanceLossFraction, greaterThan(0.3));
      expect(r.imbalanceLossAh, greaterThan(9));
    });

    test('ranks the worst cell resistance against the median', () {
      final resistances = List.filled(20, 0.0025);
      resistances[6] = 0.0050;
      final r = PackHealthReport.from(
        snapshot: snapshot(resistances: resistances),
      );
      expect(r.resistanceSpreadPercent, closeTo(100, 1));
    });

    test('flags a health figure that never moves', () {
      final decorative = PackHealthReport.from(
        snapshot: snapshot(soh: 100, cycleCapacityAh: 2843.5),
      );
      expect(decorative.sohLooksDecorative, isTrue);

      final plausible = PackHealthReport.from(
        snapshot: snapshot(soh: 97, cycleCapacityAh: 2843.5),
      );
      expect(plausible.sohLooksDecorative, isFalse);
    });
  });
}
