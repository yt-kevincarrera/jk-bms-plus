import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/metrics/degradation.dart';

CapacityTest measurement(DateTime at, double ah) => CapacityTest(
      id: 0,
      deviceId: 'AA:BB',
      startedAt: at,
      endedAt: at,
      startSoc: 100,
      endSoc: 3,
      startPackVoltage: 84,
      endPackVoltage: 60,
      measuredAh: ah,
      measuredWh: ah * 72,
      catalogueAh: null,
      completed: true,
      automatic: false,
      gapSeconds: 0,
      note: '',
    );

Snapshot reading(DateTime at, {required double remainingAh, double soc = 60}) =>
    Snapshot(
      id: 0,
      timestamp: at,
      tripId: null,
      deviceId: 'AA:BB',
      packVoltage: 78,
      current: -5,
      soc: soc,
      soh: 97,
      remainingAh: remainingAh,
      cycleCount: 60,
      cycleCapacityAh: 2000,
      deltaVolts: 0.01,
      minCellVoltage: 3.89,
      maxCellVoltage: 3.9,
      maxTemperature: 25,
      mosfetTemp: 27,
      warningsMask: 0,
      balancerActive: false,
      cellVoltagesJson: '[3.9]',
    );

void main() {
  final y1 = DateTime.utc(2025, 1, 1);
  final y2 = DateTime.utc(2026, 1, 1);

  group('a pack that was never what it was sold as', () {
    test('is not reported as degraded on day one', () {
      // The whole point. A pack advertised as 45 Ah that was always 40 has
      // lost nothing, and calling it 89% healthy describes the advert, not
      // the battery.
      final d = Degradation.from(
        tests: [measurement(y1, 40)],
        readings: const [],
        advertisedAh: 45,
      );

      expect(d.lostFraction, isNull);
      expect(d.current!.ah, 40);
    });

    test('but does say it came up short of the advert', () {
      // The separate question, answered separately: a fact about the purchase,
      // not about wear.
      final d = Degradation.from(
        tests: [measurement(y1, 40)],
        readings: const [],
        advertisedAh: 45,
      );
      expect(d.shortOfAdvertisedFraction, closeTo(0.111, 0.002));
    });

    test('says nothing about the advert when nobody stated one', () {
      final d = Degradation.from(
        tests: [measurement(y1, 40)],
        readings: const [],
      );
      expect(d.shortOfAdvertisedFraction, isNull);
    });

    test('a pack that beat its advert is not short of it', () {
      final d = Degradation.from(
        tests: [measurement(y1, 46)],
        readings: const [],
        advertisedAh: 45,
      );
      expect(d.shortOfAdvertisedFraction, 0);
    });
  });

  group('degradation, once there is something to compare', () {
    test('is measured against the best this pack ever managed', () {
      // 40 when new, 36 a year later: 10% gone. Against the 45 Ah advert it
      // would read as 20%, half of which the pack never had.
      final d = Degradation.from(
        tests: [measurement(y1, 40), measurement(y2, 36)],
        readings: const [],
        advertisedAh: 45,
      );

      expect(d.baseline!.ah, 40);
      expect(d.current!.ah, 36);
      expect(d.lostFraction, closeTo(0.10, 0.001));
      // And the purchase question still answers separately.
      expect(d.shortOfAdvertisedFraction, closeTo(0.111, 0.002));
    });

    test('takes the high-water mark, not the first measurement', () {
      // A first test done badly, or on a cold day, is not the baseline.
      final d = Degradation.from(
        tests: [
          measurement(y1, 37),
          measurement(DateTime.utc(2025, 6, 1), 41),
          measurement(y2, 38),
        ],
        readings: const [],
      );
      expect(d.baseline!.ah, 41);
      expect(d.lostFraction, closeTo(0.073, 0.002));
    });

    test('a pack that measured better than before has not lost capacity', () {
      // Measurements wobble. Reporting a negative loss would read as the pack
      // having gained capacity.
      final d = Degradation.from(
        tests: [measurement(y1, 39), measurement(y2, 40)],
        readings: const [],
      );
      expect(d.lostFraction, 0);
    });

    test('one measurement is a capacity, not a degradation', () {
      // With a single point there is nothing to have declined from, and 0%
      // would claim the pack is provably as good as new.
      final d = Degradation.from(
        tests: [measurement(y1, 40)],
        readings: const [],
      );
      expect(d.lostFraction, isNull);
      expect(d.baselineIsMeasured, isTrue);
    });
  });

  group('before any capacity has been measured', () {
    test('falls back to what the BMS implies, and says so', () {
      final d = Degradation.from(
        tests: const [],
        readings: [
          reading(y1, remainingAh: 24, soc: 60), // implies 40
          reading(y2, remainingAh: 21.6, soc: 60), // implies 36
        ],
      );

      expect(d.baselineIsMeasured, isFalse);
      expect(d.baseline!.ah, closeTo(40, 0.001));
      expect(d.current!.ah, closeTo(36, 0.001));
      expect(d.lostFraction, closeTo(0.10, 0.001));
    });

    test('ignores readings near the ends of the range', () {
      // Dividing by a rounded percentage there is noise, and a noisy high
      // reading would set a baseline the pack never reached.
      final d = Degradation.from(
        tests: const [],
        readings: [
          reading(y1, remainingAh: 39, soc: 95), // would imply 41
          reading(y2, remainingAh: 20, soc: 50), // implies 40
        ],
      );
      expect(d.baseline!.ah, closeTo(40, 0.001));
    });

    test('a single real measurement outranks any amount of arithmetic', () {
      final d = Degradation.from(
        tests: [measurement(y2, 36)],
        readings: [reading(y1, remainingAh: 24, soc: 60)],
      );
      expect(d.current!.source, CapacitySource.measured);
      expect(d.current!.ah, 36);
    });

    test('with nothing at all, it says nothing', () {
      final d = Degradation.from(tests: const [], readings: const []);
      expect(d.current, isNull);
      expect(d.baseline, isNull);
      expect(d.lostFraction, isNull);
      expect(d.shortOfAdvertisedFraction, isNull);
    });
  });
}
