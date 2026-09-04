import '../metrics/advice_engine.dart';
import 'chemistry.dart';
import 'pack_config.dart';

/// Reads the BMS's own settings and says which ones are a bad idea.
///
/// Strictly read only, and that is a design decision rather than a
/// limitation. This app never writes to a BMS: a wrong value written to a
/// battery management system is a fire, the protocol's write path is
/// undocumented and reverse-engineered, and a bug in it would be discovered
/// by somebody's pack rather than by a test. So the audit explains what to
/// change and leaves the changing to the official app, where the rider is
/// deliberately taking that decision on themselves.
///
/// Everything about voltages hangs off the declared chemistry. When nobody
/// has said what the cells are, the voltage checks stay quiet rather than
/// guessing: the two chemistries disagree by a volt a cell, so an audit run
/// against the wrong one would either bless a dangerous setting or condemn a
/// normal one, and both are worse than silence.
class ConfigAudit {
  const ConfigAudit();

  /// How far the configured capacity can sit from what the pack was sold as
  /// before it is worth mentioning. Round numbers and rounding both live
  /// inside this.
  static const double capacityGapAh = 2;

  /// A charge current above this many times the pack's own amp-hour figure
  /// is fast enough to age it noticeably.
  static const double chargeRateWarn = 1.0;

