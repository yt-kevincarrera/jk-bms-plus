import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/metrics/capacity_cycle_detector.dart';

/// Builds a stored reading. Cell voltages are derived from the pack voltage so
/// the "full by top cell" path can be exercised too.
Snapshot reading(
  DateTime at, {
  required double soc,
  required double current,
  double cellVolts = 3.8,
  int cells = 20,
}) =>
    Snapshot(
      id: 0,
      timestamp: at,
      tripId: null,
      packVoltage: cellVolts * cells,
      current: current,
      soc: soc,
      soh: 97,
      remainingAh: 45 * soc / 100,
      cycleCount: 60,
      deltaVolts: 0.01,
      minCellVoltage: cellVolts - 0.005,
      maxCellVoltage: cellVolts,
      maxTemperature: 25,
      mosfetTemp: 27,
      warningsMask: 0,
      balancerActive: false,
      cellVoltagesJson: encodeCellVoltages(List.filled(cells, cellVolts)),
    );

/// Cell voltage for a given charge level, so a fixture that starts at 60%
/// does not also claim its cells are sitting at the top.
double cellVoltsFor(double soc) => 3.0 + soc / 100 * 1.15;

/// A steady discharge, one reading every ten seconds.
List<Snapshot> dischargeRun(
  DateTime from, {
  required double amps,
  required int seconds,
  double startSoc = 100,
  double endSoc = 2,
}) {
  final out = <Snapshot>[];
  final steps = seconds ~/ 10;
  for (var i = 0; i <= steps; i++) {
    final soc = startSoc - (startSoc - endSoc) * (i / steps);
    out.add(
      reading(
        from.add(Duration(seconds: i * 10)),
        soc: soc,
        current: -amps,
        cellVolts: cellVoltsFor(soc),
      ),
    );
  }
  return out;
}

void main() {
  const detector = CapacityCycleDetector();
  final t0 = DateTime.utc(2026, 1, 1, 8);

  group('CapacityCycleDetector', () {
    test('finds nothing in an empty history', () {
      expect(detector.scan(const []), isEmpty);
    });

    test('finds a full discharge and measures it', () {
      // 20 A for two hours would be 40 Ah end to end, but the run closes the
      // moment charge reaches the floor at 3%, a little before this synthetic
      // ride bottoms out at 2%. Stopping at the floor rather than running on is
      // the correct behaviour, so the expected figure is a shade under 40.
      final readings = dischargeRun(t0, amps: 20, seconds: 7200);
      final cycles = detector.scan(readings);

      expect(cycles, hasLength(1));
      expect(cycles.single.measuredAh, closeTo(39.6, 0.3));
      expect(cycles.single.startSoc, 100);
      expect(cycles.single.endSoc, lessThanOrEqualTo(3));
      expect(cycles.single.gapSeconds, 0);
    });

    test('ignores a discharge that did not start from full', () {
      final readings =
          dischargeRun(t0, amps: 20, seconds: 3600, startSoc: 60);
      expect(detector.scan(readings), isEmpty);
    });

    test('ignores a discharge that stopped part way down', () {
      final readings = dischargeRun(t0, amps: 20, seconds: 3600, endSoc: 40);
      expect(detector.scan(readings), isEmpty);
    });

    test('throws away a run that was charged in the middle', () {
      final first = dischargeRun(t0, amps: 20, seconds: 1800, endSoc: 50);
      final charge = [
        for (var i = 0; i < 10; i++)
          reading(
            t0.add(Duration(seconds: 1800 + i * 10)),
            soc: 50 + i.toDouble(),
            current: 15,
            cellVolts: 3.9,
          ),
      ];
      final second = dischargeRun(
        t0.add(const Duration(seconds: 2000)),
        amps: 20,
        seconds: 1800,
        startSoc: 60,
      );

      // Neither half started from full and ended at the floor on its own.
      expect(detector.scan([...first, ...charge, ...second]), isEmpty);
    });

    test('a charge back to full opens a fresh run', () {
      final firstCycle = dischargeRun(t0, amps: 20, seconds: 3600);
      final recharge = [
        for (var i = 0; i < 5; i++)
          reading(
            t0.add(Duration(seconds: 3700 + i * 10)),
            soc: 100,
            current: 10,
            cellVolts: 4.16,
          ),
      ];
      final secondCycle = dischargeRun(
        t0.add(const Duration(seconds: 4000)),
        amps: 15,
        seconds: 3600,
      );

      final cycles =
          detector.scan([...firstCycle, ...recharge, ...secondCycle]);
      expect(cycles, hasLength(2));
      expect(cycles.first.measuredAh, closeTo(20, 0.3));
      expect(cycles.last.measuredAh, closeTo(15, 0.3));
    });

    test('counts the time it was not watching rather than inventing it', () {
      final before = dischargeRun(t0, amps: 20, seconds: 600, endSoc: 90);
      // Half an hour with the app closed, then it picks back up.
      final after = dischargeRun(
        t0.add(const Duration(seconds: 2400)),
        amps: 20,
        seconds: 600,
        startSoc: 40,
      );

      final cycles = detector.scan([...before, ...after]);
      expect(cycles, hasLength(1));
      expect(cycles.single.gapSeconds, greaterThan(1500));
      // Roughly 20 minutes of counting at 20 A, not 50.
      expect(cycles.single.measuredAh, lessThan(8));
    });

    test('recognises full by top cell when the charge reading has drifted', () {
      // Coulomb counter reads 80% but the cells are at the top. That drift is
      // exactly what a capacity measurement is meant to settle, so it must not
      // be the thing that stops the measurement happening.
      final readings = <Snapshot>[
        reading(t0, soc: 80, current: -20, cellVolts: 4.18),
        ...dischargeRun(
          t0.add(const Duration(seconds: 10)),
          amps: 20,
          seconds: 3600,
          startSoc: 80,
        ),
      ];

      final cycles = detector.scan(readings);
      expect(cycles, hasLength(1));
      expect(cycles.single.startSoc, 80);
    });

    test('rejects a run too small to be a cycle', () {
      final readings = dischargeRun(t0, amps: 0.5, seconds: 120);
      expect(detector.scan(readings), isEmpty);
    });
    test('a rescan does not turn one discharge into several measurements', () {
      final readings = dischargeRun(t0, amps: 20, seconds: 7200);
      final first = detector.scan(readings);
      final second = detector.scan(readings);

      // Every start instant found the second time is already on record.
      final known = first.map((c) => c.startedAt).toList();
      final fresh = second
          .where((c) => !cycleAlreadyRecorded(c.startedAt, known))
          .toList();
      expect(fresh, isEmpty);
    });

    test('a genuinely different cycle is not mistaken for a stored one', () {
      final known = [t0];
      expect(
        cycleAlreadyRecorded(t0.add(const Duration(hours: 5)), known),
        isFalse,
      );
      // A sample or two of drift between scans still counts as the same run.
      expect(
        cycleAlreadyRecorded(t0.add(const Duration(seconds: 20)), known),
        isTrue,
      );
    });
  });
}
