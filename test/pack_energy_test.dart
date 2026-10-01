import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/metrics/pack_energy.dart';
import 'package:jk_bms/src/metrics/snapshot_history.dart';
import 'package:jk_bms/src/pack/chemistry.dart';

import 'fixtures/snapshot_builder.dart';

/// "Wh restantes" on the health tab read too big, and it did: remaining
/// amp-hours times the pack voltage of the moment. These pin the figure that
/// replaced it, on the owner's own pack where it matters (20S NMC, 40 Ah
/// configured), and on LFP where the old fixed 3.7 V a cell was worst.
void main() {
  group('the typical curves', () {
    test('run from the cutoff to full and invert cleanly', () {
      for (final curve in [OcvCurve.nmc, OcvCurve.lfp]) {
        expect(curve.voltsAt(0), curve.volts.first);
        expect(curve.voltsAt(100), curve.volts.last);
        for (final soc in [5.0, 23.0, 50.0, 77.0, 95.0]) {
          expect(curve.socAt(curve.voltsAt(soc)), closeTo(soc, 1e-9));
        }
      }
      expect(OcvCurve.of(CellChemistry.unknown), isNull);
    });

    test('mean over a whole discharge is about 3.73 V NMC and 3.25 V LFP', () {
      expect(OcvCurve.nmc.meanVoltsBelow(100), closeTo(3.73, 0.01));
      expect(OcvCurve.lfp.meanVoltsBelow(100), closeTo(3.25, 0.01));
      // At empty the mean is the cutoff itself.
      expect(OcvCurve.nmc.meanVoltsBelow(0), 3.0);
    });

    test('the LFP plateau does not resolve a charge level, NMC does', () {
      expect(OcvCurve.lfp.resolves(3.285), isFalse);
      expect(OcvCurve.lfp.resolves(3.18), isTrue);
      for (final v in [3.3, 3.6, 3.75, 3.9, 4.1]) {
        expect(OcvCurve.nmc.resolves(v), isTrue, reason: '$v V');
      }
    });
  });

  group('energy left', () {
    PackEnergy nmcAt(double soc, {double ah = 40}) => PackEnergy.remaining(
      remainingAh: ah,
      soc: soc,
      cellCount: 20,
      chemistry: CellChemistry.nmc,
      cutoffVoltagePerCell: 3.0,
    );

    test('a full 20S 40 Ah NMC pack holds about 3 kWh, not 3.3', () {
      // The old figure: 40 Ah times 83.6 V at the top, 3344 Wh.
      final full = nmcAt(100);
      expect(full.grossWh, inInclusiveRange(2900, 3000));
      expect(full.grossWh, lessThan(40 * 83.6 * 0.92));
    });

    test('the voltage of the moment does not move it', () {
      // A charger holds the cells at 4.2; the throttle drags them to 3.7.
      // Neither changes how much energy the amp-hours left will deliver.
      PackEnergy withLive(double cell) => PackEnergy.remaining(
        remainingAh: 32,
        soc: 80,
        cellCount: 20,
        chemistry: CellChemistry.nmc,
        cutoffVoltagePerCell: 3.0,
        liveAverageCellVoltage: cell,
      );
      expect(withLive(4.20).grossWh, withLive(3.70).grossWh);
      expect(withLive(4.20).grossWh, closeTo(32 * 20 * 3.62, 32 * 20 * 0.05));
    });

    test('an amp-hour near the bottom is worth less than one near the top', () {
      final perAhLow = nmcAt(20, ah: 8).grossWh / 8;
      final perAhHigh = nmcAt(90, ah: 36).grossWh / 36;
      expect(perAhLow, lessThan(perAhHigh));
    });

    test('a full LFP pack is priced at about 3.25 V a cell, not 3.7', () {
      final volts = PackEnergy.fullPackVoltage(
        cellCount: 16,
        chemistry: CellChemistry.lfp,
      )!;
      expect(volts / 16, closeTo(3.25, 0.01));
      final nmc = PackEnergy.fullPackVoltage(
        cellCount: 20,
        chemistry: CellChemistry.nmc,
      )!;
      expect(nmc / 20, closeTo(3.73, 0.01));
    });

    test('an unknown chemistry is never priced above either curve', () {
      for (final soc in [20.0, 50.0, 80.0]) {
        for (final curve in [OcvCurve.nmc, OcvCurve.lfp]) {
          final rest = curve.voltsAt(soc);
          final unknown = PackEnergy.meanCellVoltsRemaining(
            soc: soc,
            chemistry: CellChemistry.unknown,
            cutoffVoltagePerCell: curve.volts.first,
            averageCellVoltage: rest,
          );
          expect(unknown, lessThanOrEqualTo(curve.meanVoltsBelow(soc)));
        }
      }
      // And a full pack of unknown cells is priced as the lower of the two.
      expect(
        PackEnergy.meanCellVoltsFull(CellChemistry.unknown),
        PackEnergy.meanCellVoltsFull(CellChemistry.lfp),
      );
    });

    test('without a resting reading the imbalance is not guessed', () {
      final e = nmcAt(60);
      expect(e.usableFraction, isNull);
      expect(e.strandedFraction, isNull);
      expect(e.usableWh, e.grossWh);
    });
  });

  group('what the weakest cell strands, from a resting reading', () {
    test('a balanced pack strands nothing, a cell at cutoff strands it all', () {
      expect(
        PackEnergy.usableFractionAtRest(
          minCellVoltage: 3.90,
          averageCellVoltage: 3.90,
          chemistry: CellChemistry.nmc,
          cutoffVoltagePerCell: 3.0,
        ),
        closeTo(1, 1e-9),
      );
      expect(
        PackEnergy.usableFractionAtRest(
          minCellVoltage: 3.0,
          averageCellVoltage: 3.6,
          chemistry: CellChemistry.nmc,
          cutoffVoltagePerCell: 3.0,
        ),
        0,
      );
    });

    test('goes by charge, not by volts', () {
      // The same 50 mV low. Near the top of NMC it is about five points of
      // charge out of 84 left, some 7%. Near the bottom knee it is five
      // points out of fifteen: a third of what is left. The old headroom
      // ratio, 0.45 V against 0.50 V, called that 10%.
      double stranded(double avg) =>
          1 -
          PackEnergy.usableFractionAtRest(
            minCellVoltage: avg - 0.05,
            averageCellVoltage: avg,
            chemistry: CellChemistry.nmc,
            cutoffVoltagePerCell: 3.0,
          )!;
      expect(stranded(4.00), closeTo(0.07, 0.02));
      expect(stranded(3.50), closeTo(0.35, 0.03));
      expect(stranded(3.80), lessThan(stranded(3.50)));
    });

    test('on the LFP plateau it says nothing rather than something huge', () {
      // 20 mV apart at 3.28 would read as twenty points of charge.
      expect(
        PackEnergy.usableFractionAtRest(
          minCellVoltage: 3.27,
          averageCellVoltage: 3.29,
          chemistry: CellChemistry.lfp,
          cutoffVoltagePerCell: 2.8,
        ),
        isNull,
      );
    });

    test('with no chemistry it falls back to the headroom ratio', () {
      expect(
        PackEnergy.usableFractionAtRest(
          minCellVoltage: 3.60,
          averageCellVoltage: 3.90,
          chemistry: CellChemistry.unknown,
          cutoffVoltagePerCell: 3.0,
        ),
        closeTo(2 / 3, 1e-9),
      );
    });

    test('carries the time of the resting reading', () {
      final at = DateTime.utc(2026, 9, 1, 10);
      final e = PackEnergy.remaining(
        remainingAh: 20,
        soc: 50,
        cellCount: 20,
        chemistry: CellChemistry.nmc,
        cutoffVoltagePerCell: 3.0,
        resting: RestingCells(
          minCellVoltage: 3.70,
          averageCellVoltage: 3.73,
          at: at,
        ),
      );
      expect(e.restingAt, at);
      expect(e.strandedFraction, greaterThan(0));
      expect(e.usableWh, lessThan(e.grossWh));
    });
  });

  test('the declared chemistry wins, then the settings, then the cells', () {
    expect(
      PackEnergy.chemistryFor(declared: 'lfp', highestCellVolts: 4.1),
      CellChemistry.lfp,
    );
    expect(PackEnergy.chemistryFor(cellOvp: 4.2), CellChemistry.nmc);
    expect(PackEnergy.chemistryFor(highestCellVolts: 4.05), CellChemistry.nmc);
    expect(PackEnergy.chemistryFor(highestCellVolts: 3.5), CellChemistry.unknown);
  });

  group('the readings history keeps what a connection needs', () {
    final t0 = DateTime.utc(2026, 9, 1, 10);

    test('a charger tapering off is not rest, nor is a ride', () {
      final h = SnapshotHistory()
        ..add(buildSnapshot(timestamp: t0, current: 0))
        ..add(
          buildSnapshot(
            timestamp: t0.add(const Duration(seconds: 1)),
            current: 0.6,
          ),
        )
        ..add(
          buildSnapshot(
            timestamp: t0.add(const Duration(seconds: 2)),
            current: -12,
          ),
        );
      expect(h.latestResting!.timestamp, t0);
      // The lights alone are rest.
      h.add(
        buildSnapshot(
          timestamp: t0.add(const Duration(seconds: 3)),
          current: -0.44,
        ),
      );
      expect(h.latestResting!.current, -0.44);
    });

    test('sag is only quoted against a recent resting reading', () {
      final h = SnapshotHistory()
        ..add(buildSnapshot(timestamp: t0, current: 0, soc: 80))
        ..add(
          buildSnapshot(
            timestamp: t0.add(const Duration(seconds: 20)),
            current: -30,
            soc: 80,
            cells: List.filled(20, 3.80),
          ),
        );
      expect(h.sagVolts, closeTo(2.0, 1e-6));

      // Twenty minutes of riding later the resting reading describes a
      // different pack: the drop since is charge used, not sag.
      h.add(
        buildSnapshot(
          timestamp: t0.add(const Duration(minutes: 20)),
          current: -30,
          soc: 62,
          cells: List.filled(20, 3.70),
        ),
      );
      expect(h.sagVolts, isNull);
    });

    test('session energy keeps out and in apart, past the buffer', () {
      // A small buffer, so the readings run off the end of it.
      final h = SnapshotHistory(capacity: 10);
      var at = t0;
      // 60 s out at about 78 V and 20 A, then 60 s in at 10 A.
      for (var s = 0; s <= 60; s++) {
        h.add(buildSnapshot(timestamp: at, current: -20));
        at = at.add(const Duration(seconds: 1));
      }
      for (var s = 0; s <= 60; s++) {
        h.add(buildSnapshot(timestamp: at, current: 10));
        at = at.add(const Duration(seconds: 1));
      }
      expect(h.length, 10);
      expect(h.sessionOutWh, closeTo(78 * 20 / 60, 0.5));
      expect(h.sessionInWh, closeTo(78 * 10 / 60, 0.5));

      h.clear();
      expect(h.sessionOutWh, 0);
      expect(h.latestResting, isNull);
    });
  });
}
