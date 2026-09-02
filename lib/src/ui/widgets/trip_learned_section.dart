import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../metrics/range_estimator.dart';
import '../../metrics/trip_recorder.dart';
import '../theme.dart';
import 'common.dart';

/// What a ride changed, and one or two things worth knowing about it.
///
/// This used to live inside the sheet that appears when a ride is stopped,
/// which meant it existed for as long as the sheet was on screen and not a
/// second longer. Twenty-two kilometres of conclusions dismissed with a swipe
/// and unreachable afterwards. It is a widget of its own now so the stored
/// ride can show exactly what the rider read at the time.
class TripLearnedSection extends StatelessWidget {
  const TripLearnedSection({
    required this.conclusions,
    required this.whPerKm,
    required this.socUsed,
    required this.distanceKm,
    required this.maxTemperature,
    required this.maxDeltaVolts,
    required this.t,
    super.key,
  });

  /// What the app concluded, or null for a ride recorded before conclusions
  /// were kept. Nothing is drawn in that case: an empty section is honest, a
  /// filled-in one would not be.
  final TripConclusions? conclusions;

  /// What the ride itself cost, which is what the conclusions are about.
  final double? whPerKm;

  final double socUsed;
  final double distanceKm;
  final double maxTemperature;
  final double maxDeltaVolts;
  final AppL10n t;

  @override
  Widget build(BuildContext context) {
    final c = conclusions;
    if (c == null) return const SizedBox.shrink();

    final tips = _tips(c);

    return Section(
      title: t.tripLearnedTitle,
      accent: AppTheme.cool,
      intro: _headline(c),
      children: [
        if (whPerKm != null) ...[
          InfoRow(
            t.tripLearnedRange,
            '${c.rangeKmAtEnd.toStringAsFixed(0)} km',
          ),
          InfoRow(
            t.tripLearnedTotalKm,
            '${c.learnedKm.toStringAsFixed(1)} km',
          ),
          InfoRow(
            t.tripLearnedConfidence,
            switch (c.confidence) {
              RangeConfidence.low => t.rangeConfidenceLow,
              RangeConfidence.medium => t.rangeConfidenceMedium,
              RangeConfidence.high => t.rangeConfidenceHigh,
            },
            valueColor: switch (c.confidence) {
              RangeConfidence.low => AppTheme.textFaint,
              RangeConfidence.medium => AppTheme.watch,
              RangeConfidence.high => AppTheme.good,
            },
            last: tips.isEmpty,
          ),
        ],
        for (final tip in tips)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2, right: 10),
                  child: Icon(
                    Icons.lightbulb_outline,
                    size: 15,
                    color: AppTheme.cool,
                  ),
                ),
                Expanded(
                  child: Text(
                    tip,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
      ],
    );
  }

  String _headline(TripConclusions c) {
    final after = c.whPerKmAfter.toStringAsFixed(1);
    if (whPerKm == null) return t.tripLearnedTooShort;
    if (!c.hadLearnedBefore) return t.tripLearnedFirst(after);
    if (!c.moved) return t.tripLearnedUnchanged(after);
    // hadLearnedBefore is exactly the case where this is non-null.
    return t.tripLearnedChanged(c.whPerKmBefore!.toStringAsFixed(1), after);
  }

  /// At most two, so this stays a summary rather than a lecture.
  List<String> _tips(TripConclusions c) {
    final tips = <String>[];

    // How much of the pack a ride covers is what decides how sharp the
    // estimate can get. A ride from 100% to 20% pins the number down; five
    // short hops around the block cannot.
    if (socUsed >= 25) {
      tips.add(t.tripDeepDischargeTip);
    } else if (socUsed > 0 && socUsed < 8 && distanceKm > 0.5) {
      tips.add(t.tripShallowTip);
    }

    final thirst = c.thirstPercentFor(whPerKm);
    if (thirst != null) {
      tips.add(t.tripThirstyTip(thirst.toStringAsFixed(0)));
    }

    if (tips.length < 2 && maxTemperature > 45) {
      tips.add(t.tripHotTip(maxTemperature.toStringAsFixed(1)));
    }
    if (tips.length < 2 && maxDeltaVolts > 0.06) {
      tips.add(t.tripDeltaTip(maxDeltaVolts.toStringAsFixed(3)));
    }

    return tips.take(2).toList();
  }
}
