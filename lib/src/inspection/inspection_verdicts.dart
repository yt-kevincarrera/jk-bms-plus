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
    for (final a in evaluate(r)) {
      if (a.level.index > worst.index) worst = a.level;
    }
    return switch (worst) {
      AdviceLevel.problem => InspectionLight.problem,
      AdviceLevel.watch => InspectionLight.watch,
      AdviceLevel.info || AdviceLevel.good => InspectionLight.good,
    };
  }

  List<Advice> evaluate(InspectionResult r) {
    final th = thresholds;
    final out = <Advice>[];
    if (r.cells.isEmpty) return out;

    // --- Sag under the hard pull: the cell that gives up ---
    final worst = r.worstSag;
    final excess = r.worstSagExcess;
    final medianSag = r.medianHeavySagVolts;
    if (worst != null && excess != null && medianSag != null) {
      final evidence = [
        Evidence(
          EvidenceKind.cellSag,
          value: worst.heavySagVolts,
          cell: worst.index,
        ),
        Evidence(EvidenceKind.medianSag, value: medianSag),
        Evidence(EvidenceKind.currentStep, value: r.currentStepAmps),
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
      ];
      if (excess >= th.sagProblemVolts) {
        out.add(
          Advice(
            code: AdviceCode.inspectionCellSagging,
            level: AdviceLevel.problem,
            cellIndex: worst.index,
            value: excess,
            evidence: evidence,
          ),
        );
      } else if (excess >= th.sagWatchVolts) {
        out.add(
          Advice(
            code: AdviceCode.inspectionCellSagging,
            level: AdviceLevel.watch,
            cellIndex: worst.index,
            value: excess,
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
      Evidence(EvidenceKind.restingDelta, value: r.restDeltaVolts),
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
      } else {
        out.add(
          Advice(
            code: AdviceCode.inspectionRecoveryOk,
            level: AdviceLevel.good,
            value: medianRec,
            evidence: evidence,
          ),
        );
      }
    }

    // --- Right now ---
    final hot = r.maxTemperature;
    if (hot != null && hot >= th.hotCelsius) {
      out.add(
        Advice(
          code: AdviceCode.inspectionHot,
          level: AdviceLevel.watch,
          value: hot,
          evidence: [Evidence(EvidenceKind.hottestProbe, value: hot)],
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
    if (r.reported.cycleCount != null ||
        r.reported.configuredCapacityAh != null) {
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
