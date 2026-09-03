import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/inspection/inspection_result.dart';
import 'package:jk_bms/src/inspection/inspection_session.dart';
import 'package:jk_bms/src/inspection/inspection_verdicts.dart';
import 'package:jk_bms/src/metrics/advice_engine.dart';
import 'package:jk_bms/src/model/bms_snapshot.dart';

import 'fixtures/snapshot_builder.dart';

/// Plays a scripted pack through a session, two readings a second.
///
/// [cellsAt] gives the cell voltages for a moment; [currentAt] the current.
/// Both take the elapsed seconds, so a test describes the pack's behaviour
/// as a function of time and lets the session find the steps by itself.
class Rig {
  Rig({
    this.session,
    required this.currentAt,
    required this.cellsAt,
    this.hz = 2,
  });

  final InspectionSession? session;
  final double Function(double t) currentAt;
  final List<double> Function(double t) cellsAt;
  final int hz;

  final start = DateTime.utc(2026, 9, 3, 10);
  double t = 0;

  BmsSnapshot at(double seconds) => buildSnapshot(
    timestamp: start.add(Duration(milliseconds: (seconds * 1000).round())),
    cells: cellsAt(seconds),
    current: currentAt(seconds),
  );

  /// Feeds readings until [seconds] have passed or the session finishes.
  /// Returns true when the session finished.
  bool run(InspectionSession s, double seconds) {
    while (t < seconds) {
      if (s.feed(at(t))) return true;
      t += 1 / hz;
    }
    return false;
  }
}

/// A healthy 20S pack: even resistances, small spread.
List<double> healthyCells(double amps, {double sagOhms = 0.0025}) =>
    List<double>.generate(20, (i) => 3.90 + (i % 3) * 0.002 - amps * sagOhms);

/// The same pack with cell 7 (index 6) three times as resistive and, at rest,
/// a touch low.
List<double> weakCellPack(double amps) {
  final v = healthyCells(amps);
  v[6] = 3.895 - amps * 0.0075;
  return v;
}

/// The script the PRD describes: 30 s quiet, lights, a hard pull, release.
double scripted(double t) {
  if (t < 35) return 0.0;
  if (t < 55) return -2.0; // lights
  if (t < 63) return -40.0; // rear wheel in the air, throttle
  return 0.0; // released
}

