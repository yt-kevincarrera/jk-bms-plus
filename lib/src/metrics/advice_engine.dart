import '../model/bms_snapshot.dart';
import '../model/jk_settings.dart';
import 'cell_drift.dart';
import 'degradation.dart';
import 'pack_health_report.dart';
import 'range_estimator.dart';
import 'range_outlook.dart';
import 'soc_trust.dart';

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

  /// The delta under a heavy load is what it is at rest: nothing resistive
  /// going on.
  deltaUnderLoadNormal,

  /// The same, but only light loads have been seen, which cannot show a
  /// resistive fault. Said as that, not as a clean bill.
  deltaUnderLightLoadNormal,

  // --- Findings ---

  /// Cells drift apart even with no current flowing. That is capacity
  /// mismatch, not resistance.
  imbalanceAtRest,

  /// Cells only drift apart under load. That is resistance — a cell or, more
  /// often, a connection.
  imbalanceUnderLoad,

  /// One cell is consistently the lowest, and it sets what the pack can do.
  weakCellDominant,

  /// The BMS cycle counter reads far from the charge the BMS itself counted
  /// through the pack, in either direction.
  cycleCounterDisagrees,

  /// What the BMS says about itself was checkable and held up: its cycle
  /// count against the throughput, or its charge level at an end of the
  /// range against the cells.
  bmsClaimsConsistent,

  /// The charge counter reads nearly full while the cells are still well
  /// below where a charge ends.
  socCounterAhead,

  /// It reads nearly empty while the cells are still well above where the BMS
  /// itself calls empty. There is more battery here than the screen admits.
  socCounterBehind,

  /// State of health has not moved off its initial value despite real use.
  healthFigureDecorative,

  /// Implied capacity sits well under what the pack was sold as.
  capacityBelowCatalogue,

  /// Nothing has ever been measured end to end.
  noCapacityTestYet,

  /// A battery probe is running hot.
  runningHot,

  /// The BMS's MOSFET is running hot. Its own code, because it is not the
  /// battery and the advice about it is not the advice about cells.
  bmsRunningHot,

  /// Battery probes are fitted and none is hot, nor is the MOSFET.
  temperatureOk,

  /// The balancer has never been seen working despite a wide delta.
  balancerNeverSeen,

  /// The overvoltage limit is set above what this chemistry likes.
  overvoltageSetHigh,

  /// The settings frame arrived and the one limit this screen checks, the
  /// charge cutoff per cell, is not high. Not a full audit: that has its
  /// own screen.
  configNothingFlagged,

  /// Not enough kilometres behind the range figure to trust it.
  rangeStillLearning,

  /// The charge cutoff leaves usable energy stranded because of imbalance.
  imbalanceCostingRange,

  // --- Inspection of somebody else's pack (quick test) ---

  /// One cell sagged far more than the rest under the hard pull.
  inspectionCellSagging,

  /// Every cell sagged about the same: nothing giving up under load.
  inspectionSagUniform,

  /// The cells moved together, but the pull was too small for that to rule
  /// out a bad cell: the least fault this current could show is bigger than
  /// the one the test looks for.
  inspectionSagUnresolved,

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

  /// The cells climbed back, but at this little load any cell would have:
  /// the recovery says nothing either way.
  inspectionRecoveryNotDiscriminating,

  /// The pack was hot during the test.
  inspectionHot,

  /// The BMS raised a fault at some point during the test.
  inspectionAlarmsSeen,

  /// Cycles and configured capacity as the BMS reports them: editable, so
  /// shown and never trusted.
  inspectionCountersEditable,

  /// No load big enough to measure sag was seen: reduced fidelity.
  inspectionNoHeavyLoad,

  // --- Repeated inspections: what a second look adds ---

  /// The same cell gave up again. A finding rather than a reading.
  inspectionRepeatSameCell,

  /// A different cell was worst this time, which usually means the two runs
  /// were not pulled the same way.
  inspectionRepeatCellMoved,

  /// The pack measures worse than it did last time.
  inspectionRepeatWorse,

  /// A setting or a counter the BMS keeps moved between visits in a way it
  /// can move by itself or by an honest hand: the configured capacity, or a
  /// state of health that went up.
  inspectionRepeatConfigChanged,

  /// Two runs agree within noise: the first was not a fluke.
  inspectionRepeatSteady,

  /// The BMS's own counters moved between visits in a direction they cannot
  /// move by themselves.
  inspectionRepeatCountersReset,

  /// The two runs pulled very different currents, so their sag figures are
  /// not comparable.
  inspectionRepeatLoadDiffers,

  // --- What the BMS is configured to do ---

  /// The charge cutoff is above what the cells can take.
  configOvpDangerous,

  /// It is inside the limit but high enough to cost cycle life.
  configOvpHigh,

  /// The discharge cutoff would take cells below where they recover.
  configUvpDangerous,

  /// Low enough to be hard on the cells without being dangerous.
  configUvpLow,

  /// The BMS will charge the pack below freezing.
  configChargesWhenFrozen,

  /// It will not, with margin, which is worth saying.
  configColdCutoffOk,

  /// It stops above freezing, but with less margin than the advice asks for.
  configColdCutoffMarginal,

  /// The heat cutoff while charging is set high.
  configChargeHotLimit,

  /// So is the one while discharging.
  configDischargeHotLimit,

  /// What the BMS is configured to hold is not what the pack was sold as.
  configCapacityDisagrees,

  /// It is set for a different number of cells than are connected.
  configCellCountDisagrees,

  /// The charge current is a large fraction of the pack's own rating.
  configChargeCurrentHigh,

  /// The balancer is switched off.
  configBalancerOff,

  /// Charging is switched off at the BMS.
  configChargeOff,

  /// So is discharging.
  configDischargeOff,

  /// Balancing starts on the flat part of the curve, where voltage is not a
  /// measure of charge.
  configBalanceStartLow,

  /// Settings are not what they were on day one.
  configChangedSinceDayOne,

  /// Nobody has said what the cells are, so the voltage checks stayed quiet.
  configChemistryUnknown,

  /// Everything checked came back sensible.
  configLooksSane,

  /// The voltage settings came back sensible, and the BMS reports no
  /// temperature cutoffs or switches to check (an ANT).
  configVoltagesLookSane,
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
  reportedSoc,
  highestCell,
  lowestCell,
  socFullAnchor,
  socEmptyAnchor,
  impliedCapacity,
  catalogueCapacity,
  capacityTests,
  hottestProbe,
  mosfetTemperature,
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
  driftDays,
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

  /// The spread of the cells' median resting voltages in an inspection. Not
  /// [restingDelta], which is the widest spread seen on a live connection.
  inspectionRestDelta,

  /// The worst cell's extra sag over the median, divided by the current.
  excessResistance,

  /// The least extra resistance the pull could have shown.
  detectionFloor,

  /// The load was a charger. A flag: it carries no value.
  loadWasCharge,

  /// Which inspection step a figure was seen in, by the step's index.
  seenDuringStep,
  // Repeated inspections. Each is a figure from an earlier run, carrying the
  // date it was measured on so the sentence can say when.
  runCount,
  timesSameCell,
  previousSag,
  previousRestDelta,
  previousResistance,
  previousCycles,
  previousSoh,
  previousConfiguredCapacity,
  previousPeakCurrent,
  previousCycleCapacity,

  /// The amp-hours the BMS says it has counted through the pack, ever.
  cycleCapacity,
  // Configuration audit.
  configuredSetting,
  safeLimit,
  cellsSeen,
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
    AdviceCode.deltaUnderLoadNormal ||
    AdviceCode.deltaUnderLightLoadNormal => true,
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
    this.heavyLoadMinFrames = 5,
    this.weakCellMinReadings = 50,
    this.weakCellShare = 0.6,
    this.cycleInflation = 1.4,
    this.catalogueShortfall = 0.12,
    this.hotWatchCelsius = 45,
    this.hotProblemCelsius = 55,
    this.mosfetWatchCelsius = BmsSnapshot.mosfetWarmCelsius,
    this.mosfetProblemCelsius = BmsSnapshot.mosfetHotCelsius,
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

  /// Distinct readings at a heavy load (SessionAggregates.heavyLoadAmps)
  /// needed before a normal loaded delta is called "nothing resistive".
  final int heavyLoadMinFrames;

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

  /// The same two lines for the BMS's MOSFET, which runs hotter than the
  /// cells by design.
  final double mosfetWatchCelsius;
  final double mosfetProblemCelsius;

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
  const AdviceEngine({
    this.thresholds = VerdictThresholds.defaults,
    this.trust = SocTrust.defaults,
  });

  final VerdictThresholds thresholds;

  /// Where the charge counter is checked against the cells. Its own home
  /// rather than a row in [VerdictThresholds], because the charge ETA draws
  /// the same lines and two copies of a number drift apart.
  final SocTrust trust;

  /// [restingDelta] and [loadedDelta] come from the connection's aggregates
  /// (SessionAggregates): the widest delta seen at rest, and the delta
  /// several readings under load reached. [restingDeltaCell] and
  /// [loadedDeltaCell] are the cells that were lowest in those readings, which
  /// is the cell a finding about them names; the cell lowest in [snapshot] is
  /// only a fallback. [heavyLoadFrames] is how many readings were at a load
  /// heavy enough to show a resistive fault. [weakCellCounts] is how many
  /// times each cell has been clearly the lowest.
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
    int? restingDeltaCell,
    int? loadedDeltaCell,
    int heavyLoadFrames = 0,
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
        heavyLoadFrames: heavyLoadFrames,
      ),
    ];

    // --- Imbalance, and which kind ---
    //
    // Splitting these two apart is the useful part. A delta that is already
    // there at rest means the cells hold different amounts of charge. A delta
    // that only opens under current means resistance: a connection or a cell
    // with more of it. Checking the connection first is the cheaper step.
    if (restingDelta != null && restingDelta > th.restingDeltaWatch) {
      advice.add(
        Advice(
          code: AdviceCode.imbalanceAtRest,
          level: restingDelta > th.restingDeltaProblem
              ? AdviceLevel.problem
              : AdviceLevel.watch,
          value: restingDelta,
          cellIndex: restingDeltaCell ?? snapshot.minCellIndex,
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
          cellIndex: loadedDeltaCell ?? snapshot.minCellIndex,
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
    // Not on a young pack, whatever the ratio says. The BMS counts whole
    // cycles while the equivalent count runs in decimals, so on a pack with a
    // handful on it the two differ by rounding: one real pack read 0.53, 0.91,
    // 0.83, 0.70 and 0.96 on consecutive days off three counted cycles. None
    // of those would trip the threshold, but 4 counted against 2.4 equivalent
    // would, and it would mean nothing.
    //
    // Either direction. It used to fire only on a counter reading high, with
    // a sentence about partial charges, when the one real pack this was
    // checked on read lower every time. Which way a firmware errs is not
    // something to assume.
    final inflation = report.bmsCycleCountWorthQuoting == null
        ? null
        : report.cycleInflation;
    final cyclesDisagree =
        inflation != null &&
        (inflation > th.cycleInflation || inflation < 1 / th.cycleInflation);
    if (cyclesDisagree) {
      advice.add(
        Advice(
          code: AdviceCode.cycleCounterDisagrees,
          level: AdviceLevel.info,
          value: inflation,
          evidence: [
            Evidence(
              EvidenceKind.reportedCycles,
              // Non-null here: inflation is only non-null when
              // bmsCycleCountWorthQuoting was, which is reportedCycles itself.
              value: report.reportedCycles!.toDouble(),
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

    // The charge percentage, checked the same way: against something nobody
    // typed in. It is a running total of amps over time against a configured
    // capacity, so it drifts, and every figure on the screen is built on it.
    //
    // Only the two ends are checkable. In between, a flat-curve chemistry
    // says almost nothing and load sags the reading; at the ends the cells
    // are decisive, and that is where the drift shows.
    final cells = snapshot.cellVoltages.isEmpty;
    final socDrift = trust.check(
      soc: snapshot.soc,
      current: snapshot.current,
      capacityAh: snapshot.nominalCapacityAh,
      highestCellVolts: cells ? null : snapshot.maxCellVoltage,
      lowestCellVolts: cells ? null : snapshot.minCellVoltage,
      full: SocTrust.fullAnchor(
        soc100Volts: settings?.soc100Voltage,
        cellOvp: settings?.cellOvp,
      ),
      empty: SocTrust.emptyAnchor(soc0Volts: settings?.soc0Voltage),
    );
    switch (socDrift) {
      case SocDrift.aheadOfCells:
        final anchor = SocTrust.fullAnchor(
          soc100Volts: settings?.soc100Voltage,
          cellOvp: settings?.cellOvp,
        );
        advice.add(
          Advice(
            code: AdviceCode.socCounterAhead,
            level: AdviceLevel.info,
            value: anchor == null
                ? null
                : anchor.volts - snapshot.maxCellVoltage,
            evidence: [
              Evidence(EvidenceKind.reportedSoc, value: snapshot.soc),
              if (!cells)
                Evidence(
                  EvidenceKind.highestCell,
                  value: snapshot.maxCellVoltage,
                  cell: snapshot.maxCellIndex,
                ),
              if (anchor != null)
                Evidence(EvidenceKind.socFullAnchor, value: anchor.volts),
            ],
          ),
        );
      case SocDrift.behindCells:
        final anchor = SocTrust.emptyAnchor(soc0Volts: settings?.soc0Voltage);
        advice.add(
          Advice(
            code: AdviceCode.socCounterBehind,
            level: AdviceLevel.info,
            value: anchor == null
                ? null
                : snapshot.minCellVoltage - anchor.volts,
            evidence: [
              Evidence(EvidenceKind.reportedSoc, value: snapshot.soc),
              Evidence(
                EvidenceKind.lowestCell,
                value: snapshot.minCellVoltage,
                cell: snapshot.minCellIndex,
              ),
              if (anchor != null)
                Evidence(EvidenceKind.socEmptyAnchor, value: anchor.volts),
            ],
          ),
        );
      case SocDrift.none:
        break;
    }

    // The good news for this subject, said only about what was actually
    // checkable. The charge counter can only be caught out at the ends of the
    // range and the cycle counter only on a pack with cycles enough; "nothing
    // found" in the middle of a young pack's range is "nothing checked", and
    // stays unsaid.
    final fullAnchor = SocTrust.fullAnchor(
      soc100Volts: settings?.soc100Voltage,
      cellOvp: settings?.cellOvp,
    );
    final emptyAnchor = SocTrust.emptyAnchor(soc0Volts: settings?.soc0Voltage);
    final socCheckable =
        !cells &&
        ((snapshot.current > trust.restingCurrentAmps &&
                snapshot.soc >= trust.fullAbove &&
                fullAnchor != null) ||
            (snapshot.current < trust.restingCurrentAmps &&
                snapshot.soc <= trust.emptyBelow &&
                emptyAnchor != null));
    final cyclesCheckable = inflation != null;
    if (socDrift == SocDrift.none &&
        !cyclesDisagree &&
        !report.sohLooksDecorative &&
        (socCheckable || cyclesCheckable)) {
      advice.add(
        Advice(
          code: AdviceCode.bmsClaimsConsistent,
          level: AdviceLevel.good,
          evidence: [
            if (cyclesCheckable) ...[
              Evidence(
                EvidenceKind.reportedCycles,
                value: report.reportedCycles!.toDouble(),
              ),
              Evidence(
                EvidenceKind.equivalentCycles,
                value: report.equivalentFullCycles,
              ),
            ],
            if (socCheckable)
              Evidence(EvidenceKind.reportedSoc, value: snapshot.soc),
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
    // The battery and the BMS apart. "Heat is what ages a cell fastest" is
    // about cells, and it used to be said about the MOSFET, which runs hotter
    // than the cells by design.
    final hottest = snapshot.hottestBatteryTemp;
    if (hottest != null) {
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
    final mosfet = snapshot.mosfetTemp;
    if (mosfet != null && mosfet > th.mosfetWatchCelsius) {
      advice.add(
        Advice(
          code: AdviceCode.bmsRunningHot,
          level: mosfet > th.mosfetProblemCelsius
              ? AdviceLevel.problem
              : AdviceLevel.watch,
          value: mosfet,
          evidence: [Evidence(EvidenceKind.mosfetTemperature, value: mosfet)],
        ),
      );
    }
    // Said when it was looked at and was fine. Without it a healthy pack's
    // health tab listed temperature as "cannot say anything yet", which was
    // untrue of a pack with probes reading 25 degrees. Not said without a
    // battery probe: the MOSFET alone is not the battery.
    if (hottest != null &&
        hottest <= th.hotWatchCelsius &&
        (mosfet == null || mosfet <= th.mosfetWatchCelsius)) {
      advice.add(
        Advice(
          code: AdviceCode.temperatureOk,
          level: AdviceLevel.good,
          value: hottest,
          evidence: [
            Evidence(EvidenceKind.hottestProbe, value: hottest),
            if (mosfet != null)
              Evidence(EvidenceKind.mosfetTemperature, value: mosfet),
          ],
        ),
      );
    }

    // A balancer that has never been seen working while the pack sits wide open
    // is either switched off or its start voltage is above where the pack ever
    // gets. Both are settings, and both are worth knowing about.
    //
    // Judged on the resting delta, which is what the evidence line calls it.
    // It used to be the live delta, sag included, labelled as resting.
    if (!balancerEverSeen &&
        restingDelta != null &&
        restingDelta > th.balancerDelta &&
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
              Evidence(EvidenceKind.restingDelta, value: restingDelta),
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
    } else if (settings != null) {
      // The one limit this screen checks, checked and fine. The full audit is
      // its own screen, and this does not pretend to be it.
      advice.add(
        Advice(
          code: AdviceCode.configNothingFlagged,
          level: AdviceLevel.good,
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
    int heavyLoadFrames = 0,
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
      // Every cell is judged, not just the first of the ranking: "no cell is
      // drifting" has to be true of all of them, and "the lowest" has to be
      // the lowest one, not the one whose gap happened to move fastest.
      final sinking = CellDriftAnalysis.worstWorsening(drift);
      final worst = sinking ?? CellDriftAnalysis.lowest(drift)!;
      final days = worst.days.toDouble();
      if (sinking != null) {
        out.add(
          Advice(
            code: AdviceCode.cellDrifting,
            level: worst.currentDeviationVolts >= th.driftProblemVolts
                ? AdviceLevel.problem
                : AdviceLevel.watch,
            cellIndex: worst.index + 1,
            value: days,
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
              Evidence(EvidenceKind.driftDays, value: days),
            ],
          ),
        );
      } else {
        out.add(
          Advice(
            code: AdviceCode.noCellDrifting,
            level: AdviceLevel.good,
            value: days,
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
              Evidence(EvidenceKind.driftDays, value: days),
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
    // current: a pack that sat idle has not been tested. And "nothing
    // resistive to chase" only after a load that could have shown one: ten
    // amps for a moment cannot, and it used to be enough.
    if (restingDelta != null &&
        loadedDelta != null &&
        restingDelta <= th.restingDeltaWatch &&
        loadedDelta - restingDelta <= th.loadDeltaExtra) {
      out.add(
        Advice(
          code: heavyLoadFrames >= th.heavyLoadMinFrames
              ? AdviceCode.deltaUnderLoadNormal
              : AdviceCode.deltaUnderLightLoadNormal,
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
