import 'dart:math' as math;

import '../model/bms_snapshot.dart';
import '../model/jk_settings.dart';
import 'cell_drift.dart';
import 'degradation.dart';
import 'pack_health_report.dart';
import 'range_estimator.dart';
import 'range_outlook.dart';

/// How much a verdict wants your attention.
///
/// [good] exists so the app can say "nothing wrong here" about a specific
/// thing it checked. Silence and a clean bill of health look identical on a
/// screen, and only one of them is reassuring.
enum AdviceLevel { good, info, watch, problem }

/// What the app has noticed. A code rather than a sentence, so the wording can
/// live in the translations instead of being baked into the analysis.
enum AdviceCode {
  // --- Headlines: the sentences a person reads first ---

  /// Capacity now against the best this pack ever measured.
  healthMeasured,

  /// Wear cannot be stated yet: fewer than two full discharges on record.
  healthNotMeasurable,

  /// One cell has been pulling away from the rest over weeks of readings.
  cellDrifting,

  /// Enough history to say it, and no cell is pulling away.
  noCellDrifting,

  /// Kilometres left at this charge, from how this rider actually rides.
  rangeNow,

  /// The delta under load is what it is at rest: nothing resistive going on.
  deltaUnderLoadNormal,

  // --- Findings ---

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

  // --- Inspection of somebody else's pack (quick test) ---

  /// One cell sagged far more than the rest under the hard pull.
  inspectionCellSagging,

  /// Every cell sagged about the same: nothing giving up under load.
  inspectionSagUniform,

  /// Cells sat apart with no current flowing.
  inspectionRestDeltaWide,

  /// Cells sat together at rest.
  inspectionRestDeltaOk,

  /// A cell fell behind with only the lights on.
  inspectionWeakUnderLightLoad,

  /// A cell took much longer than the others to climb back after the load.
  inspectionSlowRecovery,

  /// Every cell climbed back at about the same pace.
  inspectionRecoveryOk,

  /// The pack was hot during the test.
  inspectionHot,

  /// The BMS raised a fault at some point during the test.
  inspectionAlarmsSeen,

  /// Cycles and configured capacity as the BMS reports them: editable, so
  /// shown and never trusted.
  inspectionCountersEditable,

  /// No load big enough to measure sag was seen: reduced fidelity.
  inspectionNoHeavyLoad,
}

/// One measured thing a verdict rests on.
///
/// Every sentence the app says about a pack has to be able to answer "why",
/// and the answer is a number the app actually holds, not a restatement of the
/// sentence. The kinds are fixed so the screen knows how to label and format
/// each one; the analysis never produces text.
enum EvidenceKind {
  restingDelta,
  loadedDelta,
  weakCellShare,
  readingsInSession,
  reportedCycles,
  equivalentCycles,
  reportedSoh,
  impliedCapacity,
  catalogueCapacity,
  capacityTests,
  hottestProbe,
  balanceStartVoltage,
  cellOvp,
  learnedKm,
  whPerKm,
  usableWh,
  strandedFraction,
  rangeBand,
  baselineCapacity,
  currentCapacity,
  driftDeviation,
  driftRate,
  driftSamples,
  driftSpanWeeks,
  // Inspection
  cellSag,
  medianSag,
  currentStep,
  cellResistance,
  medianResistance,
  lowestRestCell,
  lightLoadAmps,
  recoverySeconds,
  medianRecoverySeconds,
  alarmCount,
  peakCurrent,
}

class Evidence {
  const Evidence(this.kind, {this.value, this.value2, this.cell, this.at});

  final EvidenceKind kind;

  /// The number, in the unit the kind implies.
  final double? value;

  /// A second number for kinds that are a pair, such as a range band.
  final double? value2;

  /// 1-based cell number, when the fact is about one cell.
  final int? cell;

  /// When the fact was measured, for figures that age.
  final DateTime? at;
}

/// One thing worth telling the rider.
class Advice {
  const Advice({
    required this.code,
    required this.level,
    this.cellIndex,
    this.value,
    this.evidence = const [],
  });

  final AdviceCode code;
  final AdviceLevel level;

  /// The cell this is about, 1-based, when it is about one cell.
  final int? cellIndex;

