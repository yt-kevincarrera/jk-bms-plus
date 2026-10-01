import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../data/database.dart';
import '../data/repository.dart';
import '../metrics/cell_history.dart';
import '../metrics/charge_session.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// Which stretch of a pack's readings to draw.
enum CellHistoryRange { hour, day, week, trip, charge }

/// "Celdas en el tiempo": every cell's voltage over a ride, a charge, or the
/// last hour, day or week of readings, from what is on disk.
///
/// Every reading's cell voltages have been stored from the start, and read
/// back only ever as one number: the last reading, a delta, a trend. How the
/// cells moved against each other through a ride or a charge is where a
/// weak cell shows itself, and it could not be seen.
class CellHistoryScreen extends StatefulWidget {
  const CellHistoryScreen({
    required this.repository,
    required this.deviceId,
    required this.packName,
    this.trip,
    super.key,
  });

  final BmsRepository repository;
  final String deviceId;
  final String packName;

  /// When opened from a ride, that ride: offered as a window, and the one
  /// shown first.
  final Trip? trip;

  @override
  State<CellHistoryScreen> createState() => _CellHistoryScreenState();
}

class _CellHistoryScreenState extends State<CellHistoryScreen> {
  late CellHistoryRange _range = widget.trip == null
      ? CellHistoryRange.hour
      : CellHistoryRange.trip;

  /// Volts, or each cell against the pack average in millivolts.
  bool _deviation = false;

  /// A cell the rider picked out, one-based.
  int? _picked;

  /// The newest stored reading, which the hour, day and week reach back
  /// from. Not the phone's clock: a pack last seen three weeks ago has no
  /// "last hour" of readings, and an empty chart would say nothing.
  DateTime? _newest;
  ChargeReport? _lastCharge;
  bool _ready = false;

