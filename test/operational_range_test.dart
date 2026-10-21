import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/metrics/pack_energy.dart';
import 'package:jk_bms/src/metrics/range_estimator.dart';
import 'package:jk_bms/src/metrics/range_outlook.dart';
import 'package:jk_bms/src/pack/chemistry.dart';
import 'package:jk_bms/src/protocol/jk_frame.dart';
import 'package:jk_bms/src/protocol/jk_parser.dart';
import 'package:jk_bms/src/protocol/protocol_variant.dart';

import 'fixtures/real_kevinjk_frames.dart';

void main() {
  final estimator = RangeEstimator(learnedWhPerKm: 20, learnedKm: 60);

  PackEnergy energy({
    double remainingAh = 40,
    double nominalAh = 40,
    double referenceAh = 40,
    double soc = 100,
    CellChemistry chemistry = CellChemistry.nmc,
    RestingCells? resting,
  }) => PackEnergy.operationalRemaining(
    remainingAh: remainingAh,
    nominalCapacityAh: nominalAh,
    referenceCapacityAh: referenceAh,
    soc: soc,
    cellCount: 20,
    chemistry: chemistry,
    cutoffVoltagePerCell: 2.8,
    liveAverageCellVoltage: 3.8,
    resting: resting,
  );

  RangeOutlook outlook(
    PackEnergy e,
    double capacity,
    CellChemistry chemistry,
  ) => RangeOutlook.from(
    estimator: estimator,
    usableWhNow: e.usableWh,
    fullCapacityAh: capacity,
    fullPackVoltage: PackEnergy.operationalFullPackVoltage(
      cellCount: 20,
      chemistry: chemistry,
    ),
    usableFraction: e.usableFraction ?? 1,
    fullNeedsChemistry: !chemistry.isKnown,
  );

  test('the BMS reference outranks a larger sales claim', () {
    final reference = RangeCapacityReference.best(
      configuredCapacityAh: 40,
      catalogueCapacityAh: 45,
    )!;
    final o = outlook(
      energy(referenceAh: reference.capacityAh),
      reference.capacityAh,
      CellChemistry.nmc,
    );
    expect(reference.source, RangeCapacitySource.bmsConfig);
    expect(reference.capacityAh, 40);
    expect(o.nowKm, closeTo(149.28, 1e-9));
    expect(o.fullKm, closeTo(o.nowKm!, 1e-9));
  });

  test('only a trusted measurement outranks the BMS reference', () {
    for (final measured in [38.0, 45.0]) {
      final reference = RangeCapacityReference.best(
        measuredCapacityAh: measured,
        configuredCapacityAh: 40,
        catalogueCapacityAh: 50,
      )!;
      final e = energy(referenceAh: reference.capacityAh);
      final o = outlook(e, reference.capacityAh, CellChemistry.nmc);
      expect(reference.source, RangeCapacitySource.measured);
      expect(reference.capacityAh, measured);
      expect(o.nowKm, closeTo(o.fullKm!, 1e-9));
      expect(o.fullKm, closeTo(measured * 3.732, 1e-9));
    }
  });

  test('catalogue is a fallback and invalid capacity sources are skipped', () {
    final reference = RangeCapacityReference.best(
      measuredCapacityAh: double.nan,
      configuredCapacityAh: double.infinity,
      catalogueCapacityAh: 45,
    )!;
    expect(reference.capacityAh, 45);
    expect(reference.source, RangeCapacitySource.catalogue);
    expect(
      RangeCapacityReference.best(
        measuredCapacityAh: 0,
        configuredCapacityAh: -1,
        catalogueCapacityAh: double.nan,
      ),
      isNull,
    );
  });

  test('a real 100-percent frame retains its missing 0.081 Ah', () {
    final s = const JkParser().parseCellInfo(
      JkFrame(
        bytes: kevinJkCellInfo.first,
        receivedAt: DateTime.utc(2026, 8, 29, 9, 28, 55),
      ),
      JkProtocolVariant.jk02_32s,
    );
    final e = energy(
      remainingAh: s.remainingCapacityAh,
      nominalAh: s.nominalCapacityAh,
      referenceAh: 40,
      soc: s.soc,
    );
    final o = outlook(e, 40, CellChemistry.nmc);
    expect(s.soc, 100);
    expect(s.remainingCapacityAh, closeTo(39.919, 1e-9));
    expect(o.nowKm, lessThan(o.fullKm!));
    expect(o.fullKm! - o.nowKm!, lessThan(0.5));
    expect(o.nowKm!.toStringAsFixed(0), o.fullKm!.toStringAsFixed(0));
  });

  test('a contradictory percentage never replaces the Ah counter', () {
    final reportedFull = energy(remainingAh: 20, soc: 100);
    final reportedEmpty = energy(remainingAh: 20, soc: 0);
    final matching = energy(remainingAh: 20, soc: 50);
    expect(reportedFull.usableWh, matching.usableWh);
    expect(reportedEmpty.usableWh, matching.usableWh);
    expect(
      reportedFull.usableWh,
      closeTo(20 * 20 * OcvCurve.nmc.meanVoltsBelow(50), 1e-9),
    );
    expect(outlook(reportedFull, 40, CellChemistry.nmc).nowKm, lessThan(75));
  });

  test('calibration leaves raw energy and the original reading untouched', () {
    final raw = PackEnergy.remaining(
      remainingAh: 20,
      soc: 50,
      cellCount: 20,
      chemistry: CellChemistry.nmc,
      cutoffVoltagePerCell: 2.8,
    );
    final calibrated = energy(remainingAh: 20, soc: 50, referenceAh: 38);
    final largerMeasurement = energy(remainingAh: 20, soc: 50, referenceAh: 45);
    expect(calibrated.usableWh, closeTo(raw.usableWh * 38 / 40, 1e-9));
    expect(largerMeasurement.usableWh, closeTo(raw.usableWh * 45 / 40, 1e-9));
    expect(
      raw.grossWh,
      closeTo(20 * 20 * OcvCurve.nmc.meanVoltsBelow(50), 1e-9),
    );
  });

  test('without a nominal capacity no percentage manufactures Ah', () {
    final e = energy(remainingAh: 20, nominalAh: 0, referenceAh: 40);
    final full = energy(remainingAh: 50, nominalAh: 0, referenceAh: 40);
    expect(e.grossWh, closeTo(20 * 20 * OcvCurve.nmc.meanVoltsBelow(50), 1e-9));
    expect(outlook(full, 40, CellChemistry.nmc).nowKm, closeTo(149.28, 1e-9));
  });

  test(
    'a broken over-full counter cannot exceed the selected full capacity',
    () {
      final o = outlook(energy(remainingAh: 50), 40, CellChemistry.nmc);
      expect(o.nowKm, closeTo(o.fullKm!, 1e-9));
    },
  );

  for (final chemistry in [CellChemistry.nmc, CellChemistry.lfp]) {
    test('$chemistry uses one curve for partial and full ranges and bands', () {
      final full = outlook(energy(chemistry: chemistry), 40, chemistry);
      final partial = outlook(
        energy(chemistry: chemistry, remainingAh: 20),
        40,
        chemistry,
      );
      expect(full.nowKm, closeTo(full.fullKm!, 1e-9));
      expect(full.nowBandKm!.$1, closeTo(full.fullBandKm!.$1, 1e-9));
      expect(full.nowBandKm!.$2, closeTo(full.fullBandKm!.$2, 1e-9));
      expect(partial.nowKm, lessThan(full.nowKm! / 2));
      expect(partial.fullKm, closeTo(full.fullKm!, 1e-9));
    });
  }

  test(
    'resting-cell derating shortens both predictions by the same factor',
    () {
      final e = energy(
        resting: RestingCells(
          minCellVoltage: 4.08,
          averageCellVoltage: 4.18,
          at: DateTime.utc(2026, 10, 21),
        ),
      );
      final o = outlook(e, 40, CellChemistry.nmc);
      expect(e.usableFraction, lessThan(1));
      expect(o.nowKm, closeTo(o.fullKm!, 1e-9));
      expect(o.nowKm, lessThan(149.28));
    },
  );

  test(
    'unknown chemistry retains the conservative current model, no full guess',
    () {
      final e = energy(chemistry: CellChemistry.unknown);
      final o = outlook(e, 40, CellChemistry.unknown);
      expect(e.meanCellVolts, closeTo(3.3, 1e-9));
      expect(o.nowKm, closeTo(132, 1e-9));
      expect(o.fullKm, isNull);
      expect(o.fullBandKm, isNull);
      expect(o.fullNeedsChemistry, isTrue);
    },
  );

  test('invalid counters and capacities cannot produce non-finite range', () {
    for (final invalid in [double.nan, double.infinity, -1.0, 0.0]) {
      expect(energy(remainingAh: invalid), same(PackEnergy.none));
      final e = energy(nominalAh: invalid, referenceAh: 40);
      expect(e.usableWh.isFinite, isTrue);
      expect(e.usableWh, closeTo(2985.6, 1e-9));
    }
    final o = RangeOutlook.from(
      estimator: estimator,
      usableWhNow: double.infinity,
      fullCapacityAh: double.nan,
      fullPackVoltage: 74.64,
    );
    expect(o.nowKm, isNull);
    expect(o.fullKm, isNull);
    for (final invalidFull in [
      (double.infinity, 74.64, 1.0),
      (40.0, double.nan, 1.0),
      (40.0, 74.64, double.infinity),
      (double.maxFinite, 74.64, 1.0),
    ]) {
      final invalid = RangeOutlook.from(
        estimator: estimator,
        usableWhNow: 1000,
        fullCapacityAh: invalidFull.$1,
        fullPackVoltage: invalidFull.$2,
        usableFraction: invalidFull.$3,
      );
      expect(invalid.nowKm, 50);
      expect(invalid.fullKm, isNull);
      expect(invalid.fullBandKm, isNull);
    }
    expect(
      energy(
        remainingAh: double.maxFinite,
        nominalAh: 0,
        referenceAh: double.nan,
      ),
      same(PackEnergy.none),
    );
  });
}
