import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ble/ble_transport.dart';
import '../bms_service.dart';
import '../model/bms_snapshot.dart';
import '../model/jk_device_info.dart';
import '../protocol/jk_frame.dart';

/// Milestone 1 deliverable: prove the link decodes correctly, live, for as long
/// as you care to watch.
///
/// This is a diagnostic view, not the product UI. It stays in the app after
/// milestone 4 as the raw view behind the System tab, because when a number
/// looks wrong the first question is always what the frame actually said.
class LiveConsoleScreen extends StatefulWidget {
  const LiveConsoleScreen({
    required this.service,
    required this.deviceName,
    super.key,
  });

  final BmsService service;
  final String deviceName;

  @override
  State<LiveConsoleScreen> createState() => _LiveConsoleScreenState();
}

class _LiveConsoleScreenState extends State<LiveConsoleScreen> {
  static const _maxLogLines = 200;

  final _encoder = const JsonEncoder.withIndent('  ');
  final List<String> _log = [];
  final ScrollController _scroll = ScrollController();

  final List<StreamSubscription<Object?>> _subs = [];

  BmsSnapshot? _snapshot;
  JkDeviceInfo? _deviceInfo;
  FrameStats? _stats;
  BleLinkState _link = BleLinkState.connecting;
  DateTime? _lastSnapshotAt;
  bool _follow = true;

  @override
  void initState() {
    super.initState();
    final s = widget.service;

    _subs.add(s.linkState.listen((v) => setState(() => _link = v)));
    _subs.add(s.frameStats.listen((v) => setState(() => _stats = v)));
    _subs.add(
      s.deviceInfo.listen((v) {
        setState(() => _deviceInfo = v);
        _append('device info', v.toJson());
      }),
    );
    _subs.add(
      s.settings.listen((v) => _append('settings', v.toJson())),
    );
    _subs.add(
      s.snapshots.listen((v) {
        setState(() {
          _snapshot = v;
          _lastSnapshotAt = DateTime.now();
        });
        _append('cell info', v.toJson());
      }),
    );
    _subs.add(
      s.problems.listen((v) => _appendLine('!! $v')),
    );
    _subs.add(
      s.linkErrors.listen((v) => _appendLine('!! ${v.message}')),
    );
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _scroll.dispose();
    super.dispose();
  }

  void _append(String label, Map<String, Object?> json) {
    _appendLine('--- $label ---\n${_encoder.convert(json)}');
  }

  void _appendLine(String line) {
    if (!mounted) return;
    setState(() {
      _log.add(line);
      if (_log.length > _maxLogLines) {
        _log.removeRange(0, _log.length - _maxLogLines);
      }
    });
    if (_follow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deviceName),
        actions: [
          IconButton(
            tooltip: _follow ? 'Following' : 'Paused',
            icon: Icon(_follow ? Icons.vertical_align_bottom : Icons.pause),
            onPressed: () => setState(() => _follow = !_follow),
          ),
          IconButton(
            tooltip: 'Copy log',
            icon: const Icon(Icons.copy_all),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _log.join('\n\n')));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Log copied')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _StatusStrip(
            link: _link,
            snapshot: _snapshot,
            deviceInfo: _deviceInfo,
            stats: _stats,
            mtu: widget.service.negotiatedMtu,
            lastSnapshotAt: _lastSnapshotAt,
          ),
          const Divider(height: 1),
          Expanded(
            child: Container(
              color: theme.colorScheme.surfaceContainerLowest,
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(12),
                itemCount: _log.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SelectableText(
                    _log[i],
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.link,
    required this.snapshot,
    required this.deviceInfo,
    required this.stats,
    required this.mtu,
    required this.lastSnapshotAt,
  });

  final BleLinkState link;
  final BmsSnapshot? snapshot;
  final JkDeviceInfo? deviceInfo;
  final FrameStats? stats;
  final int? mtu;
  final DateTime? lastSnapshotAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = snapshot;
    final st = stats;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: theme.colorScheme.surfaceContainerHigh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_linkIcon, size: 16, color: _linkColor(theme)),
              const SizedBox(width: 6),
              Text(link.name, style: theme.textTheme.labelLarge),
              const Spacer(),
              if (mtu != null) Text('MTU $mtu', style: theme.textTheme.labelSmall),
            ],
          ),
          if (deviceInfo != null) ...[
            const SizedBox(height: 6),
            Text(
              '${deviceInfo!.model}  hw ${deviceInfo!.hardwareVersion}  '
              'sw ${deviceInfo!.softwareVersion}  '
              '-> ${deviceInfo!.variant?.name ?? "variant unknown"}',
              style: theme.textTheme.labelSmall,
            ),
          ],
          if (s != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 18,
              runSpacing: 6,
              children: [
                _Stat('Pack', '${s.packVoltage.toStringAsFixed(2)} V'),
                _Stat('Current', '${s.current.toStringAsFixed(2)} A'),
                _Stat('Power', '${s.power.toStringAsFixed(0)} W'),
                _Stat('SOC', '${s.soc.toStringAsFixed(0)} %'),
                _Stat(
                  'Delta',
                  '${(s.deltaCellVoltage * 1000).toStringAsFixed(0)} mV',
                ),
                _Stat('Cells', '${s.cellCount}'),
              ],
            ),
          ],
          if (st != null) ...[
            const SizedBox(height: 8),
            Text(
              'frames ok ${st.accepted}  bad checksum ${st.badChecksum}  '
              'unsupported ${st.unsupportedType}  '
              'accept ${(st.acceptRate * 100).toStringAsFixed(1)}%'
              '${lastSnapshotAt == null ? "" : "  last ${_ago(lastSnapshotAt!)}"}',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ],
      ),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    return d.inSeconds < 1 ? 'now' : '${d.inSeconds}s ago';
  }

  IconData get _linkIcon => switch (link) {
        BleLinkState.connected => Icons.bluetooth_connected,
        BleLinkState.failed => Icons.bluetooth_disabled,
        BleLinkState.reconnecting => Icons.bluetooth_searching,
        _ => Icons.bluetooth,
      };

  Color _linkColor(ThemeData theme) => switch (link) {
        BleLinkState.connected => theme.colorScheme.primary,
        BleLinkState.failed => theme.colorScheme.error,
        _ => theme.colorScheme.onSurfaceVariant,
      };
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
