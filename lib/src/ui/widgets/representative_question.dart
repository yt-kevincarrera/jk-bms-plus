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

/// How far a ride moved the learned consumption, as a fraction of where it
/// stood before the ride.
///
/// Free function, next to [shouldAskAbout], so the arithmetic this task exists
/// to fix is exercised directly rather than only from inside `build()`. Zero
/// whenever there is nothing honest to compare: no `before` (the first ride
/// ever, or one stored before these columns existed), a `before` that is zero
/// or negative, or no `after`. Dividing anyway in any of those cases would
/// manufacture a number that looks like a measurement (including, for a zero
/// `before`, an infinite one) and could push a meaningless ride past the ask
/// threshold.
double shiftFraction({required double? before, required double? after}) {
  if (before == null || before <= 0 || after == null) return 0.0;
  return (after - before).abs() / before;
}

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
    final shift = shiftFraction(before: before, after: after);
    if (!shouldAskAbout(shiftFraction: shift, answered: null)) {
      return const SizedBox.shrink();
    }

    // Reachable only when shift > 0, which the branch above rules out unless
    // before and after are both real numbers.
    final rawBeforeKm = _fullPackKm(before!);
    final rawAfterKm = _fullPackKm(after!);
    // Converting through today's fullKm is only honest for the ride that
    // just ended. Open an older ride from history and its recorded "after"
    // no longer matches what the estimator currently believes -- every ride
    // since has moved it -- so the km figures below would be a projection
    // from today's estimate dressed up as what that ride actually did. Only
    // the most recent counted ride still has fullKm and whPerKmAfter talking
    // about the same moment.
    final isCurrentEstimate =
        (after - service.rangeEstimator.whPerKm).abs() < 0.05;
    final beforeKm = isCurrentEstimate ? rawBeforeKm : null;
    final afterKm = isCurrentEstimate ? rawAfterKm : null;
    final percent = ((rideWhPerKm - before).abs() / before * 100).round();
    final higher = rideWhPerKm > before;
    final rideWh = rideWhPerKm.toStringAsFixed(0);
    final percentStr = '$percent';

    // Kilometres only when there is a real full-pack figure to quote them
    // from. Substituting the remaining range instead (charge-dependent, and
    // exactly the conflation RangeOutlook's own doc warns about) would put a
    // number in the rider's head that is not the one the sentence promises.
    // No capacity measured or catalogued is an everyday state, not an edge
    // case, so this sentence has to exist and say something true: the same
    // shift, in the unit the app can still stand behind.
    final String body;
    if (beforeKm != null && afterKm != null) {
      body = higher
          ? t.representativeAskBodyUp(
              rideWh,
              percentStr,
              beforeKm.toStringAsFixed(0),
              afterKm.toStringAsFixed(0),
            )
          : t.representativeAskBodyDown(
              rideWh,
              percentStr,
              beforeKm.toStringAsFixed(0),
              afterKm.toStringAsFixed(0),
            );
    } else {
      final beforeWh = before.toStringAsFixed(1);
      final afterWh = after.toStringAsFixed(1);
      body = higher
          ? t.representativeAskBodyUpNoKm(rideWh, percentStr, beforeWh, afterWh)
          : t.representativeAskBodyDownNoKm(rideWh, percentStr, beforeWh, afterWh);
    }

    return Section(
      title: t.representativeAsk,
      accent: AppTheme.watch,
      children: [
        Text(
          body,
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
  /// sentence are comparable. Null when there is no full-pack figure to
  /// convert, which the caller must handle by saying the same thing in
  /// Wh/km instead, never by reaching for [RangeOutlook.nowKm].
  ///
  /// [outlook.fullKm] and [service.rangeEstimator.whPerKm] are both read off
  /// the same current estimator, so their product is the pack's full energy
  /// in watt-hours regardless of what "current" happens to be at the moment
  /// this builds; dividing that back by [whPerKm] is what turns one reference
  /// point into a figure for a different consumption.
  double? _fullPackKm(double whPerKm) {
    final fullKm = service.rangeOutlook.fullKm;
    final learned = service.rangeEstimator.whPerKm;
    if (fullKm == null || fullKm <= 0 || whPerKm <= 0 || learned <= 0) {
      return null;
    }
    return fullKm * learned / whPerKm;
  }

  Future<void> _answer(BuildContext context, int tripId, bool normal) async {
    final messenger = ScaffoldMessenger.of(context);
    await service.setTripRepresentative(tripId, normal);
    // The consequence, not the action, and true either way:
    // setTripRepresentative has already relearned by the time this reads, so
    // both answers report what resulted rather than "saved", which would tell
    // the rider nothing they could not already see. Wh/km rather than km when
    // there is no full-pack figure, for the same reason the ask body falls
    // back the same way: nowKm is a different quantity and substituting it
    // would confirm a number the rider never actually asked about.
    final fullKm = service.rangeOutlook.fullKm;
    final message = fullKm != null
        ? (normal
              ? t.representativeDone(fullKm.toStringAsFixed(0))
              : t.representativeMarkedException(fullKm.toStringAsFixed(0)))
        : (normal
              ? t.representativeDoneNoKm(
                  service.rangeEstimator.whPerKm.toStringAsFixed(1),
                )
              : t.representativeMarkedExceptionNoKm(
                  service.rangeEstimator.whPerKm.toStringAsFixed(1),
                ));
    messenger.showSnackBar(SnackBar(content: Text(message)));
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
