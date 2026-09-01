import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/metrics/charge_eta.dart';

void main() {
  const estimator = ChargeEtaEstimator();

  ChargeEta at({
    required double soc,
    double current = 10,
    double capacityAh = 40,
  }) =>
      estimator.estimate(
        current: current,
        soc: soc,
        capacityAh: capacityAh,
      );

  group('through the flat part of a charge', () {
    test('is roughly amp-hours left over amps going in', () {
      // 40 Ah pack at 50%, 10 A in. Twenty amp-hours to 100%, of which sixteen
      // are at full rate: about 1.6 h plus the tail.
      final eta = at(soc: 50);
      expect(eta.remaining, isNotNull);
      expect(eta.remaining!.inMinutes, greaterThan(90));
      expect(eta.remaining!.inMinutes, lessThan(180));
      expect(eta.isTapering, isFalse);
    });

    test('halves when the current doubles', () {
      final slow = at(soc: 50, current: 5);
      final fast = at(soc: 50, current: 10);
      expect(
        fast.remaining!.inSeconds / slow.remaining!.inSeconds,
        closeTo(0.5, 0.02),
      );
    });

    test('a bigger pack takes longer at the same rate', () {
      final small = at(soc: 50, capacityAh: 20);
      final big = at(soc: 50, capacityAh: 40);
      expect(big.remaining!, greaterThan(small.remaining!));
    });
  });

  group('the tail, where the naive answer is wrong', () {
    test('says it is tapering above ninety percent', () {
      expect(at(soc: 95).isTapering, isTrue);
      expect(at(soc: 80).isTapering, isFalse);
    });

    test('allows more time than dividing would suggest', () {
      // 40 Ah at 92%, 10 A in. Naively 0.03 h, about two minutes. In reality
      // the current is already falling away and it takes far longer, and a
      // two-minute promise on a charge that takes half an hour is the kind of
      // number that stops people trusting the screen.
      final eta = at(soc: 92, current: 10);
      final naive = (0.995 - 0.92) * 40 / 10 * 3600;
      expect(eta.remaining!.inSeconds, greaterThan(naive * 1.5));
    });

    test('reaches zero once the pack is full', () {
      expect(at(soc: 100).remaining, Duration.zero);
      expect(at(soc: 99.6).remaining, Duration.zero);
    });
  });

  group('when it will not guess', () {
    test('nothing is going in', () {
      expect(at(soc: 50, current: 0).remaining, isNull);
      // Discharging is not a charge with a negative time left.
      expect(at(soc: 50, current: -20).remaining, isNull);
    });

    test('a trickle says nothing useful', () {
      // Either finished or not really charging, and dividing by it produces
      // an answer in days.
      expect(at(soc: 50, current: 0.2).remaining, isNull);
    });

    test('no capacity to work from', () {
      expect(at(soc: 50, capacityAh: 0).remaining, isNull);
    });
  });
}
