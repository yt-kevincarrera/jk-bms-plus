import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../data/database.dart';
import '../../metrics/maintenance.dart';
import '../theme.dart';
import 'common.dart';

/// The log of what has been done to one pack.
class MaintenanceCard extends StatefulWidget {
  const MaintenanceCard({
    required this.db,
    required this.deviceId,
    this.onChanged,
    super.key,
  });

  final AppDatabase db;
  final String deviceId;

  /// Fired after an edit, so a screen showing derived figures can reload.
  final VoidCallback? onChanged;

  @override
  State<MaintenanceCard> createState() => _MaintenanceCardState();
}

class _MaintenanceCardState extends State<MaintenanceCard> {
  List<MaintenanceEvent> _events = const [];

  MaintenanceLog get _log => MaintenanceLog(widget.db);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final events = await _log.forPack(widget.deviceId);
    if (mounted) setState(() => _events = events);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final lastCell =
        MaintenanceLog.lastOf(_events, MaintenanceKind.cellReplaced);

    return Section(
      title: t.maintTitle,
      intro: t.maintIntro,
      children: [
        // Dating the history that still describes this pack. Readings from
        // before a cell was replaced are about a battery that no longer
        // exists, and every long-term figure quietly includes them.
        if (lastCell != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              t.maintSince(_date(lastCell.at)),
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: AppTheme.watch,
              ),
            ),
          ),
        if (_events.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              t.maintNone,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.textFaint,
              ),
            ),
          )
        else
          for (final e in _events)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_date(e.at)}  ·  '
                          '${_kindLabel(t, MaintenanceKind.parse(e.kind))}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        if (e.note.isNotEmpty)
                          Text(
                            e.note,
                            style: const TextStyle(
                              fontSize: 11.5,
                              height: 1.4,
                              color: AppTheme.textFaint,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _delete(e),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: AppTheme.textFaint,
                    visualDensity: VisualDensity.compact,
                    tooltip: t.maintDelete,
                  ),
                ],
              ),
            ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () => _add(t),
          icon: const Icon(Icons.add, size: 18),
          label: Text(t.maintAdd),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Future<void> _delete(MaintenanceEvent e) async {
    await _log.remove(e.id);
    await _load();
    widget.onChanged?.call();
  }

  Future<void> _add(AppL10n t) async {
    var kind = MaintenanceKind.cellReplaced;
    var at = DateTime.now();
    final note = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(t.maintAdd),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<MaintenanceKind>(
                  initialValue: kind,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: t.maintKind),
                  items: [
                    for (final k in MaintenanceKind.values)
                      DropdownMenuItem(
                        value: k,
                        child: Text(
                          _kindLabel(t, k),
                          style: const TextStyle(fontSize: 13.5),
                        ),
                      ),
                  ],
                  onChanged: (v) => setLocal(() => kind = v ?? kind),
                ),
                const SizedBox(height: 12),
                // The date is asked for, not assumed: people write things down
                // days after doing them, and a chart marker on the wrong week
                // is worse than none.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${t.maintDate}: ${_date(at.toUtc())}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: at,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setLocal(() => at = picked);
                      },
                      child: const Icon(Icons.calendar_today, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: note,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: t.maintNote),
                  style: const TextStyle(fontSize: 13.5),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(t.packsCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(t.maintSave),
            ),
          ],
        ),
      ),
    );

    if (saved ?? false) {
      await _log.add(
        deviceId: widget.deviceId,
        at: at,
        kind: kind,
        note: note.text,
      );
      await _load();
      widget.onChanged?.call();
    }
    note.dispose();
  }

  String _kindLabel(AppL10n t, MaintenanceKind k) => switch (k) {
        MaintenanceKind.cellReplaced => t.maintKindCellReplaced,
        MaintenanceKind.manualBalance => t.maintKindManualBalance,
        MaintenanceKind.connectionsServiced => t.maintKindConnections,
        MaintenanceKind.chargerChanged => t.maintKindCharger,
        MaintenanceKind.bmsSettingsChanged => t.maintKindBmsSettings,
        MaintenanceKind.other => t.maintKindOther,
      };

  static String _date(DateTime utc) {
    final d = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }
}
