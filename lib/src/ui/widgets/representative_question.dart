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

/// Full-pack kilometres at a given consumption, so the two halves of the
/// sentence are comparable.
///
/// Free function, and taking the pack's own figures as arguments rather than
/// reading them off a service, because this question is also asked from the
/// saved-pack screen with nothing connected. Read off the service, the
/// figures belong to whatever happens to be on the radio, or with nothing
/// connected at all, to no pack at all.
///
/// Null when there is no full-pack figure to convert, which the caller must
/// handle by saying the same thing in Wh/km instead, never by reaching for
/// [RangeOutlook.nowKm]. No capacity measured or catalogued is an everyday
/// state, not an edge case.
double? fullPackKmAt({
  required double whPerKm,
  required double? fullKm,
  required double learnedWhPerKm,
}) {
  if (fullKm == null || fullKm <= 0 || whPerKm <= 0 || learnedWhPerKm <= 0) {
    return null;
  }
  return fullKm * learnedWhPerKm / whPerKm;
}

/// Whether a ride's recorded "after" still describes what the pack currently
/// believes, and so whether kilometres may be quoted for it.
///
/// Converting through the current full-pack range is only honest for the most
/// recent counted ride. Open an older ride and every ride since has moved the
/// estimate, so the kilometres would be a projection from today's figure
/// dressed up as what that ride actually did. A pack with nothing learned
/// yet answers no rather than matching every ride against zero.
bool quotesCurrentEstimate({
  required double after,
  required double learnedWhPerKm,
}) {
  if (learnedWhPerKm <= 0) return false;
  return (after - learnedWhPerKm).abs() < 0.05;
}

/// The two figures the representative question quotes, for one pack.
///
/// Exists so the question can be asked about a pack that is not connected.
/// Both figures used to be read straight off [BmsService], which ties them to
/// whatever is on the radio; from the saved-pack screen that is nothing, and
/// the question would quote a default estimator belonging to no pack.
class LearnedRange {
  const LearnedRange({required this.whPerKm, required this.fullKm});

  /// What this pack has been measured to consume.
  final double whPerKm;

  /// Kilometres on a full pack, or null where no capacity has been measured
  /// or cataloged and there is nothing honest to quote.
  final double? fullKm;

  /// The figures of the connected pack.
  factory LearnedRange.ofService(BmsService service) => LearnedRange(
    whPerKm: service.rangeEstimator.whPerKm,
    fullKm: service.rangeOutlook.fullKm,
  );
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
    required this.learned,
    required this.t,
    this.onChanged,
    super.key,
  });

  final TripSummaryView view;
  final BmsService service;

  /// The figures of the pack being looked at, read fresh each time.
  ///
  /// A getter rather than a value because the confirmation quotes what the
  /// answer *resulted in*, so it has to be read again after the write. A
  /// callback keeps that honest for both callers: connected, the service has
  /// already relearned by then; from the saved-pack screen, [onChanged] has
  /// just rebuilt the screen's own figures.
  final LearnedRange Function() learned;

  /// Awaited after a write, before the confirmation reads [learned] again.
  ///
  /// Null where the write already refreshed what [learned] reads, which is
  /// the connected case: `setTripRepresentative` relearns before it returns.
  final Future<void> Function()? onChanged;

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
        // Unanswering has to refresh the same things answering does, or the
        // saved-pack screen keeps showing figures that still count the ride.
        onChange: () async {
          await service.setTripRepresentative(tripId, null);
          await onChanged?.call();
        },
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
    final figures = learned();
    final rawBeforeKm = _fullPackKm(before!, figures);
    final rawAfterKm = _fullPackKm(after!, figures);
    final isCurrentEstimate = quotesCurrentEstimate(
      after: after,
      learnedWhPerKm: figures.whPerKm,
    );
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

  /// [LearnedRange.fullKm] and [LearnedRange.whPerKm] are both read off the
  /// same estimator, so their product is the pack's full energy in watt-hours
  /// regardless of what "current" happens to be at the moment this builds;
  /// dividing that back by [whPerKm] is what turns one reference point into a
  /// figure for a different consumption.
  double? _fullPackKm(double whPerKm, LearnedRange figures) => fullPackKmAt(
    whPerKm: whPerKm,
    fullKm: figures.fullKm,
    learnedWhPerKm: figures.whPerKm,
  );

  Future<void> _answer(BuildContext context, int tripId, bool normal) async {
    final messenger = ScaffoldMessenger.of(context);
    await service.setTripRepresentative(tripId, normal);
    // Whatever reads [learned] has to be rebuilt before the figure below is
    // taken, or the confirmation quotes the state from before the answer.
    // Connected, setTripRepresentative relearned on the way here and there is
    // nothing to wait for; from the saved-pack screen the screen reloads.
    await onChanged?.call();
    // The consequence, not the action, and true either way: both answers
    // report what resulted rather than "saved", which would tell the rider
    // nothing they could not already see. Wh/km rather than km when there is
    // no full-pack figure, for the same reason the ask body falls back the
    // same way: nowKm is a different quantity and substituting it would
    // confirm a number the rider never actually asked about.
    final figures = learned();
    final fullKm = figures.fullKm;
    final message = fullKm != null
        ? (normal
              ? t.representativeDone(fullKm.toStringAsFixed(0))
              : t.representativeMarkedException(fullKm.toStringAsFixed(0)))
        : (normal
              ? t.representativeDoneNoKm(figures.whPerKm.toStringAsFixed(1))
              : t.representativeMarkedExceptionNoKm(
                  figures.whPerKm.toStringAsFixed(1),
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
