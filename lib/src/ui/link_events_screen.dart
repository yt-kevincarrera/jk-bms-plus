import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../data/database.dart';
import '../data/link_event.dart';
import '../data/repository.dart';
import 'link_event_labels.dart';
import 'theme.dart';

/// "Historial de conexión": the app's own record of what it decided, newest
/// first.
///
/// The log has been written since it was added, to explain rides that went
/// wrong in a pocket, and it could only be read by exporting a backup and
/// opening the JSON. The rider who wanted to know why the link dropped at
/// the lights had to send the file to somebody else to find out.
class LinkEventsScreen extends StatefulWidget {
  const LinkEventsScreen({required this.repository, this.deviceId, super.key});

  final BmsRepository repository;

  /// The pack the screen was opened for, if any. Offered as a filter; most of
  /// what goes wrong while connecting has no pack yet, so the default is all.
  final String? deviceId;

  @override
  State<LinkEventsScreen> createState() => _LinkEventsScreenState();
}

class _LinkEventsScreenState extends State<LinkEventsScreen> {
  List<LinkEvent> _all = const [];
  Map<String, String> _names = const {};
  bool _loading = true;
  bool _thisPack = false;

  /// The kind picked, by stored name, or null for every kind.
  String? _kind;

  /// Rows whose bytes are shown, by id.
  final Set<int> _open = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final events = await widget.repository.recentLinkEvents();
    final devices = await widget.repository.devices();
    if (!mounted) return;
    setState(() {
      _all = events;
      _names = {for (final d in devices) d.id: d.name.isEmpty ? d.id : d.name};
      _loading = false;
    });
  }

  List<LinkEvent> get _shown => [
    for (final e in _all)
      if ((!_thisPack || e.deviceId == widget.deviceId) &&
          (_kind == null || e.kind == _kind))
        e,
  ];

  String _label(AppL10n t, String kind) {
    final k = linkEventKindNamed(kind);
    return k == null ? t.linkEventsUnknownKind(kind) : linkEventLabel(t, k);
  }

  String _pack(AppL10n t, String? id) =>
      id == null ? t.linkEventsNoPack : (_names[id] ?? id);

  /// The rows shown, as plain text: one per line, every byte included. The
  /// stored kind name stays beside the translated one, so a paste reads the
  /// same to whoever gets it whatever their language.
  String _asText(AppL10n t, List<LinkEvent> rows) => [
    for (final e in rows)
      '${_stamp(e.at)}  ${e.kind} (${_label(t, e.kind)})  '
          '${_pack(t, e.deviceId)}  ${e.detail}',
  ].join('\n');

  void _copy(String text, String said) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(said)));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final shown = _shown;
    final kinds = {for (final e in _all) e.kind}.toList()
      ..sort((a, b) => _label(t, a).compareTo(_label(t, b)));
    return Scaffold(
      appBar: AppBar(
        title: Text(t.linkEventsTitle),
        actions: [
          IconButton(
            tooltip: t.linkEventsCopyAll,
            icon: const Icon(Icons.copy_all),
            onPressed: shown.isEmpty
                ? null
                : () => _copy(
                    _asText(t, shown),
                    t.linkEventsCopiedAll(shown.length),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                    child: Text(
                      t.linkEventsIntro,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  _filters(t, kinds),
                  if (_thisPack)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Text(
                        t.linkEventsThisPackHint,
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: AppTheme.textFaint,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                    child: Text(
                      t.linkEventsCount(shown.length),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textFaint,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: shown.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              t.linkEventsEmpty,
                              style: const TextStyle(color: AppTheme.textFaint),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: shown.length,
                            itemBuilder: (context, i) => _row(t, shown[i]),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _filters(AppL10n t, List<String> kinds) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
    child: Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (widget.deviceId != null) ...[
          ChoiceChip(
            label: Text(t.linkEventsAllPacks),
            selected: !_thisPack,
            onSelected: (_) => setState(() => _thisPack = false),
          ),
          ChoiceChip(
            label: Text(t.linkEventsThisPack),
            selected: _thisPack,
            onSelected: (_) => setState(() => _thisPack = true),
          ),
        ],
        DropdownButton<String?>(
          value: _kind,
          isDense: true,
          items: [
            DropdownMenuItem<String?>(child: Text(t.linkEventsAnyKind)),
            for (final k in kinds)
              DropdownMenuItem<String?>(value: k, child: Text(_label(t, k))),
          ],
          onChanged: (v) => setState(() => _kind = v),
        ),
      ],
    ),
  );

  Widget _row(AppL10n t, LinkEvent e) {
    final split = splitLinkEventDetail(e.detail);
    final hex = split.hex;
    final open = _open.contains(e.id);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _label(t, e.kind),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _stamp(e.at),
                style: const TextStyle(
                  fontSize: 11,
                  fontFeatures: AppTheme.tabular,
                  color: AppTheme.textFaint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            _pack(t, e.deviceId),
            style: const TextStyle(fontSize: 11, color: AppTheme.textFaint),
          ),
          if (split.text.isNotEmpty) ...[
            const SizedBox(height: 4),
            SelectableText(
              split.text,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          if (hex != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () => setState(
                    () => open ? _open.remove(e.id) : _open.add(e.id),
                  ),
                  icon: Icon(
                    open ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                  ),
                  label: Text(t.linkEventsBytes(hex.length ~/ 2)),
                ),
                IconButton(
                  tooltip: t.linkEventsCopyBytes,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: () =>
                      _copy(spacedHex(hex), t.linkEventsBytesCopied),
                ),
              ],
            ),
            if (open)
              SelectableText(
                spacedHex(hex),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Seconds matter here: the log's rows arrive several a second around a
  /// failure, and the order is the story.
  static String _stamp(DateTime at) {
    final d = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} '
        '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }
}
