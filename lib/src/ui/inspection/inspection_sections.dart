import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../inspection/inspection_result.dart';
import '../../inspection/inspection_verdicts.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'inspection_texts.dart';

/// The blocks of an inspection that the verdict screen and the certificate
/// checker both show.
///
/// The checker used to show three figures and tint a border, and its intro
/// promised "exactly the figures that were signed". These are the same
/// widgets the person who ran the test saw, built from the same signed
/// result, so the promise holds.

/// What the test could not see.
Widget inspectionCaveatsSection(AppL10n t, InspectionResult r) {
  if (r.caveats.isEmpty) return const SizedBox.shrink();
  return Section(
    title: t.inspectionCaveatsTitle,
    accent: AppTheme.watch,
    children: [
      for (final c in r.caveats)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            inspectionCaveatText(t, c),
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      const SizedBox(height: 4),
    ],
  );
}

/// One row per cell: rest, the excursion under load, resistance, recovery.
Widget inspectionCellsSection(
  AppL10n t,
  InspectionResult r, {
  InspectionVerdicts verdicts = const InspectionVerdicts(),
}) {
  if (r.cells.isEmpty) return const SizedBox.shrink();
  final worstSag = r.worstSag?.index;
  final slow = r.slowestRecovery;
  const label = TextStyle(fontSize: 10.5, color: AppTheme.textFaint);
  const cell = TextStyle(
    fontSize: 12,
    fontFeatures: AppTheme.tabular,
    color: AppTheme.textSecondary,
  );
  return Section(
    title: t.inspectionCellsTitle,
    children: [
      Row(
        children: [
          const SizedBox(width: 30, child: Text('#', style: label)),
          Expanded(child: Text(t.inspectionCellHeaderRest, style: label)),
          // Under a charger the cells rose. "Sag" over a column of rises is
          // a heading that says the opposite of the numbers under it.
          Expanded(
            child: Text(
              r.heavyWasCharge
                  ? t.inspectionCellHeaderChange
                  : t.inspectionCellHeaderSag,
              style: label,
            ),
          ),
          Expanded(child: Text(t.inspectionCellHeaderIr, style: label)),
          Expanded(child: Text(t.inspectionCellHeaderRec, style: label)),
        ],
      ),
      const SizedBox(height: 4),
      for (final c in r.cells)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  '${c.index}',
                  style: cell.copyWith(
                    color: c.index == worstSag && r.worstSagExcess != null
                        ? AppTheme.watch
                        : AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text('${c.restVolts.toStringAsFixed(3)} V', style: cell),
              ),
              Expanded(
                child: Text(
                  c.heavySagVolts == null
                      ? '--'
                      : '${(c.heavySagVolts! * 1000).toStringAsFixed(0)} mV',
                  style: cell.copyWith(
                    color:
                        c.index == worstSag &&
                            (r.worstExcessOhms ?? 0) >=
                                verdicts.thresholds.sagWatchOhms
                        ? AppTheme.watch
                        : null,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  c.resistanceOhms == null
                      ? '--'
                      : '${(c.resistanceOhms! * 1000).toStringAsFixed(1)} mΩ',
                  style: cell,
                ),
              ),
              Expanded(
                child: Text(
                  inspectionRecoveryCell(t, c, digits: 0),
                  style: cell.copyWith(
                    color: slow != null && slow.index == c.index && !c.recovered
                        ? AppTheme.watch
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 6),
    ],
  );
}

/// What the BMS says about itself, marked as editable.
Widget inspectionReportedSection(AppL10n t, InspectionResult r) {
  final rep = r.reported;
  return Section(
    title: t.inspectionReportedTitle,
    intro: t.inspectionReportedHint,
    accent: AppTheme.textFaint,
    children: [
      if (rep.model.isNotEmpty) InfoRow(t.inspectionReportedModel, rep.model),
      if (rep.serialNumber.isNotEmpty)
        InfoRow(t.reportSerial, rep.serialNumber),
      InfoRow(
        t.inspectionReportedCycles,
        rep.cycleCount?.toString() ?? '--',
        dim: rep.cycleCount == null,
      ),
      InfoRow(
        t.inspectionReportedCapacity,
        rep.configuredCapacityAh == null
            ? '--'
            : '${rep.configuredCapacityAh!.toStringAsFixed(0)} Ah',
        dim: rep.configuredCapacityAh == null,
      ),
      InfoRow(
        t.inspectionReportedSoc,
        rep.soc == null ? '--' : '${rep.soc!.toStringAsFixed(0)} %',
        dim: rep.soc == null,
      ),
      InfoRow(
        t.inspectionReportedSoh,
        rep.soh == null ? '--' : '${rep.soh!.toStringAsFixed(0)} %',
        dim: rep.soh == null,
        last: true,
      ),
    ],
  );
}

/// The loud line a run against the app's own simulator carries everywhere
/// it is shown. A rehearsal produces a perfectly ordinary looking result.
Widget inspectionSimulatedBanner(String text) => Padding(
  padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
  child: Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.bad.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.bad),
    ),
    child: Row(
      children: [
        const Icon(Icons.science_outlined, color: AppTheme.bad),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: AppTheme.bad,
            ),
          ),
        ),
      ],
    ),
  ),
);
