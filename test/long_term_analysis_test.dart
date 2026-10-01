import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/metrics/long_term_analysis.dart';

Snapshot _reading({
  required int i,
  required double soc,
  required double current,
  required double delta,
}) => Snapshot(
  id: i,
  timestamp: DateTime.utc(2026, 9, 1).add(Duration(seconds: i)),
  tripId: null,
  deviceId: 'AA:BB',
  packVoltage: 78,
  current: current,
  soc: soc,
  soh: 100,
  remainingAh: 30,
  cycleCount: 60,
  cycleCapacityAh: 2000,
  deltaVolts: delta,
  minCellVoltage: 3.9,
  maxCellVoltage: 3.9 + delta,
  maxTemperature: 25,
  mosfetTemp: 27,
  warningsMask: 0,
  balancerActive: false,
  cellVoltagesJson: jsonEncode(List.filled(20, 3.9)),
);

void main() {
  const analysis = LongTermAnalysis();

  group('delta against charge', () {
    test('a charger at the top is not rest', () {
      // Charging used to count as rest, and the top of a charge is where the
      // delta peaks on every pack: it drew a "weak cell" shape on all of them.
      final readings = [
        for (var i = 0; i < 5; i++)
          _reading(i: i, soc: 95, current: 10, delta: 0.080),
      ];
      expect(analysis.deltaAgainstCharge(readings), isEmpty);
    });

    test('each point is the middle of its readings, not the worst', () {
      final readings = [
        for (final d in [0.010, 0.011, 0.012, 0.013, 0.090])
          _reading(i: 0, soc: 60, current: 0, delta: d),
      ];
      final points = analysis.deltaAgainstCharge(readings);
      expect(points, hasLength(1));
      expect(points.single.deltaVolts, 0.012);
      expect(points.single.underLoad, isFalse);
    });

    test('light current in between is neither rest nor load', () {
      final readings = [
        for (var i = 0; i < 5; i++)
          _reading(i: i, soc: 50, current: -2.5, delta: 0.02),
      ];
      expect(analysis.deltaAgainstCharge(readings), isEmpty);
    });

    test('discharge past 5 A is the loaded line', () {
      final readings = [
        for (var i = 0; i < 3; i++)
          _reading(i: i, soc: 50, current: -20, delta: 0.03),
      ];
      expect(analysis.deltaAgainstCharge(readings).single.underLoad, isTrue);
    });
  });
}
