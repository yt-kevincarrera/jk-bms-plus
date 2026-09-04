import 'dart:math' as math;

import '../metrics/advice_engine.dart';
import 'inspection_result.dart';

/// One test already on record, as much of it as a comparison needs.
///
/// Kept apart from the stored row so the comparison stays pure Dart: the
/// arithmetic of "is this the same fault as last time" has nothing to do with
/// databases, and it is the part that has to be right.
class PastInspection {
  const PastInspection({
    required this.at,
    required this.result,
    this.id,
    this.bmsId = '',
    this.note = '',
  });

  /// When the test was run.
  final DateTime at;
  final InspectionResult result;

  /// The row it came from, when it came from one.
  final int? id;

  /// The address the pack answered on that day. Kept because a pack can be
  /// met again on a different address, and the serial is then what ties the
  /// two runs together.
  final String bmsId;
  final String note;
}

/// How much has to move before a repeat is saying something.
///
/// A second test is never a copy of the first: the load is pulled by hand,
/// the pack sits at a different charge, the weather is different. These are
/// the margins inside which two runs are the same run said twice.
class SeriesThresholds {
  const SeriesThresholds({
    this.restDeltaMoveVolts = 0.010,
    this.sagMoveVolts = 0.030,
    this.resistanceMoveFraction = 0.25,
    this.comparableLoadFraction = 0.4,
    this.comparableLoadFloorAmps = 5,
    this.sohRiseTolerance = 0.5,
    this.capacityMoveAh = 0.5,
  });

  static const SeriesThresholds defaults = SeriesThresholds();

  /// A resting spread that moved by more than this is a real change.
  final double restDeltaMoveVolts;

  /// How much the worst cell's excess sag has to move to count.
  final double sagMoveVolts;

  /// Estimated resistance is noisy; only a relative move this big counts.
  final double resistanceMoveFraction;

  /// Two runs are comparable when the harder pull is within this fraction of
  /// the softer one. Sag scales with current, so comparing a 40 A pull with a
  /// 12 A pull would report a pack that "improved" when nothing changed but
  /// the throttle.
  final double comparableLoadFraction;

  /// Below this, both runs are effectively no-load and the sag figures are
  /// not worth comparing either way.
  final double comparableLoadFloorAmps;

  /// State of health wobbles by rounding; only a rise beyond this is a reset.
  final double sohRiseTolerance;

  /// Configured capacity is a whole setting; this much movement is a change.
  final double capacityMoveAh;
}

/// What the BMS's own counters did between two visits.
///
/// The interesting direction is backwards. Cycles only ever go up and state
/// of health only ever goes down, so a pack that reports fewer cycles or more
/// health than it did last week has been reset by somebody, and the only
/// reason to reset it between two viewings is the viewing.
class CounterChanges {
  const CounterChanges({
    this.cyclesFell = false,
    this.sohRose = false,
    this.capacityChanged = false,
    this.cyclesBefore,
    this.cyclesNow,
    this.sohBefore,
    this.sohNow,
    this.capacityBefore,
    this.capacityNow,
  });

  final bool cyclesFell;
  final bool sohRose;
  final bool capacityChanged;

  final int? cyclesBefore;
  final int? cyclesNow;
  final double? sohBefore;
  final double? sohNow;
  final double? capacityBefore;
  final double? capacityNow;

  bool get anything => cyclesFell || sohRose || capacityChanged;
}

/// This run set against every run before it on the same pack.
class InspectionComparison {
  const InspectionComparison({
    required this.result,
    required this.earlier,
    required this.runNumber,
    required this.loadComparable,
    required this.counters,
    this.previous,
    this.worstCellNow,
    this.worstCellBefore,
    this.timesSameWorstCell = 0,
    this.restDeltaChange,
    this.sagExcessChange,
    this.resistanceChangeFraction,
  });

  final InspectionResult result;

  /// Every earlier run on this pack, oldest first.
  final List<PastInspection> earlier;

  /// The run right before this one, when there is one.
  final PastInspection? previous;

  /// 1 for a first look, 2 for a second opinion, and so on.
  final int runNumber;

