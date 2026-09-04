import 'dart:async';

import 'package:flutter/material.dart';
import '../../platform/screen_awake.dart';

import '../../../l10n/app_localizations.dart';
import '../../app_settings.dart';
import '../../ble/waiting_diagnosis.dart';
import '../../bms_service.dart';
import '../../metrics/charge_eta.dart';
import '../../metrics/range_estimator.dart';
import '../../metrics/range_outlook.dart';
import '../../model/bms_snapshot.dart';
import '../theme.dart';
import '../warning_labels.dart';
import '../widgets/common.dart';
import '../../metrics/ride_alerts.dart';
import '../../metrics/trip_recorder.dart';
import '../trip_screen.dart';
import '../widgets/gauges.dart';

/// The riding screen. One glance should answer two questions: can I keep going,
/// and is anything wrong.
class NowTab extends StatefulWidget {
  const NowTab({
    required this.service,
    required this.snapshot,
    required this.settings,
    super.key,
  });

  final BmsService service;
  final BmsSnapshot? snapshot;
  final AppSettings settings;

  @override
  State<NowTab> createState() => _NowTabState();
}

class _NowTabState extends State<NowTab> {
  /// Redraws the waiting screen while there is nothing else to redraw it.
  /// Readings drive every rebuild once they arrive; until then the counters
  /// this screen explains itself with change without anything repainting.
  Timer? _waitingTick;

