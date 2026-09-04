import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/metrics/range_estimator.dart';

void main() {
  group('how much a ride is allowed to count for', () {
    // The estimator kept one running figure and had to start it somewhere, so
    // it took the first sample whole. A 1.8 km trundle round the block then
    // carried the same authority as a 40 km commute, and later samples could
    // only move it by their own small fraction of the half-life.

    test('a short first ride does not set the figure for good', () {
      // The three real rides off the pack, in order, once their energy was
      // measured properly: 31.2, 23.5 and 17.9 Wh/km over 1.86, 1.81 and
      // 5.95 km. Total energy over total distance is 21.5, which is the answer
      // any honest method has to land near.
      final e = RangeEstimator();
      e.addSegment(wh: 0.76 * 76.3, km: 1.86);
      e.addSegment(wh: 0.56 * 76.0, km: 1.81);
      e.addSegment(wh: 1.42 * 75.0, km: 5.95);

      // The old method gave 29.7, which quoted a full pack as 100 km against a
      // true 138: pessimistic by 40%, from arithmetic rather than the battery.
      expect(e.whPerKm, closeTo(21.2, 0.5));
      expect(e.learnedKm, closeTo(9.62, 0.01));
    });

    test('a long ride outweighs a short one', () {
      final e = RangeEstimator();
      e.addSegment(wh: 40 * 1, km: 1); // 40 Wh/km over 1 km
      e.addSegment(wh: 20 * 30, km: 30); // 20 Wh/km over 30 km
      // Nearly all the distance is at 20, so the answer belongs near 20.
      expect(e.whPerKm, lessThan(22));
    });

    test('one ride is the whole of the answer, and no more', () {
      final e = RangeEstimator();
      e.addSegment(wh: 25 * 10, km: 10);
      expect(e.whPerKm, closeTo(25, 0.001));
      expect(e.hasLearned, isTrue);
    });

    test('recent riding still wins over old riding', () {
      // The decay is the point of the half-life: winter, a new tyre or a
      // heavier load should move the number rather than be averaged away.
      final e = RangeEstimator(halfLifeKm: 40);
      for (var i = 0; i < 10; i++) {
        e.addSegment(wh: 20 * 20, km: 20);
      }
      final before = e.whPerKm;
      for (var i = 0; i < 5; i++) {
        e.addSegment(wh: 35 * 20, km: 20);
      }
      expect(before, closeTo(20, 0.5));
      expect(e.whPerKm, greaterThan(30));
    });

    test('a restored estimate keeps the weight its distance earned', () {
      // Otherwise reloading the app would hand the next short ride the same
      // outsized influence all over again.
      final restored = RangeEstimator(learnedWhPerKm: 20, learnedKm: 200);
      restored.addSegment(wh: 40 * 2, km: 2);
      expect(restored.whPerKm, closeTo(20, 0.5));
    });

    test('nothing learned still quotes the default, and says so', () {
      final e = RangeEstimator();
      expect(e.hasLearned, isFalse);
      expect(e.whPerKm, e.defaultWhPerKm);
    });
  });

  group('when a ride is worth asking about', () {
    // The trigger is what the ride would do to the number, not how far off the
    // ride was. A weird 2 km errand cannot move a 40 km half-life average, so
    // asking about it would be noise with no consequence behind it.

    test('a long ride slightly off is worth asking about', () {
      // 40 km at 14% below a learned 17.5 moves the figure 6.3%, past the line.
      // The break-even for a 40 km ride is 15.53 Wh/km, or 11.25% below, so this
      // sits clear of it rather than on it: a test balanced on the threshold
      // passes or fails on the last bit of a double.
      final e = RangeEstimator()..addSegment(wh: 17.5 * 100, km: 100);
      final shift = e.projectedShiftFraction(wh: 15.0 * 40, km: 40);
      expect(shift, greaterThan(RangeEstimator.askThresholdFraction));
    });

    test('and a long ride just inside the line is not', () {
      // 15.6 Wh/km is 10.9% below, which moves the figure 4.8%. Under the
      // threshold, so it passes without a word. This is the case that decides
      // whether the feature nags: an ordinary day is a few percent off, and a
      // few percent must stay silent.
      final e = RangeEstimator()..addSegment(wh: 17.5 * 100, km: 100);
      final shift = e.projectedShiftFraction(wh: 15.6 * 40, km: 40);
      expect(shift, lessThan(RangeEstimator.askThresholdFraction));
    });

    test('a short ride wildly off is not', () {
      // 5 km at half the usual consumption still cannot move the average by 5%.
      final e = RangeEstimator()..addSegment(wh: 17.5 * 100, km: 100);
      final shift = e.projectedShiftFraction(wh: 8.75 * 5, km: 5);
      expect(shift, lessThan(RangeEstimator.askThresholdFraction));
    });

    test('it works in both directions', () {
      // A day with a passenger or a headwind is no more representative than a
      // deliberately gentle one, and reads as a rise rather than a fall.
      final e = RangeEstimator()..addSegment(wh: 17.5 * 100, km: 100);
      final high = e.projectedShiftFraction(wh: 26 * 40, km: 40);
      expect(high, greaterThan(RangeEstimator.askThresholdFraction));
    });

    test('a sample the estimator would reject moves nothing', () {
      final e = RangeEstimator()..addSegment(wh: 17.5 * 100, km: 100);
      expect(e.projectedShiftFraction(wh: 5, km: 0.05), 0);
      expect(e.projectedShiftFraction(wh: -10, km: 5), 0);
    });

    test('asking does not change what was learned', () {
      final e = RangeEstimator()..addSegment(wh: 17.5 * 100, km: 100);
      final beforeWhPerKm = e.whPerKm;
      final beforeHasLearned = e.hasLearned;
      final beforeLearnedKm = e.learnedKm;
      e.projectedShiftFraction(wh: 26 * 40, km: 40);
      expect(e.whPerKm, beforeWhPerKm);
      expect(e.hasLearned, beforeHasLearned);
      expect(e.learnedKm, beforeLearnedKm);
    });

    test('a fresh estimator has no learned figure for a ride to move', () {
      // Before any segment is folded in, whPerKm answers with defaultWhPerKm,
      // a number about a hypothetical motorcycle rather than anything learned.
      // Asking whether a ride represents the rider against that invented
      // baseline is the same mistake RangeOutlook.from refuses to make when it
      // will not quote a range before hasLearned is true.
      final e = RangeEstimator();
      expect(e.hasLearned, isFalse);
      expect(e.projectedShiftFraction(wh: 15.0 * 40, km: 40), 0);
    });
  });
}
