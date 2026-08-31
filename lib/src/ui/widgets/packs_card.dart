import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../bms_service.dart';
import '../../data/database.dart';
import '../theme.dart';
import 'common.dart';

/// The batteries this phone has seen, and what belongs to each.
///
/// Exists because one phone and several packs is the normal case, not an edge
/// case: a spare battery, a friend's bike, a pack being tested before it goes
/// in. Pooling them would not average anything — it would produce a history
/// describing no battery that exists.
class PacksCard extends StatefulWidget {
  const PacksCard({required this.service, super.key});

  final BmsService service;

  @override
  State<PacksCard> createState() => _PacksCardState();
}

class _PacksCardState extends State<PacksCard> {
  List<Device> _devices = const [];
  int _orphans = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = widget.service.repository;
    if (repo == null) return;
    final devices = await repo.devices();
    final orphans = await repo.totalOrphans();
    if (!mounted) return;
    setState(() {
      _devices = devices;
      _orphans = orphans;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final active = widget.service.activeDevice;

    return Section(
      title: t.packsTitle,
      intro: t.packsIntro,
      children: [
        InfoRow(
          t.packsCurrent,
          active == null ? t.packsNone : _label(active),
          dim: active == null,
          valueColor: active == null ? null : AppTheme.good,
        ),
        if (_devices.isNotEmpty) ...[
          const SizedBox(height: 8),
          Caption(t.packsKnown, color: AppTheme.textFaint),
          const SizedBox(height: 4),
          for (final d in _devices) _deviceRow(t, d, d.id == active?.id),
        ],
        if (_orphans > 0) ..._orphanBlock(t, active),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _deviceRow(AppL10n t, Device d, bool isActive) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(
              d.demo ? Icons.science_outlined : Icons.battery_full,
              size: 17,
              color: isActive ? AppTheme.good : AppTheme.textFaint,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _label(d),
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isActive ? AppTheme.good : null,
                    ),
                  ),
                  Text(
                    '${d.catalogueCapacityAh?.toStringAsFixed(0) ?? t.catalogueUnset} Ah  ·  '
                    '${t.packsLastSeen(_date(d.lastSeenAt))}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textFaint,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _busy ? null : () => _rename(t, d),
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: t.packsRename,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: _busy ? null : () => _confirmDelete(t, d),
              icon: const Icon(Icons.delete_outline, size: 18),
              color: AppTheme.bad,
              tooltip: t.packsDelete,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      );

  List<Widget> _orphanBlock(AppL10n t, Device? active) => [
        const SizedBox(height: 10),
        Caption(t.orphansTitle, color: AppTheme.watch),
        const SizedBox(height: 4),
        Text(
          t.orphansBody('$_orphans'),
          style: const TextStyle(
            fontSize: 11.5,
            height: 1.45,
            color: AppTheme.textFaint,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: [
            // Only offered with a pack connected: attaching history to nothing
            // is what created this situation in the first place.
            OutlinedButton(
              onPressed: active == null || _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      await widget.service.repository
                          ?.adoptOrphans(active.id);
                      await widget.service.relearnRangeFromTrips();
                      if (mounted) setState(() => _busy = false);
                      await _load();
                    },
              child: Text(t.orphansAdopt),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      await widget.service.repository?.discardOrphans();
                      if (mounted) setState(() => _busy = false);
                      await _load();
                    },
              child: Text(
                t.orphansDiscard,
                style: const TextStyle(color: AppTheme.bad),
              ),
            ),
          ],
        ),
      ];

  Future<void> _rename(AppL10n t, Device d) async {
    final controller = TextEditingController(text: d.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.packsRename),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: t.packsRenameHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.packsCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(t.packsSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;

    await widget.service.repository?.setDeviceName(d.id, name);
    if (d.id == widget.service.activeDeviceId) {
      await widget.service.refreshActiveDevice();
    }
    await _load();
  }

  Future<void> _confirmDelete(AppL10n t, Device d) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.packsDelete),
        content: Text(t.packsDeleteConfirm(_label(d))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.packsCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.bad),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.packsDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    await widget.service.repository?.deleteDevice(d.id);
    // The range estimate is rebuilt from stored rides, so deleting a pack has
    // to be followed by a relearn or the number keeps the deleted pack in it.
    await widget.service.relearnRangeFromTrips();
    if (mounted) setState(() => _busy = false);
    await _load();
  }

  String _label(Device d) => d.name.isEmpty ? d.id : d.name;

  static String _date(DateTime utc) {
    final d = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }
}
