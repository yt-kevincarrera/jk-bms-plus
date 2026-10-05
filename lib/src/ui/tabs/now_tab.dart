import 'dart:async';

import 'package:flutter/material.dart';
import '../../platform/screen_awake.dart';

import '../../../l10n/app_localizations.dart';
import '../../app_settings.dart';
import '../../ble/waiting_diagnosis.dart';
import '../../bms_service.dart';
import '../../protocol/bms_brand.dart';
import '../../metrics/charge_alerts.dart';
import '../../metrics/charge_eta.dart';
import '../../metrics/range_outlook.dart';
import '../../metrics/soc_trust.dart';
import '../../model/bms_snapshot.dart';
import '../bms_code_labels.dart';
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
    final isAnt = service.brand == BmsBrand.ant;
    // ANT's own counters, not the JK ones: cellInfoFrames and
    // deviceInfoFrames never move for an ANT connection, and reusing them
    // here would describe a pack that is actually talking as silent, or as
    // "device info only" when its buffers are simply failing to frame.
    final reason = isAnt
        ? diagnoseWaiting(
            link: link,
            framesAccepted: stats.accepted,
            cellInfoFrames: service.antStatusFrames,
            heldBackFrames: 0,
            decodeFailures: service.decodeFailures,
            variantKnown: true,
            rejectedFrames: service.antRejectedFrames,
            // An ANT status held back is one that failed plausibility, which
            // is the pack's bytes not making sense, not a variant to pick.
            implausibleFrames: service.heldBackFrames,
          )
        : diagnoseWaiting(
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
    final evidence = isAnt
        ? 'link ${link.name} · ${stats.bytesReceived} bytes · '
              '${t.antEvidence(service.antStatusFrames, service.antInfoFrames, service.antRejectedFrames)}'
              '${service.lastDecodeError == null ? '' : ' · ${service.lastDecodeError}'}'
        : 'link ${link.name} · ${stats.bytesReceived} bytes · '
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
    final health = packHealthOf(s, chemistry: service.cutoffChemistry);
    final power = history.smoothedPower;
    final current = history.smoothedCurrent;
    final estimator = service.rangeEstimator;
    final outlook = service.rangeOutlook;

    final (low, high) = estimator.rangeBandKm(service.energyOf(s).usableWh);

    final status = packStatusOf(s, chemistry: service.cutoffChemistry);

    // Whether the charge percentage can be taken at face value. The gauge and
    // the charge ETA ask the same question of the same reading, so they are
    // never allowed to answer it differently.
    final drift = SocTrust.defaults.check(
      soc: s.soc,
      current: s.current,
      capacityAh: s.nominalCapacityAh,
      highestCellVolts: s.cellVoltages.isEmpty ? null : s.maxCellVoltage,
      lowestCellVolts: s.cellVoltages.isEmpty ? null : s.minCellVoltage,
      full: SocTrust.fullAnchor(
        soc100Volts: service.lastSettings?.soc100Voltage,
        cellOvp: service.configuredCellOvp,
      ),
      empty: SocTrust.emptyAnchor(
        soc0Volts: service.lastSettings?.soc0Voltage,
      ),
    );

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
        if (s.isCharging || s.chargerPlugged == true) _chargerState(t, s),
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
                  note: switch (drift) {
                    SocDrift.aheadOfCells => t.socNoteAhead,
                    SocDrift.behindCells => t.socNoteBehind,
                    SocDrift.none => null,
                  },
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
            // Out and in apart, since the pack connected. One net figure over the
            // reading buffer let a charge cancel a ride, and forgot anything
            // older than the buffer's twenty-odd minutes.
            InfoRow(
              t.sessionEnergy,
              '${history.sessionOutWh.toStringAsFixed(1)} Wh',
              hint: history.sessionInWh >= 0.05 ? null : t.sessionEnergyHint,
            ),
            if (history.sessionInWh >= 0.05)
              InfoRow(
                t.sessionEnergyIn,
                '${history.sessionInWh.toStringAsFixed(1)} Wh',
                hint: t.sessionEnergyHint,
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
            // An ANT keeps no cycle counter. It used to print "null" here.
            InfoRow(
              t.packCycles,
              s.cycleCount == null ? t.notReported : '${s.cycleCount}',
              dim: s.cycleCount == null,
            ),
            InfoRow(
              t.packSoh,
              s.soh == null ? t.notReported : '${s.soh!.toStringAsFixed(0)} %',
              dim: s.soh == null,
            ),
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
              : outlook.fullFromBmsConfig
              ? t.rangeFullFromBms
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

/// Time until the pack is full, from what is going in right now — or, when
/// the BMS's charge counter has run ahead of the cells, the admission that
/// there is no honest number to give.
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

  // What the counter gets checked against. Both are allowed to be missing —
  // an empty cell list reads as 0 V, which is not a low cell, and the anchor
  // only exists once a settings frame has arrived.
  // The last minute's current, not this frame's: the BMS repeats a value
  // across frames and the charger wanders, and minutes computed off one
  // reading jumped about with it.
  final current =
      ChargeEta.smoothedCurrent(
        service.history.recent(const Duration(seconds: 60)),
      ) ??
      s.current;
  final eta = const ChargeEtaEstimator().estimate(
    current: current,
    soc: s.soc,
    capacityAh: capacity,
    highestCellVolts: s.cellVoltages.isEmpty ? null : s.maxCellVoltage,
    fullAnchor: SocTrust.fullAnchor(
      soc100Volts: service.lastSettings?.soc100Voltage,
      cellOvp: service.lastSettings?.cellOvp,
    ),
  );
  final exact = eta.remaining;
  // No number and no reason to doubt one: nothing to say.
  if (exact == null && !eta.socLooksOptimistic && !eta.nearlyFull) {
    return const SizedBox.shrink();
  }
  final left = exact == null || exact == Duration.zero
      ? exact
      : ChargeEta.rounded(exact);

  final String label;
  if (eta.socLooksOptimistic) {
    // Not "nearly there". At 99 % with the cells still low, the charge the
    // rider reported had two hours to run: "nearly there" is the same wrong
    // promise as "3 min", only vaguer. The subtitle below says why.
    label = t.etaCannotSay;
  } else if (eta.nearlyFull || left == null) {
    // The counter is at the top and the charger is still pushing more than
    // a tapered current: not full, and no minutes left to divide.
    label = t.etaNearlyFull;
  } else if (left == Duration.zero) {
    label = t.etaDone;
  } else if (left.inHours >= 1) {
    label = left.inMinutes % 60 == 0
        ? '${left.inHours} h'
        : '${left.inHours} h ${left.inMinutes % 60} min';
  } else {
    label = '${left.inMinutes} min';
  }
  final hasTime = left != null && left != Duration.zero;

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
                  // Always "about": see [ChargeEta.rounded].
                  hasTime ? '${t.etaFull} $label' : label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.cool,
                  ),
                ),
                if (eta.socLooksOptimistic)
                  Text(
                    t.etaCounterAhead,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textFaint,
                    ),
                  )
                else if (eta.isTapering && hasTime)
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

