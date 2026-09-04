import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../bms_service.dart';
import '../../data/database.dart';
import '../../inspection/inspection_result.dart';
import '../../inspection/inspection_session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'inspection_verdict_screen.dart';

/// Every quick test the rider has run on somebody else's pack, newest first.
///
/// Not a list of batteries: the packs here were looked at, not adopted, and
/// nothing about them lives anywhere else in the app.
class InspectionsListScreen extends StatelessWidget {
  const InspectionsListScreen({required this.service, super.key});

  final BmsService service;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final repo = service.repository;

    return Scaffold(
      appBar: AppBar(title: Text(t.inspectionsTitle)),
      body: SafeArea(
        child: repo == null
            ? _empty(t)
            : StreamBuilder<List<Inspection>>(
                stream: repo.watchInspections(),
                builder: (context, snapshot) {
                  final rows = snapshot.data ?? const <Inspection>[];
                  if (rows.isEmpty) return _empty(t);
                  // Which run of that pack each row is. The list is newest
                  // first and a pack can appear several times; the number is
                  // what tells a second opinion from a first look.
                  final runs = _runNumbers(rows);
                  return ListView(
                    padding: const EdgeInsets.only(top: 8, bottom: 28),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                        child: Text(
                          t.inspectionsIntro,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      for (final row in rows)
                        _tile(context, t, row, runs[row.id]),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _empty(AppL10n t) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.fact_check_outlined,
            size: 40,
            color: AppTheme.textFaint,
          ),
          const SizedBox(height: 16),
          Text(
            t.inspectionsEmpty,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _tile(
    BuildContext context,
    AppL10n t,
    Inspection row,
    (int, int)? run,
  ) {
    final tone = switch (row.light) {
      'problem' => AppTheme.bad,
      'watch' => AppTheme.watch,
      _ => AppTheme.good,
    };
    final name = row.bmsName.isEmpty ? row.bmsId : row.bmsName;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Dismissible(
        key: ValueKey('inspection-${row.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppTheme.bad.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.delete_outline, color: AppTheme.bad),
        ),
        confirmDismiss: (_) => _confirmDelete(context, t),
        onDismissed: (_) async {
          await service.repository?.deleteInspection(row.id);
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t.inspectionDeleted)));
        },
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _open(context, row),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceRaised,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.hairline),
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: tone,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.model.isEmpty ? name : '$name · ${row.model}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          _date(row.at),
                          if (run != null && run.$2 > 1)
                            t.inspectionSeriesRun('${run.$1}', '${run.$2}'),
                          if (row.note.isNotEmpty) row.note,
                        ].join('  ·  '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                Pill(switch (row.light) {
                  'problem' => t.inspectionLightProblem,
                  'watch' => t.inspectionLightWatch,
                  _ => t.inspectionLightGood,
                }, color: tone),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// For each row, which run of that pack it is and how many there are.
  ///
  /// Grouped by address rather than by serial: this is a label on a list, and
  /// a wrong grouping here would quietly merge two packs in front of the
  /// person trying to tell them apart.
  static Map<int, (int, int)> _runNumbers(List<Inspection> rows) {
    final byPack = <String, List<Inspection>>{};
    for (final row in rows) {
      byPack.putIfAbsent(row.bmsId, () => []).add(row);
    }
    final out = <int, (int, int)>{};
    for (final group in byPack.values) {
      final ordered = [...group]..sort((a, b) => a.at.compareTo(b.at));
      for (var i = 0; i < ordered.length; i++) {
        out[ordered[i].id] = (i + 1, ordered.length);
      }
    }
    return out;
  }

  Future<void> _open(BuildContext context, Inspection row) async {
    final result = InspectionResult.fromJson(
      (jsonDecode(row.resultJson) as Map).cast<String, Object?>(),
    );
    final samples = [
      for (final m in (jsonDecode(row.samplesJson) as List<dynamic>))
        InspectionSample.fromJson((m as Map).cast<String, Object?>()),
    ];
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InspectionVerdictScreen(
          service: service,
          result: result,
          samples: samples,
          bmsId: row.bmsId,
          bmsName: row.bmsName,
          savedId: row.id,
          initialNote: row.note,
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, AppL10n t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceRaised,
        title: Text(t.inspectionDeleteConfirmTitle),
        content: Text(
          t.inspectionDeleteConfirmBody,
          style: const TextStyle(fontSize: 13, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.bad),
            child: Text(t.licenseRemoveKey),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  static String _date(DateTime utc) {
    final d = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }
}
