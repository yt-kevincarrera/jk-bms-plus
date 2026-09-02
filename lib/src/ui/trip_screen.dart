import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../l10n/app_localizations.dart';
import '../bms_service.dart';
import '../gps/location_source.dart';
import '../metrics/range_estimator.dart';
import '../metrics/trip_recorder.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// Trip mode: the speedometer half of the app.
///
/// A speedometer app can tell you how far and how fast. A BMS app can tell you
/// what the pack did. Neither on its own answers the question someone with a
/// new battery actually has, which is what this ride cost and whether the pack
/// held up — so this screen shows both at once.
class TripScreen extends StatefulWidget {
  const TripScreen({required this.service, super.key});

  final BmsService service;

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  Timer? _tick;
  String? _problem;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
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
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _start() async {
    final t = AppL10n.of(context);

    // The wording lives here, where the translations are. The service only
    // knows how to keep the notification alive and when to refresh it.
    widget.service.notificationTitle = t.tripNotificationTitle;
    widget.service.notificationText = (trip, snapshot) {
      final consumption = trip.whPerKm;
      return [
        '${trip.speedKmh.toStringAsFixed(0)} km/h',
        '${trip.distanceKm.toStringAsFixed(2)} km',
        if (snapshot != null) '${snapshot.soc.toStringAsFixed(0)} %',
        if (consumption != null) '${consumption.toStringAsFixed(0)} Wh/km',
      ].join('  ·  ');
    };

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
          _LearnedSection(outcome: outcome, t: t),
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

/// What the ride changed, and one thing worth knowing about it.
///
/// A summary of what happened is useful once. Telling you what it *taught* is
/// what makes the next ride worth recording too.
class _LearnedSection extends StatelessWidget {
  const _LearnedSection({required this.outcome, required this.t});

  final TripOutcome outcome;
  final AppL10n t;

  @override
  Widget build(BuildContext context) {
    final summary = outcome.summary;
    final tips = _tips();

    return Section(
      title: t.tripLearnedTitle,
      accent: AppTheme.cool,
      intro: _headline(),
      children: [
        if (summary.whPerKm != null) ...[
          InfoRow(
            t.tripLearnedRange,
            '${outcome.rangeKmNow.toStringAsFixed(0)} km',
          ),
          InfoRow(
            t.tripLearnedTotalKm,
            '${outcome.learnedKm.toStringAsFixed(1)} km',
          ),
          InfoRow(
            t.tripLearnedConfidence,
            switch (outcome.confidence) {
              RangeConfidence.low => t.rangeConfidenceLow,
              RangeConfidence.medium => t.rangeConfidenceMedium,
              RangeConfidence.high => t.rangeConfidenceHigh,
            },
            valueColor: switch (outcome.confidence) {
              RangeConfidence.low => AppTheme.textFaint,
              RangeConfidence.medium => AppTheme.watch,
              RangeConfidence.high => AppTheme.good,
            },
            last: tips.isEmpty,
          ),
        ],
        for (final tip in tips)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2, right: 10),
                  child: Icon(
                    Icons.lightbulb_outline,
                    size: 15,
                    color: AppTheme.cool,
                  ),
                ),
                Expanded(
                  child: Text(
                    tip,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
      ],
    );
  }

  String _headline() {
    final after = outcome.whPerKmAfter.toStringAsFixed(1);
    if (outcome.summary.whPerKm == null) return t.tripLearnedTooShort;
    if (!outcome.hadLearnedBefore) return t.tripLearnedFirst(after);
    if (!outcome.moved) return t.tripLearnedUnchanged(after);
    return t.tripLearnedChanged(
      outcome.whPerKmBefore.toStringAsFixed(1),
      after,
    );
  }

  /// At most two, so the sheet stays a summary rather than a lecture.
  List<String> _tips() {
    final s = outcome.summary;
    final tips = <String>[];

    // How much of the pack a ride covers is what decides how sharp the estimate
    // can get. A ride from 100% to 20% pins the number down; five short hops
    // around the block cannot.
    if (s.socUsed >= 25) {
      tips.add(t.tripDeepDischargeTip);
    } else if (s.socUsed > 0 && s.socUsed < 8 && s.distanceKm > 0.5) {
      tips.add(t.tripShallowTip);
    }

    final thirst = outcome.thirstPercent;
    if (thirst != null) {
      tips.add(t.tripThirstyTip(thirst.toStringAsFixed(0)));
    }

    if (tips.length < 2 && s.maxTemperature > 45) {
      tips.add(t.tripHotTip(s.maxTemperature.toStringAsFixed(1)));
    }
    if (tips.length < 2 && s.maxDeltaVolts > 0.06) {
      tips.add(t.tripDeltaTip(s.maxDeltaVolts.toStringAsFixed(3)));
    }

    return tips.take(2).toList();
  }
}
