import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../ble/ble_transport.dart';
import '../ble/link_traffic.dart';
import '../bms_service.dart';
import '../model/bms_device_info.dart';
import '../model/bms_snapshot.dart';
import '../protocol/bms_brand.dart';
import '../protocol/jk_frame.dart';

/// Milestone 1 deliverable: prove the link decodes correctly, live, for as long
/// as you care to watch.
///
/// This is a diagnostic view, not the product UI. It stays in the app after
/// milestone 4 as the raw view behind the System tab, because when a number
/// looks wrong the first question is always what the frame actually said.
///
/// It is also the screen opened from the connect screen when a pack will not
/// connect, and for that it used to be no use: it showed decoded frames, of
/// which a failing pack has none, and the same notices the connect screen had
/// just shown. The bytes view is what answers that case: what the pack sent,
/// and what the app wrote to it, from before the console was opened.
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

enum _ConsoleView { decoded, bytes }

class _LiveConsoleScreenState extends State<LiveConsoleScreen> {
  static const _maxLogLines = 200;

  /// As many as the service keeps, so nothing it still holds is cut off
  /// here.
  static const _maxByteLines = 400;

  final _encoder = const JsonEncoder.withIndent('  ');
  final ScrollController _scroll = ScrollController();

  // What each view shows, and what arrived while it was paused. Paused
  // holds the list still rather than only stopping the scroll: bytes arrive
  // several times a second, and a list trimmed at the top while someone is
  // reading a line in it moves the line out from under them.
  final List<String> _log = [];
  final List<String> _logPending = [];
  final List<String> _bytes = [];
  final List<String> _bytesPending = [];

  final List<StreamSubscription<Object?>> _subs = [];

  BmsSnapshot? _snapshot;
  BmsDeviceInfo? _deviceInfo;
  FrameStats? _stats;
  late BleLinkState _link;
  DateTime? _lastSnapshotAt;
  bool _follow = true;
  _ConsoleView _view = _ConsoleView.decoded;

  /// The localised marker between what was known before the console opened
  /// and what arrived after. Put in on the first build, which is the first
  /// point the locale is known.
  bool _markersPlaced = false;
  int _logPrefilled = 0;
  int _bytesPrefilled = 0;

