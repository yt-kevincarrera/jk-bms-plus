import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/metrics/advice_engine.dart';
import 'package:jk_bms/src/pack/chemistry.dart';
import 'package:jk_bms/src/pack/config_audit.dart';
import 'package:jk_bms/src/pack/pack_config.dart';

/// A configuration a careful LFP builder would be happy with.
PackConfig sane({Map<ConfigField, double> changes = const {}}) => PackConfig({
  ConfigField.cellOvp: 3.55,
  ConfigField.cellUvp: 2.90,
  ConfigField.balanceStartVoltage: 3.40,
  ConfigField.soc100Voltage: 3.45,
  ConfigField.soc0Voltage: 2.90,
  ConfigField.maxChargeCurrent: 20,
  ConfigField.maxDischargeCurrent: 100,
  ConfigField.maxBalanceCurrent: 0.6,
  ConfigField.chargeOtp: 40,
  ConfigField.dischargeOtp: 55,
  ConfigField.chargeUtp: 2,
  ConfigField.mosfetOtp: 80,
  ConfigField.nominalCapacityAh: 40,
  ConfigField.cellCount: 16,
  ConfigField.chargeSwitchOn: 1,
  ConfigField.dischargeSwitchOn: 1,
  ConfigField.balancerSwitchOn: 1,
  ...changes,
});

bool has(List<Advice> a, AdviceCode code) => a.any((e) => e.code == code);
Advice of(List<Advice> a, AdviceCode code) =>
    a.firstWhere((e) => e.code == code);

