import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../bms_service.dart';
import '../../data/database.dart';
import '../../inspection/inspection_result.dart';
import '../../inspection/inspection_session.dart';
import '../../inspection/inspection_verdicts.dart';
import '../../license/entitlements.dart';
import '../license_scope.dart';
import '../theme.dart';
import '../widgets/advice_list.dart';
import '../widgets/common.dart';

/// The traffic light, three sentences, the fidelity, and a save button.
///
/// Opened straight after a test, or from the list of saved inspections. The
/// same screen either way, so what the buyer saw in the yard is exactly what
/// they reread at home. It says "quick test" and "estimate" in so many words:
/// the PRD's one reputational risk is this screen promising more than the
/// two minutes it rests on.
class InspectionVerdictScreen extends StatefulWidget {
  const InspectionVerdictScreen({
    required this.service,
    required this.result,
    required this.samples,
    required this.bmsId,
    required this.bmsName,
    this.savedId,
    this.initialNote = '',
    super.key,
  });

  final BmsService service;
  final InspectionResult result;
  final List<InspectionSample> samples;
  final String bmsId;
  final String bmsName;

  /// Set when this is a saved inspection being reread.
  final int? savedId;
  final String initialNote;

  @override
  State<InspectionVerdictScreen> createState() =>
      _InspectionVerdictScreenState();
}

class _InspectionVerdictScreenState extends State<InspectionVerdictScreen> {
  static const _verdicts = InspectionVerdicts();
  late final TextEditingController _note = TextEditingController(
    text: widget.initialNote,
  );
  bool _saving = false;
  int? _savedId;

  @override
  void initState() {
    super.initState();
    _savedId = widget.savedId;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _isSaved => _savedId != null;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final r = widget.result;
    final light = _verdicts.light(r);
    final advice = _verdicts.evaluate(r);
    final (headline, tone) = switch (light) {
      InspectionLight.good => (t.inspectionLightGood, AppTheme.good),
      InspectionLight.watch => (t.inspectionLightWatch, AppTheme.watch),
      InspectionLight.problem => (t.inspectionLightProblem, AppTheme.bad),
    };

    return Scaffold(
      appBar: AppBar(title: Text(t.inspectionTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 4, bottom: 28),
          children: [
            // --- The light ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.inspectionQuickTestLabel,
                    style: AppTheme.caption(
                      context,
                    ).copyWith(color: AppTheme.textFaint),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.only(top: 7),
                        decoration: BoxDecoration(
                          color: tone,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          headline,
                          style: TextStyle(
                            fontSize: 24,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            color: tone,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _headerLine(t, r),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textFaint,
                      fontFeatures: AppTheme.tabular,
                    ),
                  ),
                ],
              ),
            ),
            AdviceList(
              advice: advice,
              title: t.verdictTitle,
              showHonestyNote: false,
            ),
            if (r.caveats.isNotEmpty)
              Section(
                title: t.inspectionCaveatsTitle,
                accent: AppTheme.watch,
                children: [
                  for (final c in r.caveats)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        _caveat(t, c),
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                ],
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
              child: Text(
                t.inspectionFidelityNote,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: AppTheme.textFaint,
                ),
              ),
            ),
            _cellsSection(t, r),
            _reportedSection(t, r),
            Section(
              title: t.inspectionsTitle,
              children: [
                TextField(
                  controller: _note,
                  minLines: 1,
                  maxLines: 3,
                  readOnly: _isSaved,
                  decoration: InputDecoration(
                    hintText: t.inspectionNoteHint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13.5),
                ),
                const SizedBox(height: 12),
                if (!_isSaved) ...[
                  _creditsLine(t),
                  FilledButton.icon(
                    onPressed: _saving ? null : () => _save(t),
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: Text(t.inspectionSave),
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(t.inspectionDiscard),
                  ),
                ] else
                  Text(
                    t.inspectionSaved,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.good,
                    ),
                  ),
                const SizedBox(height: 6),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _headerLine(AppL10n t, InspectionResult r) {
    final name = widget.bmsName.isEmpty ? widget.bmsId : widget.bmsName;
    final model = r.reported.model;
    final who = model.isEmpty ? name : '$name · $model';
    return '$who\n${_date(r.at)}  ·  '
        '${t.inspectionSummaryLine('${r.cellCount}', r.peakDischargeAmps.toStringAsFixed(0), '${r.durationSeconds}', '${r.readings}')}';
  }

  Widget _creditsLine(AppL10n t) {
    final e = LicenseScope.entitlements(context);
    if (e.isWorkshop) return const SizedBox.shrink();
    if (!e.allows(Feature.inspection)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          t.inspectionCreditsGone,
          style: const TextStyle(fontSize: 12, color: AppTheme.watch),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        t.inspectionCreditsLeft('${e.inspectionCreditsLeft}'),
        style: const TextStyle(fontSize: 12, color: AppTheme.textFaint),
      ),
    );
  }

