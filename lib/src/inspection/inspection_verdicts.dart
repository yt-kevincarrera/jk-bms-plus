import 'dart:math' as math;

import '../metrics/advice_engine.dart';
import 'inspection_result.dart';
import 'inspection_session.dart';

/// Turns an [InspectionResult] into the sentences on the verdict screen.
///
/// Same shape as everything else the app says: an [Advice] with a level and
/// the measured facts behind it, so the verdict screen and the saved report
/// use the very same list widget the Health tab does, and every sentence can
/// answer "why" on a tap.
///
/// The PRD's rule holds throughout: the physics (sag, recovery, resting
/// spread) is what the verdict rests on. The counters the BMS reports are
/// shown, marked as editable, and never trusted on their own.
class InspectionVerdicts {
  const InspectionVerdicts({this.thresholds = InspectionThresholds.defaults});

  final InspectionThresholds thresholds;

  /// The traffic light: the worst level among the physical findings.
  InspectionLight light(InspectionResult r) {
    var worst = AdviceLevel.good;
    var unresolved = false;
    for (final a in evaluate(r)) {
      if (a.level.index > worst.index) worst = a.level;
      if (a.code == AdviceCode.inspectionSagUnresolved) unresolved = true;
    }
    // Anything actually found still gets said, whatever else was missed: a
    // cell that is far out at rest is a finding even with no load behind it,
    // and burying it because the pull never happened would be its own kind of
    // dishonesty.
    if (worst == AdviceLevel.problem) return InspectionLight.problem;
    if (worst == AdviceLevel.watch) return InspectionLight.watch;

    // Nothing found. Whether that means anything depends entirely on whether
    // there was anything to find it in. Per-cell sag under load is where this
    // test gets its answer; with no sag captured, "nothing found" is a fact
    // about the test rather than about the pack.
    if (!r.hasHeavyLoad || r.medianHeavySagVolts == null) {
      return InspectionLight.unmeasured;
    }
    // A load arrived, but too little of one to see a fault of the size this
    // test exists to find. Even cells at 3 A say nothing about a cell that
    // would only stand out at 10.
    if (unresolved) return InspectionLight.unmeasured;
    return InspectionLight.good;
  }

  /// Whether the test loaded the pack, just not hard enough to rule a bad
  /// cell out. The screens say this rather than "the pack was never loaded".
  bool loadTooSmall(InspectionResult r) =>
      evaluate(r).any((a) => a.code == AdviceCode.inspectionSagUnresolved);

  /// Whether the pull was big enough for recovery times to tell a tired cell
  /// from a good one. Unknown capacity counts as not: the claim needs a
  /// reason to be made, not a reason to be withheld.
  bool recoveryDiscriminates(InspectionResult r) {
    final capacity = r.reported.configuredCapacityAh;
    if (capacity == null || capacity <= 0) return false;
    return r.currentStepAmps >=
        thresholds.recoveryDiscriminatesCRate * capacity;
  }

