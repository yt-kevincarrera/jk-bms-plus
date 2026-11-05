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
import 'widgets/cockpit.dart';
import 'widgets/trip_summary_sheet.dart';
import 'widgets/trip_summary_view.dart';
import 'widgets/instruments.dart';

/// Trip mode: the speedometer half of the app.
///
/// A speedometer app can tell you how far and how fast. A BMS app can tell you
/// what the pack did. Neither on its own answers the question someone with a
/// new battery actually has, which is what this ride cost and whether the pack
/// held up — so this screen shows both at once.
class TripScreen extends StatefulWidget {
  const TripScreen({required this.service, required this.settings, super.key});

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
    await showTripSummarySheet(
      context: context,
      view: TripSummaryView.fromOutcome(
        outcome,
        tripId: widget.service.lastStoredTripId,
      ),
      service: widget.service,
      t: t,
    );
    // The rider just read this summary by hand, right here. Without marking
    // it seen, _offerPendingSummary would pop it again on the next launch,
    // then walk backwards through every stale ride before it, one per
    // launch. Marked after the sheet resolves, like _offerPendingSummary
    // does, so a sheet that throws leaves it unseen rather than lost.
    final id = widget.service.lastStoredTripId;
    if (id != null) await widget.service.markTripSummarySeen(id);
    if (mounted) setState(() {});
  }

  /// "12 s ago", or minutes past two of them.
  static String _ago(AppL10n t, Duration age) => age.inSeconds < 120
      ? t.tripReadingAgeSeconds('${age.inSeconds}')
      : t.tripReadingAgeMinutes('${age.inMinutes}');

  String _problemText(AppL10n t, LocationProblem p) => switch (p) {
    LocationProblem.serviceDisabled => t.locationDisabled,
    LocationProblem.permissionDenied => t.locationDenied,
    LocationProblem.permanentlyDenied => t.locationDeniedForever,
    LocationProblem.approximateOnly => t.locationApproximateOnly,
  };

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final trip = widget.service.trip;
    final snapshot = widget.service.lastSnapshot;
    // Only a speed still worth believing: the last fix's figure stays put
    // forever once the fixes stop, and a frozen 32 read as riding at 32.
    final speed = trip.freshSpeedKmh;
    // How old the reading behind the charge figures is, when old enough to
    // say. With the link down they kept showing the last value as if live.
    final age = snapshot == null
        ? null
        : DateTime.now().toUtc().difference(snapshot.timestamp.toUtc());
    final stale = age != null && age > const Duration(seconds: 10);
    String withAge(String value) =>
        stale ? '$value  ·  ${_ago(t, age)}' : value;

    // Riding is the case this screen exists for, so the awake setting is
    // honoured here too rather than only on the live tab.
    ScreenAwakeKeeper.apply(widget.settings.screenAwake, riding: trip.isActive);

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
                  TripState.recording => context.colors.good,
                  TripState.paused => context.colors.watch,
                  TripState.idle => context.colors.textFaint,
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
                  // Said while the ride is still going, when it can be acted
                  // on. A ride that recorded no GPS used to say so only at the
                  // end, as 0 km.
                  if (widget.service.tripLacksGps)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Text(
                        t.tripNoGpsFixes,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: context.colors.bad,
                        ),
                      ),
                    ),
                  if (_problem != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Text(
                        _problem!,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: context.colors.watch,
                        ),
                      ),
                    ),
                  RidingSpeedometer(
                    value: speed?.toStringAsFixed(0) ?? '--',
                    available: speed != null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: CockpitPanel(
                      padding: EdgeInsets.zero,
                      child: TelemetryStrip(
                        size: 44,
                        items: [
                          TelemetryDatum(
                            t.tripDistance,
                            trip.distanceKm.toStringAsFixed(2),
                            unit: 'km',
                          ),
                          TelemetryDatum(
                            t.tripMoving,
                            _clock(trip.movingDuration),
                            note:
                                '${t.tripElapsed}: ${_clock(trip.totalDuration)}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (snapshot != null) ...[
                    TelemetryStrip(
                      size: 32,
                      items: [
                        TelemetryDatum(
                          t.rangeCurrent,
                          widget.service.rangeOutlook.nowKm?.toStringAsFixed(
                                0,
                              ) ??
                              '--',
                          unit: 'km',
                          note: stale ? _ago(t, age) : null,
                        ),
                        TelemetryDatum(
                          withAge(t.soc),
                          snapshot.soc.toStringAsFixed(0),
                          unit: '%',
                          color: stale
                              ? context.colors.textFaint
                              : context.colors.good,
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: ChargeSegments(
                        soc: snapshot.soc,
                        label: withAge(t.soc),
                      ),
                    ),
                  ],
                  TelemetryStrip(
                    size: 30,
                    items: [
                      TelemetryDatum(
                        t.tripConsumption,
                        trip.whPerKm?.toStringAsFixed(0) ?? '--',
                        unit: 'Wh/km',
                      ),
                      TelemetryDatum(
                        t.tripMaxSpeed,
                        trip.maxSpeedKmh.toStringAsFixed(0),
                        unit: 'km/h',
                      ),
                      TelemetryDatum(
                        t.tripAvgSpeed,
                        trip.averageSpeedKmh.toStringAsFixed(0),
                        unit: 'km/h',
                      ),
                    ],
                  ),
                  Section(
                    title: t.tripPackDuring,
                    children: [
                      // With the link down long enough that the readings no
                      // longer cover the ride, the ride's own figure is zero
                      // on purpose (it will be measured again afterwards), and
                      // "0.0 Wh" mid-ride read as a ride that cost nothing.
                      // What was measured until the link went is shown, as
                      // that.
                      InfoRow(
                        t.tripEnergyOut,
                        trip.energyCoversRide
                            ? '${trip.energyOutWh.toStringAsFixed(1)} Wh'
                            : t.tripEnergySoFarOffline(
                                trip.energyOutWhSoFar.toStringAsFixed(1),
                              ),
                        dim: !trip.energyCoversRide,
                      ),
                      InfoRow(
                        t.tripSocUsed,
                        trip.startSoc == null || snapshot == null
                            ? '--'
                            : withAge(
                                '${(trip.startSoc! - snapshot.soc).toStringAsFixed(0)} %',
                              ),
                        dim: trip.startSoc == null || stale,
                      ),
                      InfoRow(
                        t.soc,
                        snapshot == null
                            ? '--'
                            : withAge('${snapshot.soc.toStringAsFixed(0)} %'),
                        dim: stale,
                        last: true,
                      ),
                    ],
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
    final actions = switch (trip.state) {
      TripState.idle => <Widget>[
        FilledButton.icon(
          onPressed: _start,
          icon: const Icon(Icons.play_arrow, size: 20),
          label: Text(t.tripStart),
        ),
      ],
      TripState.recording => <Widget>[
        OutlinedButton.icon(
          onPressed: () => setState(widget.service.pauseTrip),
          icon: const Icon(Icons.pause, size: 20),
          label: Text(t.tripPause),
        ),
        FilledButton.icon(
          onPressed: _stop,
          icon: const Icon(Icons.stop, size: 20),
          label: Text(t.tripStop),
        ),
      ],
      TripState.paused => <Widget>[
        FilledButton.icon(
          onPressed: _resume,
          icon: const Icon(Icons.play_arrow, size: 20),
          label: Text(t.tripResume),
        ),
        OutlinedButton.icon(
          onPressed: _stop,
          icon: const Icon(Icons.stop, size: 20),
          label: Text(t.tripStop),
        ),
      ],
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: actions.length == 1
          ? actions.first
          : MediaQuery.textScalerOf(context).scale(16) > 23
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [actions[0], const SizedBox(height: 8), actions[1]],
            )
          : Row(
              children: [
                Expanded(child: actions[0]),
                const SizedBox(width: 10),
                Expanded(child: actions[1]),
              ],
            ),
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
