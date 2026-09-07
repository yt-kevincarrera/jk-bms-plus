import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/inspection/inspection_result.dart';
import 'package:jk_bms/src/inspection/inspection_session.dart';
import 'package:jk_bms/src/inspection/inspection_verdicts.dart';

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

  InspectionSession replay() {
    final s = InspectionSession();
    for (final r in rows) {
      s.feed(
        buildSnapshot(
          timestamp: DateTime.parse(r['t'] as String),
          cells: [for (final v in r['c'] as List<dynamic>) (v as num).toDouble()],
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
      [for (final r in rows) (r['i'] as num).toDouble().abs()].reduce(
        (a, b) => a > b ? a : b,
      ),
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
}
