import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../app_settings.dart';
import '../bms_service.dart';
import '../gps/location_source.dart';
import '../metrics/trip_recorder.dart';
import '../platform/screen_awake.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/trip_learned_section.dart';

/// Trip mode: the speedometer half of the app.
///
/// A speedometer app can tell you how far and how fast. A BMS app can tell you
/// what the pack did. Neither on its own answers the question someone with a
/// new battery actually has, which is what this ride cost and whether the pack
/// held up — so this screen shows both at once.
class TripScreen extends StatefulWidget {
  const TripScreen({
    required this.service,
    required this.settings,
    super.key,
  });

  final BmsService service;
  final AppSettings settings;

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  Timer? _tick;
  String? _problem;

  @override
  void initState() {
    super.initState();
    // The recorder is updated by two streams that do not go through setState,
    // so redraw on a clock rather than trying to hook both.
    _tick = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    ScreenAwakeKeeper.release();
    super.dispose();
  }

  Future<void> _start() async {
    final t = AppL10n.of(context);

    final problem = await widget.service.startTrip();
    if (!mounted) return;
    setState(() {
      _problem = problem == null ? null : _problemText(t, problem);
    });
  }

  /// Resumes, and says so if location did not come back with it.
  ///
  /// Silence here was the expensive part of the pause bug: the ride carried on
  /// looking normal while recording nothing.
  Future<void> _resume() async {
    final t = AppL10n.of(context);
    final problem = await widget.service.resumeTrip();
    if (!mounted) return;
    setState(() {
      _problem = problem == null ? null : _problemText(t, problem);
    });
  }

