import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/inspection/inspection_result.dart';
import 'package:jk_bms/src/inspection/inspection_session.dart';
import 'package:jk_bms/src/inspection/inspection_verdicts.dart';
import 'package:jk_bms/src/model/bms_snapshot.dart';

import 'fixtures/snapshot_builder.dart';

/// Every number here was measured, not chosen.
///
/// Source: a real inspection of the pack "KevinJK" (JK-BD6A20S6P, 40 Ah
/// configured, 20S NMC), run on 2026-09-05 and read back out of a backup.
/// 805 readings over 318 s, at 2.5 a second. What it found:
///
///  * rest was 0.00 A exactly, for the full 30 s
///  * the lights drew 0.44 A, flat, for the whole 120 s of the light step
///  * the hard pull, with the rear wheel in the air, sat at a median of
///    1.51 A and touched 14.20 A for two readings
///
/// Both load steps timed out, so the result recorded medianHeavySag null,
/// medianResistance null and both "not measured" caveats. It then showed a
/// green light, because the verdict starts at good and only rises when a
/// finding fires, and nothing can fire on data that was never captured.
///
/// A green light on a test that measured nothing is the worst thing this tool
/// can do: the whole point of it is not buying a battery blind.

/// Plays a scripted pack through a session at 2.5 readings a second, which is
/// what the real BMS delivers.
class Rig {
  Rig({
    required this.currentAt,
    required this.cellsAt,
    this.capacityAh = 40,
  });

  final double Function(double t) currentAt;
  final List<double> Function(double t) cellsAt;
  final double capacityAh;

  final start = DateTime.utc(2026, 9, 5, 20, 7);

  BmsSnapshot at(double seconds) => buildSnapshot(
    timestamp: start.add(Duration(milliseconds: (seconds * 1000).round())),
    cells: cellsAt(seconds),
    current: currentAt(seconds),
    nominalCapacityAh: capacityAh,
  );

  /// Feeds readings until [seconds] have passed or the session finishes.
  bool run(InspectionSession s, double seconds) {
    var t = 0.0;
    while (t < seconds) {
      if (s.feed(at(t))) return true;
      t += 0.4;
    }
    return false;
  }
}

/// A 20S pack with even resistance. [amps] is the magnitude of the load and
/// [charging] which way it is flowing, so a charge lifts the cells the same
/// way a discharge drops them.
List<double> evenPack(double amps, {bool charging = false}) => List<double>.
    generate(20, (i) {
  final rest = 3.750 + (i % 3) * 0.002;
  final swing = amps * 0.0025;
  return charging ? rest + swing : rest - swing;
});

