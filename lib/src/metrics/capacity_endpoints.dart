import 'dart:math' as math;

import '../data/database.dart';
import '../model/bms_warning.dart';
import '../pack/chemistry.dart';

/// What closed a capacity measurement, stored by name on the row.
///
/// Recorded because it decides what the number is worth. A run closed by the
/// cells reaching the cutoff measured the pack; a run closed by anything
/// else measured a slice of it.
enum CapacityEndReason {
  /// The lowest cell reached the cutoff, within a small margin.
  cellCutoff,

  /// The BMS itself cut: its undervoltage warning, or the discharge MOSFET
  /// opening with the lowest cell near the cutoff.
  bmsCutoff,

  /// Finished by hand before the cutoff. A partial: kept, shown as one, and
  /// never extrapolated into a capacity.
  stoppedEarly,

  /// Recorded before the app stored what closed a run. Those runs opened at
  /// 97 % on the BMS's percentage and closed at 3 %, and the percentage is
  /// remaining amp-hours over the configured capacity, so what they counted
  /// was about 0.94 of the configured capacity by construction. Kept in the
  /// history, not believed.
  legacy;

  static CapacityEndReason? byName(String? name) {
    for (final r in values) {
      if (r.name == name) return r;
    }
    return null;
  }

  /// Whether the run went all the way from full to the cutoff.
  bool get isFullDischarge =>
      this == CapacityEndReason.cellCutoff ||
      this == CapacityEndReason.bmsCutoff;
}

/// Where a capacity measurement starts and stops, from the cells.
///
/// Both ends used to be the BMS's percentage: full at 97 %, empty at 3 %. The
/// percentage is remaining amp-hours over the capacity somebody typed into
/// the BMS, and the app integrates the same current the BMS does, so 97 to 3
/// handed back 0.94 of the configured figure whatever the cells held. It
/// could never find a pack bigger than its setting, and would have found a
/// worn one exactly as big.
///
/// The cells do not know what anybody typed. Full is the top cell at the
/// chemistry's full mark with the charge current tapered off (or gone);
/// empty is the lowest cell at the cutoff, or the BMS cutting. The
/// percentage is left only as the opening condition for a pack that reports
/// no cell voltages at all.
class CapacityEndpoints {
  const CapacityEndpoints({
    required this.fullCellVolts,
    required this.cutoffCellVolts,
    this.taperAmps = 2.0,
    this.fullSoc = 97,
    this.cutoffMargin = 0.05,
    this.mosfetCutoffMargin = 0.20,
  });

  /// Built from what the service knows about the pack.
  ///
  /// [capacityAh] only sets where the charge current counts as tapered:
  /// C/20, with half an amp as the floor so a small pack's tail still
  /// qualifies. Two amps when nothing is known.
  factory CapacityEndpoints.forPack({
    required CellChemistry chemistry,
    required double cutoffVoltagePerCell,
    double? requestChargeVolts,
    double? capacityAh,
  }) => CapacityEndpoints(
    fullCellVolts: ChemistryLimits.fullCellVoltsFor(
      chemistry,
      requestChargeVolts: requestChargeVolts,
    ),
    cutoffCellVolts: cutoffVoltagePerCell,
    taperAmps: taperAmpsFor(capacityAh),
  );

  /// C/20, the usual "the charger has let go" current, floored at half an
  /// amp. Shared with the charge-complete alert so both mean the same thing
  /// by a tapered charge.
  static double taperAmpsFor(double? capacityAh) {
    final c = capacityAh;
    if (c == null || c <= 0) return 2.0;
    return math.max(0.5, c / 20);
  }

  /// The top cell at or above which the pack is full. Null when neither the
  /// chemistry nor the BMS says where full is, and then no run can open on a
  /// pack with cell voltages: better no measurement than one opened on a
  /// guess.
  final double? fullCellVolts;

  /// Where the BMS cuts a cell, stated or assumed for the chemistry.
  final double cutoffCellVolts;

  /// Charging current at or below which the charge counts as tapered.
  final double taperAmps;

  /// Only for a pack with no cell voltages.
  final double fullSoc;

  /// How close to the cutoff the lowest cell has to be. Under load is fine:
  /// the BMS cuts on the loaded voltage too.
  final double cutoffMargin;

  /// With the discharge MOSFET open, how close the lowest cell has to be for
  /// the opening to count as the cutoff. Wider, because a cell rebounds the
  /// moment the load goes. An over-current trip opens the same MOSFET on a
  /// full pack, and that is not the pack being empty.
  final double mosfetCutoffMargin;

  /// Whether a reading shows the pack full.
  ///
  /// [topCell] of zero means no cell voltages were reported.
  bool isFull({
    required double topCell,
    required double current,
    required double soc,
  }) {
    // Still pushing in bulk is not full, even with a cell up at the mark:
    // under charge current a cell reads higher than it rests.
    if (current > taperAmps) return false;
    if (topCell <= 0) return soc >= fullSoc;
    final mark = fullCellVolts;
    return mark != null && topCell >= mark;
  }

  /// What, if anything, in this reading means the pack has reached empty.
  ///
  /// [dischargeMosfetOn] is null where it is not known, which is every stored
  /// reading: the history keeps the warnings but not the switches.
  CapacityEndReason? emptyReason({
    required double minCell,
    required int warningsMask,
    bool? dischargeMosfetOn,
  }) {
    final active = BmsWarnings.fromBitmask(warningsMask).active;
    if (active.contains(BmsWarning.cellUndervoltage) ||
        active.contains(BmsWarning.packUndervoltage)) {
      return CapacityEndReason.bmsCutoff;
    }
    if (minCell <= 0) return null;
    if (minCell <= cutoffCellVolts + cutoffMargin) {
      return CapacityEndReason.cellCutoff;
    }
    if (dischargeMosfetOn == false &&
        minCell <= cutoffCellVolts + mosfetCutoffMargin) {
      return CapacityEndReason.bmsCutoff;
    }
    return null;
  }
}

/// Which stored capacity tests are measurements of the pack.
///
/// One predicate, used by everything that turns tests into a capacity: the
/// full-pack range, the wear figures, the trend chart, the comparison between
/// packs. They used to disagree, so a test with twenty minutes missing was
/// thrown out of the range and kept as the baseline of the wear figure.
extension CapacityTestTrust on CapacityTest {
  /// More than this unobserved and the count is too low to believe.
  static const int maxGapSeconds = 120;

  CapacityEndReason? get endReasonValue => CapacityEndReason.byName(endReason);

  /// Finished, from full all the way to the cutoff, watched the whole way,
  /// with no charge in the middle.
  bool get isTrustworthy =>
      completed &&
      measuredAh > 0 &&
      gapSeconds <= maxGapSeconds &&
      !chargedDuringRun &&
      (endReasonValue?.isFullDischarge ?? false);
}