  @override
  void initState() {
    super.initState();
    _waitingTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.snapshot == null) setState(() {});
    });
  }

  @override
  void dispose() {
    _waitingTick?.cancel();
    ScreenAwakeKeeper.release();
    super.dispose();
  }

  /// The reason there is no reading yet, in the rider's words, with the
  /// evidence under it and the latest notices the service raised.
  List<Widget> _waitingExplanation(AppL10n t) {
    final service = widget.service;
    final stats = service.stats;
    final link = service.lastLinkState;
    final reason = diagnoseWaiting(
      link: link,
      framesAccepted: stats.accepted,
      cellInfoFrames: service.cellInfoFrames,
      heldBackFrames: service.heldBackFrames,
      decodeFailures: service.decodeFailures,
      variantKnown: service.variant != null,
    );
    final why = switch (reason) {
      WaitingReason.linkDown => t.waitingWhyLinkDown,
      WaitingReason.noFrames => t.waitingWhyNoFrames,
      WaitingReason.onlyDeviceInfo => t.waitingWhyOnlyDeviceInfo,
      WaitingReason.variantUnknown => t.waitingWhyVariantUnknown,
      WaitingReason.decodeFailing => t.waitingWhyDecodeFailing,
      WaitingReason.unexplained => t.waitingWhyUnexplained,
    };
    // Terse and the same in every language, like the exception text it sits
    // beside: what the app saw, so a screenshot settles which stage stalled.
    final evidence =
        'link ${link.name} · ${stats.bytesReceived} bytes · '
        '${stats.accepted} frames ok · ${stats.badChecksum} bad checksum · '
        '${service.deviceInfoFrames} device info · '
        '${service.cellInfoFrames} cell info · '
        '${service.heldBackFrames} held back · '
        '${service.decodeFailures} undecodable · '
        '${service.snapshotsEmitted} emitted · '
        'variant ${service.variant?.name ?? '?'} · '
        'MTU ${service.negotiatedMtu ?? '?'}';
    final notices = service.recentProblems.take(3).toList();

    return [
      const SizedBox(height: 22),
      Text(
        why,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12.5,
          height: 1.4,
          color: AppTheme.textSecondary,
        ),
      ),
      const SizedBox(height: 12),
      SelectableText(
        evidence,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10.5,
          height: 1.35,
          fontFamily: 'monospace',
          color: AppTheme.textFaint,
        ),
      ),
      if (notices.isNotEmpty) ...[
        const SizedBox(height: 14),
        Text(
          t.systemNotices.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            letterSpacing: 0.8,
            color: AppTheme.textFaint,
          ),
        ),
        const SizedBox(height: 6),
        for (final n in notices)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: SelectableText(
              n,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                height: 1.35,
                color: AppTheme.textFaint,
              ),
            ),
          ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Applied from build rather than initState: it depends on whether a ride
    // is open, which changes while this screen is on show. The keeper only
    // touches the platform when the answer changes.
    ScreenAwakeKeeper.apply(
      widget.settings.screenAwake,
      riding: widget.service.trip.isActive,
    );
    final t = AppL10n.of(context);
    final s = widget.snapshot;
    if (s == null) {
      return WaitingForData(
        message: t.waitingFor(t.waitingFirstReading),
        children: _waitingExplanation(t),
      );
    }

    final service = widget.service;
    final history = service.history;
    final health = packHealthOf(s);
    final power = history.smoothedPower;
    final current = history.smoothedCurrent;
    final estimator = service.rangeEstimator;
    final outlook = service.rangeOutlook;

    final usableWh = RangeEstimator.usableWh(
      remainingAh: s.remainingCapacityAh,
      packVoltage: s.packVoltage,
      cellCount: s.cellCount,
      minCellVoltage: s.minCellVoltage,
      averageCellVoltage: s.averageCellVoltage,
      cutoffVoltagePerCell: service.cutoffVoltagePerCell,
    );
    final (low, high) = estimator.rangeBandKm(usableWh);

    final status = packStatusOf(s);

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        StatusBand(
          health: status.health,
          message: _statusMessage(t, status),
          // The band is tappable so "why does it say that" has an answer one
          // finger away, instead of being a colour you learn to ignore.
          explanation: t.statusExplain,
          badge: s.balancerActive
              // Named, not just "working": on its own in the band a bare
              // state word says nothing about what is doing it.
              ? Pill(t.balancerBadge, color: AppTheme.cool, icon: Icons.bolt)
              : null,
        ),
        _AlertBanner(service: service, settings: widget.settings),
        // While charging, how long until it is full. Range is the wrong
        // question with a charger plugged in, and "how long do I wait" is the
        // only one anybody is actually asking.
        if (s.isCharging) _chargeEta(t, s, service),
        _TripStrip(service: service, settings: widget.settings),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Center(
                child: SocGauge(
                  soc: s.soc,
                  color: health.color,
                  centreLabel: t.soc,
                  centreValue: '${s.soc.toStringAsFixed(0)}%',
                  subtitle: '${s.remainingCapacityAh.toStringAsFixed(1)} Ah',
                  size: 166,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Readout(
                      label: t.range,
                      value: outlook.nowKm?.toStringAsFixed(0) ?? '--',
                      unit: 'km',
                      size: 44,
                      footnote: outlook.hasLearned
                          ? t.rangeBand(
                              low.toStringAsFixed(0),
                              high.toStringAsFixed(0),
                            )
                          : t.rangeNoneLearned,
                    ),
                    const SizedBox(height: 10),
                    // The separate question, answered separately. One of these
                    // changes when you charge and the other does not, and
                    // showing only the first invited it to be read as what the
                    // bike does.
                    _FullPackRange(outlook: outlook, t: t),
                    const SizedBox(height: 12),
                    Pill(
                      estimator.hasLearned
                          ? '${estimator.whPerKm.toStringAsFixed(0)} Wh/km'
                          : t.rangeLearning,
                      color: estimator.hasLearned
                          ? AppTheme.good
                          : AppTheme.textFaint,
                      icon: estimator.hasLearned
                          ? Icons.route_outlined
                          : Icons.hourglass_bottom,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: MetricTile(
                  label: t.power,
                  value: power.abs() < 999
                      ? power.toStringAsFixed(0)
                      : (power / 1000).toStringAsFixed(2),
                  unit: power.abs() < 999 ? 'W' : 'kW',
                  color: power.abs() > 5 ? AppTheme.cool : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricTile(
                  label: t.current,
                  value: current.toStringAsFixed(1),
                  unit: 'A',
                  footnote: s.isCharging
                      ? t.charging
                      : s.isDischarging
                      ? t.discharging
                      : t.resting,
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
                  label: t.packVoltage,
                  value: s.packVoltage.toStringAsFixed(1),
                  unit: 'V',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricTile(
                  label: t.cellDelta,
                  value: s.deltaCellVoltage.toStringAsFixed(3),
                  unit: 'V',
                  color: _deltaColour(s.deltaCellVoltage),
                  footnote: 'min ${s.minCellIndex} · max ${s.maxCellIndex}',
                ),
              ),
            ],
          ),
        ),
        if (history.length > 3) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Caption(t.power, color: AppTheme.textFaint),
                const SizedBox(height: 8),
                Sparkline(
                  values: [
                    for (final x in history.recent(const Duration(minutes: 5)))
                      x.power,
                  ],
                  color: AppTheme.cool,
                ),
              ],
            ),
          ),
        ],
        Section(
          title: t.sessionTitle,
          children: [
            InfoRow(
              t.sessionEnergy,
              '${history.energyWh.abs().toStringAsFixed(1)} Wh',
            ),
            InfoRow(
              t.sessionDistance,
              service.trip.isActive
                  ? '${service.trip.distanceKm.toStringAsFixed(2)} km'
                  : t.tripIdle,
              dim: !service.trip.isActive,
            ),
            InfoRow(
              t.sessionWhPerKm,
              service.trip.whPerKm == null
                  ? t.tripIdle
                  : '${service.trip.whPerKm!.toStringAsFixed(1)} Wh/km',
              dim: service.trip.whPerKm == null,
            ),
            InfoRow(t.sessionSamples, '${history.length}', last: true),
          ],
        ),
        Section(
          title: t.packTitle,
          children: [
            InfoRow(
              t.packRemaining,
              t.packRemainingValue(
                s.remainingCapacityAh.toStringAsFixed(1),
                s.nominalCapacityAh.toStringAsFixed(1),
              ),
            ),
            InfoRow(t.packCycles, '${s.cycleCount}'),
            InfoRow(t.packSoh, '${s.soh.toStringAsFixed(0)} %'),
            InfoRow(
              t.packSag,
              history.sagVolts == null
                  ? t.packSagNoBaseline
                  : '${history.sagVolts!.toStringAsFixed(2)} V',
              dim: history.sagVolts == null,
            ),
            InfoRow(
              t.packMosfets,
              '${s.chargeMosfetOn ? t.mosfetChargeOn : t.mosfetChargeOff}, '
              '${s.dischargeMosfetOn ? t.mosfetDischargeOn : t.mosfetDischargeOff}',
              last: true,
            ),
          ],
        ),
      ],
    );
  }

  Color? _deltaColour(double delta) {
    if (delta > 0.10) return AppTheme.bad;
    if (delta > 0.04) return AppTheme.watch;
    return null;
  }
}

