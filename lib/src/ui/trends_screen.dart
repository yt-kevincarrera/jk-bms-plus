import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../bms_service.dart';
import '../data/database.dart';
import '../metrics/chart_markers.dart';
import '../metrics/long_term_analysis.dart';
import '../metrics/maintenance.dart';
import '../license/entitlements.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/pro_gate.dart';

/// The long view.
///
/// Everything here is drawn from rows the app has been storing all along. It
/// was built last for the same reason it stays honest about itself: a curve
/// through three points spread over two days looks exactly like a curve through
/// thirty points spread over a year, and only one of them means anything. Each
/// section says how much history is behind it.
class TrendsScreen extends StatefulWidget {
  const TrendsScreen({required this.service, this.deviceId, super.key});

  final BmsService service;

  /// Which pack to chart. Defaults to whatever is connected, but the offline
  /// summary opens this with nothing connected at all, and it used to show an
  /// empty screen there.
  final String? deviceId;

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  static const _analysis = LongTermAnalysis();

  List<MaintenanceEvent> _maintenance = const [];

  /// The last cell replacement, from which the pack's charts start. Null
  /// when there was none.
  DateTime? _since;

  List<Trip> _trips = const [];
  List<Snapshot> _snapshots = const [];
  List<CapacityTest> _tests = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = widget.service.repository;
    if (repo == null) {
      setState(() => _loading = false);
      return;
    }

    final device = widget.deviceId ?? widget.service.activeDeviceId;
    if (device == null) {
      setState(() => _loading = false);
      return;
    }

    final trips = await repo.db.recentTrips(device, limit: 500);
    // The pack's own charts start at the last cell replacement; consumption
    // does not, because what the bike costs did not change with the cell.
    final tests = await repo.currentPackCapacityTests(device);
    final maintenance = await MaintenanceLog(repo.db).forPack(device);
    // Ninety days is enough to show a season's worth of drift without pulling
    // millions of rows into memory.
    final snapshots = await repo.currentPackSnapshots(device, days: 90);