  /// A number the wording can quote, when it needs one.
  final double? value;

  /// The facts behind it, for the "why" the screen shows on a tap.
  final List<Evidence> evidence;

  bool get isHeadline => switch (code) {
    AdviceCode.healthMeasured ||
    AdviceCode.healthNotMeasurable ||
    AdviceCode.cellDrifting ||
    AdviceCode.noCellDrifting ||
    AdviceCode.rangeNow ||
    AdviceCode.deltaUnderLoadNormal => true,
    _ => false,
  };
}

/// Every line the verdicts are drawn at, in one place.
///
/// None of these is a law of physics. They are starting points, chosen to be
/// conservative, and the PRD is explicit that they get calibrated against
/// real packs — the author's own and known good and bad ones — rather than
/// argued about in the abstract. Keeping them here, named, is what makes that
/// calibration a one-line change instead of a hunt through the rules.
class VerdictThresholds {
  const VerdictThresholds({
    this.restingDeltaWatch = 0.030,
    this.restingDeltaProblem = 0.060,
    this.loadDeltaExtra = 0.040,
    this.weakCellMinReadings = 50,
    this.weakCellShare = 0.6,
    this.cycleInflation = 1.4,
    this.catalogueShortfall = 0.12,
    this.hotWatchCelsius = 45,
    this.hotProblemCelsius = 55,
    this.balancerDelta = 0.030,
    this.cellOvpMax = 4.22,
    this.strandedFraction = 0.08,
    this.healthGoodPercent = 92,
    this.healthWatchPercent = 80,
    this.driftProblemVolts = 0.030,
  });

  static const VerdictThresholds defaults = VerdictThresholds();

  /// Delta at rest that is worth a look, and that is a problem, in volts.
  final double restingDeltaWatch;
  final double restingDeltaProblem;

  /// How much more the delta may open under load before it counts as a
  /// resistive fault rather than noise.
  final double loadDeltaExtra;

  /// Readings needed before "always the same cell" means anything, and the
  /// share of them one cell has to win.
  final int weakCellMinReadings;
  final double weakCellShare;

  /// BMS cycles over equivalent full cycles, above which the counter is
  /// called inflated.
  final double cycleInflation;

  /// Fraction short of the advertised capacity worth mentioning.
  final double catalogueShortfall;

  final double hotWatchCelsius;
  final double hotProblemCelsius;

  /// Delta above which a balancer that has never run is worth a remark.
  final double balancerDelta;

  /// Per-cell overvoltage limit above which NMC is being pushed.
  final double cellOvpMax;

  /// Share of remaining energy stranded above cutoff by the weakest cell.
  final double strandedFraction;

  /// Measured capacity kept, as a percent of the pack's own best.
  final double healthGoodPercent;
  final double healthWatchPercent;

  /// A drifting cell this far under the pack is past "watch".
  final double driftProblemVolts;

  AdviceLevel healthLevel(double percentKept) {
    if (percentKept >= healthGoodPercent) return AdviceLevel.good;
    if (percentKept >= healthWatchPercent) return AdviceLevel.watch;
    return AdviceLevel.problem;
  }
}

/// Turns what the app has measured into things worth doing.
///
/// Every rule here fires on evidence the app actually holds, and each one says
/// something a person can act on. Nothing fires "just in case": advice that
/// appears on a healthy pack teaches people to ignore all of it.
///
/// Two entry points. [evaluate] needs a live reading and produces everything.
/// [headlines] needs only what is on disk, and is what the saved-pack screen
/// shows with no radio in range; [evaluate] calls it too, so the two screens
/// never disagree about the same battery.
class AdviceEngine {
  const AdviceEngine({this.thresholds = VerdictThresholds.defaults});

  final VerdictThresholds thresholds;

