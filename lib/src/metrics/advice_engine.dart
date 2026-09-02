import 'dart:math' as math;

import '../model/bms_snapshot.dart';
import '../model/jk_settings.dart';
import 'pack_health_report.dart';
import 'range_estimator.dart';

/// How much a piece of advice wants your attention.
enum AdviceLevel { info, watch, problem }

/// What the app has noticed. A code rather than a sentence, so the wording can
/// live in the translations instead of being baked into the analysis.
enum AdviceCode {
  /// Cells drift apart even with no current flowing. That is capacity
  /// mismatch, not resistance.
  imbalanceAtRest,

  /// Cells only drift apart under load. That is resistance — a cell or, more
  /// often, a connection.
  imbalanceUnderLoad,

  /// One cell is consistently the lowest, and it sets what the pack can do.
  weakCellDominant,

  /// The BMS cycle counter reads far higher than the charge actually put
  /// through the pack.
  cycleCounterInflated,

  /// State of health has not moved off its initial value despite real use.
  healthFigureDecorative,

  /// Implied capacity sits well under what the pack was sold as.
  capacityBelowCatalogue,

  /// Nothing has ever been measured end to end.
  noCapacityTestYet,

  /// The pack is running hot.
  runningHot,

  /// The balancer has never been seen working despite a wide delta.
  balancerNeverSeen,

  /// The overvoltage limit is set above what this chemistry likes.
  overvoltageSetHigh,

  /// Not enough kilometres behind the range figure to trust it.
  rangeStillLearning,

  /// The charge cutoff leaves usable energy stranded because of imbalance.
  imbalanceCostingRange,
}

/// One thing worth telling the rider.
class Advice {
  const Advice({
    required this.code,
    required this.level,
    this.cellIndex,
    this.value,
  });

  final AdviceCode code;
  final AdviceLevel level;

  /// The cell this is about, 1-based, when it is about one cell.
  final int? cellIndex;

  /// A number the wording can quote, when it needs one.
  final double? value;
}

/// Turns what the app has measured into things worth doing.
///
/// Every rule here fires on evidence the app actually holds, and each one says
/// something a person can act on. Nothing fires "just in case": advice that
/// appears on a healthy pack teaches people to ignore all of it.
class AdviceEngine {
  const AdviceEngine();

