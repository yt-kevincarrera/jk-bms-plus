import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../bms_service.dart';
import '../data/database.dart';
import '../data/exporter.dart';
import '../data/repository.dart';
import '../metrics/trip_learning.dart';
import '../metrics/trip_recorder.dart';
import 'cell_history_screen.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/energy_source_label.dart';
import 'widgets/representative_question.dart';
import 'widgets/trip_grade_rows.dart';
import 'widgets/instruments.dart';
import 'widgets/trip_learned_section.dart';
import 'widgets/trip_map.dart';
import 'widgets/trip_summary_view.dart';

/// One stored ride, in full.
///
/// The profile chart puts speed and altitude on the same time axis because that
/// is where the interesting question lives: a stretch where consumption spiked
/// is either a hill or a heavy right hand, and the two lines together say which.
class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({
    required this.trip,
    required this.repository,
    required this.service,
    required this.learned,
    this.onChanged,
    super.key,
  });

  final Trip trip;
  final BmsRepository repository;

  /// Handed to [RepresentativeQuestion], which needs it to record and to
  /// re-learn from an answer given here, same as from the sheet.
  final BmsService service;

  /// The figures of the pack this ride belongs to. Passed down rather than
  /// read off [service] because this screen is also opened from the
  /// saved-pack screen, with nothing connected.
  final LearnedRange Function() learned;

  /// Refreshes whatever [learned] reads, after an answer changes it.
  final Future<void> Function()? onChanged;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  /// The row as it stands now.
  ///
  /// Held in state rather than read off the widget because re-measuring a ride
  /// rewrites it, and a screen showing the figure the rider just corrected
  /// would be the same "nothing appeared to happen" the change button was
  /// guilty of.
  late Trip trip = widget.trip;

  BmsRepository get repository => widget.repository;
  BmsService get service => widget.service;

  bool _remeasuring = false;

  /// The track, read once. Both the profile chart and the uphill/downhill
  /// figures are built from it, and each doing its own query would read a
  /// thousand rows twice to answer the same question.
  late final Future<List<TripPoint>> _points = repository.pointsFor(
    widget.trip.id,
  );

  /// Re-reads the row after something rewrites it.
  Future<void> _reload() async {
    final fresh = await repository.db.tripById(trip.id);
    if (!mounted || fresh == null) return;
    setState(() => trip = fresh);
  }

  /// Measures this ride again, on the rider's say-so.
  ///
  /// Exists because the automatic pass cannot help here. It looks only at
  /// rides whose own row admits something is missing, since it runs on the
  /// first decoded frame of every connection and reading a week of history
  /// there once held up the live screen. Two real rides were stored as a
  /// confident coulomb count that was out by a factor of thirty, so nothing in
  /// the row hinted at it and no pass would ever look again. The rider can see
  /// the figure is wrong; this is them saying so.
  Future<void> _remeasure(AppL10n t) async {
    final messenger = ScaffoldMessenger.of(context);
    final before = trip.distanceKm < 0.2
        ? null
        : (trip.energyOutWh - trip.energyInWh) / trip.distanceKm;

    setState(() => _remeasuring = true);
    final report = await service.repairTrip(trip.id);
    await _reload();
    // The range estimate is rebuilt inside repairTrip, so whatever shows the
    // learned figures has to be told as well.
    await widget.onChanged?.call();
    if (!mounted) return;
    setState(() => _remeasuring = false);

    final after = trip.distanceKm < 0.2
        ? null
        : (trip.energyOutWh - trip.energyInWh) / trip.distanceKm;

    // Say what happened, always. The change button next to the representative
    // answer did its work in silence, and a button that appears to do nothing
    // is worse than no button: it got pressed twice.
    final String message;
    if (report.repaired == 0) {
      message = t.tripRemeasureFailed;
    } else if (before == null ||
        after == null ||
        (after - before).abs() < 0.5) {
      message = t.tripRemeasureSame;
    } else {
      message = t.tripRemeasureDone(
        after.toStringAsFixed(1),
        before.toStringAsFixed(1),
      );
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final view = TripSummaryView.fromStored(trip);
    // Null for a ride too short or never measured. Dividing the stored zero
    // of an unmeasured ride by its distance read "0 Wh/km", a ride that cost
    // nothing.
    final whPerKm = view.whPerKm;
    final measured = view.energyMeasured;
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
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            RepresentativeQuestion(
              view: view,
              service: service,
              learned: widget.learned,
              onChanged: widget.onChanged,
              t: t,
            ),
            TripInstruments(
              distanceLabel: t.tripDistance,
              distance: trip.distanceKm.toStringAsFixed(2),
              consumptionLabel: t.tripConsumption,
              consumption: whPerKm?.toStringAsFixed(0) ?? '--',
            ),
            Section(
              title: t.tripTerrain,
              children: [TripGradeRows(points: _points, t: t, asTiles: true)],
            ),
            // Where the ride went, from the same track the profile and the
            // GPX export read. Draws nothing for a ride with no fixes.
            FutureBuilder<List<TripPoint>>(
              future: _points,
              builder: (context, snap) {
                final points = snap.data ?? const <TripPoint>[];
                if (drawablePoints(points).length < 2) {
                  return const SizedBox.shrink();
                }
                return Section(
                  title: t.tripMapTitle,
                  intro: t.tripMapOffline,
                  children: [TripMap(points: points)],
                );
              },
            ),
            _ProfileSection(points: _points, t: t),
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
              ],
            ),
            Section(
              title: t.tripPackDuring,
              children: [
                InfoRow(
                  t.tripEnergyOut,
                  measured
                      ? '${trip.energyOutWh.toStringAsFixed(1)} Wh'
                      : t.tripNotMeasured,
                  dim: !measured,
                  hint: measured ? null : t.tripEnergyUnmeasuredWhy,
                ),
                InfoRow(
                  t.tripEnergyIn,
                  measured
                      ? '${trip.energyInWh.toStringAsFixed(1)} Wh'
                      : t.tripNotMeasured,
                ),
                InfoRow(
                  t.tripEnergyNet,
                  measured
                      ? '${(trip.energyOutWh - trip.energyInWh).toStringAsFixed(1)} Wh'
                      : t.tripNotMeasured,
                ),
                InfoRow(
                  t.tripPackVoltage,
                  '${trip.minPackVoltage.isFinite && trip.minPackVoltage > 0 ? trip.minPackVoltage.toStringAsFixed(1) : '--'} / ${trip.maxPackVoltage.isFinite && trip.maxPackVoltage > 0 ? trip.maxPackVoltage.toStringAsFixed(1) : '--'} V',
                ),
                if (energySourceLabel(t, trip.energySource) case final how?)
                  InfoRow(t.tripEnergySourceLabel, how),
                InfoRow(
                  t.tripSocUsed,
                  TripLearning.socIsPartial(trip.energySource)
                      ? '≈ ${socUsed.toStringAsFixed(0)} %'
                      : '${socUsed.toStringAsFixed(0)} %',
                ),
                InfoRow(
                  t.tripSocPerKm,
                  trip.distanceKm < 0.2 || socUsed <= 0
                      ? '--'
                      : '${(socUsed / trip.distanceKm).toStringAsFixed(2)} %/km',
                  dim: trip.distanceKm < 0.2 || socUsed <= 0,
                ),
                // Not "worst sag" any more: that was the ride's highest voltage
                // minus its lowest, which took in the whole fall in charge.
                if (trip.packResistanceMilliohms case final r?)
                  InfoRow(
                    t.tripResistance,
                    '${r.toStringAsFixed(0)} mΩ',
                    hint: t.tripResistanceHint,
                  ),
                InfoRow(
                  t.tripMaxCurrent,
                  '${trip.maxDischargeCurrent.toStringAsFixed(1)} A',
                ),
                // Empty when the pack has no battery probe, not 0 degC.
                InfoRow(
                  t.tripMaxTemp,
                  trip.maxTemperature == null
                      ? '--'
                      : '${trip.maxTemperature!.toStringAsFixed(1)} °C',
                  dim: trip.maxTemperature == null,
                ),
                InfoRow(
                  t.tripMaxDelta,
                  '${trip.maxDeltaVolts.toStringAsFixed(3)} V',
                  valueColor: trip.maxDeltaVolts > 0.10
                      ? context.colors.watch
                      : null,
                  last: true,
                ),
              ],
            ),
            // Every cell through the ride, from the readings stored during
            // it. A ride from before rides knew their pack has nowhere to
            // look them up.
            if (trip.deviceId case final id?)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CellHistoryScreen(
                          repository: repository,
                          deviceId: id,
                          packName: _date(trip.startedAt),
                          trip: trip,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.stacked_line_chart, size: 18),
                    label: Text(t.cellHistoryTripButton),
                  ),
                ),
              ),
            // Offered on every ride, not only the ones whose row admits to a
            // problem. That is the whole point: the rides this was written for
            // looked perfectly healthy in the database, and gating the button
            // on the row's own opinion would hide it in exactly the case it
            // exists for.
            Section(
              title: t.tripRemeasure,
              intro: t.tripRemeasureWhy,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: _remeasuring ? null : () => _remeasure(t),
                    child: _remeasuring
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(t.tripRemeasure),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
            // The track, to open in any map tool. The exporter had no caller
            // at all while the README advertised it.
            FutureBuilder<List<TripPoint>>(
              future: _points,
              builder: (context, snap) {
                if ((snap.data ?? const []).isEmpty) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => _exportGpx(t),
                      icon: const Icon(Icons.route_outlined, size: 18),
                      label: Text(t.tripExportGpx),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportGpx(AppL10n t) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await BmsExporter(repository).exportTrack(trip.id);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          fileNameOverrides: [p.basename(file.path)],
        ),
      );
    } on Exception catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(t.exportFailed)));
    }
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
  const _ProfileSection({required this.points, required this.t});

  /// Shared with the uphill/downhill figures, so the track is read once.
  final Future<List<TripPoint>> points;
  final AppL10n t;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TripPoint>>(
      future: points,
      builder: (context, snapshot) {
        final points = snapshot.data;
        if (points == null) {
          return Section(
            title: t.historyProfile,
            children: [
              SizedBox(
                height: 120,
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colors.goodDim,
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
            children: [InfoRow(t.historyNoPoints, '', dim: true, last: true)],
          );
        }

        return Section(
          title: t.historyProfile,
          trailing: Text(
            t.historyPoints(points.length),
            style: TextStyle(fontSize: 11, color: context.colors.textFaint),
          ),
          children: [
            SizedBox(height: 170, child: _ProfileChart(points: points)),
            const SizedBox(height: 12),
            Row(
              children: [
                _Legend(
                  colour: context.colors.good,
                  label: t.historyLegendSpeed,
                ),
                const SizedBox(width: 16),
                _Legend(
                  colour: context.colors.cool,
                  label: t.historyLegendAltitude,
                ),
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
                style: TextStyle(fontSize: 10, color: context.colors.textFaint),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
                style: TextStyle(fontSize: 10, color: context.colors.textFaint),
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
            color: context.colors.cool.withValues(alpha: 0.8),
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: context.colors.cool.withValues(alpha: 0.10),
            ),
          ),
          LineChartBarData(
            spots: speedSpots,
            isCurved: true,
            barWidth: 2.2,
            color: context.colors.good,
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
        style: TextStyle(fontSize: 11, color: context.colors.textSecondary),
      ),
    ],
  );
}