void main() {
  group('the guided steps advance on current, not on a button', () {
    test('a clean run walks rest, light, heavy, recovery, done', () {
      final s = InspectionSession();
      final rig = Rig(currentAt: scripted, cellsAt: healthyCells);
      final steps = <InspectionStep>[s.step];

      var finished = false;
      while (!finished && rig.t < 200) {
        finished = s.feed(rig.at(rig.t));
        if (s.step != steps.last) steps.add(s.step);
        rig.t += 0.5;
      }
      expect(finished, isTrue);
      expect(steps, [
        InspectionStep.rest,
        InspectionStep.lightLoad,
        InspectionStep.heavyLoad,
        InspectionStep.recovery,
        InspectionStep.done,
      ]);
      expect(s.skippedSteps, isEmpty);
      expect(s.peakDischargeAmps, 40);
      // Ends about 45 s after release at t=63, so around 108 s, not at the
      // step timeout.
      expect(rig.t, lessThan(120));
    });

    test('rest restarts when the vendor touches the throttle', () {
      // Quiet for 20 s, a blip, then quiet again. The rest step must only
      // complete 30 s after the blip.
      final s = InspectionSession();
      final rig = Rig(
        currentAt: (t) => (t >= 20 && t < 22) ? -8.0 : 0.0,
        cellsAt: healthyCells,
      );
      rig.run(s, 40);
      expect(s.step, InspectionStep.rest, reason: 'only 18 s quiet since blip');
      rig.run(s, 53);
      expect(s.step, InspectionStep.lightLoad);
    });

    test('a hard pull straight after rest skips the lights step honestly', () {
      final s = InspectionSession();
      final rig = Rig(
        currentAt: (t) => t < 32 ? 0.0 : (t < 40 ? -30.0 : 0.0),
        cellsAt: healthyCells,
      );
      rig.run(s, 33);
      expect(s.step, InspectionStep.heavyLoad);
      // The light step was passed over, not timed out: nothing is "skipped"
      // in the failure sense, and the analysis simply has no light window.
      expect(s.skippedSteps, isEmpty);
    });

    test('a step that never gets its load times out and is recorded', () {
      final s = InspectionSession(
        thresholds: const InspectionThresholds(stepTimeoutSeconds: 40),
      );
      // Quiet, then lights forever, never a hard pull.
      final rig = Rig(
        currentAt: (t) => t < 32 ? 0.0 : -2.0,
        cellsAt: healthyCells,
      );
      final finished = rig.run(s, 300);
      expect(finished, isTrue);
      expect(s.skippedSteps, contains(InspectionStep.heavyLoad));
      // Recovery never saw the load released either.
      expect(s.skippedSteps, contains(InspectionStep.recovery));
    });

    test('the prompt says what is being asked for and whether it is there', () {
      final s = InspectionSession();
      final rig = Rig(currentAt: scripted, cellsAt: healthyCells);
      rig.run(s, 10);
      var p = s.prompt!;
      expect(p.step, InspectionStep.rest);
      expect(p.loadDetected, isTrue, reason: 'quiet is the condition at rest');
      expect(p.secondsLeft, inInclusiveRange(19, 21));

      rig.run(s, 40);
      p = s.prompt!;
      expect(p.step, InspectionStep.lightLoad);
      expect(p.currentAmps, 2.0);
      expect(p.loadDetected, isTrue);

      rig.run(s, 56);
      p = s.prompt!;
      expect(p.step, InspectionStep.heavyLoad);
      expect(p.loadDetected, isTrue);
      expect(p.progress, greaterThan(0));
    });

    test('aborting marks every remaining step as not measured', () {
      final s = InspectionSession();
      final rig = Rig(currentAt: scripted, cellsAt: healthyCells);
      rig.run(s, 40);
      s.abortToDone();
      expect(s.isDone, isTrue);
      expect(s.skippedSteps, [
        InspectionStep.lightLoad,
        InspectionStep.heavyLoad,
        InspectionStep.recovery,
      ]);
    });
  });

  group('the analysis', () {
    InspectionResult runPack(List<double> Function(double amps) pack) {
      final s = InspectionSession();
      final rig = Rig(
        currentAt: scripted,
        cellsAt: (t) => pack(scripted(t).abs()),
      );
      rig.run(s, 200);
      expect(s.isDone, isTrue);
      return const InspectionAnalysis().compute(
        s,
        reported: const ReportedFigures(
          cycleCount: 12,
          configuredCapacityAh: 45,
        ),
      );
    }

    test('a healthy pack: even sag, tight rest, fast recovery, no caveats', () {
      final r = runPack(healthyCells);
      expect(r.caveats, isEmpty);
      expect(r.cellCount, 20);
      expect(r.restDeltaVolts, closeTo(0.004, 0.0005));
      expect(r.peakDischargeAmps, 40);
      expect(r.currentStepAmps, closeTo(40, 0.5));
      // 40 A across 2.5 mOhm is 100 mV of sag on every cell.
      expect(r.medianHeavySagVolts, closeTo(0.100, 0.002));
      expect(r.worstSagExcess, lessThan(0.005));
      expect(r.medianResistanceOhms, closeTo(0.0025, 0.0002));
      // The model recovers instantly, so every cell is back on the first
      // quiet reading.
      expect(r.medianRecoverySeconds, lessThan(1));
      expect(r.cells.every((c) => c.recovered), isTrue);
    });

    test('a weak cell: named, with its extra sag and resistance', () {
      final r = runPack(weakCellPack);
      final worst = r.worstSag!;
      expect(worst.index, 7, reason: '1-based on the label');
      // 40 A across 7.5 mOhm is 300 mV against 100 mV for the rest.
      expect(r.worstSagExcess, closeTo(0.200, 0.005));
      expect(worst.resistanceOhms, closeTo(0.0075, 0.0003));
      expect(r.restDeltaVolts, closeTo(0.009, 0.001));
    });

    test('no hard pull means no sag figures and a caveat, not a guess', () {
      final s = InspectionSession(
        thresholds: const InspectionThresholds(stepTimeoutSeconds: 40),
      );
      final rig = Rig(
        currentAt: (t) => t < 32 ? 0.0 : -2.0,
        cellsAt: (t) => healthyCells(t < 32 ? 0 : 2),
      );
      rig.run(s, 300);
      final r = const InspectionAnalysis().compute(s);
      expect(r.caveats, contains(InspectionCaveat.noHeavyLoad));
      expect(r.medianHeavySagVolts, isNull);
      expect(r.medianResistanceOhms, isNull);
      expect(r.cells.every((c) => c.heavySagVolts == null), isTrue);
      // But the lights step did happen and is reported.
      expect(r.lightLoadAmps, closeTo(2, 0.1));
    });

    test('a cell that never climbs back is flagged, not timed out quietly', () {
      // Cell 12 sits 40 mV under its rest for the whole recovery window.
      final s = InspectionSession();
      final rig = Rig(
        currentAt: scripted,
        cellsAt: (t) {
          final v = healthyCells(scripted(t).abs());
          if (t >= 63) v[11] -= 0.040;
          return v;
        },
      );
      rig.run(s, 200);
      final r = const InspectionAnalysis().compute(s);
      final slow = r.slowestRecovery!;
      expect(slow.index, 12);
      expect(slow.recovered, isFalse);
    });

    test('the result survives a round trip through JSON', () {
      final r = runPack(weakCellPack);
      final back = InspectionResult.fromJson(r.toJson());
      expect(back.cellCount, r.cellCount);
      expect(back.worstSag!.index, r.worstSag!.index);
      expect(back.restDeltaVolts, closeTo(r.restDeltaVolts, 0.001));
      expect(back.reported.cycleCount, 12);
      expect(back.caveats, r.caveats);
      expect(back.readings, r.readings);
    });

    test('samples survive a round trip too', () {
      final s = InspectionSession();
      final rig = Rig(currentAt: scripted, cellsAt: healthyCells);
      rig.run(s, 40);
      final json = [for (final x in s.samples) x.toJson()];
      final back = [for (final m in json) InspectionSample.fromJson(m)];
      expect(back.length, s.samples.length);
      expect(back.first.step, InspectionStep.rest);
      expect(back.last.cells.length, 20);
    });
  });

  group('the verdict', () {
    const verdicts = InspectionVerdicts();

    InspectionResult result(List<double> Function(double) pack) {
      final s = InspectionSession();
      final rig = Rig(
        currentAt: scripted,
        cellsAt: (t) => pack(scripted(t).abs()),
      );
      rig.run(s, 200);
      return const InspectionAnalysis().compute(
        s,
        reported: const ReportedFigures(
          cycleCount: 12,
          configuredCapacityAh: 45,
        ),
      );
    }

    bool has(List<Advice> all, AdviceCode c) => all.any((a) => a.code == c);

    test('a healthy pack is green, with the good news said out loud', () {
      final r = result(healthyCells);
      final all = verdicts.evaluate(r);
      expect(verdicts.light(r), InspectionLight.good);
      expect(has(all, AdviceCode.inspectionSagUniform), isTrue);
      expect(has(all, AdviceCode.inspectionRestDeltaOk), isTrue);
      expect(has(all, AdviceCode.inspectionRecoveryOk), isTrue);
      expect(has(all, AdviceCode.inspectionCellSagging), isFalse);
      // The counters are always shown and always marked, even on a good pack.
      final counters = all.singleWhere(
        (a) => a.code == AdviceCode.inspectionCountersEditable,
      );
      expect(counters.level, AdviceLevel.info);
      expect(
        counters.evidence.map((e) => e.kind),
        containsAll([
          EvidenceKind.reportedCycles,
          EvidenceKind.impliedCapacity,
        ]),
      );
    });

    test('a weak cell is red and named', () {
      final r = result(weakCellPack);
      expect(verdicts.light(r), InspectionLight.problem);
      final sag = verdicts
          .evaluate(r)
          .singleWhere((a) => a.code == AdviceCode.inspectionCellSagging);
      expect(sag.level, AdviceLevel.problem);
      expect(sag.cellIndex, 7);
      expect(
        sag.evidence.map((e) => e.kind),
        contains(EvidenceKind.cellResistance),
      );
    });

    test('a mildly uneven cell is amber, not red', () {
      final r = result((amps) {
        final v = healthyCells(amps);
        v[3] -= amps * 0.0012; // 48 mV extra at 40 A
        return v;
      });
      expect(verdicts.light(r), InspectionLight.watch);
    });

    test('without a hard pull the verdict says so and stays honest', () {
      final s = InspectionSession(
        thresholds: const InspectionThresholds(stepTimeoutSeconds: 40),
      );
      final rig = Rig(
        currentAt: (t) => t < 32 ? 0.0 : -2.0,
        cellsAt: (t) => healthyCells(t < 32 ? 0 : 2),
      );
      rig.run(s, 300);
      final r = const InspectionAnalysis().compute(s);
      final all = verdicts.evaluate(r);
      expect(has(all, AdviceCode.inspectionNoHeavyLoad), isTrue);
      expect(has(all, AdviceCode.inspectionSagUniform), isFalse);
      expect(has(all, AdviceCode.inspectionCellSagging), isFalse);
    });

    test('every verdict carries evidence, problems first', () {
      final all = verdicts.evaluate(result(weakCellPack));
      expect(all, isNotEmpty);
      for (final a in all) {
        expect(a.evidence, isNotEmpty, reason: a.code.name);
      }
      expect(all.first.level, AdviceLevel.problem);
      expect(all.last.level.index, lessThanOrEqualTo(AdviceLevel.info.index));
    });
  });
}