  /// [restingDelta] and [loadedDelta] come from the stored history — the widest
  /// delta seen with no meaningful current, and the widest seen under load.
  /// [weakCellCounts] is how many times each cell has been the lowest.
  List<Advice> evaluate({
    required BmsSnapshot snapshot,
    required PackHealthReport report,
    required RangeEstimator estimator,
    JkSettings? settings,
    double? restingDelta,
    double? loadedDelta,
    Map<int, int> weakCellCounts = const {},
    bool balancerEverSeen = false,
    int capacityTestCount = 0,
    /// Whether real degradation can be worked out from measurements. Once it
    /// can, comparing against the advert has nothing left to add.
    bool degradationMeasurable = false,
    double usableWh = 0,
    double grossWh = 0,
  }) {
    final advice = <Advice>[];

    // --- Imbalance, and which kind ---
    //
    // Splitting these two apart is the useful part. A delta that is already
    // there at rest means the cells hold different amounts of charge. A delta
    // that only opens under current means resistance, and resistance is far
    // more often a loose busbar than a bad cell — which is a much cheaper fix.
    if (restingDelta != null && restingDelta > 0.030) {
      advice.add(
        Advice(
          code: AdviceCode.imbalanceAtRest,
          level: restingDelta > 0.060 ? AdviceLevel.problem : AdviceLevel.watch,
          value: restingDelta,
          cellIndex: snapshot.minCellIndex,
        ),
      );
    } else if (loadedDelta != null &&
        restingDelta != null &&
        loadedDelta - restingDelta > 0.040) {
      advice.add(
        Advice(
          code: AdviceCode.imbalanceUnderLoad,
          level: AdviceLevel.watch,
          value: loadedDelta - restingDelta,
          cellIndex: snapshot.minCellIndex,
        ),
      );
    }

    // --- The cell that keeps showing up ---
    if (weakCellCounts.isNotEmpty) {
      final total = weakCellCounts.values.fold<int>(0, (a, b) => a + b);
      if (total >= 50) {
        final worst = weakCellCounts.entries
            .reduce((a, b) => a.value >= b.value ? a : b);
        if (worst.value / total > 0.6) {
          advice.add(
            Advice(
              code: AdviceCode.weakCellDominant,
              level: AdviceLevel.watch,
              cellIndex: worst.key,
              value: worst.value / total * 100,
            ),
          );
        }
      }
    }

    // --- Numbers the BMS reports that do not add up ---
    final inflation = report.cycleInflation;
    if (inflation != null && inflation > 1.4) {
      advice.add(
        Advice(
          code: AdviceCode.cycleCounterInflated,
          level: AdviceLevel.info,
          value: inflation,
        ),
      );
    }

    if (report.sohLooksDecorative) {
      advice.add(
        const Advice(
          code: AdviceCode.healthFigureDecorative,
          level: AdviceLevel.info,
        ),
      );
    }

    // Falling short of the advertised capacity is worth mentioning once, and
    // it is not a fault. It cannot tell a pack that has degraded from one that
    // was never the advertised size, which is the far more common case with a
    // number printed on a box. Calling that a problem told riders their
    // healthy battery was failing.
    //
    // Suppressed entirely once real degradation can be measured, because by
    // then the honest figure exists and this comparison adds nothing.
    final loss = report.shortOfAdvertisedFraction;
    if (!degradationMeasurable && loss != null && loss > 0.12) {
      advice.add(
        Advice(
          code: AdviceCode.capacityBelowCatalogue,
          level: AdviceLevel.info,
          value: loss * 100,
        ),
      );
    }

    if (capacityTestCount == 0) {
      advice.add(
        const Advice(
          code: AdviceCode.noCapacityTestYet,
          level: AdviceLevel.info,
        ),
      );
    }

    // --- Right now ---
    final temps = <double>[
      ...snapshot.plausibleTemperatures,
      if (snapshot.mosfetTemp != null) snapshot.mosfetTemp!,
    ];
    if (temps.isNotEmpty) {
      final hottest = temps.reduce(math.max);
      if (hottest > 45) {
        advice.add(
          Advice(
            code: AdviceCode.runningHot,
            level: hottest > 55 ? AdviceLevel.problem : AdviceLevel.watch,
            value: hottest,
          ),
        );
      }
    }

    // A balancer that has never been seen working while the pack sits wide open
    // is either switched off or its start voltage is above where the pack ever
    // gets. Both are settings, and both are worth knowing about.
    if (!balancerEverSeen &&
        snapshot.deltaCellVoltage > 0.030 &&
        settings != null) {
      final startsAbove = settings.balanceStartVoltage;
      if (settings.balancerSwitchOn == false ||
          snapshot.maxCellVoltage < startsAbove) {
        advice.add(
          Advice(
            code: AdviceCode.balancerNeverSeen,
            level: AdviceLevel.watch,
            value: startsAbove,
          ),
        );
      }
    }

    // NMC does not enjoy living at the top. Anything above 4.2 per cell as an
    // overvoltage limit is asking for a shorter life.
    if (settings != null && settings.cellOvp > 4.22) {
      advice.add(
        Advice(
          code: AdviceCode.overvoltageSetHigh,
          level: AdviceLevel.watch,
          value: settings.cellOvp,
        ),
      );
    }

    // --- Range confidence ---
    if (estimator.confidence == RangeConfidence.low) {
      advice.add(
        Advice(
          code: AdviceCode.rangeStillLearning,
          level: AdviceLevel.info,
          value: estimator.learnedKm,
        ),
      );
    }

    if (grossWh > 0 && usableWh > 0) {
      final stranded = 1 - usableWh / grossWh;
      if (stranded > 0.08) {
        advice.add(
          Advice(
            code: AdviceCode.imbalanceCostingRange,
            level: AdviceLevel.watch,
            value: stranded * 100,
          ),
        );
      }
    }

    // Loudest first, so the screen leads with what matters.
    advice.sort((a, b) => b.level.index.compareTo(a.level.index));
    return advice;
  }
}
