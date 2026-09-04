import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../metrics/advice_engine.dart';
import '../theme.dart';
import 'common.dart';

/// Renders what the advice engine found.
///
/// The engine deals in codes; the wording lives here, so the analysis has no
/// opinion about what language the rider reads. Every item opens on a tap to
/// show the measured facts it rests on: a sentence about a battery that cannot
/// point at a number is an opinion, and this app does not offer those.
class AdviceList extends StatelessWidget {
  const AdviceList({
    required this.advice,
    this.title,
    this.showHonestyNote = true,
    super.key,
  });

  final List<Advice> advice;

  /// Overrides the section title, for a screen that wants "Veredicto" rather
  /// than the default.
  final String? title;

  /// Whether to close with the line about editable BMS figures.
  final bool showHonestyNote;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final heading = title ?? t.adviceTitle;

    if (advice.isEmpty) {
      return Section(
        title: heading,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 17,
                color: AppTheme.good,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t.adviceNone,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      );
    }

    // The accent follows the worst thing said. Good news alone reads calm.
    final worst = advice.first.level;
    return Section(
      title: heading,
      accent: accentFor(worst),
      children: [
        for (final item in advice)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AdviceItem(advice: item),
          ),
        if (showHonestyNote)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: Text(
              t.adviceHonestyNote,
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppTheme.textFaint,
              ),
            ),
          ),
      ],
    );
  }

  static Color accentFor(AdviceLevel level) => switch (level) {
    AdviceLevel.problem => AppTheme.bad,
    AdviceLevel.watch => AppTheme.watch,
    AdviceLevel.info => AppTheme.good,
    AdviceLevel.good => AppTheme.good,
  };
}

/// One verdict: a title, a sentence, and the facts behind it on a tap.
class AdviceItem extends StatefulWidget {
  const AdviceItem({required this.advice, super.key});

  final Advice advice;

  @override
  State<AdviceItem> createState() => _AdviceItemState();
}