  /// Whether the two runs pulled enough current, and similar enough current,
  /// for their sag figures to mean the same thing.
  final bool loadComparable;

  final CounterChanges counters;

  /// The cell that gave up first, this time and last time. 1-based.
  final int? worstCellNow;
  final int? worstCellBefore;

  /// How many runs in the series, this one included, named [worstCellNow] as
  /// the weakest. The number that turns a suspicion into a finding.
  final int timesSameWorstCell;

  /// Positive means worse than the previous run.
  final double? restDeltaChange;
  final double? sagExcessChange;

  /// Relative, so 0.3 is thirty per cent more resistance than last time.
  final double? resistanceChangeFraction;

  bool get isFirstRun => earlier.isEmpty;
}

/// Compares a fresh test against what this pack did before.
///
/// The point of running the test twice is that a single quick test can be
/// wrong in ways nobody notices: a loose crocodile clip, a throttle that was
/// not held down, a pack that had just come off the charger. Repeating it
/// turns a one-off reading into evidence, or shows it up as an artefact. So
/// this layer answers three questions and no others: is it the same fault as
/// last time, has anything moved, and did the pack's own counters change
/// between visits in a way they cannot change by themselves.
class InspectionSeries {
  const InspectionSeries({this.thresholds = SeriesThresholds.defaults});

  final SeriesThresholds thresholds;