/// The way into trip mode, and a live readout once one is running.
///
/// It sits on the riding screen rather than in a tab of its own because
/// starting a ride is something you do once, at the kerb, not something you go
/// hunting for in a menu.
class _TripStrip extends StatefulWidget {
  const _TripStrip({required this.service, required this.settings});

  final BmsService service;
  final AppSettings settings;

  @override
  State<_TripStrip> createState() => _TripStripState();
}

class _TripStripState extends State<_TripStrip> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(
      const Duration(seconds: 1),
      (_) => mounted && widget.service.trip.isActive ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            TripScreen(service: widget.service, settings: widget.settings),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final trip = widget.service.trip;
    final active = trip.isActive;
    final tone = switch (trip.state) {
      TripState.recording => AppTheme.good,
      TripState.paused => AppTheme.watch,
      TripState.idle => AppTheme.textSecondary,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: InkWell(
        onTap: _open,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceRaised,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? tone.withValues(alpha: 0.45) : AppTheme.hairline,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Icon(
                active ? Icons.fiber_manual_record : Icons.route_outlined,
                size: 16,
                color: tone,
              ),
              const SizedBox(width: 10),
              if (!active)
                Expanded(
                  child: Text(
                    t.tripOpen,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                )
              else ...[
                Expanded(
                  child: Row(
                    children: [
                      _mini(
                        '${trip.distanceKm.toStringAsFixed(1)} km',
                        t.tripDistance,
                      ),
                      const SizedBox(width: 18),
                      _mini(
                        '${trip.speedKmh.toStringAsFixed(0)} km/h',
                        t.tripSpeed,
                      ),
                      const SizedBox(width: 18),
                      _mini(
                        trip.whPerKm == null
                            ? '--'
                            : '${trip.whPerKm!.toStringAsFixed(0)} Wh/km',
                        t.tripConsumption,
                      ),
                    ],
                  ),
                ),
              ],
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppTheme.textFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mini(String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          fontFeatures: AppTheme.tabular,
        ),
      ),
      const SizedBox(height: 1),
      Text(
        label,
        style: const TextStyle(fontSize: 10, color: AppTheme.textFaint),
      ),
    ],
  );
}