class _AdviceItemState extends State<AdviceItem> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final advice = widget.advice;
    final tone = AdviceList.accentFor(advice.level);
    final hasWhy = advice.evidence.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: hasWhy ? () => setState(() => _open = !_open) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 10),
            child: Icon(_icon(advice.level), size: 16, color: tone),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  adviceTitle(t, advice),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: tone,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  adviceBody(t, advice),
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (hasWhy) ...[
                  const SizedBox(height: 4),
                  Text(
                    _open ? t.adviceWhyHide : t.adviceWhy,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: AppTheme.textFaint,
                    ),
                  ),
                ],
                if (_open)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      children: [
                        for (final e in advice.evidence)
                          _EvidenceRow(evidence: e, t: t),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _icon(AdviceLevel level) => switch (level) {
    AdviceLevel.problem => Icons.warning_amber_rounded,
    AdviceLevel.watch => Icons.error_outline,
    AdviceLevel.info => Icons.lightbulb_outline,
    AdviceLevel.good => Icons.check_circle_outline,
  };
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({required this.evidence, required this.t});

  final Evidence evidence;
  final AppL10n t;

  @override
  Widget build(BuildContext context) {
    final (label, value) = describeEvidence(t, evidence);
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: AppTheme.textFaint,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
                fontFeatures: AppTheme.tabular,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Label and formatted value for one fact.
(String, String) describeEvidence(AppL10n t, Evidence e) {
  final v = e.value ?? 0;
  String volts(double x) => '${x.toStringAsFixed(3)} V';
  String ah(double x) => '${x.toStringAsFixed(1)} Ah';
  String whole(double x) => x.toStringAsFixed(0);
  return switch (e.kind) {
    EvidenceKind.restingDelta => (t.evidenceRestingDelta, volts(v)),
    EvidenceKind.loadedDelta => (t.evidenceLoadedDelta, volts(v)),
    EvidenceKind.weakCellShare => (
      t.evidenceWeakCellShare('${e.cell ?? 0}'),
      '${whole(v)} %',
    ),
    EvidenceKind.readingsInSession => (t.evidenceReadingsInSession, whole(v)),
    EvidenceKind.reportedCycles => (t.evidenceReportedCycles, whole(v)),
    EvidenceKind.equivalentCycles => (t.evidenceEquivalentCycles, whole(v)),
    EvidenceKind.reportedSoh => (t.evidenceReportedSoh, '${whole(v)} %'),
    EvidenceKind.impliedCapacity => (t.evidenceImpliedCapacity, ah(v)),
    EvidenceKind.catalogueCapacity => (t.evidenceCatalogueCapacity, ah(v)),
    EvidenceKind.capacityTests => (t.evidenceCapacityTests, whole(v)),
    EvidenceKind.hottestProbe => (
      t.evidenceHottestProbe,
      '${v.toStringAsFixed(1)} °C',
    ),
    EvidenceKind.balanceStartVoltage => (
      t.evidenceBalanceStart,
      '${v.toStringAsFixed(2)} V',
    ),
    EvidenceKind.cellOvp => (t.evidenceCellOvp, '${v.toStringAsFixed(2)} V'),
    EvidenceKind.learnedKm => (t.evidenceLearnedKm, '${whole(v)} km'),
    EvidenceKind.whPerKm => (t.evidenceWhPerKm, '${whole(v)} Wh/km'),
    EvidenceKind.usableWh => (t.evidenceUsableWh, '${whole(v)} Wh'),
    EvidenceKind.strandedFraction => (
      t.evidenceStrandedFraction,
      '${whole(v)} %',
    ),
    EvidenceKind.rangeBand => (
      t.evidenceRangeBand,
      '${whole(v)}–${whole(e.value2 ?? v)} km',
    ),
    EvidenceKind.baselineCapacity => (
      t.evidenceBaselineCapacity(_date(e.at)),
      ah(v),
    ),
    EvidenceKind.currentCapacity => (
      t.evidenceCurrentCapacity(_date(e.at)),
      ah(v),
    ),
    EvidenceKind.driftDeviation => (
      t.evidenceDriftDeviation('${e.cell ?? 0}'),
      volts(v),
    ),
    EvidenceKind.driftRate => (
      t.evidenceDriftRate,
      '${volts(v)} / ${t.evidencePerMonth}',
    ),
    EvidenceKind.driftSamples => (t.evidenceDriftSamples, whole(v)),
    EvidenceKind.driftSpanWeeks => (
      t.evidenceDriftSpanWeeks,
      v.toStringAsFixed(1),
    ),
    EvidenceKind.cellSag => (t.evidenceCellSag('${e.cell ?? 0}'), volts(v)),
    EvidenceKind.medianSag => (t.evidenceMedianSag, volts(v)),
    EvidenceKind.currentStep => (
      t.evidenceCurrentStep,
      '${v.toStringAsFixed(1)} A',
    ),
    EvidenceKind.cellResistance => (
      t.evidenceCellResistance('${e.cell ?? 0}'),
      '${(v * 1000).toStringAsFixed(1)} mΩ',
    ),
    EvidenceKind.medianResistance => (
      t.evidenceMedianResistance,
      '${(v * 1000).toStringAsFixed(1)} mΩ',
    ),
    EvidenceKind.lowestRestCell => (
      t.evidenceLowestRestCell('${e.cell ?? 0}'),
      volts(v),
    ),
    EvidenceKind.lightLoadAmps => (
      t.evidenceLightLoadAmps,
      '${v.toStringAsFixed(1)} A',
    ),
    EvidenceKind.recoverySeconds => (
      t.evidenceRecoverySeconds('${e.cell ?? 0}'),
      '${v.toStringAsFixed(1)} s',
    ),
    EvidenceKind.medianRecoverySeconds => (
      t.evidenceMedianRecoverySeconds,
      '${v.toStringAsFixed(1)} s',
    ),
    EvidenceKind.alarmCount => (t.evidenceAlarmCount, whole(v)),
    EvidenceKind.peakCurrent => (
      t.evidencePeakCurrent,
      '${v.toStringAsFixed(1)} A',
    ),
    EvidenceKind.runCount => (t.evidenceRunCount, whole(v)),
    EvidenceKind.timesSameCell => (
      t.evidenceTimesSameCell('${e.cell ?? 0}'),
      whole(v),
    ),
    EvidenceKind.previousSag => (t.evidencePreviousSag(_date(e.at)), volts(v)),
    EvidenceKind.previousRestDelta => (
      t.evidencePreviousRestDelta(_date(e.at)),
      volts(v),
    ),
    EvidenceKind.previousResistance => (
      t.evidencePreviousResistance(_date(e.at)),
      '${(v * 1000).toStringAsFixed(1)} m\u03a9',
    ),
    EvidenceKind.previousCycles => (
      t.evidencePreviousCycles(_date(e.at)),
      whole(v),
    ),
    EvidenceKind.previousSoh => (
      t.evidencePreviousSoh(_date(e.at)),
      '${whole(v)} %',
    ),
    EvidenceKind.previousConfiguredCapacity => (
      t.evidencePreviousConfiguredCapacity(_date(e.at)),
      ah(v),
    ),
    EvidenceKind.previousPeakCurrent => (
      t.evidencePreviousPeakCurrent(_date(e.at)),
      '${v.toStringAsFixed(1)} A',
    ),
    EvidenceKind.configuredSetting => (
      t.evidenceConfiguredSetting,
      v.toStringAsFixed(3),
    ),
    EvidenceKind.safeLimit => (t.evidenceSafeLimit, v.toStringAsFixed(3)),
    EvidenceKind.cellsSeen => (t.evidenceCellsSeen, whole(v)),
  };
}

String adviceTitle(AppL10n t, Advice advice) {
  final v = advice.value ?? 0;
  final cell = advice.cellIndex ?? 0;
  return switch (advice.code) {
    AdviceCode.healthMeasured => t.verdictHealthMeasuredTitle,
    AdviceCode.healthNotMeasurable => t.verdictHealthNotMeasurableTitle,
    AdviceCode.cellDrifting => t.verdictCellDriftingTitle('$cell'),
    AdviceCode.noCellDrifting => t.verdictNoCellDriftingTitle,
    AdviceCode.rangeNow => t.verdictRangeNowTitle(v.toStringAsFixed(0)),
    AdviceCode.deltaUnderLoadNormal => t.verdictDeltaNormalTitle,
    AdviceCode.imbalanceAtRest => t.adviceImbalanceAtRestTitle,
    AdviceCode.imbalanceUnderLoad => t.adviceImbalanceUnderLoadTitle,
    AdviceCode.weakCellDominant => t.adviceWeakCellTitle,
    AdviceCode.cycleCounterInflated => t.adviceCycleInflatedTitle,
    AdviceCode.healthFigureDecorative => t.adviceHealthDecorativeTitle,
    AdviceCode.capacityBelowCatalogue => t.adviceCapacityBelowTitle,
    AdviceCode.noCapacityTestYet => t.adviceNoCapacityTestTitle,
    AdviceCode.runningHot => t.adviceRunningHotTitle,
    AdviceCode.balancerNeverSeen => t.adviceBalancerNeverSeenTitle,
    AdviceCode.overvoltageSetHigh => t.adviceOvervoltageHighTitle,
    AdviceCode.rangeStillLearning => t.adviceRangeLearningTitle,
    AdviceCode.imbalanceCostingRange => t.adviceImbalanceCostingTitle,
    AdviceCode.inspectionCellSagging => t.verdictInspCellSaggingTitle('$cell'),
    AdviceCode.inspectionSagUniform => t.verdictInspSagUniformTitle,
    AdviceCode.inspectionRestDeltaWide => t.verdictInspRestDeltaWideTitle,
    AdviceCode.inspectionRestDeltaOk => t.verdictInspRestDeltaOkTitle,
    AdviceCode.inspectionWeakUnderLightLoad => t.verdictInspWeakLightTitle(
      '$cell',
    ),
    AdviceCode.inspectionSlowRecovery => t.verdictInspSlowRecoveryTitle(
      '$cell',
    ),
    AdviceCode.inspectionRecoveryOk => t.verdictInspRecoveryOkTitle,
    AdviceCode.inspectionHot => t.verdictInspHotTitle,
    AdviceCode.inspectionAlarmsSeen => t.verdictInspAlarmsTitle,
    AdviceCode.inspectionCountersEditable => t.verdictInspCountersTitle,
    AdviceCode.inspectionNoHeavyLoad => t.verdictInspNoHeavyLoadTitle,
    AdviceCode.inspectionRepeatSameCell => t.verdictInspRepeatSameCellTitle(
      '$cell',
      _fact(advice, EvidenceKind.timesSameCell, 0),
      _fact(advice, EvidenceKind.runCount, 0),
    ),
    AdviceCode.inspectionRepeatCellMoved => t.verdictInspRepeatCellMovedTitle(
      '$cell',
    ),
    AdviceCode.inspectionRepeatWorse => t.verdictInspRepeatWorseTitle,
    AdviceCode.inspectionRepeatSteady => t.verdictInspRepeatSteadyTitle,
    AdviceCode.inspectionRepeatCountersReset =>
      t.verdictInspRepeatCountersResetTitle,
    AdviceCode.inspectionRepeatLoadDiffers =>
      t.verdictInspRepeatLoadDiffersTitle,
    AdviceCode.configOvpDangerous => t.verdictConfigOvpDangerousTitle,
    AdviceCode.configOvpHigh => t.verdictConfigOvpHighTitle,
    AdviceCode.configUvpDangerous => t.verdictConfigUvpDangerousTitle,
    AdviceCode.configUvpLow => t.verdictConfigUvpLowTitle,
    AdviceCode.configChargesWhenFrozen => t.verdictConfigChargesWhenFrozenTitle,
    AdviceCode.configColdCutoffOk => t.verdictConfigColdCutoffOkTitle,
    AdviceCode.configChargeHotLimit => t.verdictConfigChargeHotLimitTitle,
    AdviceCode.configDischargeHotLimit => t.verdictConfigDischargeHotLimitTitle,
    AdviceCode.configCapacityDisagrees => t.verdictConfigCapacityDisagreesTitle,
    AdviceCode.configCellCountDisagrees =>
      t.verdictConfigCellCountDisagreesTitle,
    AdviceCode.configChargeCurrentHigh => t.verdictConfigChargeCurrentHighTitle,
    AdviceCode.configBalancerOff => t.verdictConfigBalancerOffTitle,
    AdviceCode.configChargeOff => t.verdictConfigChargeOffTitle,
    AdviceCode.configDischargeOff => t.verdictConfigDischargeOffTitle,
    AdviceCode.configBalanceStartLow => t.verdictConfigBalanceStartLowTitle,
    AdviceCode.configChangedSinceDayOne =>
      t.verdictConfigChangedSinceDayOneTitle,
    AdviceCode.configChemistryUnknown => t.verdictConfigChemistryUnknownTitle,
    AdviceCode.configLooksSane => t.verdictConfigLooksSaneTitle,
  };
}

/// One evidence figure of an advice, formatted, or zero when it carries none.
String _fact(Advice advice, EvidenceKind kind, int digits) =>
    (advice.evidence.where((e) => e.kind == kind).firstOrNull?.value ?? 0)
        .toStringAsFixed(digits);

String adviceBody(AppL10n t, Advice advice) {
  final v = advice.value ?? 0;
  final cell = advice.cellIndex ?? 0;
  double? fact(EvidenceKind kind) =>
      advice.evidence.where((e) => e.kind == kind).firstOrNull?.value;
  String f(EvidenceKind kind, int digits) =>
      (fact(kind) ?? 0).toStringAsFixed(digits);

  return switch (advice.code) {
    AdviceCode.healthMeasured => t.verdictHealthMeasuredBody(
      v.toStringAsFixed(0),
      f(EvidenceKind.currentCapacity, 1),
      f(EvidenceKind.baselineCapacity, 1),
    ),
    AdviceCode.healthNotMeasurable => t.verdictHealthNotMeasurableBody(
      v.toStringAsFixed(0),
    ),
    AdviceCode.cellDrifting => t.verdictCellDriftingBody(
      v.toStringAsFixed(0),
      f(EvidenceKind.driftDeviation, 3),
      f(EvidenceKind.driftRate, 3),
    ),
    AdviceCode.noCellDrifting => t.verdictNoCellDriftingBody(
      v.toStringAsFixed(0),
      f(EvidenceKind.driftDeviation, 3),
    ),
    AdviceCode.rangeNow => t.verdictRangeNowBody(
      f(EvidenceKind.whPerKm, 0),
      f(EvidenceKind.learnedKm, 0),
    ),
    AdviceCode.deltaUnderLoadNormal => t.verdictDeltaNormalBody(
      f(EvidenceKind.loadedDelta, 3),
      f(EvidenceKind.restingDelta, 3),
    ),
    AdviceCode.imbalanceAtRest => t.adviceImbalanceAtRestBody(
      v.toStringAsFixed(3),
      cell,
    ),
    AdviceCode.imbalanceUnderLoad => t.adviceImbalanceUnderLoadBody(
      v.toStringAsFixed(3),
      cell,
    ),
    AdviceCode.weakCellDominant => t.adviceWeakCellBody(
      cell,
      v.toStringAsFixed(0),
    ),
    AdviceCode.cycleCounterInflated => t.adviceCycleInflatedBody(
      v.toStringAsFixed(1),
    ),
    AdviceCode.healthFigureDecorative => t.adviceHealthDecorativeBody,
    AdviceCode.capacityBelowCatalogue => t.adviceCapacityBelowBody(
      v.toStringAsFixed(0),
    ),
    AdviceCode.noCapacityTestYet => t.adviceNoCapacityTestBody,
    AdviceCode.runningHot => t.adviceRunningHotBody(v.toStringAsFixed(1)),
    AdviceCode.balancerNeverSeen => t.adviceBalancerNeverSeenBody(
      v.toStringAsFixed(2),
    ),
    AdviceCode.overvoltageSetHigh => t.adviceOvervoltageHighBody(
      v.toStringAsFixed(2),
    ),
    AdviceCode.rangeStillLearning => t.adviceRangeLearningBody(
      v.toStringAsFixed(1),
    ),
    AdviceCode.imbalanceCostingRange => t.adviceImbalanceCostingBody(
      v.toStringAsFixed(0),
    ),
    AdviceCode.inspectionCellSagging => t.verdictInspCellSaggingBody(
      v.toStringAsFixed(3),
    ),
    AdviceCode.inspectionSagUniform => t.verdictInspSagUniformBody(
      v.toStringAsFixed(3),
    ),
    AdviceCode.inspectionRestDeltaWide => t.verdictInspRestDeltaWideBody(
      v.toStringAsFixed(3),
      '$cell',
    ),
    AdviceCode.inspectionRestDeltaOk => t.verdictInspRestDeltaOkBody(
      v.toStringAsFixed(3),
    ),
    AdviceCode.inspectionWeakUnderLightLoad => t.verdictInspWeakLightBody(
      f(EvidenceKind.lightLoadAmps, 1),
      v.toStringAsFixed(3),
    ),
    AdviceCode.inspectionSlowRecovery => t.verdictInspSlowRecoveryBody(
      v.toStringAsFixed(0),
    ),
    AdviceCode.inspectionRecoveryOk => t.verdictInspRecoveryOkBody(
      v.toStringAsFixed(0),
    ),
    AdviceCode.inspectionHot => t.verdictInspHotBody(v.toStringAsFixed(0)),
    AdviceCode.inspectionAlarmsSeen => t.verdictInspAlarmsBody(
      v.toStringAsFixed(0),
    ),
    AdviceCode.inspectionCountersEditable => t.verdictInspCountersBody(
      advice.value == null ? '--' : v.toStringAsFixed(0),
    ),
    AdviceCode.inspectionNoHeavyLoad => t.verdictInspNoHeavyLoadBody(
      v.toStringAsFixed(1),
    ),
    AdviceCode.inspectionRepeatSameCell => t.verdictInspRepeatSameCellBody,
    AdviceCode.inspectionRepeatCellMoved => t.verdictInspRepeatCellMovedBody(
      '${advice.evidence.where((e) => e.kind == EvidenceKind.previousSag).firstOrNull?.cell ?? 0}',
      '$cell',
    ),
    AdviceCode.inspectionRepeatWorse => t.verdictInspRepeatWorseBody,
    AdviceCode.inspectionRepeatSteady => t.verdictInspRepeatSteadyBody,
    AdviceCode.inspectionRepeatCountersReset =>
      t.verdictInspRepeatCountersResetBody,
    AdviceCode.inspectionRepeatLoadDiffers =>
      t.verdictInspRepeatLoadDiffersBody,
    AdviceCode.configOvpDangerous => t.verdictConfigOvpDangerousBody(
      v.toStringAsFixed(3),
      f(EvidenceKind.safeLimit, 3),
    ),
    AdviceCode.configOvpHigh => t.verdictConfigOvpHighBody(
      v.toStringAsFixed(3),
      f(EvidenceKind.safeLimit, 3),
    ),
    AdviceCode.configUvpDangerous => t.verdictConfigUvpDangerousBody(
      v.toStringAsFixed(3),
      f(EvidenceKind.safeLimit, 3),
    ),
    AdviceCode.configUvpLow => t.verdictConfigUvpLowBody(
      v.toStringAsFixed(3),
      f(EvidenceKind.safeLimit, 3),
    ),
    AdviceCode.configChargesWhenFrozen => t.verdictConfigChargesWhenFrozenBody(
      v.toStringAsFixed(0),
    ),
    AdviceCode.configColdCutoffOk => t.verdictConfigColdCutoffOkBody(
      v.toStringAsFixed(0),
    ),
    AdviceCode.configChargeHotLimit => t.verdictConfigChargeHotLimitBody(
      v.toStringAsFixed(0),
      f(EvidenceKind.safeLimit, 0),
    ),
    AdviceCode.configDischargeHotLimit => t.verdictConfigDischargeHotLimitBody(
      v.toStringAsFixed(0),
      f(EvidenceKind.safeLimit, 0),
    ),
    AdviceCode.configCapacityDisagrees => t.verdictConfigCapacityDisagreesBody(
      v.toStringAsFixed(1),
      f(EvidenceKind.catalogueCapacity, 1),
    ),
    AdviceCode.configCellCountDisagrees =>
      t.verdictConfigCellCountDisagreesBody(
        v.toStringAsFixed(0),
        f(EvidenceKind.cellsSeen, 0),
      ),
    AdviceCode.configChargeCurrentHigh => t.verdictConfigChargeCurrentHighBody(
      v.toStringAsFixed(0),
      f(EvidenceKind.impliedCapacity, 0),
    ),
    AdviceCode.configBalancerOff => t.verdictConfigBalancerOffBody,
    AdviceCode.configChargeOff => t.verdictConfigChargeOffBody,
    AdviceCode.configDischargeOff => t.verdictConfigDischargeOffBody,
    AdviceCode.configBalanceStartLow => t.verdictConfigBalanceStartLowBody(
      v.toStringAsFixed(3),
      f(EvidenceKind.safeLimit, 2),
    ),
    AdviceCode.configChangedSinceDayOne =>
      t.verdictConfigChangedSinceDayOneBody(v.toStringAsFixed(0)),
    AdviceCode.configChemistryUnknown => t.verdictConfigChemistryUnknownBody,
    AdviceCode.configLooksSane => t.verdictConfigLooksSaneBody,
  };
}

String _date(DateTime? utc) {
  if (utc == null) return '--';
  final d = utc.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}
