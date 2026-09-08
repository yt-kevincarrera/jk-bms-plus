import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/metrics/pack_health_report.dart';
import 'package:jk_bms/src/pack/pack_baseline.dart';

import 'fixtures/snapshot_builder.dart';

/// The two figures the health tab needed before three of its cards could be
/// replaced by something a rider can use.
///
/// Both came out of the same complaint: "I don't understand what I'd use this
/// for". Measured against the rider's own pack, all three cards were dead --
/// one was a constant, one was mislabelled, one sat at a fiftieth of its own
/// warning threshold -- and the numbers below are the guards that keep their
/// replacements from being dead in the same way.
void main() {
  group('quoting the BMS cycle count', () {
    // The BMS counts in whole numbers while the honest figure -- throughput
    // divided by capacity -- runs in decimals. On the rider's pack that made
    // the ratio between them read 0.53, 0.91, 0.83, 0.70 and 0.96 on
    // consecutive days, all of it integer rounding, and all of it under 1,
    // on a card labelled "counter inflates".
    List<double> cellsAt(double v) => List.filled(20, v);

    PackHealthReport reportWith({
      required int bmsCycles,
      required double throughputAh,
    }) => PackHealthReport.from(
      snapshot: buildSnapshot(
        cells: cellsAt(3.8),
        soc: 60,
        remainingAh: 24,
        cycles: bmsCycles,
        cycleCapacityAh: throughputAh,
        nominalCapacityAh: 40,
      ),
      catalogueCapacityAh: 45,
      cutoffVoltagePerCell: 2.8,
    );

    test('a pack with three cycles on it says nothing about the counter', () {
      // The rider's pack exactly: 3 counted, 125 Ah of throughput on a 40 Ah
      // pack, so 3.1 honest cycles. One cycle of disagreement out of three is
      // 33%, and it is rounding, not a finding.
      final r = reportWith(bmsCycles: 3, throughputAh: 125);

      expect(r.equivalentFullCycles, closeTo(3.125, 0.001));
      expect(r.bmsCycleCountWorthQuoting, isNull);
    });

    test('a pack with real mileage on it quotes both', () {
      // Where the figure earns its keep: judging a cycle count somebody is
      // quoting at you, on a pack that has actually been used.
      final r = reportWith(bmsCycles: 800, throughputAh: 40 * 320);

      expect(r.equivalentFullCycles, closeTo(320, 0.01));
      expect(r.bmsCycleCountWorthQuoting, 800);
    });

    test('agreement is worth quoting too', () {
      // Seeing the two match is information about the pack, not an absence of
      // information.
      final r = reportWith(bmsCycles: 100, throughputAh: 40 * 100);
      expect(r.bmsCycleCountWorthQuoting, 100);
    });

    test('the floor sits where integer rounding stops dominating', () {
      final below = reportWith(bmsCycles: 19, throughputAh: 40 * 19.4);
      final above = reportWith(bmsCycles: 21, throughputAh: 40 * 20.4);

      expect(below.bmsCycleCountWorthQuoting, isNull);
      expect(above.bmsCycleCountWorthQuoting, 21);
    });
  });

  group('a cell whose resistance is climbing away from the rest', () {
    // What the rider asked for in place of "worst resistance", which read +2%
    // against a warning threshold of +40% and would have read +2% for ever.
    //
    // The absolute figures the BMS reports here are not credible as internal
    // resistance -- 354 mOhm per cell is a hundred times a real one -- but a
    // *change* in them is still a change, which is why this is a rise since
    // day one and not a value.
    final theirCells = [
      3.569, 3.567, 3.569, 3.567, 3.567, 3.567, 3.567, 3.567, 3.567, 3.567,
      3.569, 3.569, 3.569, 3.569, 3.569, 3.569, 3.569, 3.567, 3.569, 3.567,
    ];
    // Their real day-one resistances, in ohms.
    final theirResistances = [
      0.344, 0.349, 0.350, 0.348, 0.349, 0.349, 0.354, 0.353, 0.356, 0.354,
      0.359, 0.354, 0.355, 0.353, 0.356, 0.356, 0.360, 0.358, 0.360, 0.361,
    ];

    final dayOne = PackBaseline(
      capturedAt: DateTime.utc(2026, 9, 4),
      cellVoltages: theirCells,
      cellResistances: theirResistances,
      cycleCount: 2,
      current: 0.0,
    );

    BaselineComparison compare(List<double> nowResistances) =>
        BaselineComparison.computeFrom(
          baseline: dayOne,
          at: DateTime.utc(2027, 3, 4),
          cells: theirCells,
          cellResistances: nowResistances,
          current: 0.0,
          cycleCount: 40,
        )!;

    test('the same reading twice is nobody drifting', () {
      expect(compare(theirResistances).worstResistanceRise, isNull);
    });

    test('the natural spread between cells is not drift', () {
      // Their twenty cells span 344 to 361 mOhm on one reading, about 2.4%
      // either side of the median. A rule that called that drift would have
      // every pack in the world drifting on day one, which is the mistake the
      // card being replaced made in the other direction.
      final jittered = [
        for (var i = 0; i < theirResistances.length; i++)
          theirResistances[i] * (i.isEven ? 1.024 : 0.976),
      ];
      expect(compare(jittered).worstResistanceRise, isNull);
    });

    test('one cell climbing well clear of the rest is named', () {
      final drifting = [...theirResistances];
      drifting[16] = theirResistances[16] * 1.18;

      final worst = compare(drifting).worstResistanceRise;
      expect(worst, isNotNull);
      // 1-based, as written on the pack.
      expect(worst!.index, 17);
      expect(worst.resistanceRise, closeTo(0.18, 0.005));
    });

    test('the worst climber is the one named, not the first found', () {
      final drifting = [...theirResistances];
      drifting[3] = theirResistances[3] * 1.09;
      drifting[16] = theirResistances[16] * 1.22;

      expect(compare(drifting).worstResistanceRise!.index, 17);
    });

    test('a cell whose resistance fell is not a finding', () {
      final settled = [
        for (final r in theirResistances) r * 0.85,
      ];
      expect(compare(settled).worstResistanceRise, isNull);
    });

    test('a baseline with no resistances says nothing rather than guessing',
        () {
      // Packs recorded before resistances were captured, and the wire array
      // the firmware leaves at zero.
      final noResistances = PackBaseline(
        capturedAt: DateTime.utc(2026, 9, 4),
        cellVoltages: theirCells,
        cellResistances: const [],
        cycleCount: 2,
        current: 0.0,
      );
      final c = BaselineComparison.computeFrom(
        baseline: noResistances,
        at: DateTime.utc(2027, 3, 4),
        cells: theirCells,
        cellResistances: theirResistances,
        current: 0.0,
        cycleCount: 40,
      )!;
      expect(c.worstResistanceRise, isNull);
    });
  });
}