/// What a full pack is worth, in kilometres.
///
/// Kept visually quieter than the remaining range: it is the figure you plan
/// with rather than the one you watch. It refuses to appear as a number until
/// there is a capacity to build it on, because a full-pack range derived from
/// nothing is exactly the sort of confident invention this app is meant not to
/// do.
class _FullPackRange extends StatelessWidget {
  const _FullPackRange({required this.outlook, required this.t});

  final RangeOutlook outlook;
  final AppL10n t;

  @override
  Widget build(BuildContext context) {
    if (!outlook.hasLearned) return const SizedBox.shrink();

    final full = outlook.fullKm;
    if (full == null) {
      return Text(
        t.rangeFullUnknown,
        style: const TextStyle(
          fontSize: 11,
          height: 1.35,
          color: AppTheme.textFaint,
        ),
      );
    }

    final band = outlook.fullBandKm;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.rangeFull,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: AppTheme.textFaint,
          ),
        ),
        const SizedBox(height: 1),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(full.toStringAsFixed(0), style: AppTheme.readout(22)),
            const SizedBox(width: 3),
            const Text(
              'km',
              style: TextStyle(fontSize: 11, color: AppTheme.textFaint),
            ),
          ],
        ),
        if (band != null)
          Text(
            t.rangeFullBand(
              band.$1.toStringAsFixed(0),
              band.$2.toStringAsFixed(0),
            ),
            style: const TextStyle(fontSize: 10, color: AppTheme.textFaint),
          ),
        Text(
          outlook.fullFromMeasuredCapacity
              ? t.rangeFullFromMeasured
              : t.rangeFullFromAdvert,
          style: TextStyle(
            fontSize: 10,
            height: 1.3,
            color: outlook.fullFromMeasuredCapacity
                ? AppTheme.good
                : AppTheme.textFaint,
          ),
        ),
      ],
    );
  }
}

