import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/metrics/sampling.dart';

/// The rides below are the real ones, from the backup of 2026-09-08. They are
/// the whole reason this rule exists, so they are the tests.
void main() {
  final t0 = DateTime.utc(2026, 9, 7, 16, 9, 49);

  bool covers({
    required int rideMinutes,
    required int watchedMinutes,
    Duration? tolerance,
  }) => readingsCoverRide(
    rideDuration: Duration(minutes: rideMinutes),
    firstReading: t0,
    lastReading: t0.add(Duration(minutes: watchedMinutes)),
    tolerance: tolerance ?? counterEdgeTolerance,
  );

  group('readingsCoverRide', () {
    test('a ride watched from end to end is covered', () {
      // Trip 18: 6847 readings spanning all 108 minutes. Stored 6.64 Ah and
      // 20.3 Wh/km, which is right.
      expect(covers(rideMinutes: 108, watchedMinutes: 108), isTrue);
    });

    test('a blackout in the middle costs nothing, however long', () {
      // Also trip 18, which lost 63 of those 108 minutes to a single gap and
      // still measured correctly. The counter kept counting; the phone simply
      // was not listening. Only the ends are load-bearing, and this rule never
      // looks inside the span.
      expect(covers(rideMinutes: 108, watchedMinutes: 108), isTrue);
    });

    test('a link that dies a minute in does not cover the ride', () {
      // Trip 20: readings covered 1 minute of 53. The difference across them
      // was 0.13 Ah, stored as the whole ride's cost: 0.5 Wh/km over 22 km.
      // Bracketing the ride recovers 4.93 Ah, which is 17.0 Wh/km.
      expect(covers(rideMinutes: 53, watchedMinutes: 1), isFalse);
    });

    test('a link that dies nine minutes in does not cover it either', () {
      // Trip 21: 9 minutes of 47, stored as 4.3 Wh/km. This is the one that
      // moved the estimate from 19.2 to 13.7 and quoted 225 km of range.
      expect(covers(rideMinutes: 47, watchedMinutes: 9), isFalse);
    });

    test('a ride joined late is not covered', () {
      // The mirror of the case above and just as wrong: connecting halfway
      // through measures the second half and calls it the ride. The span is
      // what counts, wherever it sits.
      expect(covers(rideMinutes: 40, watchedMinutes: 20), isFalse);
    });

    test('the ordinary slop between a ride and its readings is tolerated', () {
      // A ride's own start and stop are written a moment apart from the
      // readings nearest them. That is not a measurement problem.
      expect(covers(rideMinutes: 40, watchedMinutes: 38), isTrue);
    });

    test('readings from either side of the ride cover it', () {
      // What the bracketing repair finds: the last reading before setting off
      // and the first on arrival. They span more than the ride lasted.
      expect(covers(rideMinutes: 40, watchedMinutes: 50), isTrue);
    });

    test('a ride shorter than the tolerance is always covered', () {
      // Nothing to protect here: a two-minute ride cannot hide a missing hour,
      // and the counter's own quantisation is the real limit at that length.
      expect(covers(rideMinutes: 2, watchedMinutes: 0), isTrue);
    });

    test('the tolerance is the caller to set', () {
      expect(
        covers(
          rideMinutes: 40,
          watchedMinutes: 35,
          tolerance: const Duration(minutes: 3),
        ),
        isFalse,
      );
      expect(
        covers(
          rideMinutes: 40,
          watchedMinutes: 35,
          tolerance: const Duration(minutes: 10),
        ),
        isTrue,
      );
    });
  });
}