  /// Picks out the runs that are about the same pack.
  ///
  /// The address is the usual key. The serial is the fallback for the same
  /// pack met on a different address, and the reason it is not the only key
  /// is that plenty of BMS units report an empty serial, which would then
  /// merge every anonymous pack in the list into one battery with a very
  /// strange history.
  static List<PastInspection> forPack(
    Iterable<PastInspection> all, {
    required String bmsId,
    String serialNumber = '',
    DateTime? before,
    int? excludeId,
  }) {
    final out = [
      for (final p in all)
        if (p.id == null || p.id != excludeId)
          if (before == null || p.at.isBefore(before))
            if (p.bmsId == bmsId ||
                (serialNumber.isNotEmpty &&
                    p.result.reported.serialNumber == serialNumber))
              p,
    ]..sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  InspectionComparison compare(
    InspectionResult result,
    List<PastInspection> earlier,
  ) {
    final sorted = [...earlier]..sort((a, b) => a.at.compareTo(b.at));
    final previous = sorted.isEmpty ? null : sorted.last;

    final worstNow = result.worstSag?.index;
    final worstBefore = previous?.result.worstSag?.index;

    // How many runs, this one included, blamed the cell this run blames. A
    // cell named once is a reading; named three times it is the cell.
    var sameCell = 0;
    if (worstNow != null) {
      sameCell = 1;
      for (final p in sorted) {
        if (p.result.worstSag?.index == worstNow) sameCell++;
      }
    }

    final comparable =
        previous != null &&
        _comparableLoad(
          result.currentStepAmps,
          previous.result.currentStepAmps,
        );

    return InspectionComparison(
      result: result,
      earlier: sorted,
      previous: previous,
      runNumber: sorted.length + 1,
      loadComparable: comparable,
      counters: _counters(result, previous?.result),
      worstCellNow: worstNow,
      worstCellBefore: worstBefore,
      timesSameWorstCell: sameCell,
      restDeltaChange: previous == null
          ? null
          : result.restDeltaVolts - previous.result.restDeltaVolts,
      sagExcessChange: !comparable
          ? null
          : _change(result.worstSagExcess, previous.result.worstSagExcess),
      resistanceChangeFraction: !comparable
          ? null
          : _fraction(
              result.medianResistanceOhms,
              previous.result.medianResistanceOhms,
            ),
    );
  }

  /// The sentences a repeat earns, worst first.
  ///
  /// Nothing here restates what the single-run verdict already said. A repeat
  /// can only add three kinds of thing: this happened again, this moved, or
  /// somebody changed the pack between visits.
  List<Advice> evaluate(InspectionComparison c) {
    final out = <Advice>[];
    if (c.isFirstRun) return out;
    final th = thresholds;
    final previous = c.previous!;

    // --- Somebody reset the counters between visits ---
    final counters = c.counters;
    if (counters.anything) {
      out.add(
        Advice(
          code: AdviceCode.inspectionRepeatCountersReset,
          level: AdviceLevel.problem,
          evidence: [
            if (counters.cyclesBefore != null)
              Evidence(
                EvidenceKind.previousCycles,
                value: counters.cyclesBefore!.toDouble(),
                at: previous.at,
              ),
            if (counters.cyclesNow != null)
              Evidence(
                EvidenceKind.reportedCycles,
                value: counters.cyclesNow!.toDouble(),
              ),
            if (counters.sohBefore != null)
              Evidence(
                EvidenceKind.previousSoh,
                value: counters.sohBefore,
                at: previous.at,
              ),
            if (counters.sohNow != null)
              Evidence(EvidenceKind.reportedSoh, value: counters.sohNow),
            if (counters.capacityBefore != null)
              Evidence(
                EvidenceKind.previousConfiguredCapacity,
                value: counters.capacityBefore,
                at: previous.at,
              ),
            if (counters.capacityNow != null)
              Evidence(
                EvidenceKind.impliedCapacity,
                value: counters.capacityNow,
              ),
          ],
        ),
      );
    }

    // --- The same cell, again ---
    final worstNow = c.worstCellNow;
    if (worstNow != null && c.timesSameWorstCell >= 2) {
      final excess = c.result.worstSagExcess;
      out.add(
        Advice(
          code: AdviceCode.inspectionRepeatSameCell,
          level: AdviceLevel.problem,
          cellIndex: worstNow,
          value: excess,
          evidence: [
            Evidence(
              EvidenceKind.timesSameCell,
              value: c.timesSameWorstCell.toDouble(),
              cell: worstNow,
            ),
            Evidence(EvidenceKind.runCount, value: c.runNumber.toDouble()),
            // The sag itself on both runs, not the excess over the median:
            // two numbers a reader can hold side by side and subtract.
            if (c.result.worstSag?.heavySagVolts != null)
              Evidence(
                EvidenceKind.cellSag,
                value: c.result.worstSag!.heavySagVolts,
                cell: worstNow,
              ),
            if (previous.result.worstSag?.heavySagVolts != null)
              Evidence(
                EvidenceKind.previousSag,
                value: previous.result.worstSag!.heavySagVolts,
                cell: previous.result.worstSag!.index,
                at: previous.at,
              ),
          ],
        ),
      );
    } else if (worstNow != null &&
        c.worstCellBefore != null &&
        c.worstCellBefore != worstNow) {
      // A different cell each time is not two faults. It is one measurement
      // that is not measuring what it looks like, most often because the two
      // runs were not pulled the same way.
      out.add(
        Advice(
          code: AdviceCode.inspectionRepeatCellMoved,
          level: AdviceLevel.watch,
          cellIndex: worstNow,
          evidence: [
            Evidence(
              EvidenceKind.cellSag,
              value: c.result.worstSag?.heavySagVolts,
              cell: worstNow,
            ),
            Evidence(
              EvidenceKind.previousSag,
              value: previous.result.worstSag?.heavySagVolts,
              cell: c.worstCellBefore,
              at: previous.at,
            ),
            Evidence(EvidenceKind.currentStep, value: c.result.currentStepAmps),
            Evidence(
              EvidenceKind.previousPeakCurrent,
              value: previous.result.currentStepAmps,
              at: previous.at,
            ),
          ],
        ),
      );
    }

    // --- Not the same test twice ---
    if (!c.loadComparable) {
      out.add(
        Advice(
          code: AdviceCode.inspectionRepeatLoadDiffers,
          level: AdviceLevel.info,
          evidence: [
            Evidence(EvidenceKind.currentStep, value: c.result.currentStepAmps),
            Evidence(
              EvidenceKind.previousPeakCurrent,
              value: previous.result.currentStepAmps,
              at: previous.at,
            ),
          ],
        ),
      );
    }

    // --- Something moved, or nothing did ---
    final restMove = c.restDeltaChange ?? 0;
    final sagMove = c.sagExcessChange ?? 0;
    final resistanceMove = c.resistanceChangeFraction ?? 0;
    final worse =
        restMove > th.restDeltaMoveVolts ||
        sagMove > th.sagMoveVolts ||
        resistanceMove > th.resistanceMoveFraction;
    final better =
        restMove < -th.restDeltaMoveVolts ||
        sagMove < -th.sagMoveVolts ||
        resistanceMove < -th.resistanceMoveFraction;

    if (worse) {
      out.add(
        Advice(
          code: AdviceCode.inspectionRepeatWorse,
          level: AdviceLevel.problem,
          value: sagMove != 0 ? sagMove : restMove,
          evidence: _movementEvidence(c, previous),
        ),
      );
    } else if (!better && c.loadComparable) {
      // Steady is a finding in its own right, and the one a seller with an
      // honest pack is owed: the first test was not a fluke and the second
      // did not find anything new.
      out.add(
        Advice(
          code: AdviceCode.inspectionRepeatSteady,
          level: AdviceLevel.good,
          evidence: [
            Evidence(EvidenceKind.runCount, value: c.runNumber.toDouble()),
            ..._movementEvidence(c, previous),
          ],
        ),
      );
    }

    out.sort((a, b) => b.level.index.compareTo(a.level.index));
    return out;
  }

  List<Evidence> _movementEvidence(
    InspectionComparison c,
    PastInspection previous,
  ) => [
    Evidence(EvidenceKind.restingDelta, value: c.result.restDeltaVolts),
    Evidence(
      EvidenceKind.previousRestDelta,
      value: previous.result.restDeltaVolts,
      at: previous.at,
    ),
    if (c.result.worstSagExcess != null)
      Evidence(EvidenceKind.medianSag, value: c.result.medianHeavySagVolts),
    if (previous.result.medianHeavySagVolts != null)
      Evidence(
        EvidenceKind.previousSag,
        value: previous.result.medianHeavySagVolts,
        at: previous.at,
      ),
    if (c.result.medianResistanceOhms != null)
      Evidence(
        EvidenceKind.medianResistance,
        value: c.result.medianResistanceOhms,
      ),
    if (previous.result.medianResistanceOhms != null)
      Evidence(
        EvidenceKind.previousResistance,
        value: previous.result.medianResistanceOhms,
        at: previous.at,
      ),
  ];

  bool _comparableLoad(double now, double before) {
    final th = thresholds;
    if (now < th.comparableLoadFloorAmps ||
        before < th.comparableLoadFloorAmps) {
      return false;
    }
    final bigger = math.max(now, before);
    final smaller = math.min(now, before);
    return smaller >= bigger * (1 - th.comparableLoadFraction);
  }

  CounterChanges _counters(InspectionResult now, InspectionResult? before) {
    if (before == null) return const CounterChanges();
    final th = thresholds;
    final cyclesBefore = before.reported.cycleCount;
    final cyclesNow = now.reported.cycleCount;
    final sohBefore = before.reported.soh;
    final sohNow = now.reported.soh;
    final capBefore = before.reported.configuredCapacityAh;
    final capNow = now.reported.configuredCapacityAh;

    return CounterChanges(
      cyclesFell:
          cyclesBefore != null && cyclesNow != null && cyclesNow < cyclesBefore,
      sohRose:
          sohBefore != null &&
          sohNow != null &&
          sohNow > sohBefore + th.sohRiseTolerance,
      capacityChanged:
          capBefore != null &&
          capNow != null &&
          (capNow - capBefore).abs() > th.capacityMoveAh,
      cyclesBefore: cyclesBefore,
      cyclesNow: cyclesNow,
      sohBefore: sohBefore,
      sohNow: sohNow,
      capacityBefore: capBefore,
      capacityNow: capNow,
    );
  }

  static double? _change(double? now, double? before) =>
      now == null || before == null ? null : now - before;

  static double? _fraction(double? now, double? before) =>
      now == null || before == null || before <= 0 ? null : now / before - 1;
}
