import '../pack/chemistry.dart';

/// A reading taken with essentially no current flowing, which is the only
/// kind whose cell voltages say how much charge the cells hold.
///
/// Under load every cell sags by its own resistance times the current, and on
/// a charger every cell is pushed up the same way. Either one moves the
/// spread between cells by more than the imbalance being measured.
class RestingCells {
  const RestingCells({
    required this.minCellVoltage,
    required this.averageCellVoltage,
    required this.at,
  });

  final double minCellVoltage;
  final double averageCellVoltage;
  final DateTime at;
}

/// Energy left in the pack, and how much of it the weakest cell lets out.
///
/// One definition, used by every screen that quotes watt-hours or a range: the
/// health tab, the live tab, the saved-pack screen, the home-screen widget and
/// the range stored with a ride. They used to share a formula that multiplied
/// remaining amp-hours by the pack voltage of the moment, which is the voltage
/// the *next* amp-hour comes out at and not the ones after it. At the top of
/// an NMC pack that is some 12% high, higher still while charging, and it
/// swung with the throttle.
///
/// Here the amp-hours are turned into watt-hours at the mean voltage over the
/// rest of the discharge, read off the chemistry's typical curve from the
/// BMS's own charge percentage. The percentage rather than a voltage, because
/// the voltage is exactly the thing load and charger move; the percentage is
/// the BMS's counter, and it is what the remaining amp-hours come from anyway.
class PackEnergy {
  const PackEnergy._({
    required this.grossWh,
    required this.meanCellVolts,
    required this.usableFraction,
    required this.restingAt,
  });

  static const PackEnergy none = PackEnergy._(
    grossWh: 0,
    meanCellVolts: 0,
    usableFraction: null,
    restingAt: null,
  );

  /// Remaining amp-hours times the mean voltage they will come out at.
  final double grossWh;

  /// That mean voltage, per cell.
  final double meanCellVolts;

  /// Share of [grossWh] the weakest cell lets out before it reaches cutoff,
  /// worked out from a resting reading. Null when no resting reading could
  /// say: none has been seen, or the cells sit on the flat part of an LFP
  /// curve where a resting voltage does not locate the charge.
  final double? usableFraction;

  /// When the resting reading behind [usableFraction] was taken.
  final DateTime? restingAt;

  /// What the pack can actually deliver. Without a resting reading to judge
  /// the imbalance by it is [grossWh] undiscounted: a figure from a loaded
  /// reading would include sag and read as imbalance that is not there.
  double get usableWh => grossWh * (usableFraction ?? 1);

  /// Share of [grossWh] stranded in the stronger cells, or null when not
  /// known.
  double? get strandedFraction {
    final f = usableFraction;
    return f == null ? null : 1 - f;
  }

  /// Energy left, from the BMS's remaining amp-hours and charge percentage.
  ///
  /// [liveAverageCellVoltage] is only used when the chemistry is unknown: see
  /// [meanCellVoltsRemaining].
  static PackEnergy remaining({
    required double remainingAh,
    required double soc,
    required int cellCount,
    required CellChemistry chemistry,
    required double cutoffVoltagePerCell,
    RestingCells? resting,
    double? liveAverageCellVoltage,
  }) {
    if (cellCount <= 0 || remainingAh <= 0) return none;
    final mean = meanCellVoltsRemaining(
      soc: soc,
      chemistry: chemistry,
      cutoffVoltagePerCell: cutoffVoltagePerCell,
      averageCellVoltage:
          resting?.averageCellVoltage ?? liveAverageCellVoltage,
    );
    final fraction = resting == null
        ? null
        : usableFractionAtRest(
            minCellVoltage: resting.minCellVoltage,
            averageCellVoltage: resting.averageCellVoltage,
            chemistry: chemistry,
            cutoffVoltagePerCell: cutoffVoltagePerCell,
          );
    return PackEnergy._(
      grossWh: remainingAh * mean * cellCount,
      meanCellVolts: mean,
      usableFraction: fraction,
      restingAt: fraction == null ? null : resting?.at,
    );
  }

