import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../l10n/app_localizations.dart';
import '../../bms_service.dart';
import '../../metrics/range_estimator.dart';
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
  const NowTab({required this.service, required this.snapshot, super.key});

  final BmsService service;
  final BmsSnapshot? snapshot;

  @override
  State<NowTab> createState() => _NowTabState();
}

class _NowTabState extends State<NowTab> {
  @override
  void initState() {
    super.initState();
    // This is meant to live in a phone mount while riding.
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final s = widget.snapshot;
    if (s == null) {
      return WaitingForData(message: t.waitingFor(t.waitingFirstReading));
    }

    final service = widget.service;
    final history = service.history;
    final health = packHealthOf(s);
    final power = history.smoothedPower;
    final current = history.smoothedCurrent;
    final estimator = service.rangeEstimator;

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
        _AlertBanner(service: service),
        _TripStrip(service: service),
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
                      value: estimator.rangeKm(usableWh).toStringAsFixed(0),
                      unit: 'km',
                      size: 44,
                      footnote: t.rangeBand(
                        low.toStringAsFixed(0),
                        high.toStringAsFixed(0),
                      ),
                    ),
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
  const _TripStrip({required this.service});

  final BmsService service;

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
        builder: (_) => TripScreen(service: widget.service),
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

/// Turns a verdict into a sentence that says why.
String _statusMessage(AppL10n t, PackStatus status) {
  final v = status.value ?? 0;
  return switch (status.reason) {
    PackStatusReason.allClear => t.statusAllClear,
    PackStatusReason.bmsWarning =>
      status.warnings.map((w) => warningLabel(t, w)).join(' · '),
    PackStatusReason.cellSpread => status.health == PackHealth.bad
        ? t.statusSpreadBad(v.toStringAsFixed(3))
        : t.statusSpreadWatch(v.toStringAsFixed(3)),
    PackStatusReason.temperature => status.health == PackHealth.bad
        ? t.statusTempBad(v.toStringAsFixed(1))
        : t.statusTempWatch(v.toStringAsFixed(1)),
  };
}

/// Puts an alert on the screen as well as in the phone's vibration motor.
///
/// The buzz is what reaches you while riding; this is what tells you what the
/// buzz was about when you next look down.
class _AlertBanner extends StatefulWidget {
  const _AlertBanner({required this.service});

  final BmsService service;

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
              child: Text(
                _label(t, alert),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tone,
                ),
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
      };
}