  Future<void> _save(AppL10n t) async {
    final repo = widget.service.repository;
    if (repo == null) return;
    setState(() => _saving = true);

    // The credit is spent on saving, not on looking: a test that was aborted
    // or came out with nothing measured costs nothing. The workshop tier and
    // a build with licensing off never spend.
    final license = LicenseScope.of(context);
    final ok = await license.consumeInspection();
    if (!ok) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.inspectionCreditsGone)));
      }
      return;
    }

    final r = widget.result;
    final id = await repo.saveInspection(
      InspectionsCompanion.insert(
        at: r.at,
        bmsId: widget.bmsId,
        bmsName: Value(widget.bmsName),
        model: Value(r.reported.model),
        serialNumber: Value(r.reported.serialNumber),
        light: _verdicts.light(r).name,
        resultJson: jsonEncode(r.toJson()),
        samplesJson: jsonEncode([for (final s in widget.samples) s.toJson()]),
        note: Value(_note.text.trim()),
      ),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _savedId = id;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t.inspectionSaved)));
  }

  Widget _cellsSection(AppL10n t, InspectionResult r) {
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
            Expanded(child: Text(t.inspectionCellHeaderSag, style: label)),
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
                  child: Text(
                    '${c.restVolts.toStringAsFixed(3)} V',
                    style: cell,
                  ),
                ),
                Expanded(
                  child: Text(
                    c.heavySagVolts == null
                        ? '--'
                        : '${(c.heavySagVolts! * 1000).toStringAsFixed(0)} mV',
                    style: cell.copyWith(
                      color:
                          c.index == worstSag &&
                              (r.worstSagExcess ?? 0) >=
                                  _verdicts.thresholds.sagWatchVolts
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
                    c.recoverySeconds == null
                        ? '--'
                        : c.recovered
                        ? '${c.recoverySeconds!.toStringAsFixed(0)} s'
                        : '> ${c.recoverySeconds!.toStringAsFixed(0)} s',
                    style: cell.copyWith(
                      color:
                          slow != null && slow.index == c.index && !c.recovered
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

  Widget _reportedSection(AppL10n t, InspectionResult r) {
    final rep = r.reported;
    return Section(
      title: t.inspectionReportedTitle,
      intro: t.inspectionReportedHint,
      accent: AppTheme.textFaint,
      children: [
        if (rep.model.isNotEmpty) InfoRow(t.inspectionReportedModel, rep.model),
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

  static String _caveat(AppL10n t, InspectionCaveat c) => switch (c) {
    InspectionCaveat.noHeavyLoad => t.inspectionCaveatNoHeavyLoad,
    InspectionCaveat.noLightLoad => t.inspectionCaveatNoLightLoad,
    InspectionCaveat.restNoisy => t.inspectionCaveatRestNoisy,
    InspectionCaveat.noRecovery => t.inspectionCaveatNoRecovery,
    InspectionCaveat.currentStepTooSmall => t.inspectionCaveatStepTooSmall,
    InspectionCaveat.fewReadings => t.inspectionCaveatFewReadings,
  };

  static String _date(DateTime utc) {
    final d = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }
}