/// What the BMS itself says about the charge: whether it sees a charger, and
/// the phase it reports. Decoded from every reading and never shown, while
/// the one screen a rider watches during a charge guessed at both from the
/// current alone. Said as the BMS's, and left out where it reports neither.
Widget _chargerState(AppL10n t, BmsSnapshot s) {
  final parts = [
    if (s.chargerPlugged case final plugged?)
      plugged ? t.nowChargerSeen : t.nowChargerNotSeen,
    if (s.chargeStatusCode case final code?)
      t.nowChargePhase(chargeStatusLabel(t, code)),
  ];
  if (parts.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
    child: Text(
      '${t.nowChargerByBms}: ${parts.join('  ·  ')}',
      style: const TextStyle(
        fontSize: 12,
        height: 1.4,
        color: AppTheme.textSecondary,
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
    PackStatusReason.bmsHot =>
      status.health == PackHealth.bad
          ? t.statusBmsHotBad(v.toStringAsFixed(1))
          : t.statusBmsHotWatch(v.toStringAsFixed(1)),
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

/// One alert as the banner shows it: the name it is muted under, whether it
/// is the red kind, and its words.
typedef _Shown = ({String key, bool critical, String Function(AppL10n) label});

class _AlertBannerState extends State<_AlertBanner> {
  final List<StreamSubscription<Object?>> _subs = [];
  _Shown? _latest;
  Timer? _clear;

  @override
  void initState() {
    super.initState();
    // Riding alerts, charge alerts and the link going: all three. Only the
    // first used to reach the screen, so a charge finishing or the cells
    // spreading at the top with the app open in hand was a buzz with nothing
    // on screen to say what it was about.
    _subs
      ..add(
        widget.service.rideAlerts.listen(
          (a) => _show((
            key: a.name,
            critical: a.isCritical,
            label: (t) => _label(t, a),
          )),
        ),
      )
      ..add(
        widget.service.chargeAlertStream.listen(
          (a) => _show((
            key: a.name,
            critical: a.isProblem,
            label: (t) => _chargeLabel(t, a),
          )),
        ),
      )
      ..add(
        widget.service.linkLostAlerts.listen(
          (_) => _show((
            key: BmsService.linkLostAlertKey,
            critical: true,
            label: (t) => t.alertLinkLost,
          )),
        ),
      );
  }

  void _show(_Shown alert) {
    if (!mounted) return;
    setState(() => _latest = alert);
    _clear?.cancel();
    // Long enough to be seen at the next glance down, short enough that a
    // stale warning is not still sitting there ten minutes later.
    _clear = Timer(const Duration(minutes: 1), () {
      if (mounted) setState(() => _latest = null);
    });
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _clear?.cancel();
    super.dispose();
  }

  Future<void> _silence(AppL10n t, _Shown alert) async {
    await widget.settings.setAlertMuted(alert.key, true);
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
    final tone = alert.critical ? AppTheme.bad : AppTheme.watch;

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
                    alert.label(t),
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
    RideAlert.bmsHot => t.alertBmsHot,
    RideAlert.lowCharge => t.alertLowCharge,
    RideAlert.criticalCharge => t.alertCriticalCharge,
    RideAlert.cellNearCutoff => t.alertCellNearCutoff,
    RideAlert.nearCurrentLimit => t.alertNearCurrentLimit,
  };

  String _chargeLabel(AppL10n t, ChargeAlert alert) => switch (alert) {
    ChargeAlert.targetReached => t.chargeAlertTargetReached(
      (widget.service.lastSnapshot?.soc ?? 0).toStringAsFixed(0),
    ),
    ChargeAlert.chargeComplete => t.chargeAlertComplete,
    ChargeAlert.hotWhileCharging => t.chargeAlertHot,
    ChargeAlert.spreadAtTop => t.chargeAlertSpread,
  };
}
