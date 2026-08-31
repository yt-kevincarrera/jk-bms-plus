import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/metrics/cell_drift.dart';

/// One stored reading with a given set of cells.
Snapshot reading(DateTime at, List<double> cells, {double current = 0}) =>
    Snapshot(
      id: 0,
      timestamp: at,
      tripId: null,
      deviceId: 'AA:BB',
      packVoltage: cells.reduce((a, b) => a + b),
      current: current,
      soc: 70,
      soh: 97,
      remainingAh: 30,
      cycleCount: 60,
      cycleCapacityAh: 2000,
      deltaVolts: cells.reduce((a, b) => a > b ? a : b) -
          cells.reduce((a, b) => a < b ? a : b),
      minCellVoltage: cells.reduce((a, b) => a < b ? a : b),
      maxCellVoltage: cells.reduce((a, b) => a > b ? a : b),
      maxTemperature: 25,
      mosfetTemp: 27,
      warningsMask: 0,
      balancerActive: false,
      cellVoltagesJson: jsonEncode(cells),
    );

/// A run of readings over [days], where cell [failing] sinks from level to
/// [endSag] volts below the rest.
List<Snapshot> history({
  required int days,
  required int perDay,
  int? failing,
  double endSag = 0,
  double current = 0,
  int cells = 20,
}) {
  final start = DateTime.utc(2026, 1, 1);
  final out = <Snapshot>[];
  final total = days * perDay;
  for (var i = 0; i < total; i++) {
    final progress = total <= 1 ? 0.0 : i / (total - 1);
    final v = List<double>.filled(cells, 3.90);
    if (failing != null) v[failing] = 3.90 - endSag * progress;
    out.add(
      reading(
        start.add(Duration(minutes: (i * days * 1440 / total).round())),
        v,
        current: current,
      ),
    );
  }
  return out;
}

void main() {
  const analysis = CellDriftAnalysis();

  group('spotting a cell on its way out', () {
    test('finds the one that is sinking away from the rest', () {
      // Cell 7 goes from level with the pack to 40 mV under, over six weeks.
      final readings = history(days: 42, perDay: 4, failing: 6, endSag: 0.040);

      final worst = analysis.worsening(readings);
      expect(worst, isNotNull);
      expect(worst!.index, 6);
      expect(worst.isWorsening, isTrue);
      // Roughly 40 mV over six weeks is about 30 mV a month.
      expect(worst.changeVoltsPerMonth, greaterThan(0.010));
    });

    test('a cell that has always been low is not a cell going bad', () {
      // Built that way. Flagging it would have the rider chasing a pack that
      // is doing exactly what it has always done.
      final start = DateTime.utc(2026, 1, 1);
      final readings = <Snapshot>[];
      for (var i = 0; i < 168; i++) {
        final v = List<double>.filled(20, 3.90);
        v[6] = 3.88;
        readings.add(reading(start.add(Duration(hours: i * 6)), v));
      }

      expect(analysis.worsening(readings), isNull);
      // It still shows up in the ranking, just not as worsening.
      final all = analysis.analyse(readings);
      expect(all.firstWhere((c) => c.index == 6).currentDeviationVolts,
          closeTo(0.019, 0.002));
    });

    test('a healthy pack flags nothing', () {
      expect(analysis.worsening(history(days: 42, perDay: 4)), isNull);
    });
  });

  group('refusing to guess', () {
    test('says nothing from a handful of readings', () {
      // Twenty readings spread over six weeks is a shape, not a trend. Once a
      // day for the same six weeks is enough, and the threshold sits between
      // the two rather than at a round number.
      final readings = history(days: 42, perDay: 1, failing: 6, endSag: 0.040)
          .take(20)
          .toList();
      expect(analysis.analyse(readings), isEmpty);
    });

    test('says nothing from a single afternoon', () {
      // A rate per month extrapolated from three hours is a number with a unit
      // and no meaning.
      final readings = history(days: 1, perDay: 200, failing: 6, endSag: 0.040);
      expect(analysis.analyse(readings), isEmpty);
    });

    test('ignores readings taken under load', () {
      // Under load the cell with the highest resistance sags most, which looks
      // identical to the cell with the least capacity and is a different fault
      // with a different fix.
      final readings =
          history(days: 42, perDay: 4, failing: 6, endSag: 0.040, current: -25);
      expect(analysis.analyse(readings), isEmpty);
    });

    test('survives a reading with no cells in it', () {
      final readings = history(days: 42, perDay: 4, failing: 6, endSag: 0.040)
        ..add(reading(DateTime.utc(2026, 2, 20), [3.9]));
      expect(() => analysis.analyse(readings), returnsNormally);
    });
  });

  group('the ranking', () {
    test('is worst first', () {
      final start = DateTime.utc(2026, 1, 1);
      final readings = <Snapshot>[];
      for (var i = 0; i < 168; i++) {
        final progress = i / 167;
        final v = List<double>.filled(20, 3.90);
        v[6] = 3.90 - 0.040 * progress; // the bad one
        v[3] = 3.90 - 0.010 * progress; // mildly drifting
        readings.add(reading(start.add(Duration(hours: i * 6)), v));
      }

      final all = analysis.analyse(readings);
      expect(all.first.index, 6);
      expect(all[1].index, 3);
    });
  });
}
