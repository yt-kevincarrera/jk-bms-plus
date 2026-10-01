import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../data/repository.dart';
import '../metrics/fault_history.dart';
import 'theme.dart';
import 'warning_labels.dart';
import 'widgets/common.dart';

/// Every time the BMS raised a protection or a warning on one pack, newest
/// first, from what is on disk. Works with nothing connected.
///
/// The warning mask has been stored with every reading from the start, and
/// the only things that read it were the backup and the CSV. A cell
/// undervoltage for ten seconds on a hill, or an overcurrent at a set of
/// lights, was in the database and nowhere on screen once it cleared.
class FaultHistoryScreen extends StatefulWidget {
  const FaultHistoryScreen({
    required this.repository,
    required this.deviceId,
    required this.packName,
    super.key,
  });

  final BmsRepository repository;
  final String deviceId;
  final String packName;

  @override
  State<FaultHistoryScreen> createState() => _FaultHistoryScreenState();
}

class _FaultHistoryScreenState extends State<FaultHistoryScreen> {
  late final Future<List<FaultEpisode>> _episodes = widget.repository
      .faultHistory(widget.deviceId);

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.faultHistoryTitle)),
      body: SafeArea(
        child: FutureBuilder<List<FaultEpisode>>(
          future: _episodes,
          builder: (context, snap) {
            final episodes = snap.data;
            if (episodes == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 28),
              // The intro, every episode, and the footnote.
              itemCount: episodes.length + 2,
              itemBuilder: (context, i) {
                if (i == 0) return _intro(t, episodes.isEmpty);
                if (i == episodes.length + 1) return _footnote(t);
                return _episode(t, episodes[i - 1]);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _intro(AppL10n t, bool empty) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.packName,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          empty ? t.faultHistoryEmpty : t.faultHistoryIntro,
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.45,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    ),
  );

  Widget _footnote(AppL10n t) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
    child: Text(
      t.faultHistoryThinned,
      style: const TextStyle(
        fontSize: 11,
        height: 1.4,
        color: AppTheme.textFaint,
      ),
    ),
  );

  Widget _episode(AppL10n t, FaultEpisode e) {
    final w = e.warning;
    final name = w == null ? t.faultUnknownBit(e.bit) : warningLabel(t, w);
    return Section(
      title: name,
      accent: w?.isFault == false ? AppTheme.watch : AppTheme.bad,
      trailing: e.ongoing
          ? Pill(t.faultOngoing, color: AppTheme.bad)
          : Pill(_length(t, e), color: AppTheme.textSecondary),
      children: [
        InfoRow(t.faultStarted, _dateTime(e.start)),
        InfoRow(
          t.faultLastSeen,
          _dateTime(e.end),
          // The link was out for long enough that the fault may have begun
          // earlier, ended later, or come and gone unseen.
          hint: e.unobservedGap ? t.faultNoData : null,
          valueColor: e.unobservedGap ? AppTheme.watch : null,
        ),
        InfoRow(t.faultReadings, '${e.readings}'),
        InfoRow(
          t.faultAtStart,
          '${e.current.toStringAsFixed(1)} A  ·  ${e.soc.toStringAsFixed(0)} %',
          hint: t.faultAtStartCells(
            e.maxCellVoltage.toStringAsFixed(3),
            e.minCellVoltage.toStringAsFixed(3),
          ),
          last: true,
        ),
      ],
    );
  }

  /// How long it was seen for. One reading has no length, and saying "0 s"
  /// would read as a measurement of zero.
  static String _length(AppL10n t, FaultEpisode e) {
    final d = e.duration;
    if (e.readings <= 1 || d.inSeconds < 1) return t.faultInstant;
    if (d.inMinutes < 1) return '${d.inSeconds} s';
    if (d.inHours < 1) return '${d.inMinutes} min ${d.inSeconds % 60} s';
    if (d.inDays < 1) return '${d.inHours} h ${d.inMinutes % 60} min';
    return '${d.inDays} d ${d.inHours % 24} h';
  }

  static String _dateTime(DateTime utc) {
    final d = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}  '
        '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }
}
