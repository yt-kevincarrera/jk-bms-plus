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

    test('a BMS with no cycle counter gets no sentence about its cycles', () {
      // An ANT reports a configured capacity but keeps no cycle count. The
      // counters line fired on the capacity alone and read "the BMS reports
      // -- cycles", which is a sentence about nothing.
      final s = InspectionSession();
      Rig(
        currentAt: scripted,
        cellsAt: (t) => healthyCells(scripted(t).abs()),
      ).run(s, 200);
      final r = const InspectionAnalysis().compute(
        s,
        reported: const ReportedFigures(configuredCapacityAh: 45),
      );
      expect(
        has(verdicts.evaluate(r), AdviceCode.inspectionCountersEditable),
        isFalse,
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
      // Judged as resistance now: 2 mOhm on top of a 2.5 mOhm pack is past
      // the 1.5 mOhm watch line and short of the 3 mOhm problem one. This
      // used to be 1.2 mOhm, amber only because 48 mV cleared a 40 mV bar
      // set for millivolts, which at 4 A would have taken 10 mOhm to clear.
      final r = result((amps) {
        final v = healthyCells(amps);
        v[3] -= amps * 0.0020; // 80 mV extra at 40 A
        return v;
      });
      expect(verdicts.light(r), InspectionLight.watch);
    });

    test('the same bad cell is found at 5 A as at 40 A', () {
      // The fault this fix is about. A pack passes the hard pull at a tenth
      // of C, 4.5 A on this 45 Ah test pack, and at under 5 A a cell with
      // 5 mOhm too much sags only some 24 mV more than the others: under the
      // old 40 mV bar, green, "every cell sags evenly".
      double gentle(double t) {
        if (t < 35) return 0.0;
        if (t < 55) return -0.44;
        if (t < 63) return -4.8;
        return 0.0;
      }

      final s = InspectionSession();
      Rig(
        currentAt: gentle,
        cellsAt: (t) => weakCellPack(gentle(t).abs()),
      ).run(s, 200);
      final r = const InspectionAnalysis().compute(
        s,
        reported: const ReportedFigures(configuredCapacityAh: 40),
      );
      expect(r.hasHeavyLoad, isTrue);
      expect(r.worstSag!.index, 7);
      expect(r.worstExcessOhms!, closeTo(0.005, 0.0005));
      expect(verdicts.light(r), InspectionLight.problem);
    });

    test('a pull too small to see a bad cell is not green', () {
      // Even cells at a small current say nothing about a cell that would
      // only stand out at a bigger one. With the bar lowered so 2 A counts as
      // the hard pull, the least extra resistance 2 A can show is 2.5 mOhm,
      // above the 1.5 mOhm line a finding is drawn at.
      const th = InspectionThresholds(
        heavyLoadCRate: 0,
        heavyLoadFloorAmps: 1.8,
        minimumStepAmps: 1.5,
      );
      double small(double t) {
        if (t < 35) return 0.0;
        if (t < 55) return -0.44;
        if (t < 63) return -2.0;
        return 0.0;
      }

      final s = InspectionSession(thresholds: th);
      Rig(
        currentAt: small,
        cellsAt: (t) => healthyCells(small(t).abs()),
      ).run(s, 200);
      final r = const InspectionAnalysis(thresholds: th).compute(s);
      const v = InspectionVerdicts(thresholds: th);
      final all = v.evaluate(r);
      expect(has(all, AdviceCode.inspectionSagUniform), isFalse);
      final unresolved = all.singleWhere(
        (a) => a.code == AdviceCode.inspectionSagUnresolved,
      );
      expect(unresolved.value!, closeTo(0.0025, 0.0001));
      expect(v.light(r), InspectionLight.unmeasured);
      expect(v.loadTooSmall(r), isTrue);
    });

    test('recovery after a small pull is not praised', () {
      // 4.8 A on 40 Ah is an eighth of C. Every cell is back within
      // millivolts at once after that, so "an even recovery" is not a
      // finding.
      double gentle(double t) {
        if (t < 35) return 0.0;
        if (t < 55) return -0.44;
        if (t < 63) return -4.8;
        return 0.0;
      }

      final s = InspectionSession();
      Rig(
        currentAt: gentle,
        cellsAt: (t) => healthyCells(gentle(t).abs()),
      ).run(s, 200);
      final r = const InspectionAnalysis().compute(
        s,
        reported: const ReportedFigures(configuredCapacityAh: 40),
      );
      final all = verdicts.evaluate(r);
      expect(has(all, AdviceCode.inspectionRecoveryOk), isFalse);
      final rec = all.singleWhere(
        (a) => a.code == AdviceCode.inspectionRecoveryNotDiscriminating,
      );
      expect(rec.level, AdviceLevel.info);
      // And the pull was still enough to clear the pack of a bad cell.
      expect(verdicts.light(r), InspectionLight.good);
    });

    test('heat is placed in the step it was seen in', () {
      final s = InspectionSession();
      Rig(
        currentAt: scripted,
        cellsAt: (t) => healthyCells(scripted(t).abs()),
      ).run(s, 200);
      final r = const InspectionAnalysis().compute(s);
      // buildSnapshot reports 25 C on the hottest probe throughout, so the
      // first reading holds the maximum: the rest step.
      expect(r.maxTemperature, 25);
      expect(r.maxTemperatureStep, InspectionStep.rest);
      final back = InspectionResult.fromJson(r.toJson());
      expect(back.maxTemperatureStep, InspectionStep.rest);
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

  group('what a dropped link and an early end leave unmeasured', () {
    /// Feeds [rig] from [from] to [to] seconds at its own rate.
    void feedRange(InspectionSession s, Rig rig, double from, double to) {
      for (var t = from; t < to; t += 1 / rig.hz) {
        s.feed(rig.at(t));
      }
    }

    test('the first reading after a hole does not complete a step', () {
      // Rest, lights, then the pull starts and the link drops for 40 s. The
      // first frame back is 40 s after the pull began, which used to read
      // as 40 s of hard pull held and complete the step on its own.
      final s = InspectionSession();
      final rig = Rig(currentAt: scripted, cellsAt: healthyCells);
      feedRange(s, rig, 0, 56);
      expect(s.step, InspectionStep.heavyLoad);
      final back = rig.start.add(const Duration(seconds: 96));
      s.feed(
        buildSnapshot(timestamp: back, cells: healthyCells(40), current: -40),
      );
      expect(s.step, InspectionStep.heavyLoad, reason: 'one frame is not 5 s');
      expect(s.linkGaps, 1);
      // Five more seconds of frames, seen, and now it completes.
      for (var k = 1; k <= 12; k++) {
        s.feed(
          buildSnapshot(
            timestamp: back.add(Duration(milliseconds: 500 * k)),
            cells: healthyCells(40),
            current: -40,
          ),
        );
      }
      expect(s.step, InspectionStep.recovery);
    });

    test('a hole in the recovery leaves recovery unmeasured', () {
      // Released at 63 s, two seconds seen, then a 40 s hole. Every cell
      // would otherwise be timed at the length of the outage.
      final s = InspectionSession();
      final rig = Rig(
        currentAt: scripted,
        cellsAt: (t) {
          // Slow cells, so nobody is back before the hole.
          final v = healthyCells(scripted(t).abs());
          if (t >= 63 && t < 120) {
            for (var i = 0; i < v.length; i++) {
              v[i] -= 0.020;
            }
          }
          return v;
        },
      );
      feedRange(s, rig, 0, 65);
      feedRange(s, rig, 105, 200);
      expect(s.isDone, isTrue);
      final r = const InspectionAnalysis().compute(s);
      expect(r.hasHeavyLoad, isTrue);
      expect(r.medianRecoverySeconds, isNull);
      expect(r.caveats, contains(InspectionCaveat.recoveryLinkGap));
      expect(r.caveats, contains(InspectionCaveat.linkGaps));
      expect(
        const InspectionVerdicts().evaluate(r).map((a) => a.code),
        isNot(contains(AdviceCode.inspectionRecoveryOk)),
      );
    });

    test('a step needs readings, not only seconds', () {
      // A link delivering a frame every 2.5 s never opens a gap, and five
      // seconds of it is two readings.
      final s = InspectionSession();
      final rig = Rig(currentAt: (t) => 0.0, cellsAt: healthyCells);
      for (var t = 0.0; t < 9; t += 2.5) {
        s.feed(rig.at(t));
      }
      expect(s.step, InspectionStep.rest);
      final quick = InspectionSession(
        thresholds: const InspectionThresholds(restSeconds: 5),
      );
      for (var t = 0.0; t < 9; t += 2.5) {
        quick.feed(rig.at(t));
      }
      expect(quick.step, InspectionStep.rest, reason: 'four readings');
      quick.feed(rig.at(10));
      expect(quick.step, InspectionStep.lightLoad);
    });

    test('ending the test before the load says that, not "never released"', () {
      final s = InspectionSession();
      Rig(currentAt: scripted, cellsAt: healthyCells).run(s, 45);
      expect(s.step, InspectionStep.lightLoad);
      s.abortToDone();
      expect(s.endedEarlyIn, InspectionStep.lightLoad);
      final r = const InspectionAnalysis().compute(s);
      expect(r.caveats, contains(InspectionCaveat.endedBeforeLoad));
      expect(r.caveats, isNot(contains(InspectionCaveat.noRecovery)));
      expect(r.caveats, isNot(contains(InspectionCaveat.recoveryNoLoad)));
    });

    test('a heavy step that times out ends the test without a recovery', () {
      final s = InspectionSession(
        thresholds: const InspectionThresholds(stepTimeoutSeconds: 40),
      );
      final rig = Rig(
        currentAt: (t) => t < 32 ? 0.0 : -2.0,
        cellsAt: (t) => healthyCells(t < 32 ? 0 : 2),
      );
      expect(rig.run(s, 300), isTrue);
      final r = const InspectionAnalysis().compute(s);
      expect(r.caveats, contains(InspectionCaveat.recoveryNoLoad));
      expect(r.medianRecoverySeconds, isNull);
    });

    test('one glitched frame does not make a bad cell', () {
      // Cell 5 reads 150 mV low on one frame of the pull. Its lowest reading
      // used to be its sag, so one frame was a "problem" cell.
      final s = InspectionSession();
      Rig(
        currentAt: scripted,
        cellsAt: (t) {
          final v = healthyCells(scripted(t).abs());
          if (t == 60) v[4] -= 0.150;
          return v;
        },
      ).run(s, 200);
      final r = const InspectionAnalysis().compute(s);
      expect(r.worstSagExcess!, lessThan(0.005));
      expect(const InspectionVerdicts().light(r), InspectionLight.good);
    });

    test('a stale current is not paired with fresh cells', () {
      // The BMS repeats its current for a couple of frames while the cells
      // move on. Here the pull ramps up from 20 to 50 A, each current is sent
      // three times, and on the two repeats the cells already sit at the
      // next level. Dividing those cells by the stale current reads the
      // 2.5 mOhm pack as about 3 mOhm; only the fresh frames are paired.
      final s = InspectionSession();
      final rig = Rig(
        currentAt: (t) => t < 35 ? 0.0 : -2.0,
        cellsAt: (t) => healthyCells(t < 35 ? 0 : 2),
      );
      rig.run(s, 56);
      expect(s.step, InspectionStep.heavyLoad);
      var at = rig.start.add(const Duration(seconds: 56));
      for (final level in [20.0, 25.0, 30.0, 35.0, 40.0, 45.0, 50.0]) {
        for (var repeat = 0; repeat < 3; repeat++) {
          final cellsAt = repeat == 0 ? level : level + 5;
          s.feed(
            buildSnapshot(
              timestamp: at,
              cells: healthyCells(cellsAt),
              current: -level,
            ),
          );
          at = at.add(const Duration(milliseconds: 500));
        }
      }
      expect(s.step, InspectionStep.recovery);
      for (var k = 0; k < 120; k++) {
        s.feed(
          buildSnapshot(timestamp: at, cells: healthyCells(0), current: 0),
        );
        at = at.add(const Duration(milliseconds: 500));
      }
      final r = const InspectionAnalysis().compute(s);
      expect(r.medianResistanceOhms!, closeTo(0.0025, 0.0001));
    });
  });
}
