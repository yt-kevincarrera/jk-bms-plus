import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/metrics/capacity_endpoints.dart';
import 'package:jk_bms/src/pack/chemistry.dart';

void main() {
  group('where full is', () {
    test('the chemistry sets it', () {
      expect(ChemistryLimits.fullCellVoltsFor(CellChemistry.nmc), 4.15);
      expect(ChemistryLimits.fullCellVoltsFor(CellChemistry.lfp), 3.45);
    });

    test("the real pack's request voltage leaves it where it is", () {
      // KevinJK's settings frame asks for 4.20 V a cell: 30 mV under that is
      // above the chemistry mark, and the mark is never raised.
      expect(
        ChemistryLimits.fullCellVoltsFor(
          CellChemistry.nmc,
          requestChargeVolts: 4.20,
        ),
        4.15,
      );
    });

    test('a BMS that stops short lowers it, a little', () {
      expect(
        ChemistryLimits.fullCellVoltsFor(
          CellChemistry.nmc,
          requestChargeVolts: 4.10,
        ),
        closeTo(4.07, 1e-9),
      );
      // A storage setting is not where this pack is full.
      expect(
        ChemistryLimits.fullCellVoltsFor(
          CellChemistry.nmc,
          requestChargeVolts: 3.85,
        ),
        4.15,
      );
    });

    test('unknown chemistry: the request alone, or nothing', () {
      expect(
        ChemistryLimits.fullCellVoltsFor(
          CellChemistry.unknown,
          requestChargeVolts: 3.60,
        ),
        closeTo(3.57, 1e-9),
      );
      expect(ChemistryLimits.fullCellVoltsFor(CellChemistry.unknown), isNull);
    });
  });

  group('the endpoints', () {
    const e = CapacityEndpoints(fullCellVolts: 4.15, cutoffCellVolts: 3.0);

    test('a tapered charge is C/20, with a floor', () {
      expect(CapacityEndpoints.taperAmpsFor(45), 2.25);
      expect(CapacityEndpoints.taperAmpsFor(6), 0.5);
      expect(CapacityEndpoints.taperAmpsFor(null), 2.0);
    });

    test('full is the cells, not the percentage', () {
      expect(e.isFull(topCell: 4.16, current: 0.8, soc: 81), isTrue);
      expect(e.isFull(topCell: 3.95, current: 0, soc: 100), isFalse);
      // Still charging in bulk: the cell reads high under the current.
      expect(e.isFull(topCell: 4.17, current: 9, soc: 95), isFalse);
      // No cell voltages at all is the one case the percentage opens on.
      expect(e.isFull(topCell: 0, current: 0, soc: 98), isTrue);
    });

    test('empty is the lowest cell at the cutoff, or the BMS cutting', () {
      expect(
        e.emptyReason(minCell: 3.04, warningsMask: 0),
        CapacityEndReason.cellCutoff,
      );
      expect(e.emptyReason(minCell: 3.30, warningsMask: 0), isNull);
      expect(
        e.emptyReason(minCell: 3.30, warningsMask: 1 << 12),
        CapacityEndReason.bmsCutoff,
      );
      expect(
        e.emptyReason(minCell: 3.15, warningsMask: 0, dischargeMosfetOn: false),
        CapacityEndReason.bmsCutoff,
      );
      // A MOSFET opening on a charged pack is an over-current trip.
      expect(
        e.emptyReason(minCell: 3.9, warningsMask: 0, dischargeMosfetOn: false),
        isNull,
      );
    });
  });
}
