import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/metrics/deepest_discharge.dart';

Snapshot at(DateTime when, double soc, {double current = -15}) => Snapshot(
      id: 0,
      timestamp: when,
      tripId: null,
      deviceId: 'AA:BB',
      packVoltage: 70 + soc * 0.14,
      current: current,
      soc: soc,
      soh: 97,
      remainingAh: 40 * soc / 100,
      cycleCount: 60,
      cycleCapacityAh: 2000,
      deltaVolts: 0.01,
      minCellVoltage: 3.5,
      maxCellVoltage: 3.51,
      maxTemperature: 25,
      mosfetTemp: 27,
      warningsMask: 0,
      balancerActive: false,
      cellVoltagesJson: '[3.5]',
    );

/// A steady run from [from] down to [to], one reading a minute.
List<Snapshot> run(DateTime start, double from, double to,
    {double current = -15}) {
  final steps = (from - to).round();
  return [
    for (var i = 0; i <= steps; i++)
      at(start.add(Duration(minutes: i)), from - i, current: current),
  ];
}

void main() {
  const finder = DeepestDischargeFinder();
  final t0 = DateTime.utc(2026, 6, 1, 8);

  group('how deep the pack has been run', () {
    test('finds a single ride', () {
      final deepest = finder.find(run(t0, 95, 40));
      expect(deepest!.startSoc, 95);
      expect(deepest.endSoc, 40);
      expect(deepest.span, 55);
    });

    test('picks the deepest of several', () {
      final readings = [
        ...run(t0, 90, 70),
        ...run(t0.add(const Duration(hours: 5)), 100, 25, current: -18),
        ...run(t0.add(const Duration(hours: 20)), 80, 60),
      ];
      expect(finder.find(readings)!.span, 75);
    });

    test('a charge in the middle breaks the run', () {
      // Otherwise 90 down to 60, charged to 95, down to 30 would be reported
      // as a 60 point discharge that never happened.
      final readings = [
        ...run(t0, 90, 60),
        at(t0.add(const Duration(hours: 1)), 95, current: 10),
        ...run(t0.add(const Duration(hours: 2)), 95, 70),
      ];
      final deepest = finder.find(readings)!;
      expect(deepest.span, lessThanOrEqualTo(30));
    });

    test('a gap in the readings breaks it too', () {
      // What happened while the app was away is unknown, and assuming more of
      // the same would invent depth the pack may never have reached.
      final readings = [
        ...run(t0, 95, 80),
        ...run(t0.add(const Duration(hours: 6)), 40, 20),
      ];
      final deepest = finder.find(readings)!;
      expect(deepest.span, lessThanOrEqualTo(20));
    });

    test('says nothing about an empty history', () {
      expect(finder.find(const []), isNull);
    });

    test('says nothing when the pack only ever sat still', () {
      final readings = [
        for (var i = 0; i < 30; i++)
          at(t0.add(Duration(minutes: i)), 70, current: 0),
      ];
      expect(finder.find(readings), isNull);
    });
  });
}