  Future<void> _stop() async {
    final t = AppL10n.of(context);
    final outcome = await widget.service.stopTrip();
    if (!mounted || outcome == null) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TripSummarySheet(outcome: outcome, t: t),
    );
    if (mounted) setState(() {});
  }

  String _problemText(AppL10n t, LocationProblem p) => switch (p) {
        LocationProblem.serviceDisabled => t.locationDisabled,
        LocationProblem.permissionDenied => t.locationDenied,
        LocationProblem.permanentlyDenied => t.locationDeniedForever,
      };

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final trip = widget.service.trip;
    final snapshot = widget.service.lastSnapshot;

    // Riding is the case this screen exists for, so the awake setting is
    // honoured here too rather than only on the live tab.
    ScreenAwakeKeeper.apply(
      widget.settings.screenAwake,
      riding: trip.isActive,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(t.tripTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Pill(
                switch (trip.state) {
                  TripState.recording => t.tripRecording,
                  TripState.paused => t.tripPaused,
                  TripState.idle => t.tripIdle,
                },
                color: switch (trip.state) {
                  TripState.recording => AppTheme.good,
                  TripState.paused => AppTheme.watch,
                  TripState.idle => AppTheme.textFaint,
                },
                icon: trip.isRecording ? Icons.fiber_manual_record : null,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  if (_problem != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Text(
                        _problem!,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppTheme.watch,
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          trip.speedKmh.toStringAsFixed(0),
                          style: AppTheme.readout(96),
                        ),
                        const SizedBox(height: 2),
                        Caption('km/h'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
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
                            value: trip.whPerKm?.toStringAsFixed(0) ?? '--',
                            unit: 'Wh/km',
                            color: trip.whPerKm == null
                                ? AppTheme.textFaint
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: MetricTile(
                            label: t.tripMaxSpeed,
                            value: trip.maxSpeedKmh.toStringAsFixed(0),
                            unit: 'km/h',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MetricTile(
                            label: t.tripAvgSpeed,
                            value: trip.averageSpeedKmh.toStringAsFixed(0),
                            unit: 'km/h',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MetricTile(
                            label: t.tripMoving,
                            value: _clock(trip.movingDuration),
                            footnote: _clock(trip.totalDuration),
                          ),
                        ),
                      ],
                    ),
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
                      InfoRow(
                        t.tripSocUsed,
                        trip.startSoc == null || snapshot == null
                            ? '--'
                            : '${(trip.startSoc! - snapshot.soc).toStringAsFixed(0)} %',
                        dim: trip.startSoc == null,
                      ),
                      InfoRow(
                        t.soc,
                        snapshot == null
                            ? '--'
                            : '${snapshot.soc.toStringAsFixed(0)} %',
                        last: true,
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Text(
                      t.tripHowItLearns,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.45,
                        color: AppTheme.textFaint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _controls(t, trip),
          ],
        ),
      ),
    );
  }

  Widget _controls(AppL10n t, TripRecorder trip) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: switch (trip.state) {
        TripState.idle => FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.play_arrow, size: 20),
            label: Text(t.tripStart),
          ),
        TripState.recording => Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(widget.service.pauseTrip),
                  icon: const Icon(Icons.pause, size: 20),
                  label: Text(t.tripPause),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _stop,
                  icon: const Icon(Icons.stop, size: 20),
                  label: Text(t.tripStop),
                ),
              ),
            ],
          ),
        TripState.paused => Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _resume,
                  icon: const Icon(Icons.play_arrow, size: 20),
                  label: Text(t.tripResume),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _stop,
                  icon: const Icon(Icons.stop, size: 20),
                  label: Text(t.tripStop),
                ),
              ),
            ],
          ),
      },
    );
  }

  static String _clock(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}';
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _TripSummarySheet extends StatelessWidget {
  const _TripSummarySheet({required this.outcome, required this.t});

  final TripOutcome outcome;
  final AppL10n t;

  TripSummary get summary => outcome.summary;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              t.tripSummaryTitle,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: MetricTile(
                    label: t.tripDistance,
                    value: summary.distanceKm.toStringAsFixed(2),
                    unit: 'km',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MetricTile(
                    label: t.tripConsumption,
                    value: summary.whPerKm?.toStringAsFixed(0) ?? '--',
                    unit: 'Wh/km',
                  ),
                ),
              ],
            ),
          ),
          Section(
            title: t.tripTitle,
            children: [
              InfoRow(t.tripMoving, _long(summary.movingDuration)),
              InfoRow(t.tripElapsed, _long(summary.totalDuration)),
              InfoRow(
                t.tripStopped,
                _long(summary.totalDuration - summary.movingDuration),
              ),
              InfoRow(
                t.tripMaxSpeed,
                '${summary.maxSpeedKmh.toStringAsFixed(0)} km/h',
              ),
              InfoRow(
                t.tripAvgSpeed,
                '${summary.averageSpeedKmh.toStringAsFixed(0)} km/h',
              ),
              InfoRow(t.tripClimb, '${summary.climbM.toStringAsFixed(0)} m'),
              InfoRow(
                t.tripDescent,
                '${summary.descentM.toStringAsFixed(0)} m',
                last: true,
              ),
            ],
          ),
          Section(
            title: t.tripPackDuring,
            children: [
              InfoRow(
                t.tripEnergyOut,
                '${summary.energyOutWh.toStringAsFixed(1)} Wh',
              ),
              InfoRow(
                t.tripEnergyIn,
                '${summary.energyInWh.toStringAsFixed(1)} Wh',
              ),
              InfoRow(
                t.tripSocUsed,
                '${summary.socUsed.toStringAsFixed(0)} %',
              ),
              InfoRow(
                t.tripSocPerKm,
                summary.socPerKm == null
                    ? '--'
                    : '${summary.socPerKm!.toStringAsFixed(2)} %/km',
                dim: summary.socPerKm == null,
              ),
              InfoRow(
                t.tripSag,
                '${summary.sagVolts.toStringAsFixed(2)} V',
              ),
              InfoRow(
                t.tripMaxCurrent,
                '${summary.maxDischargeCurrent.toStringAsFixed(1)} A',
              ),
              InfoRow(
                t.tripMaxTemp,
                '${summary.maxTemperature.toStringAsFixed(1)} °C',
              ),
              InfoRow(
                t.tripMaxDelta,
                summary.maxDeltaVolts.toStringAsFixed(3),
                last: true,
              ),
            ],
          ),
          TripLearnedSection(
            conclusions: outcome.conclusions,
            whPerKm: summary.whPerKm,
            socUsed: summary.socUsed,
            distanceKm: summary.distanceKm,
            maxTemperature: summary.maxTemperature,
            maxDeltaVolts: summary.maxDeltaVolts,
            t: t,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              t.tripNotSaved,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: AppTheme.textFaint,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.tripClose),
            ),
          ),
        ],
      ),
    );
  }

  static String _long(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '$h h $m min';
    // Minutes alone would round a 52 s leg and a 55 s wait both to "1 min",
    // which makes the two lines look like they disagree with each other.
    if (d.inMinutes < 10) return '$m:${s.toString().padLeft(2, '0')}';
    return '$m min';
  }
}
