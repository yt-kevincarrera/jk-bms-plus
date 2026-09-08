import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/metrics/advice_engine.dart';
import 'package:jk_bms/src/metrics/advice_grouping.dart';

void main() {
  group('every finding belongs somewhere', () {
    // The mapping has to be total. A code with no subject would vanish from
    // the screen rather than land in a wrong group, which is the failure mode
    // worth guarding: a finding the app worked out and then did not say.

    test('all 55 codes resolve, and nothing throws', () {
      for (final code in AdviceCode.values) {
        // Null is a real answer for the handful that are caveats about the
        // measurement rather than statements about the battery. What is not
        // allowed is an unhandled case.
        expect(() => subjectOf(code), returnsNormally, reason: '$code');
      }
    });

    test('only the measurement caveats have no subject', () {
      final withoutSubject = AdviceCode.values
          .where((c) => subjectOf(c) == null)
          .toSet();

      // These three say the test itself was weak, not that the pack is. Mixing
      // them in with findings about cells is what makes a reader doubt the
      // findings that are sound.
      expect(withoutSubject, {
        AdviceCode.inspectionNoHeavyLoad,
        AdviceCode.inspectionRepeatLoadDiffers,
        AdviceCode.inspectionRepeatCountersReset,
      });
    });

    test('a cause and its price share a subject', () {
      // The bug this whole change exists to kill: imbalanceAtRest came out as
      // a problem near the top and imbalanceCostingRange as a watch four rows
      // down, separated by unrelated findings, so they read as two findings
      // saying the same thing instead of a finding and what it costs.
      expect(
        subjectOf(AdviceCode.imbalanceCostingRange),
        subjectOf(AdviceCode.imbalanceAtRest),
      );
      expect(subjectOf(AdviceCode.imbalanceAtRest), AdviceSubject.cells);
    });

    test('what the BMS says about itself is one argument, not three', () {
      // Scattered across the health tab, the inspection and the audit, these
      // repeat one idea: the numbers the BMS reports are claims, not
      // measurements. Together they argue it once.
      for (final code in [
        AdviceCode.cycleCounterInflated,
        AdviceCode.healthFigureDecorative,
        AdviceCode.socCounterAhead,
        AdviceCode.socCounterBehind,
        AdviceCode.inspectionCountersEditable,
        AdviceCode.configCapacityDisagrees,
        AdviceCode.configCellCountDisagrees,
        AdviceCode.inspectionAlarmsSeen,
      ]) {
        expect(subjectOf(code), AdviceSubject.bmsClaims, reason: '$code');
      }
    });

    test('heat is heat, wherever it was found', () {
      for (final code in [
        AdviceCode.runningHot,
        AdviceCode.inspectionHot,
        AdviceCode.configChargesWhenFrozen,
        AdviceCode.configColdCutoffOk,
        AdviceCode.configChargeHotLimit,
        AdviceCode.configDischargeHotLimit,
      ]) {
        expect(subjectOf(code), AdviceSubject.temperature, reason: '$code');
      }
    });

    test('the sag and recovery findings are about cells', () {
      for (final code in [
        AdviceCode.inspectionCellSagging,
        AdviceCode.inspectionSagUniform,
        AdviceCode.inspectionRestDeltaWide,
        AdviceCode.inspectionRestDeltaOk,
        AdviceCode.inspectionWeakUnderLightLoad,
        AdviceCode.inspectionSlowRecovery,
        AdviceCode.inspectionRecoveryOk,
        AdviceCode.inspectionRepeatSameCell,
        AdviceCode.inspectionRepeatCellMoved,
        AdviceCode.inspectionRepeatWorse,
        AdviceCode.inspectionRepeatSteady,
        AdviceCode.cellDrifting,
        AdviceCode.noCellDrifting,
        AdviceCode.imbalanceUnderLoad,
        AdviceCode.weakCellDominant,
        AdviceCode.deltaUnderLoadNormal,
        AdviceCode.balancerNeverSeen,
      ]) {
        expect(subjectOf(code), AdviceSubject.cells, reason: '$code');
      }
    });

    test('capacity, range and configuration land where they say', () {
      expect(subjectOf(AdviceCode.healthMeasured), AdviceSubject.capacity);
      expect(subjectOf(AdviceCode.noCapacityTestYet), AdviceSubject.capacity);
      expect(subjectOf(AdviceCode.rangeNow), AdviceSubject.range);
      expect(subjectOf(AdviceCode.rangeStillLearning), AdviceSubject.range);
      expect(
        subjectOf(AdviceCode.configOvpDangerous),
        AdviceSubject.configuration,
      );
      expect(
        subjectOf(AdviceCode.configBalancerOff),
        AdviceSubject.configuration,
      );
    });
  });
}
