import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../data/database.dart';
import '../data/repository.dart';
import '../metrics/trip_recorder.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/trip_learned_section.dart';

/// One stored ride, in full.
///
/// The profile chart puts speed and altitude on the same time axis because that
/// is where the interesting question lives: a stretch where consumption spiked
/// is either a hill or a heavy right hand, and the two lines together say which.
class TripDetailScreen extends StatelessWidget {
  const TripDetailScreen({
    required this.trip,
    required this.repository,
    super.key,
  });

  final Trip trip;
  final BmsRepository repository;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final net = trip.energyOutWh - trip.energyInWh;
    final whPerKm = trip.distanceKm < 0.2 ? null : net / trip.distanceKm;
    final socUsed = trip.startSoc - trip.endSoc;

    return Scaffold(
      appBar: AppBar(title: Text(t.historyDetail)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                _date(trip.startedAt),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      label: t.tripDistance,
                      value: trip.distanceKm.toStringAsFixed(2),
                      unit: 'km',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MetricTile(
                      label: t.tripConsumption,
                      value: whPerKm?.toStringAsFixed(0) ?? '--',
                      unit: 'Wh/km',
                    ),
                  ),
                ],
              ),
            ),
            _ProfileSection(
              tripId: trip.id,
              repository: repository,
              t: t,
            ),
            // What the app concluded when this ride ended, as it was then. It
            // used to be shown once in a sheet and then be unreachable, which
            // made the most interesting part of recording a ride the part you
            // could not go back and read. Draws nothing for rides from before
            // the conclusions were kept.
            TripLearnedSection(
              conclusions: TripConclusions.restore(
                whPerKmBefore: trip.whPerKmBefore,
                whPerKmAfter: trip.whPerKmAfter,
                learnedKm: trip.learnedKm,
                rangeKmAtEnd: trip.rangeKmAtEnd,
                confidence: trip.confidence,
              ),
              whPerKm: whPerKm,
              socUsed: socUsed,
              distanceKm: trip.distanceKm,
              maxTemperature: trip.maxTemperature,
              maxDeltaVolts: trip.maxDeltaVolts,
              t: t,
            ),
            Section(
              title: t.tripTitle,
              children: [
                InfoRow(t.tripMoving, _duration(trip.movingSeconds)),
                InfoRow(t.tripElapsed, _duration(trip.totalSeconds)),
                InfoRow(
                  t.tripStopped,
                  _duration(trip.totalSeconds - trip.movingSeconds),
                ),
                InfoRow(
                  t.tripMaxSpeed,
                  '${trip.maxSpeedKmh.toStringAsFixed(0)} km/h',
                ),
                InfoRow(
                  t.tripAvgSpeed,
                  trip.movingSeconds < 10
                      ? '--'
                      : '${(trip.distanceKm / (trip.movingSeconds / 3600)).toStringAsFixed(0)} km/h',
                ),
                InfoRow(t.tripClimb, '${trip.climbM.toStringAsFixed(0)} m'),
                InfoRow(
                  t.tripDescent,
                  '${trip.descentM.toStringAsFixed(0)} m',
                  last: true,
                ),
              ],
            ),
            Section(
              title: t.tripPackDuring,
              children: [
                InfoRow(
                  t.tripEnergyOut,
                  '${trip.energyOutWh.toStringAsFixed(1)} Wh',
                ),
                InfoRow(
                  t.tripEnergyIn,
                  '${trip.energyInWh.toStringAsFixed(1)} Wh',
                ),
                InfoRow(t.tripSocUsed, '${socUsed.toStringAsFixed(0)} %'),
                InfoRow(
                  t.tripSocPerKm,
                  trip.distanceKm < 0.2 || socUsed <= 0
                      ? '--'
                      : '${(socUsed / trip.distanceKm).toStringAsFixed(2)} %/km',
                  dim: trip.distanceKm < 0.2 || socUsed <= 0,
                ),
                InfoRow(
                  t.tripSag,
                  '${(trip.maxPackVoltage - trip.minPackVoltage).toStringAsFixed(2)} V',
                ),
                InfoRow(
                  t.tripMaxCurrent,
                  '${trip.maxDischargeCurrent.toStringAsFixed(1)} A',
                ),
                InfoRow(
                  t.tripMaxTemp,
                  '${trip.maxTemperature.toStringAsFixed(1)} °C',
                ),
                InfoRow(
                  t.tripMaxDelta,
                  trip.maxDeltaVolts.toStringAsFixed(3),
                  valueColor:
                      trip.maxDeltaVolts > 0.10 ? AppTheme.watch : null,
                  last: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _date(DateTime utc) {
    final d = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }

  static String _duration(int seconds) {
    final d = Duration(seconds: seconds);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '$h h $m min';
    if (d.inMinutes < 10) return '$m:${s.toString().padLeft(2, '0')}';
    return '$m min';
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.tripId,
    required this.repository,
    required this.t,
  });

  final int tripId;
  final BmsRepository repository;
  final AppL10n t;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TripPoint>>(
      future: repository.pointsFor(tripId),
      builder: (context, snapshot) {
        final points = snapshot.data;
        if (points == null) {
          return Section(
            title: t.historyProfile,
            children: const [
              SizedBox(
                height: 120,
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.goodDim,
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        if (points.length < 3) {
          return Section(
            title: t.historyProfile,
            children: [
              InfoRow(t.historyNoPoints, '', dim: true, last: true),
            ],
          );
        }

        return Section(
          title: t.historyProfile,
          trailing: Text(
            t.historyPoints(points.length),
            style: const TextStyle(fontSize: 11, color: AppTheme.textFaint),
          ),
          children: [
            SizedBox(height: 170, child: _ProfileChart(points: points)),
            const SizedBox(height: 12),
            Row(
              children: [
                _Legend(colour: AppTheme.good, label: t.historyLegendSpeed),
                const SizedBox(width: 16),
                _Legend(colour: AppTheme.cool, label: t.historyLegendAltitude),
              ],
            ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }
}

class _ProfileChart extends StatelessWidget {
  const _ProfileChart({required this.points});

  final List<TripPoint> points;

  @override
  Widget build(BuildContext context) {
    final t0 = points.first.timestamp;

    var minAlt = points.first.altitudeM;
    var maxAlt = points.first.altitudeM;
    var maxSpeed = 1.0;
    for (final p in points) {
      if (p.altitudeM < minAlt) minAlt = p.altitudeM;
      if (p.altitudeM > maxAlt) maxAlt = p.altitudeM;
      if (p.speedKmh > maxSpeed) maxSpeed = p.speedKmh;
    }
    final altRange = (maxAlt - minAlt).abs() < 1 ? 1.0 : maxAlt - minAlt;

    final speedSpots = <FlSpot>[];
    final altitudeSpots = <FlSpot>[];
    for (final p in points) {
      final x = p.timestamp.difference(t0).inSeconds / 60.0;
      speedSpots.add(FlSpot(x, p.speedKmh));
      // Altitude is normalised onto the speed axis: the shape is what matters
      // here, and two axes on a phone-width chart is one too many.
      altitudeSpots.add(
        FlSpot(x, (p.altitudeM - minAlt) / altRange * maxSpeed),
      );
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxSpeed * 1.15,
        gridData: const FlGridData(drawVerticalLine: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              getTitlesWidget: (value, meta) => Text(
                '${value.toStringAsFixed(0)}m',
                style: const TextStyle(fontSize: 10, color: AppTheme.textFaint),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
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
            spots: altitudeSpots,
            isCurved: true,
            barWidth: 1.4,
            color: AppTheme.cool.withValues(alpha: 0.8),
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.cool.withValues(alpha: 0.10),
            ),
          ),
          LineChartBarData(
            spots: speedSpots,
            isCurved: true,
            barWidth: 2.2,
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