void main() {
  const audit = ConfigAudit();

  List<Advice> run({
    Map<ConfigField, double> changes = const {},
    CellChemistry chemistry = CellChemistry.lfp,
    double? soldAsAh,
    int? cellsSeen,
    PackConfig? dayOne,
  }) => audit.evaluate(
    config: sane(changes: changes),
    chemistry: chemistry,
    soldAsAh: soldAsAh,
    cellsSeen: cellsSeen,
    dayOne: dayOne,
  );

  test('a sensible configuration is told so, rather than left blank', () {
    final findings = run();
    expect(has(findings, AdviceCode.configLooksSane), isTrue);
    expect(
      findings.any(
        (a) => a.level == AdviceLevel.problem || a.level == AdviceLevel.watch,
      ),
      isFalse,
    );
  });

  test('nothing at all is said about an empty configuration', () {
    expect(
      audit.evaluate(config: PackConfig.none, chemistry: CellChemistry.lfp),
      isEmpty,
    );
  });

  group('the two that can burn a pack', () {
    test('an LFP pack set to charge to 3.9 V a cell is a problem', () {
      final findings = run(changes: {ConfigField.cellOvp: 3.90});
      expect(has(findings, AdviceCode.configOvpDangerous), isTrue);
      final found = of(findings, AdviceCode.configOvpDangerous);
      expect(found.level, AdviceLevel.problem);
      // The safe limit travels with the finding, so the sentence can name it.
      expect(
        found.evidence
            .firstWhere((e) => e.kind == EvidenceKind.safeLimit)
            .value,
        3.65,
      );
    });

    test('3.60 V on LFP is high rather than dangerous', () {
      final findings = run(changes: {ConfigField.cellOvp: 3.60});
      expect(has(findings, AdviceCode.configOvpHigh), isTrue);
      expect(of(findings, AdviceCode.configOvpHigh).level, AdviceLevel.watch);
      expect(has(findings, AdviceCode.configOvpDangerous), isFalse);
    });

    test('the same 4.2 V is normal on NMC and a fire on LFP', () {
      final onNmc = audit.evaluate(
        config: sane(
          changes: {
            ConfigField.cellOvp: 4.20,
            ConfigField.cellUvp: 3.20,
            ConfigField.balanceStartVoltage: 4.00,
          },
        ),
        chemistry: CellChemistry.nmc,
      );
      expect(has(onNmc, AdviceCode.configOvpDangerous), isFalse);
      expect(has(onNmc, AdviceCode.configOvpHigh), isFalse);

      final onLfp = run(changes: {ConfigField.cellOvp: 4.20});
      expect(has(onLfp, AdviceCode.configOvpDangerous), isTrue);
    });

    test('a discharge cutoff under the floor is a problem', () {
      final findings = run(changes: {ConfigField.cellUvp: 2.20});
      expect(has(findings, AdviceCode.configUvpDangerous), isTrue);
    });

    test('and one merely low is a watch', () {
      final findings = run(changes: {ConfigField.cellUvp: 2.60});
      expect(has(findings, AdviceCode.configUvpLow), isTrue);
      expect(has(findings, AdviceCode.configUvpDangerous), isFalse);
    });
  });

  group('the winter one', () {
    test('a cold cutoff at zero means the pack will charge frozen', () {
      final findings = run(changes: {ConfigField.chargeUtp: 0});
      expect(has(findings, AdviceCode.configChargesWhenFrozen), isTrue);
      expect(
        of(findings, AdviceCode.configChargesWhenFrozen).level,
        AdviceLevel.problem,
      );
    });

    test('a cutoff below zero is worse, not better', () {
      expect(
        has(
          run(changes: {ConfigField.chargeUtp: -10}),
          AdviceCode.configChargesWhenFrozen,
        ),
        isTrue,
      );
    });

    test('a cutoff above zero earns a good word', () {
      final findings = run(changes: {ConfigField.chargeUtp: 3});
      expect(has(findings, AdviceCode.configColdCutoffOk), isTrue);
      expect(
        of(findings, AdviceCode.configColdCutoffOk).level,
        AdviceLevel.good,
      );
    });
  });

  group('what the BMS thinks the pack is', () {
    test('a configured capacity that is not what it was sold as', () {
      final findings = run(soldAsAh: 45);
      expect(has(findings, AdviceCode.configCapacityDisagrees), isTrue);
      final found = of(findings, AdviceCode.configCapacityDisagrees);
      expect(found.value, 40);
      expect(
        found.evidence
            .firstWhere((e) => e.kind == EvidenceKind.catalogueCapacity)
            .value,
        45,
      );
    });

    test('a couple of amp-hours apart is rounding, not a finding', () {
      expect(
        has(run(soldAsAh: 41), AdviceCode.configCapacityDisagrees),
        isFalse,
      );
    });

    test('a cell count that disagrees with what is connected', () {
      final findings = run(cellsSeen: 20);
      expect(has(findings, AdviceCode.configCellCountDisagrees), isTrue);
      expect(
        of(findings, AdviceCode.configCellCountDisagrees).level,
        AdviceLevel.problem,
      );
    });

    test('and one that agrees says nothing', () {
      expect(
        has(run(cellsSeen: 16), AdviceCode.configCellCountDisagrees),
        isFalse,
      );
    });
  });

  group('switches and rates', () {
    test('a balancer switched off is worth a warning of its own', () {
      final findings = run(changes: {ConfigField.balancerSwitchOn: 0});
      expect(has(findings, AdviceCode.configBalancerOff), isTrue);
      expect(
        of(findings, AdviceCode.configBalancerOff).level,
        AdviceLevel.watch,
      );
    });

    test('charging and discharging switched off explain themselves', () {
      final findings = run(
        changes: {
          ConfigField.chargeSwitchOn: 0,
          ConfigField.dischargeSwitchOn: 0,
        },
      );
      expect(has(findings, AdviceCode.configChargeOff), isTrue);
      expect(has(findings, AdviceCode.configDischargeOff), isTrue);
    });

    test('charging a 40 Ah pack at 50 A is mentioned', () {
      final findings = run(changes: {ConfigField.maxChargeCurrent: 50});
      expect(has(findings, AdviceCode.configChargeCurrentHigh), isTrue);
      expect(
        of(findings, AdviceCode.configChargeCurrentHigh).level,
        AdviceLevel.info,
      );
    });

    test('balancing that starts on the flat part of the curve', () {
      final findings = run(changes: {ConfigField.balanceStartVoltage: 3.20});
      expect(has(findings, AdviceCode.configBalanceStartLow), isTrue);
    });
  });

  group('heat', () {
    test('a charge cutoff above 45 degrees', () {
      expect(
        has(
          run(changes: {ConfigField.chargeOtp: 55}),
          AdviceCode.configChargeHotLimit,
        ),
        isTrue,
      );
    });

    test('a discharge cutoff above 60', () {
      expect(
        has(
          run(changes: {ConfigField.dischargeOtp: 70}),
          AdviceCode.configDischargeHotLimit,
        ),
        isTrue,
      );
    });
  });

  group('without a declared chemistry', () {
    test('no voltage is judged either way', () {
      final findings = run(
        chemistry: CellChemistry.unknown,
        changes: {ConfigField.cellOvp: 4.20, ConfigField.cellUvp: 2.00},
      );
      expect(has(findings, AdviceCode.configOvpDangerous), isFalse);
      expect(has(findings, AdviceCode.configUvpDangerous), isFalse);
      expect(has(findings, AdviceCode.configChemistryUnknown), isTrue);
    });

    test('the checks that do not depend on it still run', () {
      final findings = run(
        chemistry: CellChemistry.unknown,
        changes: {ConfigField.chargeUtp: 0, ConfigField.balancerSwitchOn: 0},
      );
      expect(has(findings, AdviceCode.configChargesWhenFrozen), isTrue);
      expect(has(findings, AdviceCode.configBalancerOff), isTrue);
    });

    test('and it never claims everything looks fine', () {
      expect(
        has(run(chemistry: CellChemistry.unknown), AdviceCode.configLooksSane),
        isFalse,
      );
    });
  });

  test('settings that are not what they were on day one are reported', () {
    final findings = run(changes: {ConfigField.cellOvp: 3.50}, dayOne: sane());
    expect(has(findings, AdviceCode.configChangedSinceDayOne), isTrue);
    expect(of(findings, AdviceCode.configChangedSinceDayOne).value, 1);
  });

  test('an unchanged configuration says nothing about day one', () {
    expect(
      has(run(dayOne: sane()), AdviceCode.configChangedSinceDayOne),
      isFalse,
    );
  });

  test('the worst news comes first', () {
    final findings = run(
      changes: {
        ConfigField.cellOvp: 3.90,
        ConfigField.balancerSwitchOn: 0,
        ConfigField.maxChargeCurrent: 60,
      },
    );
    expect(findings.first.level, AdviceLevel.problem);
    expect(findings.last.level.index, lessThan(AdviceLevel.problem.index));
  });
}
