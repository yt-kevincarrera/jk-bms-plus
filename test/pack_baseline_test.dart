import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/pack/chemistry.dart';
import 'package:jk_bms/src/pack/pack_baseline.dart';
import 'package:jk_bms/src/pack/pack_config.dart';

import 'fixtures/snapshot_builder.dart';

/// Sixteen cells, level, with whichever ones the caller drags down.
List<double> cells({Map<int, double> low = const {}, double at = 3.320}) => [
  for (var i = 1; i <= 16; i++) low[i] ?? at,
];

void main() {
  group('suggesting the chemistry', () {
    test('reads it off the overvoltage the pack builder set', () {
      final lfp = ChemistryHint.from(cellOvp: 3.60);
      expect(lfp.chemistry, CellChemistry.lfp);
      expect(lfp.evidence, ChemistryEvidence.overvoltageSetting);
      expect(lfp.value, 3.60);

      expect(ChemistryHint.from(cellOvp: 4.20).chemistry, CellChemistry.nmc);
    });

    test('says nothing when the setting sits where nothing is sold', () {
      final hint = ChemistryHint.from(cellOvp: 3.90);
      expect(hint.hasSuggestion, isFalse);
      expect(hint.chemistry, CellChemistry.unknown);
    });

    test('a cell seen above 3.8 V settles it, whatever else is known', () {
      final hint = ChemistryHint.from(highestCellVolts: 4.02);
      expect(hint.chemistry, CellChemistry.nmc);
      expect(hint.evidence, ChemistryEvidence.observedCellVoltage);
    });

    test('a cell at 3.4 V proves nothing either way', () {
      // A discharged NMC cell sits exactly where a full LFP one does.
      expect(ChemistryHint.from(highestCellVolts: 3.40).hasSuggestion, isFalse);
    });

    test('with nothing to go on it suggests nothing', () {
      expect(ChemistryHint.from().chemistry, CellChemistry.unknown);
    });

    test('the name survives a round trip and an unknown name is unknown', () {
      expect(CellChemistry.byName('lfp'), CellChemistry.lfp);
      expect(CellChemistry.byName('nmc'), CellChemistry.nmc);
      expect(CellChemistry.byName(''), CellChemistry.unknown);
      expect(CellChemistry.byName('lifepo4-ish'), CellChemistry.unknown);
    });
  });

  group('capturing day one', () {
    test('keeps the cells, the resistances and what the BMS was set to', () {
      final snapshot = buildSnapshot(
        timestamp: DateTime.utc(2026, 1, 5, 9),
        cells: cells(low: {7: 3.300}),
        cellResistances: [for (var i = 1; i <= 16; i++) 0.0002 * i],
        current: 0.2,
        soc: 78,
      );
      final baseline = PackBaseline.capture(
        snapshot: snapshot,
        at: DateTime.utc(2026, 1, 5, 9),
      );

      expect(baseline.cellCount, 16);
      expect(baseline.lowestCell, 7);
      expect(baseline.deltaVolts, closeTo(0.020, 1e-9));
      expect(baseline.cellResistances, hasLength(16));
      expect(baseline.wasAtRest, isTrue);
    });

    test('knows when it was taken with the pack under load', () {
      final baseline = PackBaseline.capture(
        snapshot: buildSnapshot(cells: cells(), current: -32),
      );
      expect(baseline.wasAtRest, isFalse);
    });

    test('survives being written down and read back', () {
      final original = PackBaseline.capture(
        snapshot: buildSnapshot(
          cells: cells(low: {3: 3.290}),
          cellResistances: [for (var i = 1; i <= 16; i++) 0.0003],
          current: 0.1,
          soc: 64,
        ),
        at: DateTime.utc(2026, 1, 5, 9),
      );
      final copy = PackBaseline.fromJson(original.toJson());

      expect(copy.capturedAt, original.capturedAt);
      expect(copy.cellVoltages, original.cellVoltages);
      expect(copy.cellResistances, original.cellResistances);
      expect(copy.soc, original.soc);
      expect(copy.lowestCell, 3);
    });
  });

  group('today against day one', () {
    final dayOne = PackBaseline(
      capturedAt: DateTime.utc(2026, 1, 5),
      cellVoltages: cells(),
      cellResistances: [for (var i = 1; i <= 16; i++) 0.00030],
      cycleCount: 12,
      current: 0.1,
    );

    test('names the cell that has fallen behind the pack', () {
      final now = buildSnapshot(
        timestamp: DateTime.utc(2026, 7, 5),
        // Everything has come down with use; cell 7 has come down further.
        cells: cells(at: 3.300, low: {7: 3.240}),
        current: 0.1,
        cycles: 96,
      );
      final c = BaselineComparison.compute(baseline: dayOne, now: now)!;

      expect(c.days, greaterThan(180));
      expect(c.comparable, isTrue);
      expect(c.worstDrift!.index, 7);
      // Deviations, not raw volts: the pack being emptier today must not read
      // as every cell having drifted.
      expect(c.worstDrift!.driftVolts, closeTo(-0.056, 0.002));
      expect(c.deltaChange, closeTo(0.060, 1e-9));
      expect(c.cyclesSince, 84);
    });

    test('a level pack reports nobody drifting', () {
      final now = buildSnapshot(cells: cells(at: 3.310), current: 0.1);
      final c = BaselineComparison.compute(baseline: dayOne, now: now)!;
      expect(c.worstDrift, isNull);
      expect(c.deltaChange, closeTo(0, 1e-9));
    });

    test('a reading taken under load is not comparable', () {
      final now = buildSnapshot(cells: cells(at: 3.100), current: -38);
      final c = BaselineComparison.compute(baseline: dayOne, now: now)!;
      expect(c.comparable, isFalse);
    });

    test('a pack with a different number of cells is not the same pack', () {
      final now = buildSnapshot(
        cells: [for (var i = 1; i <= 20; i++) 3.3],
        current: 0.1,
      );
      expect(BaselineComparison.compute(baseline: dayOne, now: now), isNull);
    });

    test('resistance that has climbed since day one is reported per cell', () {
      final now = buildSnapshot(
        cells: cells(),
        cellResistances: [
          for (var i = 1; i <= 16; i++) i == 7 ? 0.00060 : 0.00031,
        ],
        current: 0.1,
      );
      final c = BaselineComparison.compute(baseline: dayOne, now: now)!;
      final seven = c.cells.firstWhere((e) => e.index == 7);
      expect(seven.resistanceRise, closeTo(1.0, 0.01));
    });
  });

  group('the settings the audit watches', () {
    test('a change is only reported where both copies hold the field', () {
      const before = PackConfig({
        ConfigField.cellOvp: 3.60,
        ConfigField.maxChargeCurrent: 20,
      });
      const after = PackConfig({
        ConfigField.cellOvp: 3.65,
        ConfigField.maxChargeCurrent: 20,
        ConfigField.cellUvp: 2.80,
      });

      final changes = configChanges(before, after);
      expect(changes, hasLength(1));
      expect(changes.single.field, ConfigField.cellOvp);
      expect(changes.single.rose, isTrue);
    });

    test('rounding on the wire is not a change somebody made', () {
      const before = PackConfig({ConfigField.cellOvp: 3.6000});
      const after = PackConfig({ConfigField.cellOvp: 3.6002});
      expect(configChanges(before, after), isEmpty);
    });

    test('a switch turned off is a change', () {
      const before = PackConfig({ConfigField.balancerSwitchOn: 1});
      const after = PackConfig({ConfigField.balancerSwitchOn: 0});
      final changes = configChanges(before, after);
      expect(changes.single.field, ConfigField.balancerSwitchOn);
      expect(changes.single.rose, isFalse);
    });
  });
}
