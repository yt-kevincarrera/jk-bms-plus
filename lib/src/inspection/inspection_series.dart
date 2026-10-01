import 'dart:math' as math;

import '../metrics/advice_engine.dart';
import 'inspection_result.dart';
import 'inspection_session.dart';

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
    this.bmsName = '',
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

  /// What the pack called itself over BLE that day. Part of matching by
  /// serial: clone boards ship with the same default serial, and a serial
  /// alone would merge two strangers' packs into one history.
  final String bmsName;
  final String note;
}

/// How much has to move before a repeat is saying something.
///
/// A second test is never a copy of the first: the load is pulled by hand,
/// the pack sits at a different charge, the weather is different. These are
/// the margins inside which two runs are the same run said twice.
class SeriesThresholds {
  const SeriesThresholds({
    this.restDeltaMoveVolts = 0.020,
    this.restDeltaSocWindow = 10,
    this.sagMoveOhms = 0.0010,
    this.resistanceMoveFraction = 0.25,
    this.comparableLoadFraction = 0.3,
    this.comparableLoadFloorAmps = 2.0,
    this.sohRiseTolerance = 0.5,
    this.capacityMoveAh = 0.5,
    this.cycleCapacityFallAh = 1.0,
    this.inspection = InspectionThresholds.defaults,
  });

  static const SeriesThresholds defaults = SeriesThresholds();

  /// A resting spread that moved by more than this is a real change.
  ///
  /// Twice what it was. The spread at rest moves with the state of charge by
  /// itself, most of all near the top and the bottom, and 10 mV between a
  /// pack at 40 % and the same pack at 90 % was enough to call it worse.
  final double restDeltaMoveVolts;

  /// The resting spread is only compared between two runs whose state of
  /// charge, as the BMS reports it, is within this many points.
  final double restDeltaSocWindow;

  /// How much the worst cell's extra resistance has to move to count, on
  /// top of what the two runs' detection floors allow for.
  final double sagMoveOhms;

  /// Estimated resistance is noisy; only a relative move this big counts.
  final double resistanceMoveFraction;

  /// Two runs are comparable when the softer pull is within this fraction of
  /// the harder one. Sag scales with current, so comparing a 40 A pull with a
  /// 12 A pull would report a pack that "improved" when nothing changed but
  /// the throttle.
  final double comparableLoadFraction;

  /// Below this the pull is no load at all and its sag is not worth
  /// comparing either way.
  ///
  /// The hard pull's own floor (3 A) less the most a pack may draw and still
  /// be at rest (1 A), so that any run which passed the heavy step clears
  /// it. It used to be 5 A, above the 4 A a 40 Ah pack is asked for, so two
  /// identical 4.2 A pulls were always "not pulled alike".
  final double comparableLoadFloorAmps;

  /// State of health wobbles by rounding; only a rise beyond this is a reset.
  final double sohRiseTolerance;

  /// Configured capacity is a whole setting; this much movement is a change.
  final double capacityMoveAh;

  /// The amp-hours a BMS has counted through the pack only go up. A fall
  /// bigger than its rounding is a counter that was reset or a different BMS.
  final double cycleCapacityFallAh;

