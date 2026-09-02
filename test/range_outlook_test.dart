import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/metrics/range_estimator.dart';
import 'package:jk_bms/src/metrics/range_outlook.dart';

/// An estimator that has learned [whPerKm] over [km].
RangeEstimator learned({double whPerKm = 20, double km = 60}) {
  final e = RangeEstimator();
  e.addSegment(wh: whPerKm * km, km: km);
  return e;
}

void main() {
  group('two questions, answered separately', () {
    // They were one number with one label, and "range: 34 km" on a pack at 60%
    // reads as what the bike does. Only one of them changes when you charge.

    test('the remaining range comes from the charge in the pack now', () {
      final o = RangeOutlook.from(
        estimator: learned(whPerKm: 20),
        usableWhNow: 600,
        fullCapacityAh: 40,
        fullPackVoltage: 74,
      );
      expect(o.nowKm, closeTo(30, 0.001));
    });

    test('the full-pack range does not move when the charge does', () {
      final e = learned(whPerKm: 20);
      final low = RangeOutlook.from(
        estimator: e,
        usableWhNow: 300,
        fullCapacityAh: 40,
        fullPackVoltage: 74,
      );
      final high = RangeOutlook.from(
        estimator: e,
        usableWhNow: 2400,
        fullCapacityAh: 40,
        fullPackVoltage: 74,
      );

      expect(low.nowKm, isNot(closeTo(high.nowKm!, 1)));
      expect(low.fullKm, closeTo(high.fullKm!, 0.001));
      // 40 Ah at 74 V is 2960 Wh, at 20 Wh/km: 148 km.
      expect(low.fullKm, closeTo(148, 0.5));
    });

    test('it is not the remaining range scaled up by percent', () {
      // Which is the tempting shortcut and is wrong: usable energy is not
      // linear in charge near the cutoff, and the weakest-cell correction that
      // shapes the remaining figure is a fact about right now.
      final o = RangeOutlook.from(
        estimator: learned(whPerKm: 20),
        // A pack at half charge whose weakest cell has stranded some of it.
        usableWhNow: 1200,
        fullCapacityAh: 40,
        fullPackVoltage: 74,
      );
      expect(o.nowKm, closeTo(60, 0.001));
      expect(o.fullKm, closeTo(148, 0.5));
      expect(o.fullKm, isNot(closeTo(o.nowKm! * 2, 1)));
    });
  });

  group('what it refuses to say', () {
    test('nothing at all until consumption has been learned', () {
      // The estimator will divide by its own starting default all day. That is
      // a number about a hypothetical motorcycle.
      final o = RangeOutlook.from(
        estimator: RangeEstimator(),
        usableWhNow: 1200,
        fullCapacityAh: 40,
        fullPackVoltage: 74,
      );
      expect(o.hasLearned, isFalse);
      expect(o.nowKm, isNull);
      expect(o.fullKm, isNull);
    });

    test('no full-pack figure without a capacity to build it on', () {
      // And the remaining range still answers, because it needs no capacity:
      // the pack says how many amp-hours are in it right now.
      final o = RangeOutlook.from(
        estimator: learned(whPerKm: 20),
        usableWhNow: 600,
      );
      expect(o.nowKm, closeTo(30, 0.001));
      expect(o.fullKm, isNull);
    });

    test('a zero or negative capacity is not a capacity', () {
      final o = RangeOutlook.from(
        estimator: learned(),
        usableWhNow: 600,
        fullCapacityAh: 0,
        fullPackVoltage: 74,
      );
      expect(o.fullKm, isNull);
    });

    test('an empty pack has no remaining range, but still a full one', () {
      final o = RangeOutlook.from(
        estimator: learned(whPerKm: 20),
        usableWhNow: 0,
        fullCapacityAh: 40,
        fullPackVoltage: 74,
      );
      expect(o.nowKm, isNull);
      expect(o.fullKm, closeTo(148, 0.5));
    });
  });

  group('where the capacity came from', () {
    test('says when it is a measurement', () {
      final o = RangeOutlook.from(
        estimator: learned(),
        usableWhNow: 600,
        fullCapacityAh: 38,
        fullPackVoltage: 74,
        capacityWasMeasured: true,
      );
      expect(o.fullFromMeasuredCapacity, isTrue);
    });

    test('and when it is only what the pack was sold as', () {
      // A full-pack range built on an advert inherits whatever the advert got
      // wrong, and the rider is the only one who can tell the difference.
      final o = RangeOutlook.from(
        estimator: learned(),
        usableWhNow: 600,
        fullCapacityAh: 45,
        fullPackVoltage: 74,
      );
      expect(o.fullFromMeasuredCapacity, isFalse);
    });
  });

  group('the band around each', () {
    test('widens with low confidence and narrows as it learns', () {
      final young = RangeOutlook.from(
        estimator: learned(whPerKm: 20, km: 3),
        usableWhNow: 1200,
        fullCapacityAh: 40,
        fullPackVoltage: 74,
      );
      final seasoned = RangeOutlook.from(
        estimator: learned(whPerKm: 20, km: 400),
        usableWhNow: 1200,
        fullCapacityAh: 40,
        fullPackVoltage: 74,
      );

      double width((double, double) b) => b.$2 - b.$1;
      expect(
        width(young.nowBandKm!),
        greaterThan(width(seasoned.nowBandKm!)),
      );
      expect(young.confidence, RangeConfidence.low);
      expect(seasoned.confidence, RangeConfidence.high);
    });

    test('the full-pack band brackets the full-pack figure', () {
      final o = RangeOutlook.from(
        estimator: learned(whPerKm: 20, km: 400),
        usableWhNow: 1200,
        fullCapacityAh: 40,
        fullPackVoltage: 74,
      );
      expect(o.fullBandKm!.$1, lessThan(o.fullKm!));
      expect(o.fullBandKm!.$2, greaterThan(o.fullKm!));
    });
  });

  group('a weak cell shortens both figures, not just one', () {
    // Shipped wrong for one release: the remaining range was derated by the
    // imbalance and the full-pack one was not, so a fully charged pack with a
    // weak cell showed a *larger* full-pack range than remaining range. The
    // weakest cell reaches cutoff first whatever the charge was when it
    // started.
    test('the full-pack figure is derated too', () {
      final balanced = RangeOutlook.from(
        estimator: learned(whPerKm: 20),
        usableWhNow: 2960,
        fullCapacityAh: 40,
        fullPackVoltage: 74,
      );
      final imbalanced = RangeOutlook.from(
        estimator: learned(whPerKm: 20),
        usableWhNow: 2960 * 0.8,
        fullCapacityAh: 40,
        fullPackVoltage: 74,
        usableFraction: 0.8,
      );

      expect(imbalanced.fullKm, lessThan(balanced.fullKm!));
      expect(imbalanced.fullKm, closeTo(balanced.fullKm! * 0.8, 0.5));
    });

    test('a full pack does not go further than it has left', () {
      // The contradiction stated as an assertion: at full charge the two
      // figures describe the same battery and must agree.
      final o = RangeOutlook.from(
        estimator: learned(whPerKm: 20),
        usableWhNow: 40 * 74 * 0.8,
        fullCapacityAh: 40,
        fullPackVoltage: 74,
        usableFraction: 0.8,
      );
      expect(o.fullKm, closeTo(o.nowKm!, 0.5));
    });

    test('a fraction of zero leaves no full-pack figure to quote', () {
      final o = RangeOutlook.from(
        estimator: learned(),
        usableWhNow: 0,
        fullCapacityAh: 40,
        fullPackVoltage: 74,
        usableFraction: 0,
      );
      expect(o.fullKm, isNull);
    });
  });
}