  List<Advice> evaluate(InspectionResult r) {
    final th = thresholds;
    final out = <Advice>[];
    if (r.cells.isEmpty) return out;

    // --- Sag under the hard pull: the cell that gives up ---
    //
    // Judged as a resistance, not as millivolts. The extra sag of the worst
    // cell is divided by the current it was pulled at, so a 4 A pull and a
    // 40 A pull are held to the same standard, and the current also sets how
    // small a fault the test could have seen at all. When that floor is above
    // the line a finding is drawn at, the cells moving together proves
    // nothing, and the verdict says so instead of coming out green.
    final worst = r.worstSag;
    final excess = r.worstSagExcess;
    final medianSag = r.medianHeavySagVolts;
    final excessOhms = r.worstExcessOhms;
    final floor = r.detectionFloorOhms(th.sagResolutionVolts);
    if (worst != null &&
        excess != null &&
        medianSag != null &&
        excessOhms != null &&
        floor != null) {
      final evidence = [
        Evidence(
          EvidenceKind.cellSag,
          value: worst.heavySagVolts,
          cell: worst.index,
        ),
        Evidence(EvidenceKind.medianSag, value: medianSag),
        Evidence(EvidenceKind.currentStep, value: r.currentStepAmps),
        Evidence(
          EvidenceKind.excessResistance,
          value: excessOhms,
          cell: worst.index,
        ),
        Evidence(EvidenceKind.detectionFloor, value: floor),
        if (worst.resistanceOhms != null)
          Evidence(
            EvidenceKind.cellResistance,
            value: worst.resistanceOhms,
            cell: worst.index,
          ),
        if (r.medianResistanceOhms != null)
          Evidence(
            EvidenceKind.medianResistance,
            value: r.medianResistanceOhms,
          ),
        if (r.heavyWasCharge) const Evidence(EvidenceKind.loadWasCharge),
      ];
      if (excessOhms >= math.max(th.sagProblemOhms, floor)) {
        out.add(
          Advice(
            code: AdviceCode.inspectionCellSagging,
            level: AdviceLevel.problem,
            cellIndex: worst.index,
            value: excess,
            evidence: evidence,
          ),
        );
      } else if (excessOhms >= math.max(th.sagWatchOhms, floor)) {
        out.add(
          Advice(
            code: AdviceCode.inspectionCellSagging,
            level: AdviceLevel.watch,
            cellIndex: worst.index,
            value: excess,
            evidence: evidence,
          ),
        );
      } else if (floor > th.sagWatchOhms) {
        out.add(
          Advice(
            code: AdviceCode.inspectionSagUnresolved,
            level: AdviceLevel.info,
            value: floor,
            evidence: evidence,
          ),
        );
      } else {
        out.add(
          Advice(
            code: AdviceCode.inspectionSagUniform,
            level: AdviceLevel.good,
            value: excess,
            evidence: evidence,
          ),
        );
      }
    }

    // --- Spread at rest ---
    final restEvidence = [
      Evidence(EvidenceKind.inspectionRestDelta, value: r.restDeltaVolts),
      Evidence(
        EvidenceKind.lowestRestCell,
        value: r.cells.firstWhere((c) => c.index == r.lowestRestCell).restVolts,
        cell: r.lowestRestCell,
      ),
    ];
    if (r.restDeltaVolts >= th.restDeltaProblemVolts) {
      out.add(
        Advice(
          code: AdviceCode.inspectionRestDeltaWide,
          level: AdviceLevel.problem,
          cellIndex: r.lowestRestCell,
          value: r.restDeltaVolts,
          evidence: restEvidence,
        ),
      );
    } else if (r.restDeltaVolts >= th.restDeltaWatchVolts) {
      out.add(
        Advice(
          code: AdviceCode.inspectionRestDeltaWide,
          level: AdviceLevel.watch,
          cellIndex: r.lowestRestCell,
          value: r.restDeltaVolts,
          evidence: restEvidence,
        ),
      );
    } else if (!r.caveats.contains(InspectionCaveat.restNoisy)) {
      out.add(
        Advice(
          code: AdviceCode.inspectionRestDeltaOk,
          level: AdviceLevel.good,
          value: r.restDeltaVolts,
          evidence: restEvidence,
        ),
      );
    }

    // --- A cell that gives up with only the lights on ---
    final light = r.cells.where((c) => c.lightSagVolts != null).toList();
    if (light.isNotEmpty && r.lightLoadAmps != null) {
      final sags = light.map((c) => c.lightSagVolts!).toList()..sort();
      final median = sags[sags.length ~/ 2];
      final weak = light.reduce(
        (a, b) => a.lightSagVolts! >= b.lightSagVolts! ? a : b,
      );
      if (weak.lightSagVolts! - median >= th.lightSagWatchVolts) {
        out.add(
          Advice(
            code: AdviceCode.inspectionWeakUnderLightLoad,
            level: AdviceLevel.watch,
            cellIndex: weak.index,
            value: weak.lightSagVolts! - median,
            evidence: [
              Evidence(
                EvidenceKind.cellSag,
                value: weak.lightSagVolts,
                cell: weak.index,
              ),
              Evidence(EvidenceKind.lightLoadAmps, value: r.lightLoadAmps),
            ],
          ),
        );
      }
    }

    // --- Recovery: the tired cell rebounds slowly ---
    final slow = r.slowestRecovery;
    final medianRec = r.medianRecoverySeconds;
    if (slow != null && medianRec != null) {
      final extra = slow.recoverySeconds! - medianRec;
      final evidence = [
        Evidence(
          EvidenceKind.recoverySeconds,
          value: slow.recoverySeconds,
          cell: slow.index,
        ),
        Evidence(EvidenceKind.medianRecoverySeconds, value: medianRec),
        Evidence(EvidenceKind.currentStep, value: r.currentStepAmps),
      ];
      if (!slow.recovered || extra >= th.recoverySlowSeconds) {
        out.add(
          Advice(
            code: AdviceCode.inspectionSlowRecovery,
            level: AdviceLevel.watch,
            cellIndex: slow.index,
            value: extra,
            evidence: evidence,
          ),
        );
      } else if (recoveryDiscriminates(r)) {
        out.add(
          Advice(
            code: AdviceCode.inspectionRecoveryOk,
            level: AdviceLevel.good,
            value: medianRec,
            evidence: evidence,
          ),
        );
      } else {
        // At a few amps every cell, tired or not, is back within millivolts
        // almost at once. Calling that an even recovery would be praise for
        // something the test could not have failed.
        out.add(
          Advice(
            code: AdviceCode.inspectionRecoveryNotDiscriminating,
            level: AdviceLevel.info,
            value: medianRec,
            evidence: evidence,
          ),
        );
      }
    }

    // --- Right now ---
    final hot = r.maxTemperature;
    if (hot != null && hot >= th.hotCelsius) {
      final when = r.maxTemperatureStep;
      out.add(
        Advice(
          code: AdviceCode.inspectionHot,
          level: AdviceLevel.watch,
          value: hot,
          evidence: [
            Evidence(EvidenceKind.hottestProbe, value: hot),
            // When it was seen decides what it means: hot with nothing drawn
            // is one thing, hot straight after a hard pull is another.
            if (when != null)
              Evidence(
                EvidenceKind.seenDuringStep,
                value: when.index.toDouble(),
              ),
          ],
        ),
      );
    }
    if (r.faultsSeen.isNotEmpty) {
      out.add(
        Advice(
          code: AdviceCode.inspectionAlarmsSeen,
          level: AdviceLevel.watch,
          value: r.faultsSeen.length.toDouble(),
          evidence: [
            Evidence(
              EvidenceKind.alarmCount,
              value: r.faultsSeen.length.toDouble(),
            ),
          ],
        ),
      );
    }

    // --- The figures nobody should believe ---
    //
    // Cycles and configured capacity are typed into the BMS from the official
    // app. A vendor can set cycles to 3 and capacity to 45 Ah in a minute.
    // Shown, marked, and set against what was actually measured above.
    //
    // Only when there is a cycle count to distrust. An ANT keeps none, and
    // this used to fire on its capacity alone and tell the rider "the BMS
    // reports -- cycles", a sentence about a number that does not exist.
    if (r.reported.cycleCount != null) {
      out.add(
        Advice(
          code: AdviceCode.inspectionCountersEditable,
          level: AdviceLevel.info,
          value: r.reported.cycleCount?.toDouble(),
          evidence: [
            if (r.reported.cycleCount != null)
              Evidence(
                EvidenceKind.reportedCycles,
                value: r.reported.cycleCount!.toDouble(),
              ),
            if (r.reported.configuredCapacityAh != null)
              Evidence(
                EvidenceKind.impliedCapacity,
                value: r.reported.configuredCapacityAh,
              ),
            if (r.reported.soh != null)
              Evidence(EvidenceKind.reportedSoh, value: r.reported.soh),
          ],
        ),
      );
    }

    // --- What this test could not see ---
    if (r.caveats.contains(InspectionCaveat.noHeavyLoad)) {
      out.add(
        Advice(
          code: AdviceCode.inspectionNoHeavyLoad,
          level: AdviceLevel.info,
          value: r.peakDischargeAmps,
          evidence: [
            Evidence(EvidenceKind.peakCurrent, value: r.peakDischargeAmps),
          ],
        ),
      );
    }

    out.sort((a, b) => b.level.index.compareTo(a.level.index));
    return out;
  }
}