  /// The single-run lines, for the same-cell rule: a cell is only "the same
  /// bad cell again" when it was past the single-run watch line both times.
  final InspectionThresholds inspection;
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
    this.cycleCapacityFell = false,
    this.sohRose = false,
    this.capacityChanged = false,
    this.cyclesBefore,
    this.cyclesNow,
    this.sohBefore,
    this.sohNow,
    this.capacityBefore,
    this.capacityNow,
    this.cycleCapacityBefore,
    this.cycleCapacityNow,
  });

  final bool cyclesFell;
  final bool cycleCapacityFell;
  final bool sohRose;
  final bool capacityChanged;

  final int? cyclesBefore;
  final int? cyclesNow;
  final double? sohBefore;
  final double? sohNow;
  final double? capacityBefore;
  final double? capacityNow;
  final double? cycleCapacityBefore;
  final double? cycleCapacityNow;

  /// A counter that only goes up went down: reset, or a different BMS.
  bool get reset => cyclesFell || cycleCapacityFell;

  /// A setting changed, or the health figure went up. Both happen without
  /// anybody hiding anything: an owner correcting the capacity, a firmware
  /// recomputing its health. Worth asking about, not an accusation.
  bool get reconfigured => sohRose || capacityChanged;

  bool get anything => reset || reconfigured;
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
    this.excessOhmsChange,
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

  /// How many runs in the series, this one included, found [worstCellNow]
  /// past the watch line at a load comparable to this one. The number that
  /// turns a suspicion into a finding. Zero when this run's worst cell is
  /// not past the line itself: the weakest of twenty even cells is whichever
  /// one the noise picked.
  final int timesSameWorstCell;

  /// Positive means worse than the previous run.
  ///
  /// Null when the two are not comparable: the resting spread when the state
  /// of charge differed or either rest was noisy, the sag when the loads
  /// differed.
  final double? restDeltaChange;
  final double? sagExcessChange;

  /// The worst cell's extra resistance, this run less the previous one.
  final double? excessOhmsChange;

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
  /// pack met on a different address, and it is a narrow one: plenty of BMS
  /// units report an empty serial, and clone boards share a default one, so
  /// a serial alone would merge strangers' packs into one battery with a
  /// very strange history. It only counts when it looks like a real serial
  /// and the pack also gave the same name.
  static List<PastInspection> forPack(
    Iterable<PastInspection> all, {
    required String bmsId,
    String serialNumber = '',
    String bmsName = '',
    DateTime? before,
    int? excludeId,
  }) {
    final out = [
      for (final p in all)
        if (p.id == null || p.id != excludeId)
          if (before == null || p.at.isBefore(before))
            if (samePack(
              p,
              bmsId: bmsId,
              serialNumber: serialNumber,
              bmsName: bmsName,
            ))
              p,
    ]..sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  /// Whether [p] was a run on the pack at [bmsId] with this serial and name.
  static bool samePack(
    PastInspection p, {
    required String bmsId,
    String serialNumber = '',
    String bmsName = '',
  }) => sameIdentity(
    bmsId: bmsId,
    serialNumber: serialNumber,
    bmsName: bmsName,
    otherBmsId: p.bmsId,
    otherSerialNumber: p.result.reported.serialNumber,
    otherBmsName: p.bmsName,
  );

  /// The matching rule itself, on the three things a stored row carries.
  static bool sameIdentity({
    required String bmsId,
    required String serialNumber,
    required String bmsName,
    required String otherBmsId,
    required String otherSerialNumber,
    required String otherBmsName,
  }) =>
      otherBmsId == bmsId ||
      (looksLikeRealSerial(serialNumber) &&
          otherSerialNumber.trim() == serialNumber.trim() &&
          otherBmsName.trim() == bmsName.trim());

  /// A serial worth matching on: not empty, not a run of one character
  /// ("000000", "FFFFFFFF"), and long enough to be more than a placeholder.
  static bool looksLikeRealSerial(String serial) {
    final s = serial.trim();
    if (s.length < 4) return false;
    if (!RegExp(r'[A-Za-z0-9]').hasMatch(s)) return false;
    return s.split('').toSet().length > 1;
  }

  InspectionComparison compare(
    InspectionResult result,
    List<PastInspection> earlier,
  ) {
    final sorted = [...earlier]..sort((a, b) => a.at.compareTo(b.at));
    final previous = sorted.isEmpty ? null : sorted.last;

    final worstNow = result.worstSag?.index;
    final worstBefore = previous?.result.worstSag?.index;

    // How many runs, this one included, found the cell this run finds, past
    // the line and at a comparable pull. A cell named once is a reading;
    // named three times it is the cell. Not merely the cell with the most
    // sag: on an even pack that is whichever one the noise picked, and two
    // even runs used to "find the same bad cell again" by coincidence.
    var sameCell = 0;
    if (worstNow != null && _pastWatch(result)) {
      sameCell = 1;
      for (final p in sorted) {
        if (p.result.worstSag?.index == worstNow &&
            _pastWatch(p.result) &&
            _comparableLoad(result.currentStepAmps, p.result.currentStepAmps)) {
          sameCell++;
        }
      }
    }

    final comparable =
        previous != null &&
        _comparableLoad(
          result.currentStepAmps,
          previous.result.currentStepAmps,
        );
    final restComparable =
        previous != null && _comparableRest(result, previous.result);

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
      restDeltaChange: !restComparable
          ? null
          : result.restDeltaVolts - previous.result.restDeltaVolts,
      sagExcessChange: !comparable
          ? null
          : _change(result.worstSagExcess, previous.result.worstSagExcess),
      excessOhmsChange: !comparable
          ? null
          : _change(result.worstExcessOhms, previous.result.worstExcessOhms),
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

    // --- The counters went backwards between visits ---
    //
    // Watch, not problem. A counter that only goes up went down, and a reset
    // between two viewings is worth asking about, but so is a BMS that was
    // replaced, and the physics on this sheet does not depend on either.
    final counters = c.counters;
    if (counters.reset) {
      out.add(
        Advice(
          code: AdviceCode.inspectionRepeatCountersReset,
          level: AdviceLevel.watch,
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
            if (counters.cycleCapacityFell &&
                counters.cycleCapacityBefore != null)
              Evidence(
                EvidenceKind.previousCycleCapacity,
                value: counters.cycleCapacityBefore,
                at: previous.at,
              ),
            if (counters.cycleCapacityFell && counters.cycleCapacityNow != null)
              Evidence(
                EvidenceKind.cycleCapacity,
                value: counters.cycleCapacityNow,
              ),
          ],
        ),
      );
    }

    // --- A setting changed, or health went up ---
    //
    // It used to be the same accusation as a reset. An owner correcting the
    // capacity setting, or a firmware recomputing its health, is neither.
    if (counters.reconfigured) {
      out.add(
        Advice(
          code: AdviceCode.inspectionRepeatConfigChanged,
          level: AdviceLevel.watch,
          evidence: [
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
        c.worstCellBefore != worstNow &&
        (_pastWatch(c.result) || _pastWatch(previous.result))) {
      // A different cell each time is not two faults. It is one measurement
      // that is not measuring what it looks like, most often because the two
      // runs were not pulled the same way. Only said when one of the two was
      // a finding at all: on an even pack the "worst" cell moving is noise.
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
    final sagMove = c.excessOhmsChange ?? 0;
    final resistanceMove = c.resistanceChangeFraction ?? 0;
    // What the two pulls could resolve, added: a move smaller than the two
    // runs' own noise is not a move.
    final resolution = th.inspection.sagResolutionVolts;
    final sagNoise =
        (c.result.detectionFloorOhms(resolution) ?? 0) +
        (previous.result.detectionFloorOhms(resolution) ?? 0);
    final sagLine = math.max(th.sagMoveOhms, sagNoise);
    final worse =
        restMove > th.restDeltaMoveVolts ||
        sagMove > sagLine ||
        resistanceMove > th.resistanceMoveFraction;
    final better =
        restMove < -th.restDeltaMoveVolts ||
        sagMove < -sagLine ||
        resistanceMove < -th.resistanceMoveFraction;

    if (worse) {
      // Watch: two runs that differ point at a change, and a third run is
      // what would confirm it.
      out.add(
        Advice(
          code: AdviceCode.inspectionRepeatWorse,
          level: AdviceLevel.watch,
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
    Evidence(EvidenceKind.inspectionRestDelta, value: c.result.restDeltaVolts),
    Evidence(
      EvidenceKind.previousRestDelta,
      value: previous.result.restDeltaVolts,
      at: previous.at,
    ),
    if (c.result.reported.soc != null)
      Evidence(EvidenceKind.reportedSoc, value: c.result.reported.soc),
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

  /// Past the single-run watch line, and past the floor of its own pull.
  bool _pastWatch(InspectionResult r) {
    final excess = r.worstExcessOhms;
    if (excess == null) return false;
    final floor = r.detectionFloorOhms(
      thresholds.inspection.sagResolutionVolts,
    );
    return excess >= math.max(thresholds.inspection.sagWatchOhms, floor ?? 0);
  }

  /// Whether two resting spreads can be set side by side.
  ///
  /// The spread at rest depends on the state of charge: cells pull apart near
  /// full and near empty without anything being wrong. So only two rests at a
  /// similar charge, and both actually quiet.
  bool _comparableRest(InspectionResult now, InspectionResult before) {
    final a = now.reported.soc;
    final b = before.reported.soc;
    if (a == null || b == null) return false;
    if ((a - b).abs() > thresholds.restDeltaSocWindow) return false;
    return !now.caveats.contains(InspectionCaveat.restNoisy) &&
        !before.caveats.contains(InspectionCaveat.restNoisy);
  }

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
    final cycAhBefore = before.reported.cycleCapacityAh;
    final cycAhNow = now.reported.cycleCapacityAh;

    return CounterChanges(
      cyclesFell:
          cyclesBefore != null && cyclesNow != null && cyclesNow < cyclesBefore,
      cycleCapacityFell:
          cycAhBefore != null &&
          cycAhNow != null &&
          cycAhNow < cycAhBefore - th.cycleCapacityFallAh,
      cycleCapacityBefore: cycAhBefore,
      cycleCapacityNow: cycAhNow,
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
