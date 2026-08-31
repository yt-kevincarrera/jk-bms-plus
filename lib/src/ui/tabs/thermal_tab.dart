import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../bms_service.dart';
import '../../model/bms_snapshot.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Temperatures, and how they track current over time.
///
/// The correlation is the interesting part. A single number tells you the pack
/// is warm; the two lines together tell you whether it is warm because you have
/// been riding hard or because something is wrong.
class ThermalTab extends StatelessWidget {
  const ThermalTab({required this.service, required this.snapshot, super.key});

  final BmsService service;
  final BmsSnapshot? snapshot;

  static const Duration _window = Duration(minutes: 10);

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final s = snapshot;
    if (s == null) {
      return WaitingForData(message: t.waitingFor(t.waitingTemperatures));
    }

    final recent = service.history.recent(_window);

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              // Only the probes that are wired to something. An unconnected
              // one reads about -200 C, which is not a cold battery, and a
              // tile saying so is worse than no tile: it invites you to worry
              // about a number that means "no sensor here".
              for (final probe in s.connectedTemperatures)
                SizedBox(
                  width: 108,
                  child: MetricTile(
                    label: t.thermalProbe(probe.index + 1),
                    value: probe.celsius.toStringAsFixed(1),
                    unit: '°C',
                    color: _tempColour(probe.celsius),
                  ),
                ),
              if (s.mosfetTemp != null)
                SizedBox(
                  width: 108,
                  child: MetricTile(
                    label: t.thermalMosfet,
                    value: s.mosfetTemp!.toStringAsFixed(1),
                    unit: '°C',
                    color: _tempColour(s.mosfetTemp!),
                  ),
                ),
            ],
          ),
        ),
        Section(
          title: t.thermalLastMinutes(_window.inMinutes),
          trailing: Text(
            t.thermalSamples(recent.length),
            style: const TextStyle(fontSize: 11, color: AppTheme.textFaint),
          ),
          children: [
            SizedBox(
              height: 170,
              child: recent.length < 3
                  ? Center(
                      child: Text(
                        t.thermalCollecting,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.textFaint,
                        ),
                      ),
                    )
                  : _TempCurrentChart(samples: recent),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Legend(colour: AppTheme.good, label: t.thermalLegendHottest),
                const SizedBox(width: 16),
                _Legend(colour: AppTheme.cool, label: t.thermalLegendCurrent),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
        Section(
          title: t.thermalSensorsTitle,
          children: [
            InfoRow(
              t.thermalProbesReported,
              s.absentTemperatureProbes.isEmpty
                  ? '${s.temperatures.length}'
                  : '${s.connectedTemperatures.length} / ${s.temperatures.length}',
              hint: s.absentTemperatureProbes.isEmpty
                  ? null
                  : t.thermalAbsentNote,
            ),
            if (s.absentTemperatureProbes.isNotEmpty)
              for (final i in s.absentTemperatureProbes)
                InfoRow(
                  t.thermalProbe(i + 1),
                  t.thermalProbeAbsent,
                  dim: true,
                ),

            InfoRow(
              t.thermalMosfetSensor,
              s.mosfetTemp == null ? t.notReported : t.reported,
            ),
            InfoRow(
              t.thermalSensorMask,
              '0x${s.temperatureSensorMask.toRadixString(16).padLeft(4, '0')}',
              hint: t.thermalMaskNote,
            ),
            InfoRow(t.thermalHeater, s.heatingOn ? t.on : t.off),
            InfoRow(
              t.thermalHeaterCurrent,
              '${s.heatingCurrent.toStringAsFixed(2)} A',
              last: true,
            ),
          ],
        ),
      ],
    );
  }

  Color _tempColour(double c) {
    if (c > 55) return AppTheme.bad;
    if (c > 45) return AppTheme.watch;
    if (c < 0) return AppTheme.cold;
    return AppTheme.good;
  }
}

class _TempCurrentChart extends StatelessWidget {
  const _TempCurrentChart({required this.samples});

  final List<BmsSnapshot> samples;

  @override
  Widget build(BuildContext context) {
    final t0 = samples.first.timestamp;
    final spanMinutes =
        samples.last.timestamp.difference(t0).inMilliseconds / 60000.0;
    // Below a couple of minutes every label rounds to "0m", which tells you
    // nothing. Switch to seconds until there is enough history for minutes.
    final inSeconds = spanMinutes < 2;

    double hottest(BmsSnapshot s) {
      final all = [...s.temperatures, if (s.mosfetTemp != null) s.mosfetTemp!];
      return all.isEmpty ? 0 : all.reduce((a, b) => a > b ? a : b);
    }

    final tempSpots = <FlSpot>[];
    final currentSpots = <FlSpot>[];
    var maxTemp = 0.0;
    var maxCurrent = 1.0;

    for (final s in samples) {
      final x = s.timestamp.difference(t0).inMilliseconds / 60000.0;
      final temp = hottest(s);
      final amps = s.current.abs();
      tempSpots.add(FlSpot(x, temp));
      currentSpots.add(FlSpot(x, amps));
      if (temp > maxTemp) maxTemp = temp;
      if (amps > maxCurrent) maxCurrent = amps;
    }

    // Current shares the temperature axis so both fit one chart. Only the shape
    // matters for the correlation, and the legend says which line is which.
    final scale = maxTemp <= 0 ? 1.0 : maxTemp / maxCurrent;
    final scaledCurrent = [
      for (final s in currentSpots) FlSpot(s.x, s.y * scale),
    ];

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: (maxTemp * 1.25).clamp(10, 120),
        gridData: const FlGridData(
          drawVerticalLine: false,
          horizontalInterval: 20,
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              getTitlesWidget: (value, meta) => Text(
                inSeconds
                    ? '${(value * 60).toStringAsFixed(0)}s'
                    : '${value.toStringAsFixed(0)}m',
                style: const TextStyle(fontSize: 10, color: AppTheme.textFaint),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 20,
              reservedSize: 28,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
                style: const TextStyle(fontSize: 10, color: AppTheme.textFaint),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: scaledCurrent,
            isCurved: true,
            barWidth: 1.4,
            color: AppTheme.cool.withValues(alpha: 0.8),
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: tempSpots,
            isCurved: true,
            barWidth: 2.4,
            color: AppTheme.good,
            dotData: const FlDotData(show: false),
          ),
        ],
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
