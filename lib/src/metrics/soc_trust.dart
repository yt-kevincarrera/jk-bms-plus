/// Whether the BMS's charge percentage can be taken at face value, and which
/// way it is wrong when it cannot.
///
/// State of charge is not measured. The BMS integrates amps over time against
/// a capacity somebody typed into it, so two things drift it: a counter
/// working from a stale zero, and a configured capacity that is not the one
/// the pack really has. Both are invisible in the number itself — it is a
/// percentage either way — and every figure built on it inherits the error.
///
/// What is measured is cell voltage. It is a poor fuel gauge in the middle,
/// where a flat-curve chemistry says almost nothing and load sags the reading,
/// and it is decisive at the two ends, which is exactly where the counter's
/// drift shows up: a pack claiming full with its cells well below where a
/// charge stops, or claiming empty with them well above where the BMS itself
/// calls empty.
///
/// So this checks the ends and stays quiet everywhere else.
library;

/// Which way the counter has come loose from the pack.
enum SocDrift {
  /// It agrees with the cells, or nothing measured is in a position to
  /// contradict it.
  none,

  /// Nearly full on the counter, with the cells well below where a charge
  /// ends. The percentage, and every minute and kilometre built on it, is
  /// ahead of the battery.
  aheadOfCells,

  /// Nearly empty on the counter, with the cells well above where the BMS
  /// itself calls empty. There is more battery here than the screen admits,
  /// and this is the direction that has a rider stop early.
  behindCells,
}

/// A per-cell voltage the counter can be checked against, and how much slack
/// that particular voltage has earned.
///
/// The slack is part of the anchor rather than a constant because the two
/// sources are not equally trustworthy. A BMS told what voltage means 100%
/// is answering the question directly. A protection threshold is answering a
/// different one and normally sits above where the charger actually stops,
/// so a genuinely full cell can rest well under it.
class SocAnchor {
  const SocAnchor(this.volts, this.slackVolts);

  /// Per-cell volts.
  final double volts;

  /// How far a cell may sit the wrong side of [volts] before the counter is
  /// called wrong rather than the cell called normal.
  final double slackVolts;
}

/// Checks the charge counter against what the cells are doing.
class SocTrust {
  const SocTrust({
    this.fullAbove = 95,
    this.emptyBelow = 5,
    this.fullAboveOnCurrentAlone = 97,
    this.taperCurrentCRate = 0.10,
    this.restingCurrentAmps = 0.5,
  });

  static const SocTrust defaults = SocTrust();

  /// Charge percentage above which a near-full reading gets checked.
  final double fullAbove;

  /// And below which a near-empty one does.
  final double emptyBelow;

  /// The bar for the current-only fallback, higher because it is the weaker
  /// test: a flat-curve chemistry can honestly still be taking most of its
  /// charge current well into the nineties.
  final double fullAboveOnCurrentAlone;

  /// Fraction of C still going in that makes a near-full reading impossible
  /// to believe when there is no anchor to compare voltages against.
  ///
  /// Past the knee a charger holds voltage and the current decays away;
  /// chargers call a charge finished somewhere around a twentieth of C. A
  /// pack still swallowing a tenth of C is in constant current, and a pack in
  /// constant current is not at 99%.
  final double taperCurrentCRate;

  /// Above this many amps either way, the pack is doing something rather than
  /// sitting still.
  final double restingCurrentAmps;

  /// Where a charge ends, per cell.
  ///
  /// [soc100Volts] is the BMS's own answer and wins when it has one. Firmware
  /// that leaves it at zero has not been told, and then the per-cell
  /// overvoltage limit stands in — a worse anchor, given more slack to match.
  static SocAnchor? fullAnchor({double? soc100Volts, double? cellOvp}) {
    if (soc100Volts != null && soc100Volts > 0) {
      return SocAnchor(soc100Volts, 0.05);
    }
    if (cellOvp != null && cellOvp > 0) return SocAnchor(cellOvp, 0.12);
    return null;
  }

  /// Where the BMS calls the pack empty, per cell.
  ///
  /// No fallback on purpose. The undervoltage limit is a protection floor set
  /// well below the useful one, and how far below is a fact about the
  /// chemistry rather than about this pack — which is the sort of thing the
  /// app asks about rather than assumes. Unset means unchecked.
  static SocAnchor? emptyAnchor({double? soc0Volts}) =>
      soc0Volts != null && soc0Volts > 0 ? SocAnchor(soc0Volts, 0.10) : null;

  /// [current] is positive charging, in the app's convention.
  ///
  /// [capacityAh] is what the BMS is configured to hold, used only by the
  /// current-only fallback. The cell voltages may be null when no frame has
  /// carried them.
  SocDrift check({
    required double soc,
    required double current,
    required double capacityAh,
    double? highestCellVolts,
    double? lowestCellVolts,
    SocAnchor? full,
    SocAnchor? empty,
  }) {
    // --- The top, which only a charge can expose ---
    //
    // A pack that is not being charged sits below its charge voltage as a
    // matter of course, so checking there would fire on every healthy
    // battery that had been left alone for an hour.
    if (current > restingCurrentAmps && soc >= fullAbove) {
      if (full != null && highestCellVolts != null) {
        // The cells settle it in both directions, so nothing else gets a
        // vote: one at the anchor is genuinely at the end of a charge
        // whatever the current is doing, and one well below it is not.
        return full.volts - highestCellVolts > full.slackVolts
            ? SocDrift.aheadOfCells
            : SocDrift.none;
      }
      // No anchor. The current is left, and it needs nothing configured to
      // be believed because it is measured.
      if (soc >= fullAboveOnCurrentAlone &&
          capacityAh > 0 &&
          current > taperCurrentCRate * capacityAh) {
        return SocDrift.aheadOfCells;
      }
      return SocDrift.none;
    }

    // --- The bottom, which a charge would hide ---
    //
    // Under load the lowest cell sags below where it would rest, which can
    // only make this test quieter than it should be. That is the right way
    // for it to fail: the claim being made is that there is more battery
    // here than the counter says.
    if (current < restingCurrentAmps &&
        soc <= emptyBelow &&
        empty != null &&
        lowestCellVolts != null &&
        lowestCellVolts - empty.volts > empty.slackVolts) {
      return SocDrift.behindCells;
    }

    return SocDrift.none;
  }
}
