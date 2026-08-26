import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../metrics/advice_engine.dart';
import '../theme.dart';
import 'common.dart';

/// Renders what the advice engine found.
///
/// The engine deals in codes; the wording lives here, so the analysis has no
/// opinion about what language the rider reads.
class AdviceList extends StatelessWidget {
  const AdviceList({required this.advice, super.key});

  final List<Advice> advice;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);

    if (advice.isEmpty) {
      return Section(
        title: t.adviceTitle,
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

    return Section(
      title: t.adviceTitle,
      accent: _accentFor(advice.first.level),
      children: [
        for (final item in advice)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _AdviceItem(advice: item, t: t),
          ),
      ],
    );
  }

  static Color _accentFor(AdviceLevel level) => switch (level) {
        AdviceLevel.problem => AppTheme.bad,
        AdviceLevel.watch => AppTheme.watch,
        AdviceLevel.info => AppTheme.good,
      };
}

class _AdviceItem extends StatelessWidget {
  const _AdviceItem({required this.advice, required this.t});

  final Advice advice;
  final AppL10n t;

  @override
  Widget build(BuildContext context) {
    final tone = AdviceList._accentFor(advice.level);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, right: 10),
          child: Icon(_icon, size: 16, color: tone),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: tone,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _body,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData get _icon => switch (advice.level) {
        AdviceLevel.problem => Icons.warning_amber_rounded,
        AdviceLevel.watch => Icons.error_outline,
        AdviceLevel.info => Icons.lightbulb_outline,
      };

  String get _title => switch (advice.code) {
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
      };

  String get _body {
    final v = advice.value ?? 0;
    final cell = advice.cellIndex ?? 0;
    return switch (advice.code) {
      AdviceCode.imbalanceAtRest =>
        t.adviceImbalanceAtRestBody(v.toStringAsFixed(3), cell),
      AdviceCode.imbalanceUnderLoad =>
        t.adviceImbalanceUnderLoadBody(v.toStringAsFixed(3), cell),
      AdviceCode.weakCellDominant =>
        t.adviceWeakCellBody(cell, v.toStringAsFixed(0)),
      AdviceCode.cycleCounterInflated =>
        t.adviceCycleInflatedBody(v.toStringAsFixed(1)),
      AdviceCode.healthFigureDecorative => t.adviceHealthDecorativeBody,
      AdviceCode.capacityBelowCatalogue =>
        t.adviceCapacityBelowBody(v.toStringAsFixed(0)),
      AdviceCode.noCapacityTestYet => t.adviceNoCapacityTestBody,
      AdviceCode.runningHot => t.adviceRunningHotBody(v.toStringAsFixed(1)),
      AdviceCode.balancerNeverSeen =>
        t.adviceBalancerNeverSeenBody(v.toStringAsFixed(2)),
      AdviceCode.overvoltageSetHigh =>
        t.adviceOvervoltageHighBody(v.toStringAsFixed(2)),
      AdviceCode.rangeStillLearning =>
        t.adviceRangeLearningBody(v.toStringAsFixed(1)),
      AdviceCode.imbalanceCostingRange =>
        t.adviceImbalanceCostingBody(v.toStringAsFixed(0)),
    };
  }
}