  Future<CellHistory>? _history;
  ({DateTime from, DateTime to})? _window;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final db = widget.repository.db;
    final newest = await db.lastSnapshotFor(widget.deviceId);
    final device = await db.device(widget.deviceId);
    if (!mounted) return;
    setState(() {
      _newest = newest?.timestamp.toUtc();
      _lastCharge = ChargeReport.tryParse(device?.lastChargeJson);
      _ready = true;
    });
    _select(_range);
  }

  ({DateTime from, DateTime to})? _windowFor(CellHistoryRange r) {
    final newest = _newest;
    switch (r) {
      case CellHistoryRange.trip:
        final trip = widget.trip;
        return trip == null
            ? null
            : (from: trip.startedAt.toUtc(), to: trip.endedAt.toUtc());
      case CellHistoryRange.charge:
        final c = _lastCharge;
        return c == null
            ? null
            : (from: c.startedAt.toUtc(), to: c.endedAt.toUtc());
      case CellHistoryRange.hour:
      case CellHistoryRange.day:
      case CellHistoryRange.week:
        if (newest == null) return null;
        final span = switch (r) {
          CellHistoryRange.hour => const Duration(hours: 1),
          CellHistoryRange.day => const Duration(hours: 24),
          _ => const Duration(days: 7),
        };
        return (from: newest.subtract(span), to: newest);
    }
  }

  void _select(CellHistoryRange r) {
    final w = _windowFor(r);
    setState(() {
      _range = r;
      _window = w;
      _history = w == null
          ? null
          : widget.repository.cellHistory(widget.deviceId, w.from, w.to);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.cellHistoryTitle)),
      body: SafeArea(
        child: !_ready
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 28),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
                    child: Text(
                      widget.packName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _ranges(t),
                  _chartSection(t),
                ],
              ),
      ),
    );
  }

  Widget _ranges(AppL10n t) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        if (widget.trip != null)
          _rangeChip(CellHistoryRange.trip, t.cellHistoryRangeTrip),
        if (_lastCharge != null)
          _rangeChip(CellHistoryRange.charge, t.cellHistoryRangeCharge),
        _rangeChip(CellHistoryRange.hour, t.cellHistoryRangeHour),
        _rangeChip(CellHistoryRange.day, t.cellHistoryRangeDay),
        _rangeChip(CellHistoryRange.week, t.cellHistoryRangeWeek),
      ],
    ),
  );

  Widget _rangeChip(CellHistoryRange r, String label) => ChoiceChip(
    label: Text(label),
    selected: _range == r,
    onSelected: (_) => _select(r),
  );

  Widget _chartSection(AppL10n t) {
    final w = _window;
    if (w == null || _history == null) {
      return Section(
        title: t.cellHistoryTitle,
        children: [
          InfoRow(t.cellHistoryEmpty, '', dim: true, last: true),
          const SizedBox(height: 6),
        ],
      );
    }
    return FutureBuilder<CellHistory>(
      future: _history,
      builder: (context, snap) {
        final h = snap.data;
        if (h == null) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (h.isEmpty) {
          return Section(
            title: t.cellHistoryTitle,
            children: [
              InfoRow(t.cellHistoryEmpty, '', dim: true, last: true),
              const SizedBox(height: 6),
            ],
          );
        }
        final ext = h.extremes();
        final bucket = CellHistory.bucketFor(w.from, w.to);
        return Section(
          title: _rangeTitle(t),
          trailing: Text(
            t.cellHistoryPoints(h.points.length),
            style: const TextStyle(fontSize: 11, color: AppTheme.textFaint),
          ),
          children: [
            if (_range != CellHistoryRange.trip &&
                _range != CellHistoryRange.charge &&
                _newest != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  t.cellHistoryAnchor(_dateTime(_newest!)),
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: AppTheme.textFaint,
                  ),
                ),
              ),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(t.cellHistoryModeVolts),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(t.cellHistoryModeDeviation),
                ),
              ],
              selected: {_deviation},
              onSelectionChanged: (v) => setState(() => _deviation = v.first),
            ),
            const SizedBox(height: 10),
            Text(
              _deviation ? t.cellHistoryAxisDeviation : t.cellHistoryAxisVolts,
              style: const TextStyle(fontSize: 11, color: AppTheme.textFaint),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 220,
              child: _CellChart(
                history: h,
                from: w.from,
                to: w.to,
                deviation: _deviation,
                lowest: ext.lowest,
                highest: ext.highest,
                picked: _picked,
              ),
            ),
            const SizedBox(height: 12),
            if (ext.lowest != null)
              _Legend(
                colour: AppTheme.watch,
                label: t.cellHistoryLowest(ext.lowest!),
              ),
            if (ext.highest != null && ext.highest != ext.lowest) ...[
              const SizedBox(height: 4),
              _Legend(
                colour: AppTheme.cool,
                label: t.cellHistoryHighest(ext.highest!),
              ),
            ],
            if (_picked case final p?) ...[
              const SizedBox(height: 4),
              _Legend(
                colour: AppTheme.textPrimary,
                label: t.cellHistoryPicked(p),
              ),
            ],
            const SizedBox(height: 4),
            _Legend(colour: AppTheme.textFaint, label: t.cellHistoryOthers),
            const SizedBox(height: 12),
            Caption(t.cellHistoryPickCell, color: AppTheme.textFaint),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 2,
              children: [
                for (var i = 1; i <= h.cellCount; i++)
                  ChoiceChip(
                    label: Text('$i'),
                    visualDensity: VisualDensity.compact,
                    selected: _picked == i,
                    onSelected: (on) => setState(() => _picked = on ? i : null),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              t.cellHistoryNote(_bucketLabel(bucket)),
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppTheme.textFaint,
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  String _rangeTitle(AppL10n t) => switch (_range) {
    CellHistoryRange.trip => t.cellHistoryRangeTrip,
    CellHistoryRange.charge => t.cellHistoryRangeCharge,
    CellHistoryRange.hour => t.cellHistoryRangeHour,
    CellHistoryRange.day => t.cellHistoryRangeDay,
    CellHistoryRange.week => t.cellHistoryRangeWeek,
  };

  static String _bucketLabel(Duration d) => d.inSeconds < 60
      ? '${d.inSeconds} s'
      : d.inSeconds % 60 == 0
      ? '${d.inMinutes} min'
      : '${d.inMinutes} min ${d.inSeconds % 60} s';

  static String _dateTime(DateTime utc) {
    final d = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }
}

class _CellChart extends StatelessWidget {
  const _CellChart({
    required this.history,
    required this.from,
    required this.to,
    required this.deviation,
    required this.lowest,
    required this.highest,
    required this.picked,
  });

  final CellHistory history;
  final DateTime from;
  final DateTime to;
  final bool deviation;
  final int? lowest;
  final int? highest;
  final int? picked;

  @override
  Widget build(BuildContext context) {
    double x(DateTime at) => at.difference(from).inSeconds / 60.0;

    List<FlSpot> spotsFor(int cell) {
      final out = <FlSpot>[];
      for (final p in history.points) {
        // A break, not a straight line across a stretch nobody read.
        if (p.gapBefore && out.isNotEmpty) out.add(FlSpot.nullSpot);
        final v = p.cells[cell - 1];
        out.add(FlSpot(x(p.at), deviation ? (v - p.average) * 1000 : v));
      }
      return out;
    }

    LineChartBarData line(int cell, Color colour, double width) =>
        LineChartBarData(
          spots: spotsFor(cell),
          isCurved: false,
          barWidth: width,
          color: colour,
          dotData: const FlDotData(show: false),
        );

    final bars = <LineChartBarData>[
      // The rest first, faint, so the ones that matter are drawn on top.
      for (var c = 1; c <= history.cellCount; c++)
        if (c != lowest && c != highest && c != picked)
          line(c, AppTheme.textFaint.withValues(alpha: 0.45), 1),
      if (highest case final c? when c != picked) line(c, AppTheme.cool, 2.2),
      if (lowest case final c? when c != picked) line(c, AppTheme.watch, 2.2),
      if (picked case final c?) line(c, AppTheme.textPrimary, 2.4),
    ];

    final spanMinutes = to.difference(from).inMinutes.toDouble();
    final longSpan = spanMinutes > 26 * 60;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: spanMinutes <= 0 ? 1 : spanMinutes,
        gridData: const FlGridData(drawVerticalLine: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: spanMinutes > 0,
              reservedSize: 20,
              interval: spanMinutes <= 0 ? 1 : spanMinutes / 3,
              getTitlesWidget: (v, m) {
                final at = from
                    .add(Duration(seconds: (v * 60).round()))
                    .toLocal();
                String two(int n) => n.toString().padLeft(2, '0');
                return Text(
                  longSpan
                      ? '${at.day}/${at.month}'
                      : '${two(at.hour)}:${two(at.minute)}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textFaint,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (v, m) => Text(
                deviation ? v.toStringAsFixed(0) : v.toStringAsFixed(2),
                style: const TextStyle(fontSize: 10, color: AppTheme.textFaint),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: bars,
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.colour, required this.label});

  final Color colour;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 14,
        height: 3,
        decoration: BoxDecoration(
          color: colour,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ),
    ],
  );
}
