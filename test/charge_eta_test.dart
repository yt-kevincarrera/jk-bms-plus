import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/metrics/charge_eta.dart';
import 'package:jk_bms/src/metrics/soc_trust.dart';

void main() {
  const estimator = ChargeEtaEstimator();

  ChargeEta at({
    required double soc,
    double current = 10,
    double capacityAh = 40,
    double? highestCellVolts,
    double? cellFullVolts,
    double? soc100Volts,
  }) => estimator.estimate(
    current: current,
    soc: soc,
    capacityAh: capacityAh,
    highestCellVolts: highestCellVolts,
    fullAnchor: SocTrust.fullAnchor(
      soc100Volts: soc100Volts,
      cellOvp: cellFullVolts,
    ),
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
      // With the cells at the cutoff, so the near-full reading is believed.
      expect(
        at(soc: 100, highestCellVolts: 4.20, cellFullVolts: 4.25).remaining,
        Duration.zero,
      );
      expect(
        at(soc: 99.6, highestCellVolts: 4.20, cellFullVolts: 4.25).remaining,
        Duration.zero,
      );
    });
  });

  // The screen this was written for: a 40 Ah nameplate reading 99% and 39.6 Ah
  // with 8 A still going in and the pack at 80.1 V. The arithmetic was right
  // and said three minutes; the charge had the best part of an hour to run,
  // because the 99% was a drifted counter rather than a measurement.
  group('when the charge counter disagrees with the pack', () {
    test('says nothing rather than three minutes', () {
      // 20S NMC, so 80.1 V is 4.005 V a cell against a 4.20 V cutoff.
      final eta = at(
        soc: 99,
        current: 8,
        highestCellVolts: 4.009,
        cellFullVolts: 4.20,
      );
      expect(eta.remaining, isNull);
      expect(eta.socLooksOptimistic, isTrue);
      expect(eta.isTapering, isTrue);
    });

    test('the same pack read as LFP', () {
      // 24S at 3.34 V a cell against a 3.65 V cutoff. Different chemistry,
      // same verdict: nowhere near the end of a charge.
      final eta = at(
        soc: 99,
        current: 8,
        highestCellVolts: 3.342,
        cellFullVolts: 3.65,
      );
      expect(eta.remaining, isNull);
      expect(eta.socLooksOptimistic, isTrue);
    });

    test('a cell at the cutoff is believed, whatever the current', () {
      // Voltage settles it in both directions. This one really is at the end
      // of a charge, so it keeps its number.
      final eta = at(
        soc: 98,
        current: 8,
        highestCellVolts: 4.19,
        cellFullVolts: 4.25,
      );
      expect(eta.socLooksOptimistic, isFalse);
      expect(eta.remaining, isNotNull);
    });

    test('a cutoff set above where the charger stops is not a disagreement', () {
      // Builders leave headroom above the charge voltage on the protection
      // threshold. A full cell resting 70 mV under it is normal.
      final eta = at(
        soc: 99,
        current: 1.5,
        highestCellVolts: 4.18,
        cellFullVolts: 4.25,
      );
      expect(eta.socLooksOptimistic, isFalse);
      expect(eta.remaining, isNotNull);
    });

    test('the BMS\'s own 100% voltage is held to a tighter margin', () {
      // 70 mV under a protection threshold is builder headroom; 70 mV under
      // the voltage the BMS itself calls full is the counter being early.
      expect(
        at(soc: 99, current: 3, highestCellVolts: 4.13, cellFullVolts: 4.20)
            .socLooksOptimistic,
        isFalse,
      );
      expect(
        at(soc: 99, current: 3, highestCellVolts: 4.13, soc100Volts: 4.20)
            .socLooksOptimistic,
        isTrue,
      );
    });

    test('nothing below the check bar is touched', () {
      final eta = at(soc: 80, highestCellVolts: 3.9, cellFullVolts: 4.2);
      expect(eta.socLooksOptimistic, isFalse);
      expect(eta.remaining, isNotNull);
    });
  });

  group('with no cutoff to compare against', () {
    test('a tenth of C into a pack that claims 99% is not believed', () {
      // No settings frame, so the current has to carry it: 8 A into 40 Ah is
      // constant current, and a constant-current charge is not at 99%.
      final eta = at(soc: 99, current: 8);
      expect(eta.remaining, isNull);
      expect(eta.socLooksOptimistic, isTrue);
    });

    test('a real tail keeps its answer', () {
      final eta = at(soc: 99, current: 1.2);
      expect(eta.socLooksOptimistic, isFalse);
      expect(eta.remaining!.inMinutes, greaterThan(5));
    });

    test('the current alone will not call the mid-nineties wrong', () {
      // A flat-curve pack can genuinely still be taking full current there,
      // and with nothing measured to check against, guessing is worse than
      // leaving it alone.
      final eta = at(soc: 96, current: 8);
      expect(eta.socLooksOptimistic, isFalse);
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
