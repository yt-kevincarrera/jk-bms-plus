import 'dart:math' as math;

import '../model/bms_snapshot.dart';
import '../model/jk_settings.dart';

/// The numbers a battery vendor would rather you did not work out.
///
/// None of this needs new hardware or new protocol work: it is all derived by
/// cross-checking figures the BMS already hands over against each other. That
/// is precisely why it is not in the official app.
class PackHealthReport {
  PackHealthReport._({
    required this.impliedCapacityAh,
    required this.configuredCapacityAh,
    required this.catalogueCapacityAh,
    required this.shortOfAdvertisedFraction,
    required this.equivalentFullCycles,
    required this.reportedCycles,
    required this.cycleInflation,
    required this.imbalanceLossAh,
    required this.imbalanceLossFraction,
    required this.weakestCellIndex,
    required this.reportedSoh,
    required this.capacityMeaningful,
  });

  /// Builds a report from one snapshot plus, when available, the settings frame.
  ///
  /// [catalogueCapacityAh] is what the pack was sold as. It is not something the
  /// BMS knows, so it has to be told.
  factory PackHealthReport.from({
    required BmsSnapshot snapshot,
    JkSettings? settings,
    required double? catalogueCapacityAh,
    double cutoffVoltagePerCell = 3.0,
  }) {
    final configured = settings?.nominalCapacityAh ?? snapshot.nominalCapacityAh;

    // Remaining divided by reported charge reads back the capacity the BMS is
    // *configured* with, and only that: it computes remaining amp-hours as
    // charge times configured capacity, so the division cancels. Measured on a
    // real pack at every charge level from 53% to 70% it gave 40.0 Ah every
    // time, varying only with the rounding of a whole-number percentage.
    //
    // Which is why what comes out of it below is compared against the advert
    // and nothing else. It cannot be wear: on a pack whose catalogue figure was
    // itself read from the BMS this is 40 over 40, a guaranteed zero that would
    // read the same on a ruined battery.
    final socFraction = snapshot.soc / 100.0;
    final meaningful = socFraction >= 0.15 && socFraction <= 0.95;
    final implied = meaningful && socFraction > 0
        ? snapshot.remainingCapacityAh / socFraction
        : null;

    final loss = (implied != null &&
            catalogueCapacityAh != null &&
            catalogueCapacityAh > 0)
        ? (1 - implied / catalogueCapacityAh).clamp(-1.0, 1.0)
        : null;

    // The honest cycle count: total charge throughput divided by pack capacity.
    //
    // It used to say here that the BMS counter always reads higher, because it
    // increments on partial charges. It does not. On a real pack it read 1, 1,
    // 2, 2, 2, 2, 2 and 3 against honest counts of 1.9 to 3.1 -- lower every
    // time, because the counter is a whole number and this is not. Which way
    // the two disagree is not something to assume; see
    // [bmsCycleCountWorthQuoting] for what to do about it.
    final equivalent = configured > 0
        ? snapshot.cycleCapacityAh / configured
        : 0.0;
    final inflation = equivalent > 0.5
        ? snapshot.cycleCount / equivalent
        : null;

    // Imbalance cost: how much of the pack the lowest cell strands.
    final headroomAverage = snapshot.averageCellVoltage - cutoffVoltagePerCell;
    final headroomWeakest = snapshot.minCellVoltage - cutoffVoltagePerCell;
    double? imbalanceFraction;
    double? imbalanceAh;
    if (headroomAverage > 0 && headroomWeakest > 0) {
      imbalanceFraction =
          (1 - headroomWeakest / headroomAverage).clamp(0.0, 1.0);
      imbalanceAh = snapshot.remainingCapacityAh * imbalanceFraction;
    }

    return PackHealthReport._(
      impliedCapacityAh: implied,
      configuredCapacityAh: configured,
      catalogueCapacityAh: catalogueCapacityAh,
      shortOfAdvertisedFraction: loss?.toDouble(),
      equivalentFullCycles: equivalent,
      reportedCycles: snapshot.cycleCount,
      cycleInflation: inflation,
      imbalanceLossAh: imbalanceAh,
      imbalanceLossFraction: imbalanceFraction,
      weakestCellIndex: snapshot.minCellIndex,
      reportedSoh: snapshot.soh,
      capacityMeaningful: meaningful,
    );
  }

