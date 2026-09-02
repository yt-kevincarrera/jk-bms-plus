import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'dart:async';

import '../../bms_service.dart';
import '../../metrics/degradation.dart';
import '../../metrics/pack_health_report.dart';
import '../../metrics/range_estimator.dart';
import '../../model/bms_snapshot.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../../metrics/advice_engine.dart';
import '../../metrics/snapshot_history.dart';
import '../widgets/advice_list.dart';
import '../widgets/capacity_test_card.dart';
import '../widgets/charge_report_card.dart';
import '../widgets/gauges.dart';

/// The uncomfortable numbers, at a glance.
///
/// Everything here is derived by cross-checking figures the BMS already hands
/// over against each other, which is exactly why none of it appears in the
/// official app. The reasoning behind each one is worth having, but not on
/// every glance, so it lives behind a disclosure rather than down the page.
class HealthTab extends StatefulWidget {
  const HealthTab({required this.service, required this.snapshot, super.key});

  final BmsService service;
  final BmsSnapshot? snapshot;

  @override
  State<HealthTab> createState() => _HealthTabState();
}

class _HealthTabState extends State<HealthTab> {
  /// Degradation needs history, which lives on disk rather than in the live
  /// stream. Loaded once and refreshed after a capacity measurement lands.
  Degradation? _degradation;

  @override
  void initState() {
    super.initState();
    _loadDegradation();
    // A finished capacity test changes the baseline, so the figure would
    // otherwise stay stale until the tab was rebuilt from scratch.
    _capacitySub = widget.service.capacityTestState.listen((_) {
      _loadDegradation();
    });
  }

  StreamSubscription<Object?>? _capacitySub;

  @override
  void dispose() {
    _capacitySub?.cancel();
    super.dispose();
  }

