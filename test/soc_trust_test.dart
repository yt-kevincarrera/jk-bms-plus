import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/metrics/soc_trust.dart';

/// The charge percentage is the one figure on the screen nobody measures.
/// These are the two ends where the cells can contradict it.
void main() {
  const trust = SocTrust.defaults;

  SocDrift check({
    required double soc,
    required double current,
    double capacityAh = 40,
    double? highest,
    double? lowest,
    double? soc100,
    double? cellOvp,
    double? soc0,
  }) => trust.check(
    soc: soc,
    current: current,
    capacityAh: capacityAh,
    highestCellVolts: highest,
    lowestCellVolts: lowest,
    full: SocTrust.fullAnchor(soc100Volts: soc100, cellOvp: cellOvp),
    empty: SocTrust.emptyAnchor(soc0Volts: soc0),
  );

  group('choosing an anchor', () {
    test("the BMS's own 100% voltage wins, with less slack", () {
      final a = SocTrust.fullAnchor(soc100Volts: 4.10, cellOvp: 4.25)!;
      expect(a.volts, 4.10);
      expect(a.slackVolts, lessThan(0.10));
    });

    test('an unset 100% voltage falls back to the protection threshold', () {
      final a = SocTrust.fullAnchor(soc100Volts: 0, cellOvp: 4.25)!;
      expect(a.volts, 4.25);
      // Looser, because it is answering a different question.
      expect(a.slackVolts, greaterThan(0.10));
    });

    test('with neither, there is no anchor', () {
      expect(SocTrust.fullAnchor(soc100Volts: 0, cellOvp: 0), isNull);
    });

    test('the empty anchor has no fallback at all', () {
      // How far the useful floor sits above the protection floor is a fact
      // about the chemistry, which is not something to assume.
      expect(SocTrust.emptyAnchor(soc0Volts: 0), isNull);
      expect(SocTrust.emptyAnchor(soc0Volts: 3.1)!.volts, 3.1);
    });
  });

  group('the top', () {
    test('99% with the cells a fifth of a volt low is not believed', () {
      expect(
        check(soc: 99, current: 8, highest: 4.00, cellOvp: 4.20),
        SocDrift.aheadOfCells,
      );
    });

    test('a cell at the anchor is believed whatever the current', () {
      expect(
        check(soc: 99, current: 8, highest: 4.19, cellOvp: 4.25),
        SocDrift.none,
      );
    });

    test('builder headroom under a protection threshold is not a gap', () {
      expect(
        check(soc: 99, current: 2, highest: 4.13, cellOvp: 4.20),
        SocDrift.none,
      );
    });

    test('the same gap under a declared full point is', () {
      expect(
        check(soc: 99, current: 2, highest: 4.13, soc100: 4.20),
        SocDrift.aheadOfCells,
      );
    });

    test('the top is only checked while charging', () {
      expect(
        check(soc: 99, current: -20, highest: 4.00, cellOvp: 4.20),
        SocDrift.none,
      );
      expect(
        check(soc: 99, current: 0, highest: 4.00, cellOvp: 4.20),
        SocDrift.none,
      );
    });
  });

  group('the top with no anchor', () {
    test('a tenth of C at 99% is constant current, not a tail', () {
      expect(check(soc: 99, current: 8), SocDrift.aheadOfCells);
    });

    test('a real tail keeps its reading', () {
      expect(check(soc: 99, current: 1.2), SocDrift.none);
    });

    test('the mid-nineties are left alone on current alone', () {
      // A flat-curve chemistry can honestly still be taking full current
      // there, and guessing is worse than saying nothing.
      expect(check(soc: 96, current: 8), SocDrift.none);
    });
  });

  group('the bottom', () {
    test('2% with the cells well above the declared empty point', () {
      expect(
        check(soc: 2, current: -12, lowest: 3.55, soc0: 3.10),
        SocDrift.behindCells,
      );
    });

    test('cells actually at the empty point are believed', () {
      expect(
        check(soc: 2, current: -12, lowest: 3.14, soc0: 3.10),
        SocDrift.none,
      );
    });

    test('it reads at rest too', () {
      expect(
        check(soc: 0, current: 0, lowest: 3.55, soc0: 3.10),
        SocDrift.behindCells,
      );
    });

    test('the bottom is not checked while charging', () {
      expect(
        check(soc: 2, current: 8, lowest: 3.55, soc0: 3.10),
        SocDrift.none,
      );
    });

    test('nothing is said without a declared empty point', () {
      expect(check(soc: 2, current: -12, lowest: 3.55), SocDrift.none);
    });
  });

  test('the middle is never checked', () {
    // Where a flat curve says almost nothing and load sags the reading.
    for (final soc in [20.0, 50.0, 80.0, 94.0]) {
      expect(
        check(soc: soc, current: 8, highest: 3.60, cellOvp: 4.20),
        SocDrift.none,
      );
      expect(
        check(soc: soc, current: -20, lowest: 3.90, soc0: 3.10),
        SocDrift.none,
      );
    }
  });
}