  /// The capacity the BMS is configured with, read back off its own coulomb
  /// counter. A setting, not a measurement of the cells. Null when the charge
  /// level makes even that division too noisy to read.
  final double? impliedCapacityAh;

  /// What the BMS is configured to believe the pack holds.
  final double configuredCapacityAh;

  /// What the pack was sold as.
  /// What the pack was sold as, or null when nobody has said. Null is not a
  /// missing input to work around: it is the answer to a question only the
  /// rider can answer, and every figure derived from it stays null too.
  final double? catalogueCapacityAh;

  /// How far the BMS's configured capacity falls short of what the pack was
  /// sold as. Negative means it is set higher than advertised.
  ///
  /// A fact about the purchase, decided once, and not wear: nothing here
  /// changes as the battery ages. Wear needs completed discharges, and lives
  /// in [Degradation].
  final double? shortOfAdvertisedFraction;

  /// Charge throughput expressed as whole pack-fulls.
  final double equivalentFullCycles;

  /// What the BMS counter says.
  final int reportedCycles;

  /// How many times higher the BMS counter reads than the honest figure.
  final double? cycleInflation;

  /// Honest cycles the pack must have on it before the BMS's own count is
  /// worth putting beside it.
  ///
  /// The BMS counts in whole numbers while [equivalentFullCycles] runs in
  /// decimals, so on a young pack the difference between them is rounding and
  /// nothing else. On the pack that prompted this the ratio read 0.53, 0.91,
  /// 0.83, 0.70 and 0.96 on consecutive days -- every one of them under 1, on
  /// a card that called itself "counter inflates" -- because three counted
  /// cycles were being compared against 3.1 honest ones.
  ///
  /// Twenty is where one cycle of disagreement stops being able to swing the
  /// comparison by more than a few percent.
  static const double cycleComparisonFloor = 20;

  /// The BMS's cycle count, when quoting it alongside the honest figure says
  /// something. Null while it would only be showing integer rounding.
  ///
  /// This is the figure worth having when somebody quotes a cycle count at
  /// you: a pack advertised at 800 cycles whose throughput is 320 pack-fulls
  /// has done 320, and the two numbers side by side say so without anyone
  /// having to interpret a multiplier.
  int? get bmsCycleCountWorthQuoting =>
      equivalentFullCycles >= cycleComparisonFloor ? reportedCycles : null;

  /// Amp-hours stranded above cutoff in the healthier cells.
  final double? imbalanceLossAh;
  final double? imbalanceLossFraction;

  /// 1-based index of the cell that will hit cutoff first.
  final int weakestCellIndex;

  final double reportedSoh;

  /// False when charge is too near either end for the capacity maths to mean
  /// anything.
  final bool capacityMeaningful;

  /// Whether the reported health figure looks like a constant the firmware
  /// never recomputes. A pack with real cycles on it that still reads exactly
  /// 100% is almost certainly showing a placeholder.
  bool get sohLooksDecorative =>
      reportedSoh >= 100 && equivalentFullCycles > 20;

  /// A blunt one-line verdict, or null when there is not enough to say.
  double? get worstLossPercent {
    final candidates = <double>[
      if (shortOfAdvertisedFraction != null) shortOfAdvertisedFraction! * 100,
      if (imbalanceLossFraction != null) imbalanceLossFraction! * 100,
    ];
    if (candidates.isEmpty) return null;
    return candidates.reduce(math.max);
  }
}