  List<Advice> evaluate({
    required PackConfig config,
    CellChemistry chemistry = CellChemistry.unknown,
    double? soldAsAh,
    int? cellsSeen,
    PackConfig? dayOne,
  }) {
    if (config.isEmpty) return const [];
    final out = <Advice>[];
    final limits = ChemistryLimits.of(chemistry);

    // --- The two that can burn a pack ---
    final ovp = config[ConfigField.cellOvp];
    if (limits != null && ovp != null && ovp > 0) {
      if (ovp > limits.hardMaxVolts) {
        out.add(
          _advice(
            AdviceCode.configOvpDangerous,
            AdviceLevel.problem,
            value: ovp,
            limit: limits.hardMaxVolts,
          ),
        );
      } else if (ovp > limits.comfortableMaxVolts) {
        out.add(
          _advice(
            AdviceCode.configOvpHigh,
            AdviceLevel.watch,
            value: ovp,
            limit: limits.comfortableMaxVolts,
          ),
        );
      }
    }

    final uvp = config[ConfigField.cellUvp];
    if (limits != null && uvp != null && uvp > 0) {
      if (uvp < limits.hardMinVolts) {
        out.add(
          _advice(
            AdviceCode.configUvpDangerous,
            AdviceLevel.problem,
            value: uvp,
            limit: limits.hardMinVolts,
          ),
        );
      } else if (uvp < limits.comfortableMinVolts) {
        out.add(
          _advice(
            AdviceCode.configUvpLow,
            AdviceLevel.watch,
            value: uvp,
            limit: limits.comfortableMinVolts,
          ),
        );
      }
    }

    // --- The winter one ---
    //
    // Charging a lithium cell below freezing plates metal on the anode. It
    // is permanent, it shows up on no figure the BMS reports, and a cutoff
    // set at or below zero means the pack will happily do it.
    final utp = config[ConfigField.chargeUtp];
    if (utp != null) {
      if (utp <= ChemistryLimits.freezingChargeLimitCelsius) {
        out.add(
          _advice(
            AdviceCode.configChargesWhenFrozen,
            AdviceLevel.problem,
            value: utp,
            limit: ChemistryLimits.freezingChargeLimitCelsius,
          ),
        );
      } else {
        out.add(
          _advice(AdviceCode.configColdCutoffOk, AdviceLevel.good, value: utp),
        );
      }
    }

    // --- Heat ---
    final chargeOtp = config[ConfigField.chargeOtp];
    if (chargeOtp != null &&
        chargeOtp > ChemistryLimits.hotChargeLimitCelsius) {
      out.add(
        _advice(
          AdviceCode.configChargeHotLimit,
          AdviceLevel.watch,
          value: chargeOtp,
          limit: ChemistryLimits.hotChargeLimitCelsius,
        ),
      );
    }
    final dischargeOtp = config[ConfigField.dischargeOtp];
    if (dischargeOtp != null &&
        dischargeOtp > ChemistryLimits.hotDischargeLimitCelsius) {
      out.add(
        _advice(
          AdviceCode.configDischargeHotLimit,
          AdviceLevel.watch,
          value: dischargeOtp,
          limit: ChemistryLimits.hotDischargeLimitCelsius,
        ),
      );
    }

    // --- What the BMS thinks the pack is ---
    final configured = config[ConfigField.nominalCapacityAh];
    if (configured != null &&
        configured > 0 &&
        soldAsAh != null &&
        soldAsAh > 0 &&
        (configured - soldAsAh).abs() > capacityGapAh) {
      out.add(
        Advice(
          code: AdviceCode.configCapacityDisagrees,
          level: AdviceLevel.watch,
          value: configured,
          evidence: [
            Evidence(EvidenceKind.impliedCapacity, value: configured),
            Evidence(EvidenceKind.catalogueCapacity, value: soldAsAh),
          ],
        ),
      );
    }

    final configuredCells = config[ConfigField.cellCount];
    if (configuredCells != null &&
        cellsSeen != null &&
        cellsSeen > 0 &&
        configuredCells.round() != cellsSeen) {
      out.add(
        Advice(
          code: AdviceCode.configCellCountDisagrees,
          level: AdviceLevel.problem,
          value: configuredCells,
          evidence: [
            Evidence(EvidenceKind.configuredSetting, value: configuredCells),
            Evidence(EvidenceKind.cellsSeen, value: cellsSeen.toDouble()),
          ],
        ),
      );
    }

    // --- Charging fast enough to matter ---
    final maxCharge = config[ConfigField.maxChargeCurrent];
    if (maxCharge != null &&
        configured != null &&
        configured > 0 &&
        maxCharge > configured * chargeRateWarn) {
      out.add(
        Advice(
          code: AdviceCode.configChargeCurrentHigh,
          level: AdviceLevel.info,
          value: maxCharge,
          evidence: [
            Evidence(EvidenceKind.configuredSetting, value: maxCharge),
            Evidence(EvidenceKind.impliedCapacity, value: configured),
          ],
        ),
      );
    }

    // --- Switches ---
    if (config[ConfigField.balancerSwitchOn] == 0) {
      out.add(
        Advice(code: AdviceCode.configBalancerOff, level: AdviceLevel.watch),
      );
    }
    if (config[ConfigField.chargeSwitchOn] == 0) {
      out.add(
        Advice(code: AdviceCode.configChargeOff, level: AdviceLevel.info),
      );
    }
    if (config[ConfigField.dischargeSwitchOn] == 0) {
      out.add(
        Advice(code: AdviceCode.configDischargeOff, level: AdviceLevel.info),
      );
    }

    // --- Balancing where voltage says nothing ---
    //
    // Both chemistries are flat through the middle of their range, LFP
    // brutally so. A balancer that starts down there is comparing cells on
    // the part of the curve where a millivolt is not a measure of charge,
    // and it will happily move energy in the wrong direction.
    final balanceStart = config[ConfigField.balanceStartVoltage];
    if (limits != null &&
        balanceStart != null &&
        balanceStart > 0 &&
        balanceStart < limits.typicalBalanceStartVolts - 0.10) {
      out.add(
        _advice(
          AdviceCode.configBalanceStartLow,
          AdviceLevel.info,
          value: balanceStart,
          limit: limits.typicalBalanceStartVolts,
        ),
      );
    }

    // --- Not what it was ---
    if (dayOne != null && dayOne.isNotEmpty) {
      final changed = configChanges(dayOne, config);
      if (changed.isNotEmpty) {
        out.add(
          Advice(
            code: AdviceCode.configChangedSinceDayOne,
            level: AdviceLevel.info,
            value: changed.length.toDouble(),
          ),
        );
      }
    }

    // --- What the audit could not look at ---
    if (limits == null) {
      out.add(
        Advice(
          code: AdviceCode.configChemistryUnknown,
          level: AdviceLevel.info,
        ),
      );
    } else if (!out.any(
      (a) => a.level == AdviceLevel.problem || a.level == AdviceLevel.watch,
    )) {
      // Worth saying out loud. A rider who has just been told nothing is
      // wrong has learned something; a blank screen has told them the app
      // did not run.
      out.add(
        Advice(code: AdviceCode.configLooksSane, level: AdviceLevel.good),
      );
    }

    out.sort((a, b) => b.level.index.compareTo(a.level.index));
    return out;
  }

  Advice _advice(
    AdviceCode code,
    AdviceLevel level, {
    required double value,
    double? limit,
  }) => Advice(
    code: code,
    level: level,
    value: value,
    evidence: [
      Evidence(EvidenceKind.configuredSetting, value: value),
      if (limit != null) Evidence(EvidenceKind.safeLimit, value: limit),
    ],
  );
}
