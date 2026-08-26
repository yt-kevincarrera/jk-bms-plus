import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../bms_service.dart';
import '../data/database.dart';
import '../metrics/long_term_analysis.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// The long view.
///
/// Everything here is drawn from rows the app has been storing all along. It
/// was built last for the same reason it stays honest about itself: a curve
/// through three points spread over two days looks exactly like a curve through
/// thirty points spread over a year, and only one of them means anything. Each
/// section says how much history is behind it.
class TrendsScreen extends StatefulWidget {
  const TrendsScreen({required this.service, super.key});

  final BmsService service;

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  static const _analysis = LongTermAnalysis();

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

    final device = widget.service.activeDeviceId;
    if (device == null) {
      setState(() => _loading = false);
      return;
    }

    final trips = await repo.db.recentTrips(device, limit: 500);
    final tests = await repo.capacityTests(device);
    // Ninety days is enough to show a season's worth of drift without pulling
    // millions of rows into memory.
    final snapshots = await repo.db.snapshotsBetween(
      device,
      DateTime.now().toUtc().subtract(const Duration(days: 90)),
      DateTime.now().toUtc(),
    );

    if (!mounted) return;
    setState(() {
      _trips = trips;
      _snapshots = snapshots;
      _tests = tests;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.trendsTitle)),
      body: SafeArea(
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
                  _consumption(t),
                  _capacity(t),
                  _sag(t),
                  _deltaAgainstCharge(t),
                ],
              ),
      ),
    );
  }

  Widget _consumption(AppL10n t) {
    final points = _analysis.consumptionOverTime(_trips);
    final trend = _analysis.trendPerMonth(
      [for (final p in points) (at: p.at, value: p.whPerKm)],
    );

    return _TrendSection(
      title: t.trendsConsumption,
      spanDays: _analysis.spanDays([for (final p in points) p.at]),
      pointCount: points.length,
      trendLabel: trend == null
          ? null
          : t.trendsPerMonth('${trend >= 0 ? "+" : ""}${trend.toStringAsFixed(1)} Wh/km'),
      trendIsBad: (trend ?? 0) > 0.5,
      spots: [
        for (var i = 0; i < points.length; i++)
          FlSpot(i.toDouble(), points[i].whPerKm),
      ],
      unit: 'Wh/km',
      t: t,
    );
  }

  Widget _capacity(AppL10n t) {
    final points = _analysis.capacityOverTime(_tests);
    final trend = _analysis.trendPerMonth(
      [for (final p in points) (at: p.at, value: p.measuredAh)],
    );

    return _TrendSection(
      title: t.trendsCapacity,
      spanDays: _analysis.spanDays([for (final p in points) p.at]),
      pointCount: points.length,
      trendLabel: trend == null
          ? null
          : t.trendsPerMonth('${trend.toStringAsFixed(2)} Ah'),
      trendIsBad: (trend ?? 0) < -0.1,
      spots: [
        for (var i = 0; i < points.length; i++)
          FlSpot(i.toDouble(), points[i].measuredAh),
      ],
      unit: 'Ah',
      t: t,
    );
  }

  Widget _sag(AppL10n t) {
    final points = _analysis.sagOverTime(_trips);
    final resistances = <({DateTime at, double value})>[];
    for (final p in points) {
      final r = _analysis.apparentResistanceMilliohms(p);
      if (r != null) resistances.add((at: p.at, value: r));
    }
    final trend = _analysis.trendPerMonth(resistances);

    return _TrendSection(
      title: t.trendsSag,
      spanDays: _analysis.spanDays([for (final p in points) p.at]),
      pointCount: resistances.length,
      trendLabel: trend == null
          ? null
          : t.trendsPerMonth('${trend >= 0 ? "+" : ""}${trend.toStringAsFixed(1)} mΩ'),
      trendIsBad: (trend ?? 0) > 0.5,
      hint: t.trendsSagHint,
      spots: [
        for (var i = 0; i < resistances.length; i++)
          FlSpot(i.toDouble(), resistances[i].value),
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
    this.trendLabel,
    this.trendIsBad = false,
    this.hint,
  });

  final String title;
  final int spanDays;
  final int pointCount;
  final List<FlSpot> spots;
  final String unit;
  final AppL10n t;
  final String? trendLabel;
  final bool trendIsBad;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    if (pointCount < 3) {
      return Section(
        title: title,
        children: [
          InfoRow(t.trendsNotEnough, '', dim: true, last: true),
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
        SizedBox(
          height: 150,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(drawVerticalLine: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                bottomTitles: const AxisTitles(),
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
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  barWidth: 2.2,
                  color: AppTheme.good,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppTheme.good.withValues(alpha: 0.08),
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
