import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../bms_service.dart';
import '../../data/database.dart';
import '../../inspection/inspection_result.dart';
import '../../inspection/inspection_series.dart';
import '../../inspection/inspection_session.dart';
import '../../inspection/inspection_verdicts.dart';
import '../../report/certificate.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'inspection_verdict_screen.dart';

/// Every quick test the rider has run on somebody else's pack, newest first.
///
/// Not a list of batteries: the packs here were looked at, not adopted, and
/// nothing about them lives anywhere else in the app.
class InspectionsListScreen extends StatelessWidget {
  const InspectionsListScreen({
    required this.service,
    this.identity,
    super.key,
  });

  final BmsService service;

  /// This phone's signing identity, for showing its issuer code. Injectable
  /// for tests.
  final CertificateIdentity? identity;

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
                      _issuerCard(t),
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
          const SizedBox(height: 20),
          _issuerCard(t),
        ],
      ),
    ),
  );

  /// This phone's issuer code, the one its certificates carry.
  ///
  /// A certificate's signature only says which installation signed it. That
  /// is worth something to a buyer only if they can compare it with a code
  /// the seller or the workshop has published somewhere they can see, so the
  /// code has to be findable before anything is signed.
  Widget _issuerCard(AppL10n t) => FutureBuilder<String>(
    future: (identity ?? CertificateIdentity()).issuerCode(),
    builder: (context, snap) {
      final code = snap.data;
      if (code == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceRaised,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.certificateLocalIssuer.toUpperCase(),
                style: AppTheme.caption(context),
              ),
              const SizedBox(height: 6),
              SelectableText(
                code,
                style: AppTheme.readout(20, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                t.certificateLocalIssuerHint,
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.45,
                  color: AppTheme.textFaint,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _tile(
    BuildContext context,
    AppL10n t,
    Inspection row,
    (int, int)? run,
  ) {
    final light = lightOf(row);
    final tone = switch (light) {
      InspectionLight.problem => AppTheme.bad,
      InspectionLight.watch => AppTheme.watch,
      InspectionLight.good => AppTheme.good,
      InspectionLight.unmeasured => AppTheme.textFaint,
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
          onTap: () => _open(context, row, run?.$2),
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
                Pill(switch (light) {
                  InspectionLight.problem => t.inspectionLightProblem,
                  InspectionLight.watch => t.inspectionLightWatch,
                  InspectionLight.good => t.inspectionLightGood,
                  InspectionLight.unmeasured =>
                    t.inspectionLightUnmeasuredShort,
                }, color: tone),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The light a saved run shows, worked out again from its stored result.
  ///
  /// The verdict screen recomputes it from the result, and the list used to
  /// read the word saved with the row instead, and only knew three of them:
  /// a run saved as "unmeasured" fell through to green "nothing serious".
  /// Runs saved before the unmeasured light existed hold "good" for a test
  /// that measured nothing. The stored result has everything the verdict
  /// needs, so the list asks the verdict, the same one the screen behind it
  /// asks, and only falls back to the stored word when the result cannot be
  /// read.
  @visibleForTesting
  static InspectionLight lightOf(Inspection row) {
    try {
      final r = InspectionResult.fromJson(
        (jsonDecode(row.resultJson) as Map).cast<String, Object?>(),
      );
      return const InspectionVerdicts().light(r);
    } on Object {
      return InspectionLight.values
              .where((l) => l.name == row.light)
              .firstOrNull ??
          InspectionLight.unmeasured;
    }
  }

  /// For each row, which run of that pack it is and how many there are.
  ///
  /// By the same rule the verdict uses to find a pack's earlier runs: the
  /// address, or a serial that looks real together with the same name. It
  /// used to be the address alone here and the address or any serial there,
  /// so a pack could be "run 1 of 1" in the list and "run 3" on its sheet.
  static Map<int, (int, int)> _runNumbers(List<Inspection> rows) {
    bool same(Inspection a, Inspection b) => InspectionSeries.sameIdentity(
      bmsId: a.bmsId,
      serialNumber: a.serialNumber,
      bmsName: a.bmsName,
      otherBmsId: b.bmsId,
      otherSerialNumber: b.serialNumber,
      otherBmsName: b.bmsName,
    );
    return {
      for (final row in rows)
        row.id: (
          rows.where((o) => o.at.isBefore(row.at) && same(row, o)).length + 1,
          rows.where((o) => same(row, o)).length,
        ),
    };
  }

  Future<void> _open(BuildContext context, Inspection row, int? total) async {
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
          runTotal: total,
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
            child: Text(t.inspectionDeleteConfirm),
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
