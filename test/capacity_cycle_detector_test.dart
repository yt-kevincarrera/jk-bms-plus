import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/metrics/capacity_cycle_detector.dart';
import 'package:jk_bms/src/metrics/capacity_endpoints.dart';

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
      cycleCapacityAh: 0,
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
      // 20 A for two hours would be 40 Ah end to end. The run closes the
      // moment the lowest cell comes within 50 mV of the 3.0 V cutoff, which
      // on this synthetic curve is at 4.3 %, 7030 s in: 39.06 Ah. Whatever
      // the percentage says at that point is beside the point.
      final readings = dischargeRun(t0, amps: 20, seconds: 7200);
      final cycles = detector.scan(readings);

      expect(cycles, hasLength(1));
      expect(cycles.single.measuredAh, closeTo(39.06, 0.1));
      expect(cycles.single.startSoc, 100);
      expect(cycles.single.endSoc, greaterThan(3));
      expect(cycles.single.endReason, CapacityEndReason.cellCutoff);
      expect(cycles.single.gapSeconds, 0);
    });

    test('3 % on the percentage with the cells well up is not the end', () {
      // The old rule: the counter reaching the floor closed the run. On a
      // pack whose BMS is configured smaller than it is, the counter hits 3 %
      // with a good part of the pack still in it.
      final readings = [
        for (var i = 0; i <= 360; i++)
          reading(
            t0.add(Duration(seconds: i * 10)),
            soc: 100 - 97 * i / 360,
            current: -20,
            cellVolts: 4.15 - 0.6 * i / 360,
          ),
      ];
      expect(detector.scan(readings), isEmpty);
    });

    test('can measure more than the BMS is configured for', () {
      // Configured for 45 Ah, holding 50. The counter runs out at 2 h 15 min
      // and sits at 0 %, and the cells carry on for another quarter of an
      // hour. The old test, bounded by the counter, could never report more
      // than about 0.94 of the configured figure.
      final readings = <Snapshot>[];
      const steps = 900; // 2.5 h in 10 s slices, 20 A: 50 Ah.
      for (var i = 0; i <= steps; i++) {
        final ah = 20 * i * 10 / 3600;
        readings.add(
          reading(
            t0.add(Duration(seconds: i * 10)),
            soc: (100 - ah / 45 * 100).clamp(0, 100).toDouble(),
            current: -20,
            cellVolts: 4.15 - 1.12 * i / steps,
          ),
        );
      }
      final cycles = detector.scan(readings);
      expect(cycles, hasLength(1));
      expect(cycles.single.measuredAh, greaterThan(45));
      expect(cycles.single.endSoc, 0);
    });

    test("the BMS's undervoltage warning closes the run", () {
      final readings = [
        ...dischargeRun(t0, amps: 20, seconds: 3600, endSoc: 30),
      ];
      final last = readings.last;
      readings.add(
        last.copyWith(
          timestamp: last.timestamp.add(const Duration(seconds: 10)),
          warningsMask: 1 << 11, // cell undervoltage
        ),
      );
      final cycles = detector.scan(readings);
      expect(cycles, hasLength(1));
      expect(cycles.single.endReason, CapacityEndReason.bmsCutoff);
    });

    test('a pack with no full mark opens nothing', () {
      const blind = CapacityCycleDetector(
        endpoints: CapacityEndpoints(fullCellVolts: null, cutoffCellVolts: 3),
      );
      expect(blind.scan(dischargeRun(t0, amps: 20, seconds: 7200)), isEmpty);
    });

    test('a charge the app never saw voids the run', () {
      // Evening ride to 50 %, the phone left in another room overnight on
      // the charger, and the morning ride picks up from 90 %. No reading ever
      // caught current going in, which is all the old detector looked for.
      final evening = dischargeRun(t0, amps: 20, seconds: 1800, endSoc: 50);
      final morning = dischargeRun(
        t0.add(const Duration(seconds: 1800 + 20 * 60)),
        amps: 20,
        seconds: 3600,
        startSoc: 90,
      );
      expect(detector.scan([...evening, ...morning]), isEmpty);
    });

    test('more than half an hour unwatched voids the run', () {
      final before = dischargeRun(t0, amps: 20, seconds: 600, endSoc: 90);
      final after = dischargeRun(
        t0.add(const Duration(minutes: 50)),
        amps: 20,
        seconds: 600,
        startSoc: 40,
      );
      expect(detector.scan([...before, ...after]), isEmpty);
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
      // Each closes 50 mV above the cutoff, 3520 s in, rather than at the
      // end of the synthetic ride: 20 A and 15 A for 3520 s.
      expect(cycles.first.measuredAh, closeTo(19.56, 0.05));
      expect(cycles.last.measuredAh, closeTo(14.67, 0.05));
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