  /// Mean volts per cell over the discharge still to come.
  ///
  /// Known chemistry: the curve's mean from [soc] down to empty.
  ///
  /// Unknown chemistry: the two curves disagree by half a volt, so neither is
  /// used. The mean is somewhere between the cells' present resting voltage
  /// and the cutoff, and on both curves it sits above the midpoint of the two,
  /// so the midpoint is quoted: never more than the pack could hold. The cell
  /// voltage is capped at 3.8 V, above which the chemistry would not be
  /// unknown (nothing past it is LFP).
  static double meanCellVoltsRemaining({
    required double soc,
    required CellChemistry chemistry,
    required double cutoffVoltagePerCell,
    double? averageCellVoltage,
  }) {
    final curve = OcvCurve.of(chemistry);
    if (curve != null) return curve.meanVoltsBelow(soc);
    final top = (averageCellVoltage ?? cutoffVoltagePerCell).clamp(
      cutoffVoltagePerCell,
      _unknownChemistryCeiling,
    );
    return (top + cutoffVoltagePerCell) / 2;
  }

  static const double _unknownChemistryCeiling = 3.8;

  /// Mean volts per cell over a whole discharge, full to empty: what turns a
  /// full pack's capacity into watt-hours.
  ///
  /// About 3.73 V for NMC and 3.25 V for LFP. It used to be 3.7 V for every
  /// pack, which overstated a full LFP pack by 14%. With the chemistry
  /// unknown the LFP figure, the lower of the two, so a full-pack range is
  /// never quoted off energy the cells might not have.
  static double meanCellVoltsFull(CellChemistry chemistry) =>
      (OcvCurve.of(chemistry) ?? OcvCurve.lfp).meanVoltsBelow(100);

  /// Pack voltage for turning a full pack's capacity into watt-hours.
  static double? fullPackVoltage({
    required int cellCount,
    required CellChemistry chemistry,
  }) => cellCount <= 0 ? null : cellCount * meanCellVoltsFull(chemistry);

  /// How much of the average cell's remaining energy the weakest cell has,
  /// from a resting reading.
  ///
  /// The pack stops when the lowest cell reaches cutoff. What the others still
  /// hold then is stranded. The old figure was the ratio of the two cells'
  /// voltage headroom above cutoff, which treats volts as charge: on NMC a
  /// cell 50 mV low near the top is about 6% of charge behind, and the same
  /// 50 mV near the bottom knee is under 2%. Here both voltages go through the
  /// chemistry's curve to a charge level, and the ratio is of the energy
  /// between cutoff and each.
  ///
  /// Null when the curve cannot resolve either voltage (the LFP plateau).
  /// With the chemistry unknown there is no curve, and the headroom ratio is
  /// what is left; from a resting reading it is at least free of sag.
  static double? usableFractionAtRest({
    required double minCellVoltage,
    required double averageCellVoltage,
    required CellChemistry chemistry,
    required double cutoffVoltagePerCell,
  }) {
    if (averageCellVoltage <= cutoffVoltagePerCell ||
        minCellVoltage <= cutoffVoltagePerCell) {
      return 0;
    }
    final curve = OcvCurve.of(chemistry);
    if (curve == null) {
      final headroomAverage = averageCellVoltage - cutoffVoltagePerCell;
      final headroomWeakest = minCellVoltage - cutoffVoltagePerCell;
      return (headroomWeakest / headroomAverage).clamp(0.0, 1.0);
    }
    if (!curve.resolves(minCellVoltage) ||
        !curve.resolves(averageCellVoltage)) {
      return null;
    }
    final floor = curve.areaTo(curve.socAt(cutoffVoltagePerCell));
    final weakest = curve.areaTo(curve.socAt(minCellVoltage)) - floor;
    final average = curve.areaTo(curve.socAt(averageCellVoltage)) - floor;
    if (average <= 0) return 0;
    return (weakest / average).clamp(0.0, 1.0);
  }

  /// The chemistry to price energy by: what the rider declared, else what the
  /// pack gives away about itself, else unknown.
  static CellChemistry chemistryFor({
    String? declared,
    double? cellOvp,
    double? highestCellVolts,
  }) {
    final said = CellChemistry.byName(declared);
    if (said.isKnown) return said;
    return ChemistryHint.from(
      cellOvp: cellOvp,
      highestCellVolts: highestCellVolts,
    ).chemistry;
  }
}