  /// [restingDelta] and [loadedDelta] come from the stored history — the widest
  /// delta seen with no meaningful current, and the widest seen under load.
  /// [weakCellCounts] is how many times each cell has been the lowest.
  ///
  /// [degradation], [drift] and [outlook] are optional: a caller that has not
  /// read the history gets the live findings and no headlines about it.
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
    Degradation? degradation,
    List<CellDrift> drift = const [],
    RangeOutlook? outlook,
  }) {
    final th = thresholds;
    final advice = <Advice>[
      ...headlines(
        degradation: degradation,
        drift: drift,
        outlook: outlook,
        estimator: estimator,
        restingDelta: restingDelta,
        loadedDelta: loadedDelta,
      ),
    ];

    // --- Imbalance, and which kind ---
    //
    // Splitting these two apart is the useful part. A delta that is already
    // there at rest means the cells hold different amounts of charge. A delta
    // that only opens under current means resistance, and resistance is far
    // more often a loose busbar than a bad cell — which is a much cheaper fix.
    if (restingDelta != null && restingDelta > th.restingDeltaWatch) {
      advice.add(
        Advice(
          code: AdviceCode.imbalanceAtRest,
          level: restingDelta > th.restingDeltaProblem
              ? AdviceLevel.problem
              : AdviceLevel.watch,
          value: restingDelta,
          cellIndex: snapshot.minCellIndex,
          evidence: [
            Evidence(EvidenceKind.restingDelta, value: restingDelta),
            if (loadedDelta != null)
              Evidence(EvidenceKind.loadedDelta, value: loadedDelta),
          ],
        ),
      );
    } else if (loadedDelta != null &&
        restingDelta != null &&
        loadedDelta - restingDelta > th.loadDeltaExtra) {
      advice.add(
        Advice(
          code: AdviceCode.imbalanceUnderLoad,
          level: AdviceLevel.watch,
          value: loadedDelta - restingDelta,
          cellIndex: snapshot.minCellIndex,
          evidence: [
            Evidence(EvidenceKind.restingDelta, value: restingDelta),
            Evidence(EvidenceKind.loadedDelta, value: loadedDelta),
          ],
        ),
      );
    }

    // --- The cell that keeps showing up ---
    if (weakCellCounts.isNotEmpty) {
      final total = weakCellCounts.values.fold<int>(0, (a, b) => a + b);
      if (total >= th.weakCellMinReadings) {
        final worst = weakCellCounts.entries.reduce(
          (a, b) => a.value >= b.value ? a : b,
        );
        if (worst.value / total > th.weakCellShare) {
          advice.add(
            Advice(
              code: AdviceCode.weakCellDominant,
              level: AdviceLevel.watch,
              cellIndex: worst.key,
              value: worst.value / total * 100,
              evidence: [
                Evidence(
                  EvidenceKind.weakCellShare,
                  value: worst.value / total * 100,
                  cell: worst.key,
                ),
                Evidence(
                  EvidenceKind.readingsInSession,
                  value: total.toDouble(),
                ),
              ],
            ),
          );
        }
      }
    }

    // --- Numbers the BMS reports that do not add up ---
    //
    // Cycles and configured capacity can be typed into the BMS from the
    // official app, so they are claims, not measurements. The equivalent
    // cycle count comes from amp-hours that actually flowed, which nobody can
    // edit.
    final inflation = report.cycleInflation;
    if (inflation != null && inflation > th.cycleInflation) {
      advice.add(
        Advice(
          code: AdviceCode.cycleCounterInflated,
          level: AdviceLevel.info,
          value: inflation,
          evidence: [
            Evidence(
              EvidenceKind.reportedCycles,
              value: report.reportedCycles.toDouble(),
            ),
            Evidence(
              EvidenceKind.equivalentCycles,
              value: report.equivalentFullCycles,
            ),
          ],
        ),
      );
    }

    if (report.sohLooksDecorative) {
      advice.add(
        Advice(
          code: AdviceCode.healthFigureDecorative,
          level: AdviceLevel.info,
          evidence: [
            Evidence(EvidenceKind.reportedSoh, value: report.reportedSoh),
            Evidence(
              EvidenceKind.equivalentCycles,
              value: report.equivalentFullCycles,
            ),
          ],
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
    if (!degradationMeasurable &&
        loss != null &&
        loss > th.catalogueShortfall) {
      advice.add(
        Advice(
          code: AdviceCode.capacityBelowCatalogue,
          level: AdviceLevel.info,
          value: loss * 100,
          evidence: [
            if (report.impliedCapacityAh != null)
              Evidence(
                EvidenceKind.impliedCapacity,
                value: report.impliedCapacityAh,
              ),
            if (report.catalogueCapacityAh != null)
              Evidence(
                EvidenceKind.catalogueCapacity,
                value: report.catalogueCapacityAh,
              ),
          ],
        ),
      );
    }

    if (capacityTestCount == 0) {
      advice.add(
        const Advice(
          code: AdviceCode.noCapacityTestYet,
          level: AdviceLevel.info,
          evidence: [Evidence(EvidenceKind.capacityTests, value: 0)],
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
      if (hottest > th.hotWatchCelsius) {
        advice.add(
          Advice(
            code: AdviceCode.runningHot,
            level: hottest > th.hotProblemCelsius
                ? AdviceLevel.problem
                : AdviceLevel.watch,
            value: hottest,
            evidence: [Evidence(EvidenceKind.hottestProbe, value: hottest)],
          ),
        );
      }
    }

    // A balancer that has never been seen working while the pack sits wide open
    // is either switched off or its start voltage is above where the pack ever
    // gets. Both are settings, and both are worth knowing about.
    if (!balancerEverSeen &&
        snapshot.deltaCellVoltage > th.balancerDelta &&
        settings != null) {
      final startsAbove = settings.balanceStartVoltage;
      if (settings.balancerSwitchOn == false ||
          snapshot.maxCellVoltage < startsAbove) {
        advice.add(
          Advice(
            code: AdviceCode.balancerNeverSeen,
            level: AdviceLevel.watch,
            value: startsAbove,
            evidence: [
              Evidence(EvidenceKind.balanceStartVoltage, value: startsAbove),
              Evidence(
                EvidenceKind.restingDelta,
                value: snapshot.deltaCellVoltage,
              ),
            ],
          ),
        );
      }
    }

    // NMC does not enjoy living at the top. Anything above 4.2 per cell as an
    // overvoltage limit is asking for a shorter life.
    if (settings != null && settings.cellOvp > th.cellOvpMax) {
      advice.add(
        Advice(
          code: AdviceCode.overvoltageSetHigh,
          level: AdviceLevel.watch,
          value: settings.cellOvp,
          evidence: [Evidence(EvidenceKind.cellOvp, value: settings.cellOvp)],
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
          evidence: [
            Evidence(EvidenceKind.learnedKm, value: estimator.learnedKm),
          ],
        ),
      );
    }

    if (grossWh > 0 && usableWh > 0) {
      final stranded = 1 - usableWh / grossWh;
      if (stranded > th.strandedFraction) {
        advice.add(
          Advice(
            code: AdviceCode.imbalanceCostingRange,
            level: AdviceLevel.watch,
            value: stranded * 100,
            evidence: [
              Evidence(EvidenceKind.strandedFraction, value: stranded * 100),
              Evidence(EvidenceKind.usableWh, value: usableWh),
            ],
          ),
        );
      }
    }

    return _ordered(advice);
  }

  /// The sentences that can be said from history alone.
  ///
  /// Each argument is optional and each headline appears only when its input
  /// was given: a caller that did not read the capacity tests gets no health
  /// sentence rather than a "cannot measure" it did not ask about.
  List<Advice> headlines({
    Degradation? degradation,
    List<CellDrift> drift = const [],
    RangeOutlook? outlook,
    RangeEstimator? estimator,
    double? restingDelta,
    double? loadedDelta,
  }) {
    final th = thresholds;
    final out = <Advice>[];

    // --- Health, measured or not yet ---
    if (degradation != null) {
      final lost = degradation.lostFraction;
      final baseline = degradation.baseline;
      final current = degradation.current;
      if (lost != null && baseline != null && current != null) {
        final kept = (1 - lost) * 100;
        out.add(
          Advice(
            code: AdviceCode.healthMeasured,
            level: th.healthLevel(kept),
            value: kept,
            evidence: [
              Evidence(
                EvidenceKind.baselineCapacity,
                value: baseline.ah,
                at: baseline.at,
              ),
              Evidence(
                EvidenceKind.currentCapacity,
                value: current.ah,
                at: current.at,
              ),
              Evidence(
                EvidenceKind.capacityTests,
                value: degradation.observations.toDouble(),
              ),
            ],
          ),
        );
      } else {
        out.add(
          Advice(
            code: AdviceCode.healthNotMeasurable,
            level: AdviceLevel.info,
            value: degradation.observations.toDouble(),
            evidence: [
              Evidence(
                EvidenceKind.capacityTests,
                value: degradation.observations.toDouble(),
              ),
              if (current != null)
                Evidence(
                  EvidenceKind.currentCapacity,
                  value: current.ah,
                  at: current.at,
                ),
            ],
          ),
        );
      }
    }

    // --- A cell on its way out, or none ---
    //
    // Only said when there is history enough to say it either way: an empty
    // analysis means "not enough readings", and that is not the same as "no
    // cell is drifting". Silence is the honest answer there.
    if (drift.isNotEmpty) {
      final worst = drift.first;
      final weeks = worst.spanDays / 7;
      if (worst.isWorsening) {
        out.add(
          Advice(
            code: AdviceCode.cellDrifting,
            level: worst.currentDeviationVolts >= th.driftProblemVolts
                ? AdviceLevel.problem
                : AdviceLevel.watch,
            cellIndex: worst.index + 1,
            value: weeks,
            evidence: [
              Evidence(
                EvidenceKind.driftDeviation,
                value: worst.currentDeviationVolts,
                cell: worst.index + 1,
              ),
              Evidence(
                EvidenceKind.driftRate,
                value: worst.changeVoltsPerMonth,
              ),
              Evidence(
                EvidenceKind.driftSamples,
                value: worst.samples.toDouble(),
              ),
              Evidence(EvidenceKind.driftSpanWeeks, value: weeks),
            ],
          ),
        );
      } else {
        out.add(
          Advice(
            code: AdviceCode.noCellDrifting,
            level: AdviceLevel.good,
            value: weeks,
            evidence: [
              Evidence(
                EvidenceKind.driftDeviation,
                value: worst.currentDeviationVolts,
                cell: worst.index + 1,
              ),
              Evidence(
                EvidenceKind.driftSamples,
                value: worst.samples.toDouble(),
              ),
              Evidence(EvidenceKind.driftSpanWeeks, value: weeks),
            ],
          ),
        );
      }
    }

    // --- How far, in this rider's kilometres ---
    //
    // Only once something has been learned. The estimator will divide by its
    // starting default happily; that is a number about a hypothetical bike,
    // and the "still learning" finding covers it.
    final now = outlook?.nowKm;
    if (outlook != null && outlook.hasLearned && now != null) {
      final band = outlook.nowBandKm;
      out.add(
        Advice(
          code: AdviceCode.rangeNow,
          level: AdviceLevel.info,
          value: now,
          evidence: [
            if (estimator != null)
              Evidence(EvidenceKind.whPerKm, value: estimator.whPerKm),
            if (estimator != null)
              Evidence(EvidenceKind.learnedKm, value: estimator.learnedKm),
            if (band != null)
              Evidence(EvidenceKind.rangeBand, value: band.$1, value2: band.$2),
          ],
        ),
      );
    }

    // --- Nothing resistive going on ---
    //
    // The positive counterpart of the two imbalance findings. Needs both
    // figures, so it is only said about a session that has actually pulled
    // current: a pack that sat idle has not been tested.
    if (restingDelta != null &&
        loadedDelta != null &&
        restingDelta <= th.restingDeltaWatch &&
        loadedDelta - restingDelta <= th.loadDeltaExtra) {
      out.add(
        Advice(
          code: AdviceCode.deltaUnderLoadNormal,
          level: AdviceLevel.good,
          value: loadedDelta,
          evidence: [
            Evidence(EvidenceKind.restingDelta, value: restingDelta),
            Evidence(EvidenceKind.loadedDelta, value: loadedDelta),
          ],
        ),
      );
    }

    return _ordered(out);
  }

  /// Loudest first, so the screen leads with what matters; good news last,
  /// where it reassures without shouting.
  static List<Advice> _ordered(List<Advice> advice) {
    advice.sort((a, b) => b.level.index.compareTo(a.level.index));
    return advice;
  }
}
