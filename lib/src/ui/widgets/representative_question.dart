import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../bms_service.dart';
import '../../metrics/range_estimator.dart';
import '../theme.dart';
import 'common.dart';
import 'trip_summary_view.dart';

/// Whether this ride is worth a question.
///
/// Free function so the rule can be tested without building a widget tree,
/// and so the three places that show the question cannot disagree about when
/// it appears.
bool shouldAskAbout({required double shiftFraction, required bool? answered}) =>
    answered == null &&
    shiftFraction > RangeEstimator.askThresholdFraction;

/// Asks whether one ride represents how this bike normally gets ridden.
///
/// The estimator has no notion of context: one deliberately gentle ride to
/// nurse a low charge moves the learned figure a third of the way towards a
/// number that is not how anybody rides. Detecting that automatically and
/// quietly adjusting would change the range with no explanation, which is the
/// thing the rider disliked in the first place. So it asks, once, at the only
/// moment the context is still in somebody's head, and only when the answer
/// would actually change the number.
class RepresentativeQuestion extends StatelessWidget {
  const RepresentativeQuestion({
    required this.view,
    required this.service,
    required this.t,
    super.key,
  });

  final TripSummaryView view;
  final BmsService service;
  final AppL10n t;

  @override
  Widget build(BuildContext context) {
    final tripId = view.tripId;
    final rideWhPerKm = view.whPerKm;
    if (tripId == null || rideWhPerKm == null) {
      return const SizedBox.shrink();
    }

    // Already answered: a line saying so, and a way to change it. Not the
    // question again.
    if (view.representative != null) {
      return _Answered(
        representative: view.representative!,
        onChange: () => service.setTripRepresentative(tripId, null),
        t: t,
      );
    }

    // The shift has to come from what this ride actually did, not from asking
    // the estimator to imagine folding it in again. By the time this widget
    // builds, stopTrip has already relearned from every stored trip including
    // this one, so a second, hypothetical fold measures a fold-of-a-fold: on
    // a 40 km ride at 24 Wh/km against a learned 17.5 that reads as 8.33%
    // instead of the real 16.5%. The ride's own before/after figures, written
    // once by stopTrip and never touched again, are the only honest source.
    final before = view.whPerKmBefore;
    final after = view.whPerKmAfter;
    final shift = (before == null || before <= 0 || after == null)
        ? 0.0
        : (after - before).abs() / before;
    if (!shouldAskAbout(shiftFraction: shift, answered: null)) {
      return const SizedBox.shrink();
    }

    // Reachable only when shift > 0, which the branch above rules out unless
    // before and after are both real numbers.
    final beforeKm = _fullPackKm(before!);
    final afterKm = _fullPackKm(after!);
    final percent = ((rideWhPerKm - before).abs() / before * 100).round();
    final higher = rideWhPerKm > before;

    return Section(
      title: t.representativeAsk,
      accent: AppTheme.watch,
      children: [
        Text(
          higher
              ? t.representativeAskBodyUp(
                  rideWhPerKm.toStringAsFixed(0),
                  '$percent',
                  beforeKm.toStringAsFixed(0),
                  afterKm.toStringAsFixed(0),
                )
              : t.representativeAskBodyDown(
                  rideWhPerKm.toStringAsFixed(0),
                  '$percent',
                  beforeKm.toStringAsFixed(0),
                  afterKm.toStringAsFixed(0),
                ),
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.45,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _answer(context, tripId, true),
                child: Text(t.representativeYes),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _answer(context, tripId, false),
                child: Text(t.representativeNo),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  /// Full-pack kilometres at a given consumption, so the two halves of the
  /// sentence are comparable.
  ///
  /// [outlook.fullKm] and [service.rangeEstimator.whPerKm] are both read off
  /// the same current estimator, so their product is the pack's full energy
  /// in watt-hours regardless of what "current" happens to be at the moment
  /// this builds; dividing that back by [whPerKm] is what turns one reference
  /// point into a figure for a different consumption. Falls back to the
  /// remaining range when no capacity has been measured, which is the honest
  /// thing the rest of the app already does.
  double _fullPackKm(double whPerKm) {
    final outlook = service.rangeOutlook;
    final reference = outlook.fullKm ?? outlook.nowKm ?? 0;
    final learned = service.rangeEstimator.whPerKm;
    if (reference <= 0 || whPerKm <= 0 || learned <= 0) return 0;
    return reference * learned / whPerKm;
  }

  Future<void> _answer(BuildContext context, int tripId, bool normal) async {
    final messenger = ScaffoldMessenger.of(context);
    await service.setTripRepresentative(tripId, normal);
    // The consequence, not the action, and true either way: setTripRepresentative
    // has already relearned by the time this reads, so both answers report the
    // range that resulted rather than "saved", which would tell the rider
    // nothing they could not already see.
    final km = service.rangeOutlook.fullKm ?? service.rangeOutlook.nowKm;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          km == null
              ? (normal ? t.representativeYes : t.representativeNo)
              : (normal
                  ? t.representativeDone(km.toStringAsFixed(0))
                  : t.representativeMarkedException(km.toStringAsFixed(0))),
        ),
      ),
    );
  }
}

class _Answered extends StatelessWidget {
  const _Answered({
    required this.representative,
    required this.onChange,
    required this.t,
  });

  final bool representative;
  final VoidCallback onChange;
  final AppL10n t;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            representative ? t.representativeYes : t.representativeNo,
            style: const TextStyle(fontSize: 12, color: AppTheme.textFaint),
          ),
        ),
        TextButton(onPressed: onChange, child: Text(t.representativeChange)),
      ],
    ),
  );
}