  Future<void> _loadDegradation() async {
    final repo = widget.service.repository;
    final device = widget.service.activeDeviceId;
    if (repo == null || device == null) return;

    final result = Degradation.from(
      tests: await repo.capacityTests(device),
      readings: await repo.allSnapshots(device, days: 365),
      advertisedAh: widget.service.catalogueCapacityAh,
    );
    if (mounted) setState(() => _degradation = result);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final service = widget.service;
    final s = widget.snapshot;
    if (s == null) {
      return WaitingForData(message: t.waitingFor(t.waitingFirstReading));
    }

    final report = PackHealthReport.from(
      snapshot: s,
      settings: service.lastSettings,
      catalogueCapacityAh: service.catalogueCapacityAh,
      cutoffVoltagePerCell: service.cutoffVoltagePerCell,
    );
    final estimator = service.rangeEstimator;

    final usableWh = RangeEstimator.usableWh(
      remainingAh: s.remainingCapacityAh,
      packVoltage: s.packVoltage,
      cellCount: s.cellCount,
      minCellVoltage: s.minCellVoltage,
      averageCellVoltage: s.averageCellVoltage,
      cutoffVoltagePerCell: service.cutoffVoltagePerCell,
    );

    // Degradation is measured against the best this pack has ever held, not
    // against what it was advertised as. Measuring wear against a marketing
    // figure reported a pack sold as 45 Ah that was always 40 as permanently
    // 89% healthy, on day one, before it had lost anything: a number that
    // described the advert and never the battery.
    final catalogue = service.catalogueCapacityAh;
    final degradation = _degradation;
    final lost = degradation?.lostFraction;
    final healthPercent = lost != null ? (1 - lost) * 100 : s.soh;
    final tone = _healthTone(healthPercent);

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 28),
      children: [
        Row(
          children: [
            Expanded(
              child: Center(
                child: SocGauge(
                  soc: healthPercent.clamp(0.0, 100.0),
                  color: tone,
                  centreLabel: t.healthGaugeLabel,
                  centreValue: '${healthPercent.toStringAsFixed(0)}%',
                  subtitle: lost != null
                      ? t.healthGaugeMeasured
                      : t.healthGaugeReported,
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
                    Text(
                      _verdict(t, healthPercent),
                      style: TextStyle(
                        fontSize: 15.5,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: tone,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // The real amperage, against the best this pack has
                    // actually held. Not against the advert, which is a
                    // different question answered further down.
                    Readout(
                      label: t.degNowTitle,
                      value: degradation?.current?.ah.toStringAsFixed(1) ??
                          report.impliedCapacityAh?.toStringAsFixed(1) ??
                          '--',
                      unit: 'Ah',
                      size: 30,
                      footnote: degradation?.baseline == null
                          ? null
                          : '/ ${degradation!.baseline!.ah.toStringAsFixed(1)} Ah',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        // Two questions, kept apart on purpose. What the pack has lost is
        // wear. What it came up short of the advert is a fact about a
        // purchase, decided once, that does not move as the battery ages.
        if (degradation != null) ...[
          Section(
            title: t.degLost,
            intro: t.degLostWhy,
            children: [
              InfoRow(
                t.degLost,
                lost == null
                    ? t.degLostUnknown
                    : '${(lost * 100).toStringAsFixed(1)} %',
                dim: lost == null,
                valueColor: lost == null ? null : _healthTone((1 - lost) * 100),
              ),
              InfoRow(
                t.degBaseline,
                degradation.baseline == null
                    ? '--'
                    : '${degradation.baseline!.ah.toStringAsFixed(1)} Ah',
                hint: degradation.baseline == null
                    ? null
                    : degradation.baselineIsMeasured
                        ? t.degBaselineOn(_date(degradation.baseline!.at))
                        : t.degImpliedNote,
                last: catalogue == null,
              ),
              if (catalogue != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    (degradation.shortOfAdvertisedFraction ?? 0) < 0.02
                        ? t.degSoldOk
                        : t.degSoldShort(
                            catalogue.toStringAsFixed(0),
                            degradation.baseline!.ah.toStringAsFixed(1),
                            ((degradation.shortOfAdvertisedFraction ?? 0) * 100)
                                .toStringAsFixed(0),
                          ),
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: AppTheme.textFaint,
                    ),
                  ),
                ),
              const SizedBox(height: 6),
            ],
          ),
        ],
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.85,
            children: [
              StatCard(
                label: t.healthCardShortOfAdvert,
                value: report.shortOfAdvertisedFraction == null
                    ? '--'
                    : (report.shortOfAdvertisedFraction! * 100).toStringAsFixed(1),
                unit: '%',
                color: report.shortOfAdvertisedFraction == null
                    ? AppTheme.textFaint
                    : _lossTone(report.shortOfAdvertisedFraction! * 100),
                emphasis: true,
              ),
              StatCard(
                label: t.healthCardCycles,
                value: report.equivalentFullCycles.toStringAsFixed(0),
              ),
              StatCard(
                label: t.healthCardInflation,
                value: report.cycleInflation == null
                    ? '--'
                    : report.cycleInflation!.toStringAsFixed(2),
                unit: 'x',
                color:
                    (report.cycleInflation ?? 1) > 1.4 ? AppTheme.watch : null,
              ),
              StatCard(
                label: t.healthCardImbalance,
                value: report.imbalanceLossFraction == null
                    ? '--'
                    : (report.imbalanceLossFraction! * 100).toStringAsFixed(1),
                unit: '%',
                color: (report.imbalanceLossFraction ?? 0) > 0.05
                    ? AppTheme.watch
                    : null,
                emphasis: true,
              ),
              StatCard(
                label: t.healthCardWeakest,
                value: '${report.weakestCellIndex}',
                color: AppTheme.watch,
              ),
              StatCard(
                label: t.healthCardSpread,
                value: report.resistanceSpreadPercent == null
                    ? '--'
                    : '+${report.resistanceSpreadPercent!.toStringAsFixed(0)}',
                unit: '%',
                color: (report.resistanceSpreadPercent ?? 0) > 40
                    ? AppTheme.watch
                    : null,
              ),
              StatCard(
                label: t.healthCardUsable,
                value: usableWh.toStringAsFixed(0),
                unit: 'Wh',
              ),
              StatCard(
                label: t.healthCardConsumption,
                value: estimator.whPerKm.toStringAsFixed(0),
                unit: 'Wh/km',
                color: estimator.hasLearned ? null : AppTheme.textFaint,
              ),
              StatCard(
                label: t.healthCardLearnedKm,
                value: estimator.learnedKm.toStringAsFixed(0),
                unit: 'km',
                color: estimator.learnedKm == 0 ? AppTheme.textFaint : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        AdviceList(
          advice: const AdviceEngine().evaluate(
            snapshot: s,
            report: report,
            estimator: estimator,
            settings: service.lastSettings,
            restingDelta: service.history.restingDelta,
            loadedDelta: service.history.loadedDelta,
            weakCellCounts: service.history.weakCellCounts,
            balancerEverSeen: service.history.balancerEverSeen,
            capacityTestCount: service.capacityTestCount,
            degradationMeasurable: lost != null,
            usableWh: usableWh,
            grossWh: s.remainingCapacityAh * s.packVoltage,
          ),
        ),
        const SizedBox(height: 4),
        CapacityTestCard(service: service),
        ChargeReportCard(report: service.lastChargeReport),
        const SizedBox(height: 4),
        Explainer(
          title: t.healthHowCalculated,
          paragraphs: [
            t.healthIntro,
            report.capacityMeaningful
                ? t.healthRealCapacityHint
                : t.healthCapacityUnavailable,
            t.healthEquivalentCyclesHint,
            t.healthImbalanceHint,
            t.healthWeakestCellHint,
            t.rangeUsableHint,
            if (report.sohLooksDecorative) t.healthSohSuspect,
          ],
        ),
        Explainer(
          title: t.rangeEstimatorTitle,
          paragraphs: [
            t.rangeEstimatorIntro,
            service.isDemo ? t.rangeDemoNote : t.rangeNeedsGps,
          ],
        ),
        Explainer(
          title: t.healthNeedsHistoryTitle,
          paragraphs: [
            t.healthNeedsHistoryBody,
            [
              t.historyItemCapacity,
              t.historyItemTrips,
              t.historyItemDelta,
              t.historyItemSag,
              t.historyItemBalance,
            ].map((e) => '  .  $e').join('\n'),
          ],
        ),
      ],
    );
  }

  String _verdict(AppL10n t, double percent) {
    if (percent >= 92) return t.healthVerdictGood;
    if (percent >= 80) return t.healthVerdictWatch;
    return t.healthVerdictBad;
  }

  static String _date(DateTime utc) {
    final d = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  Color _healthTone(double percent) {
    if (percent >= 92) return AppTheme.good;
    if (percent >= 80) return AppTheme.watch;
    return AppTheme.bad;
  }

  Color _lossTone(double percent) {
    if (percent > 20) return AppTheme.bad;
    if (percent > 8) return AppTheme.watch;
    return AppTheme.good;
  }
}
