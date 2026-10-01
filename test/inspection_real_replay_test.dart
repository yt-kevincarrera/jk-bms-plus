import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/inspection/inspection_result.dart';
import 'package:jk_bms/src/inspection/inspection_session.dart';
import 'package:jk_bms/src/inspection/inspection_verdicts.dart';
import 'package:jk_bms/src/metrics/advice_engine.dart';

import 'fixtures/snapshot_builder.dart';

/// The 805 readings of a real inspection, replayed through the real session.
///
/// Taken out of a backup of the pack "KevinJK" (JK-BD6A20S6P, 40 Ah
/// configured, 20S NMC), inspected on 2026-09-05. Not a scenario written to
/// make a point: this is what the BMS actually sent, current and all twenty
/// cells, at the two and a half readings a second it actually sends.
///
/// What the app did with it at the time: the light step timed out with the
/// lights on, the heavy step timed out on a stand, nothing was measured, and
/// the verdict came out green.
void main() {
  final rows =
      (jsonDecode(
                File(
                  'test/fixtures/real_inspection_kevinjk.json',
                ).readAsStringSync(),
              )
              as List<dynamic>)
          .cast<Map<String, dynamic>>();

  InspectionSession replay([
    InspectionThresholds th = InspectionThresholds.defaults,
  ]) {
    final s = InspectionSession(thresholds: th);
    for (final r in rows) {
      s.feed(
        buildSnapshot(
          timestamp: DateTime.parse(r['t'] as String),
          cells: [
            for (final v in r['c'] as List<dynamic>) (v as num).toDouble(),
          ],
          current: (r['i'] as num).toDouble(),
          // What this pack's firmware is configured to hold, from the same
          // inspection's reported figures.
          nominalCapacityAh: 40,
        ),
      );
    }
    return s;
  }

  test('the recording is the one that was diagnosed', () {
    // Guards the fixture rather than the code. If these drift, every claim
    // below is about a different afternoon.
    expect(rows.length, 805);
    final light = [
      for (final r in rows) (r['i'] as num).toDouble().abs(),
    ].where((a) => a > 0.4 && a < 0.5);
    expect(light.length, greaterThan(250), reason: 'the 0.44 A lights');
    expect(
      [
        for (final r in rows) (r['i'] as num).toDouble().abs(),
      ].reduce((a, b) => a > b ? a : b),
      closeTo(14.20, 0.01),
    );
  });

  test('the lights are now recognised as the lights', () {
    // The whole first complaint: 0.44 A with the lights plainly on, and the
    // app saying the pack needed more until the step gave up.
    final s = replay();
    expect(
      s.skippedSteps,
      isNot(contains(InspectionStep.lightLoad)),
      reason: '0.44 A over a rest of 0.00 A is a load',
    );
    final r = const InspectionAnalysis().compute(s);
    expect(r.caveats, isNot(contains(InspectionCaveat.noLightLoad)));
    expect(r.lightLoadAmps, isNotNull);
    expect(r.lightLoadAmps!, closeTo(0.44, 0.02));
  });

  test('the stand still cannot pass the hard pull, and says so', () {
    // Not something to paper over. A wheel spinning free is not a load: the
    // 14.20 A peak was two readings of the wheel's own inertia and the rest
    // of the step sat at 1.5 A. Lowering the bar until this passed would buy
    // a sag figure off cell voltages that were never under load.
    final s = replay();
    final r = const InspectionAnalysis().compute(s);
    expect(r.caveats, contains(InspectionCaveat.noHeavyLoad));
    expect(r.medianHeavySagVolts, isNull);
  });

  test('and the verdict is no longer green', () {
    // The dangerous one. This exact run showed "Nada grave a la vista" on a
    // test that measured nothing at all.
    final s = replay();
    final r = const InspectionAnalysis().compute(s);
    expect(const InspectionVerdicts().light(r), InspectionLight.unmeasured);
  });

  test('no recovery is claimed after a pull that never happened', () {
    // The heavy step timed out, and the session used to walk on into the
    // recovery step anyway: the cells were timed climbing back from a load
    // they never had, all of them made it in 0.0 s, and the verdict said
    // "even recovery" over a printed "median recovery 0.0 s".
    final s = replay();
    expect(s.isDone, isTrue, reason: 'the test ends at the heavy timeout');
    expect(s.skippedSteps, contains(InspectionStep.recovery));
    final r = const InspectionAnalysis().compute(s);
    expect(r.medianRecoverySeconds, isNull);
    expect(r.cells.every((c) => c.recoverySeconds == null), isTrue);
    expect(r.caveats, contains(InspectionCaveat.recoveryNoLoad));
    expect(r.caveats, isNot(contains(InspectionCaveat.noRecovery)));
    final codes = const InspectionVerdicts().evaluate(r).map((a) => a.code);
    expect(codes, isNot(contains(AdviceCode.inspectionRecoveryOk)));
    // What is still worth saying: the lights, and a tight rest.
    expect(r.restDeltaVolts, closeTo(0.005, 0.0011));
    expect(codes, contains(AdviceCode.inspectionRestDeltaOk));
    expect(r.caveats, isNot(contains(InspectionCaveat.linkGaps)));
  });

  group('the stand, counted as a pull on purpose', () {
    // Lowering the bar until the wheel on the stand passes is exactly the
    // trap the calibration refused, and it is replayed here for that reason:
    // to show what the new arithmetic does with these real frames when it
    // is handed a load this small.
    const relaxed = InspectionThresholds(
      heavyLoadCRate: 0,
      heavyLoadFloorAmps: 1.4,
      minimumStepAmps: 1.0,
    );

    InspectionResult measured() =>
        const InspectionAnalysis(thresholds: relaxed).compute(
          replay(relaxed),
          reported: const ReportedFigures(configuredCapacityAh: 40),
        );

    test('reads the real cells at about 3 mOhm, frame by frame', () {
      final r = measured();
      expect(r.hasHeavyLoad, isTrue);
      // The held window is the last unbroken run above the bar, at the
      // stand's steady 1.5 to 1.7 A. The two readings of the wheel's own
      // inertia at 14.2 A are not in it, and cannot set anybody's sag.
      expect(r.currentStepAmps, inInclusiveRange(1.4, 2.0));
      expect(r.medianHeavySagVolts!, closeTo(0.005, 0.0015));
      expect(r.medianResistanceOhms!, closeTo(0.003, 0.001));
    });

    test('and still will not call the pack good on 1.6 A', () {
      final r = measured();
      const v = InspectionVerdicts(thresholds: relaxed);
      // At 1.6 A the least extra resistance that stands out from the 5 mV
      // the cells flicker by is 3 mOhm, double the line a finding is drawn
      // at. The worst cell reads 1.8 mOhm over the median, which on the old
      // millivolt bar would have been nothing and on a bare resistance bar
      // would have been amber: it is neither, it is under the floor.
      final floor = r.detectionFloorOhms(relaxed.sagResolutionVolts)!;
      expect(floor, greaterThan(relaxed.sagWatchOhms));
      expect(r.worstExcessOhms!, lessThan(floor));
      final codes = v.evaluate(r).map((a) => a.code).toList();
      expect(codes, contains(AdviceCode.inspectionSagUnresolved));
      expect(codes, isNot(contains(AdviceCode.inspectionSagUniform)));
      expect(codes, isNot(contains(AdviceCode.inspectionCellSagging)));
      // Recovery after 1.6 A on 40 Ah tells nothing apart, and says so.
      expect(codes, contains(AdviceCode.inspectionRecoveryNotDiscriminating));
      expect(codes, isNot(contains(AdviceCode.inspectionRecoveryOk)));
      expect(v.light(r), InspectionLight.unmeasured);
    });
  });
}