    if (!mounted) return;
    setState(() {
      _trips = trips;
      _snapshots = snapshots;
      _tests = tests;
      _maintenance = maintenance;
      _since = MaintenanceLog.historyStart(maintenance);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.trendsTitle)),
      // Gated at the screen rather than at each button that opens it, so
      // every way in (history tab, saved-pack screen) gets the same answer.
      body: SafeArea(
        child: ProGate(
          feature: Feature.degradation,
          child: _loading
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.goodDim,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(top: 8, bottom: 28),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                      child: Text(
                        t.trendsIntro,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    if (_since case final since?)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Text(
                          t.maintSince(_day(since)),
                          style: const TextStyle(
                            fontSize: 11.5,
                            height: 1.4,
                            color: AppTheme.watch,
                          ),
                        ),
                      ),
                    _consumption(t),
                    _capacity(t),
                    _sag(t),
                    _deltaAgainstCharge(t),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _consumption(AppL10n t) {
    final points = _analysis.consumptionOverTime(_trips);
    final trend = _analysis.trendPerMonth([
      for (final p in points) (at: p.at, value: p.whPerKm),
    ]);

    final first = points.isEmpty ? null : points.first.at;
    return _TrendSection(
      title: t.trendsConsumption,
      spanDays: _analysis.spanDays([for (final p in points) p.at]),
      pointCount: points.length,
      trendLabel: trend == null
          ? null
          : t.trendsPerMonth(
              '${trend >= 0 ? "+" : ""}${trend.toStringAsFixed(1)} Wh/km',
            ),
      // Not a warning colour: costing more per kilometre is the route, the
      // weather or the rider far more often than the pack.
      trendIsBad: false,
      firstDate: first,
      spots: [
        for (final p in points)
          FlSpot(ChartMarkers.dayOf(first!, p.at), p.whPerKm),
      ],
      unit: 'Wh/km',
      hint: t.trendsConsumptionHint,
      axisNote: t.trendsAxisTime,
      markers: ChartMarkers.place(
        pointDates: [for (final p in points) p.at],
        events: _maintenance,
      ),
      t: t,
    );
  }

  Widget _capacity(AppL10n t) {
    final points = _analysis.capacityOverTime(_tests);
    // The trend only through the runs the rest of the app believes; the line
    // only through the deliberate ones among those. Everything else is drawn
    // as a hollow circle beside it.
    final believed = [
      for (final p in points)
        if (p.trusted) p,
    ];
    final solid = [
      for (final p in believed)
        if (!p.detected) p,
    ];
    final hollow = [
      for (final p in points)
        if (!p.trusted || p.detected) p,
    ];
    final trend = _analysis.trendPerMonth([
      for (final p in believed) (at: p.at, value: p.measuredAh),
    ]);
    final first = points.isEmpty ? null : points.first.at;

    return _TrendSection(
      title: t.trendsCapacity,
      spanDays: _analysis.spanDays([for (final p in points) p.at]),
      pointCount: points.length,
      trendLabel: trend == null
          ? null
          : t.trendsPerMonth('${trend.toStringAsFixed(2)} Ah'),
      trendIsBad: (trend ?? 0) < -0.1,
      firstDate: first,
      spots: [
        for (final p in solid)
          FlSpot(ChartMarkers.dayOf(first!, p.at), p.measuredAh),
      ],
      hollowSpots: [
        for (final p in hollow)
          FlSpot(ChartMarkers.dayOf(first!, p.at), p.measuredAh),
      ],
      hollowNote: hollow.isEmpty ? null : t.trendsCapacityHollow,
      unit: 'Ah',
      hint: t.trendsCapacityHint,
      axisNote: t.trendsAxisTime,
      notEnough: t.trendsCapacityNotEnough,
      markers: ChartMarkers.place(
        pointDates: [for (final p in points) p.at],
        events: _maintenance,
      ),
      t: t,
    );
  }

  Widget _sag(AppL10n t) {
    final since = _since;
    final trips = since == null
        ? _trips
        : [
            for (final tr in _trips)
              if (!tr.startedAt.isBefore(since)) tr,
          ];
    final points = _analysis.resistanceOverTime(trips, _snapshots);
    final resistances = [
      for (final p in points) (at: p.at, value: p.milliohms),
    ];
    final trend = _analysis.trendPerMonth(resistances);
    final first = points.isEmpty ? null : points.first.at;

    return _TrendSection(
      title: t.trendsSag,
      spanDays: _analysis.spanDays([for (final p in points) p.at]),
      pointCount: resistances.length,
      firstDate: first,
      trendLabel: trend == null
          ? null
          : t.trendsPerMonth(
              '${trend >= 0 ? "+" : ""}${trend.toStringAsFixed(1)} mΩ',
            ),
      trendIsBad: (trend ?? 0) > 0.5,
      hint: t.trendsSagHint,
      axisNote: t.trendsAxisTime,
      spots: [
        for (final r in resistances)
          FlSpot(ChartMarkers.dayOf(first!, r.at), r.value),
      ],
      unit: 'mΩ',
      t: t,
    );
  }

  Widget _deltaAgainstCharge(AppL10n t) {
    final points = _analysis.deltaAgainstCharge(_snapshots);
    final loaded = points.where((p) => p.underLoad).toList();
    final resting = points.where((p) => !p.underLoad).toList();

    if (points.length < 8) {
      return Section(
        title: t.trendsDeltaVsCharge,
        children: [
          InfoRow(t.trendsNotEnough, '', dim: true, last: true),
          const SizedBox(height: 6),
        ],
      );
    }

    return Section(
      title: t.trendsDeltaVsCharge,
      intro: t.trendsDeltaHint,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            t.trendsAxisCharge,
            style: const TextStyle(
              fontSize: 11,
              height: 1.4,
              color: AppTheme.textFaint,
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: 100,
              minY: 0,
              gridData: const FlGridData(drawVerticalLine: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 25,
                    reservedSize: 20,
                    getTitlesWidget: (v, m) => Text(
                      '${v.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textFaint,
                      ),
                    ),
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (v, m) => Text(
                      v.toStringAsFixed(2),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textFaint,
                      ),
                    ),
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [
                if (resting.length > 1)
                  LineChartBarData(
                    spots: [
                      for (final p in resting) FlSpot(p.soc, p.deltaVolts),
                    ],
                    isCurved: false,
                    barWidth: 2,
                    color: AppTheme.good,
                    dotData: const FlDotData(show: false),
                  ),
                if (loaded.length > 1)
                  LineChartBarData(
                    spots: [
                      for (final p in loaded) FlSpot(p.soc, p.deltaVolts),
                    ],
                    isCurved: false,
                    barWidth: 2,
                    color: AppTheme.watch,
                    dotData: const FlDotData(show: false),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _Legend(colour: AppTheme.good, label: t.trendsLegendResting),
            const SizedBox(width: 16),
            _Legend(colour: AppTheme.watch, label: t.trendsLegendLoaded),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _TrendSection extends StatelessWidget {
  const _TrendSection({
    required this.title,
    required this.spanDays,
    required this.pointCount,
    required this.spots,
    required this.unit,
    required this.t,
    this.firstDate,
    this.hollowSpots = const [],
    this.hollowNote,
    this.markers = const [],
    this.trendLabel,
    this.trendIsBad = false,
    this.hint,
    this.axisNote,
    this.notEnough,
  });

  final String title;
  final int spanDays;
  final int pointCount;
  final List<FlSpot> spots;
  final String unit;
  final AppL10n t;

  /// The date at x = 0. The x axis is days since then, so a season with no
  /// rides shows as a gap instead of as two neighbouring points.
  final DateTime? firstDate;

  /// Points drawn as hollow circles off the line: shown, and not believed.
  final List<FlSpot> hollowSpots;
  final String? hollowNote;

  /// Work done to the pack, drawn over the line. A capacity that jumps reads
  /// as noise until a marker says a cell was replaced that week.
  final List<ChartMarker> markers;
  final String? trendLabel;
  final bool trendIsBad;
  final String? hint;

  /// Which way the sideways axis runs. Obvious once you know and impossible to
  /// guess from a chart whose x axis is an index rather than a date.
  final String? axisNote;

  /// What to say while there are too few points, when "it fills in on its
  /// own" is not true: capacity needs a full discharge per point.
  final String? notEnough;

  @override
  Widget build(BuildContext context) {
    if (pointCount < 3) {
      return Section(
        title: title,
        // Said even here, and especially here: an empty chart is exactly when
        // somebody wants to know what it is going to tell them.
        intro: hint,
        children: [
          InfoRow(notEnough ?? t.trendsNotEnough, '', dim: true, last: true),
          const SizedBox(height: 6),
        ],
      );
    }

    return Section(
      title: title,
      intro: hint,
      trailing: Text(
        t.trendsSpan(spanDays),
        style: const TextStyle(fontSize: 11, color: AppTheme.textFaint),
      ),
      children: [
        if (axisNote != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              axisNote!,
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppTheme.textFaint,
              ),
            ),
          ),
        // Only when there is something to explain. A legend for lines that
        // are not on the chart is noise.
        if (markers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              t.trendsMaintMarks,
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppTheme.textFaint,
              ),
            ),
          ),
        if (hollowNote != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              hollowNote!,
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppTheme.textFaint,
              ),
            ),
          ),
        SizedBox(
          height: 150,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(drawVerticalLine: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: firstDate != null && spanDays > 0,
                    reservedSize: 20,
                    interval: spanDays <= 0 ? 1 : spanDays / 3,
                    getTitlesWidget: (v, m) => Text(
                      _day(firstDate!.add(Duration(minutes: (v * 1440).round()))),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textFaint,
                      ),
                    ),
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 38,
                    getTitlesWidget: (v, m) => Text(
                      v.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textFaint,
                      ),
                    ),
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              // Work done to the pack, over the line it explains.
              extraLinesData: ExtraLinesData(
                verticalLines: [
                  for (final m in markers)
                    VerticalLine(
                      x: m.x,
                      color: AppTheme.watch.withValues(alpha: 0.55),
                      strokeWidth: 1.5,
                      dashArray: const [4, 3],
                    ),
                ],
              ),
              lineBarsData: [
                if (spots.isNotEmpty)
                  LineChartBarData(
                    spots: spots,
                    // Straight, not curved: points days or months apart are
                    // joined by a line, and a curve between them would draw
                    // a shape nothing measured.
                    isCurved: false,
                    barWidth: 2.2,
                    color: AppTheme.good,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.good.withValues(alpha: 0.08),
                    ),
                  ),
                if (hollowSpots.isNotEmpty)
                  LineChartBarData(
                    spots: hollowSpots,
                    barWidth: 0,
                    color: Colors.transparent,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                            radius: 3.5,
                            color: AppTheme.surface,
                            strokeWidth: 1.6,
                            strokeColor: AppTheme.good,
                          ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (trendLabel != null) ...[
          const SizedBox(height: 10),
          InfoRow(
            unit,
            trendLabel!,
            valueColor: trendIsBad ? AppTheme.watch : AppTheme.good,
            last: true,
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.colour, required this.label});

  final Color colour;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
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
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
      ),
    ],
  );
}

/// A date as the charts label it: day and month.
String _day(DateTime utc) {
  final d = utc.toLocal();
  return '${d.day}/${d.month}';
}
