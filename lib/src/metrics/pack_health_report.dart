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
    required this.resistanceSpreadPercent,
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
    // The BMS counter increments on partial charges, so it always reads higher.
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

    // Resistance spread: the worst cell against the median, in percent.
    double? spread;
    final resistances = [
      for (final r in snapshot.cellResistances)
        if (r > 0) r,
    ]..sort();
    if (resistances.length >= 3) {
      final median = resistances[resistances.length ~/ 2];
      final worst = resistances.last;
      if (median > 0) spread = (worst / median - 1) * 100;
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
      resistanceSpreadPercent: spread,
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

  /// Amp-hours stranded above cutoff in the healthier cells.
  final double? imbalanceLossAh;
  final double? imbalanceLossFraction;

  /// 1-based index of the cell that will hit cutoff first.
  final int weakestCellIndex;

  /// How far above the median the worst cell's resistance sits, in percent.
  final double? resistanceSpreadPercent;

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