/// Time until the pack is full, from what is going in right now.
Widget _chargeEta(AppL10n t, BmsSnapshot s, BmsService service) {
  // Remaining over charge, which reads back the capacity the BMS is
  // configured with. That cancellation makes it useless as a measurement of
  // the cells and exactly right here: the question is how many amp-hours are
  // left to put in, and the charger is filling the battery the BMS thinks it
  // has. Not to be "corrected" to a measured capacity later.
  final capacity = s.remainingCapacityAh > 0 && s.soc > 1
      ? s.remainingCapacityAh / (s.soc / 100)
      : null;
  if (capacity == null) return const SizedBox.shrink();

  final eta = const ChargeEtaEstimator().estimate(
    current: s.current,
    soc: s.soc,
    capacityAh: capacity,
  );
  final left = eta.remaining;
  if (left == null) return const SizedBox.shrink();

  final label = left == Duration.zero
      ? t.etaDone
      : left.inHours >= 1
      ? '${left.inHours} h ${left.inMinutes % 60} min'
      : '${left.inMinutes} min';

  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.hairline),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          const Icon(Icons.bolt, size: 18, color: AppTheme.cool),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  left == Duration.zero ? label : '${t.etaFull} $label',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.cool,
                  ),
                ),
                if (eta.isTapering && left != Duration.zero)
                  Text(
                    t.etaTapering,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textFaint,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Turns a verdict into a sentence that says why.
String _statusMessage(AppL10n t, PackStatus status) {
  final v = status.value ?? 0;
  return switch (status.reason) {
    PackStatusReason.allClear => t.statusAllClear,
    PackStatusReason.bmsWarning =>
      status.warnings.map((w) => warningLabel(t, w)).join(' · '),
    PackStatusReason.cellSpread =>
      status.health == PackHealth.bad
          ? t.statusSpreadBad(v.toStringAsFixed(3))
          : t.statusSpreadWatch(v.toStringAsFixed(3)),
    PackStatusReason.temperature =>
      status.health == PackHealth.bad
          ? t.statusTempBad(v.toStringAsFixed(1))
          : t.statusTempWatch(v.toStringAsFixed(1)),
  };
}

/// Puts an alert on the screen as well as in the phone's vibration motor.
///
/// The buzz is what reaches you while riding; this is what tells you what the
/// buzz was about when you next look down.
class _AlertBanner extends StatefulWidget {
  const _AlertBanner({required this.service, required this.settings});

  final BmsService service;
  final AppSettings settings;

  @override
  State<_AlertBanner> createState() => _AlertBannerState();
}

class _AlertBannerState extends State<_AlertBanner> {
  StreamSubscription<RideAlert>? _sub;
  RideAlert? _latest;
  Timer? _clear;

  @override
  void initState() {
    super.initState();
    _sub = widget.service.rideAlerts.listen((alert) {
      if (!mounted) return;
      setState(() => _latest = alert);
      _clear?.cancel();
      // Long enough to be seen at the next glance down, short enough that a
      // stale warning is not still sitting there ten minutes later.
      _clear = Timer(const Duration(minutes: 1), () {
        if (mounted) setState(() => _latest = null);
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _clear?.cancel();
    super.dispose();
  }

  Future<void> _silence(AppL10n t, RideAlert alert) async {
    await widget.settings.setAlertMuted(alert.name, true);
    widget.service.mutedAlerts = widget.settings.mutedAlerts;
    if (!mounted) return;
    setState(() => _latest = null);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t.alertSilenced)));
  }

  @override
  Widget build(BuildContext context) {
    final alert = _latest;
    if (alert == null) return const SizedBox.shrink();

    final t = AppL10n.of(context);
    final tone = alert.isCritical ? AppTheme.bad : AppTheme.watch;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tone),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 19, color: tone),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _label(t, alert),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tone,
                    ),
                  ),
                  // The moment an alert annoys somebody is the moment they
                  // want it gone, and it is the only moment they know exactly
                  // which one it was. Making them find it in a settings list
                  // later is how an app ends up with every alert switched off.
                  GestureDetector(
                    onTap: () => _silence(t, alert),
                    child: Text(
                      t.alertSilence,
                      style: TextStyle(
                        fontSize: 11.5,
                        decoration: TextDecoration.underline,
                        color: tone.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _latest = null),
              icon: Icon(Icons.close, size: 17, color: tone),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  String _label(AppL10n t, RideAlert alert) => switch (alert) {
    RideAlert.bmsFault => t.alertBmsFault,
    RideAlert.cellSpread => t.alertCellSpread,
    RideAlert.temperature => t.alertTemperature,
    RideAlert.lowCharge => t.alertLowCharge,
    RideAlert.criticalCharge => t.alertCriticalCharge,
    RideAlert.cellNearCutoff => t.alertCellNearCutoff,
    RideAlert.nearCurrentLimit => t.alertNearCurrentLimit,
  };
}