  @override
  void initState() {
    super.initState();
    final s = widget.service;

    // What is already known, before anything new arrives. This screen used to
    // start blank and show only what happened after it was opened, which made
    // it useless for the one job it is opened for: reading what went wrong a
    // moment ago, from the connect screen, with nothing connected.
    _link = s.lastLinkState;
    _stats = s.stats;
    _deviceInfo = s.lastDeviceInfo;
    _snapshot = s.lastSnapshot;
    _lastSnapshotAt = s.lastSnapshot?.timestamp;
    for (final n in s.recentNotices.reversed) {
      _log.add('${_clock(n.at)} !! ${n.text}');
    }
    _logPrefilled = _log.length;
    // The bytes too, and for the same reason: they are the part of a failed
    // attempt that nothing else on screen shows.
    final held = s.traffic.entries;
    for (final e in held.skip(
      held.length > _maxByteLines ? held.length - _maxByteLines : 0,
    )) {
      _bytes.add(formatTrafficEntry(e));
    }
    _bytesPrefilled = _bytes.length;

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
    _subs.add(
      s.traffic.stream.listen(
        (e) => _push(_bytes, _bytesPending, _maxByteLines, formatTrafficEntry(e),
            visible: _view == _ConsoleView.bytes),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_markersPlaced) return;
    _markersPlaced = true;
    final marker = AppL10n.of(context).consoleLiveFromHere;
    if (_logPrefilled > 0) _log.add(marker);
    if (_bytesPrefilled > 0) _bytes.add(marker);
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

  static String _clock(DateTime at) {
    final t = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  void _appendLine(String line) => _push(
        _log,
        _logPending,
        _maxLogLines,
        line,
        visible: _view == _ConsoleView.decoded,
      );

  void _push(
    List<String> shown,
    List<String> pending,
    int cap,
    String line, {
    required bool visible,
  }) {
    if (!mounted) return;
    if (!_follow) {
      pending.add(line);
      if (pending.length > cap) pending.removeRange(0, pending.length - cap);
      return;
    }
    setState(() {
      shown.add(line);
      if (shown.length > cap) shown.removeRange(0, shown.length - cap);
    });
    if (visible) _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _toggleFollow() {
    setState(() {
      _follow = !_follow;
      if (_follow) {
        for (final (shown, pending, cap) in [
          (_log, _logPending, _maxLogLines),
          (_bytes, _bytesPending, _maxByteLines),
        ]) {
          shown.addAll(pending);
          pending.clear();
          if (shown.length > cap) shown.removeRange(0, shown.length - cap);
        }
      }
    });
    if (_follow) _scrollToEnd();
  }

  void _setView(_ConsoleView v) {
    setState(() => _view = v);
    if (_follow) _scrollToEnd();
  }

  List<String> get _visible => _view == _ConsoleView.bytes ? _bytes : _log;

  /// Everything a diagnosis needs, as one paste: the counters, every notice
  /// the service still holds, the decoded log, and every chunk the traffic
  /// log still holds, whatever this screen happens to be showing.
  String _report(AppL10n t) {
    final s = widget.service;
    final out = StringBuffer()
      ..writeln('${t.consoleReportTitle} · ${widget.deviceName} · '
          '${DateTime.now().toIso8601String()}')
      ..writeln()
      ..writeln('== ${t.consoleThisConnection} ==')
      ..writeln(
        statusLines(
          t,
          link: _link,
          deviceInfo: _deviceInfo,
          stats: _stats,
          mtu: s.negotiatedMtu,
          lastSnapshotAt: _lastSnapshotAt,
          brand: s.brand,
          antStatusFrames: s.antStatusFrames,
          antInfoFrames: s.antInfoFrames,
          antRejectedFrames: s.antRejectedFrames,
          lastDecodeError: s.lastDecodeError,
          jkCounters: 'device info ${s.deviceInfoFrames} · '
              'cell info ${s.cellInfoFrames} · '
              'held back ${s.heldBackFrames} · '
              'undecodable ${s.decodeFailures} · '
              'variant ${s.variant?.name ?? '?'}',
        ).join('\n'),
      )
      ..writeln()
      ..writeln('== ${t.consoleReportNotices} ==');
    for (final n in s.recentNotices.reversed) {
      out.writeln('${_clock(n.at)} ${n.text}');
    }
    out
      ..writeln()
      ..writeln('== ${t.consoleReportDecoded} ==')
      ..writeln(_log.join('\n\n'))
      ..writeln()
      ..writeln('== ${t.consoleReportBytes} ==');
    for (final e in s.traffic.entries) {
      out.writeln(formatTrafficEntry(e));
    }
    return out.toString();
  }

  void _copy(String text, String said) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(said)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppL10n.of(context);
    final lines = _visible;
    final bytesEmpty = _view == _ConsoleView.bytes && lines.isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deviceName),
        actions: [
          IconButton(
            tooltip: _follow ? t.consoleFollow : t.consolePaused,
            icon: Icon(_follow ? Icons.vertical_align_bottom : Icons.pause),
            onPressed: _toggleFollow,
          ),
          IconButton(
            tooltip: t.consoleCopy,
            icon: const Icon(Icons.copy),
            onPressed: () => _copy(
              lines.join(_view == _ConsoleView.bytes ? '\n' : '\n\n'),
              t.consoleCopied,
            ),
          ),
          IconButton(
            tooltip: t.consoleCopyAll,
            icon: const Icon(Icons.copy_all),
            onPressed: () => _copy(_report(t), t.consoleCopiedAll),
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
            brand: widget.service.brand,
            antStatusFrames: widget.service.antStatusFrames,
            antInfoFrames: widget.service.antInfoFrames,
            antRejectedFrames: widget.service.antRejectedFrames,
            lastDecodeError: widget.service.lastDecodeError,
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_ConsoleView>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: _ConsoleView.decoded,
                    label: Text(t.consoleViewDecoded),
                  ),
                  ButtonSegment(
                    value: _ConsoleView.bytes,
                    label: Text(t.consoleViewBytes),
                  ),
                ],
                selected: {_view},
                onSelectionChanged: (v) => _setView(v.first),
              ),
            ),
          ),
          if (_view == _ConsoleView.bytes)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  t.consoleBytesLegend,
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
          Expanded(
            child: Container(
              color: theme.colorScheme.surfaceContainerLowest,
              child: bytesEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        t.consoleNoBytes,
                        style: theme.textTheme.bodySmall,
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: lines.length,
                      itemBuilder: (context, i) => Padding(
                        padding: EdgeInsets.only(
                          bottom: _view == _ConsoleView.bytes ? 6 : 8,
                        ),
                        child: SelectableText(
                          lines[i],
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

/// One chunk as a console line: the time to the millisecond, which way it
/// went, how long it was, and the bytes as hex pairs on the line below.
///
/// Milliseconds because a healthy pack sends several chunks a second, and a
/// write and its answer are a few tens of milliseconds apart.
String formatTrafficEntry(TrafficEntry e) {
  final t = e.at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  final ms = t.millisecond.toString().padLeft(3, '0');
  final arrow = e.direction == TrafficDirection.rx ? '← RX' : '→ TX';
  return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.$ms  '
      '$arrow  ${e.bytes.length} B\n${e.hex}';
}

/// The strip's counters as plain lines, so the copy holds exactly what the
/// strip shows. Terse and technical like the connect screen's evidence line,
/// so the two can be read side by side; only the labels are translated.
///
/// Every counter here is this connection's: the service restarts them on
/// connect. [jkCounters] adds the service's per-stage tally for a paste,
/// where there is room for it.
List<String> statusLines(
  AppL10n t, {
  required BleLinkState link,
  required BmsDeviceInfo? deviceInfo,
  required FrameStats? stats,
  required int? mtu,
  required DateTime? lastSnapshotAt,
  required BmsBrand brand,
  required int antStatusFrames,
  required int antInfoFrames,
  required int antRejectedFrames,
  required String? lastDecodeError,
  String? jkCounters,
}) {
  final lines = <String>[
    'link ${link.name}${mtu == null ? '' : ' · MTU $mtu'}',
  ];
  final d = deviceInfo;
  if (d != null) {
    lines.add(
      '${d.model}  hw ${d.hardwareVersion}  sw ${d.softwareVersion}  '
      '-> ${d.variant?.name ?? d.brand.name.toUpperCase()}',
    );
  }
  final st = stats;
  if (st != null) {
    final ago = lastSnapshotAt == null
        ? ''
        : ' · ${t.consoleLastReading(DateTime.now().difference(lastSnapshotAt).inSeconds)}';
    lines.add(
      '${t.consoleThisConnection}: ${st.bytesReceived} bytes · '
      'frames ok ${st.accepted} · bad checksum ${st.badChecksum} · '
      'unsupported ${st.unsupportedType} · '
      'accept ${(st.acceptRate * 100).toStringAsFixed(1)}%$ago',
    );
  }
  // The JK line above says nothing about an ANT: its cell-info and
  // held-back counters never move for it. This is the diagnostic this
  // console exists for, so ANT gets its own line rather than being read
  // through JK's.
  if (brand == BmsBrand.ant) {
    lines.add(
      'ant status $antStatusFrames · info $antInfoFrames · '
      'rejected $antRejectedFrames'
      '${lastDecodeError == null ? '' : ' · last error: $lastDecodeError'}',
    );
  } else if (jkCounters != null) {
    lines.add(jkCounters);
  }
  return lines;
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.link,
    required this.snapshot,
    required this.deviceInfo,
    required this.stats,
    required this.mtu,
    required this.lastSnapshotAt,
    required this.brand,
    required this.antStatusFrames,
    required this.antInfoFrames,
    required this.antRejectedFrames,
    required this.lastDecodeError,
  });

  final BleLinkState link;
  final BmsSnapshot? snapshot;
  final BmsDeviceInfo? deviceInfo;
  final FrameStats? stats;
  final int? mtu;
  final DateTime? lastSnapshotAt;
  final BmsBrand brand;
  final int antStatusFrames;
  final int antInfoFrames;
  final int antRejectedFrames;
  final String? lastDecodeError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppL10n.of(context);
    final s = snapshot;
    // The first line is drawn as a row with an icon, so it is left out here.
    final counters = statusLines(
      t,
      link: link,
      deviceInfo: deviceInfo,
      stats: stats,
      mtu: mtu,
      lastSnapshotAt: lastSnapshotAt,
      brand: brand,
      antStatusFrames: antStatusFrames,
      antInfoFrames: antInfoFrames,
      antRejectedFrames: antRejectedFrames,
      lastDecodeError: lastDecodeError,
    ).skip(1);

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
          if (s != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 18,
              runSpacing: 6,
              children: [
                _Stat(t.packVoltage, '${s.packVoltage.toStringAsFixed(2)} V'),
                _Stat(t.current, '${s.current.toStringAsFixed(2)} A'),
                _Stat(t.power, '${s.power.toStringAsFixed(0)} W'),
                _Stat('SOC', '${s.soc.toStringAsFixed(0)} %'),
                _Stat(
                  t.cellDelta,
                  '${(s.deltaCellVoltage * 1000).toStringAsFixed(0)} mV',
                ),
                _Stat(t.tabCells, '${s.cellCount}'),
              ],
            ),
          ],
          for (final line in counters) ...[
            const SizedBox(height: 6),
            Text(line, style: theme.textTheme.labelSmall),
          ],
        ],
      ),
    );
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
