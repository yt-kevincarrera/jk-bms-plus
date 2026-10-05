import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/metrics/cell_drift.dart';

/// One stored reading with a given set of cells.
Snapshot reading(
  DateTime at,
  List<double> cells, {
  double current = 0,
  double soc = 70,
}) =>
    Snapshot(
      id: 0,
      timestamp: at,
      tripId: null,
      deviceId: 'AA:BB',
      packVoltage: cells.reduce((a, b) => a + b),
      current: current,
      soc: soc,
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

  group('every cell is judged', () {
    /// Two cells moving at once, six weeks, four resting readings a day.
    List<Snapshot> twoCells() {
      final start = DateTime.utc(2026, 1, 1);
      final out = <Snapshot>[];
      for (var i = 0; i < 168; i++) {
        final p = i / 167;
        final v = List<double>.filled(20, 3.90);
        // Changes fastest, but stays inside a gap too small to matter.
        v[2] = 3.90 - 0.0095 * p;
        // Changes more slowly, from a gap that already matters.
        v[7] = 3.90 - 0.020 - 0.008 * p;
        out.add(reading(start.add(Duration(hours: i * 6)), v));
      }
      return out;
    }

    test('a fast mover with a small gap does not hide a cell really sinking',
        () {
      // The ranking's first entry used to be the only one asked. Cell 3
      // changes fastest and is not worsening, so the answer was "no cell is
      // drifting" while cell 8 sank.
      final worst = analysis.worsening(twoCells());
      expect(worst, isNotNull);
      expect(worst!.index, 7);
    });

    test('"the lowest" is the lowest cell, not the fastest-changing one', () {
      final all = analysis.analyse(twoCells());
      expect(CellDriftAnalysis.lowest(all)!.index, 7);
    });
  });

  group('readings that are not comparable', () {
    test('a cell low only at a different charge is not a trend', () {
      // A cell with less capacity sits further under the others near empty.
      // Six weeks of full-pack readings followed by six of nearly-empty ones
      // used to read as a cell sinking at 20 mV a month.
      final start = DateTime.utc(2026, 1, 1);
      final readings = <Snapshot>[];
      for (var i = 0; i < 168; i++) {
        final late = i >= 84;
        final v = List<double>.filled(20, 3.90);
        v[6] = late ? 3.87 : 3.90;
        readings.add(
          reading(start.add(Duration(hours: i * 6)), v, soc: late ? 25 : 90),
        );
      }
      expect(analysis.analyse(readings), isEmpty);
    });

    test('readings on too few days say nothing, however many there are', () {
      // Three days of five hundred readings is three days.
      final start = DateTime.utc(2026, 1, 1);
      final readings = <Snapshot>[
        for (final day in [0, 1, 20])
          for (var i = 0; i < 500; i++)
            reading(
              start.add(Duration(days: day, seconds: i * 60)),
              List<double>.filled(20, 3.90)..[6] = day == 20 ? 3.86 : 3.90,
            ),
      ];
      expect(analysis.analyse(readings), isEmpty);
    });

    test('the minute after a ride is not rest', () {
      // Under 1 A, but the cells have not recovered from the load yet.
      final start = DateTime.utc(2026, 1, 1);
      final readings = <Snapshot>[];
      for (var d = 0; d < 42; d++) {
        final day = start.add(Duration(days: d));
        readings.add(
          reading(day, List<double>.filled(20, 3.80), current: -20),
        );
        for (var s = 5; s < 50; s += 5) {
          readings.add(
            reading(
              day.add(Duration(seconds: s)),
              List<double>.filled(20, 3.90)..[6] = 3.90 - 0.001 * d,
              current: -0.4,
            ),
          );
        }
      }
      expect(analysis.analyse(readings), isEmpty);
    });
  });

  group('the cell lowest at rest', () {
    test('counts resting readings, not the one under load', () {
      final start = DateTime.utc(2026, 1, 1);
      final readings = <Snapshot>[
        for (var i = 0; i < 30; i++)
          reading(
            start.add(Duration(minutes: 10 * i)),
            List<double>.filled(20, 3.90)..[9] = 3.895,
          ),
        // The last reading, under load, where another cell sags lowest.
        reading(
          start.add(const Duration(hours: 6)),
          List<double>.filled(20, 3.70)..[3] = 3.60,
          current: -30,
        ),
      ];
      final low = analysis.mostOftenLowest(readings);
      expect(low, isNotNull);
      expect(low!.index, 9);
      expect(low.share, 1.0);
      expect(low.readings, 30);
    });

    test('says nothing with no resting reading', () {
      final readings = [
        reading(
          DateTime.utc(2026, 1, 1),
          List<double>.filled(20, 3.7),
          current: -20,
        ),
      ];
      expect(analysis.mostOftenLowest(readings), isNull);
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