void main() {
  group('what counts as the lights being on', () {
    test("0.44 A over a rest of nothing is a load", () {
      // The measured case. The old bar was a flat 1.0 A, which these lights
      // were never going to reach, so the step timed out after two minutes
      // and the rider was told the pack "needed more".
      final s = InspectionSession();
      Rig(
        currentAt: (t) => t < 35 ? 0.0 : -0.44,
        cellsAt: (t) => evenPack(t < 35 ? 0 : 0.44),
      ).run(s, 90);

      expect(s.step, isNot(InspectionStep.rest));
      expect(
        s.skippedSteps,
        isNot(contains(InspectionStep.lightLoad)),
        reason: 'the lights were on for 55 seconds',
      );
    });

    test('a pack sitting still is still at rest', () {
      // The other side of it. Judging the load as a step above rest must not
      // turn the BMS's own noise into a light that is switched on.
      final s = InspectionSession();
      Rig(
        currentAt: (t) => t < 35 ? 0.0 : -0.05,
        cellsAt: (t) => evenPack(0),
      ).run(s, 90);

      expect(s.step, InspectionStep.lightLoad);
    });
  });

  group('what counts as the hard pull', () {
    test('is a share of the pack, not a fixed fifteen amps', () {
      // 15 A is a third of a C on this 40 Ah pack and half a C on a 30 Ah
      // one. The bar has to mean the same thing on both.
      final s = InspectionSession();
      Rig(currentAt: (_) => 0, cellsAt: (_) => evenPack(0), capacityAh: 40)
          .run(s, 1);
      expect(s.heavyLoadAmps, closeTo(4.0, 0.001));
    });

    test('never asks less than a floor when the pack will not say', () {
      // Firmware that leaves the configured capacity at zero would otherwise
      // make any twitch of current count as a hard pull.
      final s = InspectionSession();
      Rig(currentAt: (_) => 0, cellsAt: (_) => evenPack(0), capacityAh: 0)
          .run(s, 1);
      expect(s.heavyLoadAmps, greaterThanOrEqualTo(3.0));
    });
  });

  group('a test that measured nothing', () {
    test('does not come out green', () {
      // The measured run, in miniature: quiet, then a trickle that is never a
      // hard pull. Both load steps time out.
      final s = InspectionSession();
      Rig(
        currentAt: (t) => t < 35 ? 0.0 : -0.44,
        cellsAt: (t) => evenPack(t < 35 ? 0 : 0.44),
      ).run(s, 400);
      s.abortToDone();

      final r = const InspectionAnalysis().compute(s);
      expect(r.medianHeavySagVolts, isNull);
      expect(
        const InspectionVerdicts().light(r),
        InspectionLight.unmeasured,
        reason: 'no sag was captured, so there is no opinion to give',
      );
    });
  });

  group('a charger standing in for the hard pull', () {
    test('measures the climb, not a sag of nothing', () {
      // The PRD offers the charger as a load for vendors with no room to
      // ride. The step accepted it and the arithmetic did not: it took each
      // cell's *lowest* reading under load, which while charging is roughly
      // where it started, so every cell came out with no sag and no
      // resistance, and the pack came out perfect.
      final s = InspectionSession();
      Rig(
        currentAt: (t) {
          if (t < 35) return 0.0;
          if (t < 60) return 0.44; // the charger's own trickle
          if (t < 100) return 8.0; // bulk
          return 0.0;
        },
        cellsAt: (t) {
          if (t < 35) return evenPack(0);
          if (t < 60) return evenPack(0.44, charging: true);
          if (t < 100) return evenPack(8.0, charging: true);
          return evenPack(0);
        },
      ).run(s, 200);

      final r = const InspectionAnalysis().compute(s);
      expect(r.medianHeavySagVolts, isNotNull);
      expect(
        r.medianHeavySagVolts!,
        greaterThan(0.010),
        reason: '8 A through 2.5 mOhm lifts a cell about 20 mV',
      );
      expect(r.medianResistanceOhms, isNotNull);
      expect(r.medianResistanceOhms!, closeTo(0.0025, 0.001));
    });
  });

  group('what the screen can tell the rider while a step waits', () {
    test('names the current the step is waiting for', () {
      // "Too little current (0.4 A). Give it more." was the whole message.
      // More than what was never said, so the rider had no way to know that
      // no amount of revving on a stand was ever going to satisfy it.
      final s = InspectionSession();
      final rig = Rig(
        currentAt: (t) => t < 35 ? 0.0 : -1.5,
        cellsAt: (t) => evenPack(t < 35 ? 0 : 1.5),
        capacityAh: 40,
      );
      rig.run(s, 80);

      expect(s.step, InspectionStep.heavyLoad);
      expect(s.prompt!.neededAmps, closeTo(4.0, 0.001));
      expect(s.prompt!.loadDetected, isFalse);
    });

    test('the light step asks for a step above where the pack rests', () {
      final s = InspectionSession();
      Rig(currentAt: (_) => 0.0, cellsAt: (_) => evenPack(0)).run(s, 40);

      expect(s.step, InspectionStep.lightLoad);
      expect(s.prompt!.neededAmps, closeTo(0.25, 0.001));
    });
  });
}
