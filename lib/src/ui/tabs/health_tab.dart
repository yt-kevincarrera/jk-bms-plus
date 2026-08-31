import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../bms_service.dart';
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
class HealthTab extends StatelessWidget {
  const HealthTab({required this.service, required this.snapshot, super.key});

  final BmsService service;
  final BmsSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final s = snapshot;
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

    // Prefer the health that can actually be measured over the one the BMS
    // asserts. A firmware reporting a fixed 100% forever is telling you nothing.
    // Only when there is a stated capacity to measure against. With none, the
    // app falls back to what the BMS claims rather than to a percentage of an
    // invented figure.
    final catalogue = service.catalogueCapacityAh;
    final measured = report.impliedCapacityAh != null &&
            catalogue != null &&
            catalogue > 0
        ? (report.impliedCapacityAh! / catalogue * 100).clamp(0.0, 120.0)
        : null;
    final healthPercent = measured ?? s.soh;
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
                  subtitle: measured != null
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
                    Readout(
                      label: t.healthCardCapacity,
                      value:
                          report.impliedCapacityAh?.toStringAsFixed(1) ?? '--',
                      unit: 'Ah',
                      size: 30,
                      footnote: catalogue == null
                          ? t.catalogueNotComparable
                          : '/ ${catalogue.toStringAsFixed(0)} Ah',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
                label: t.healthCardLoss,
                value: report.capacityLossFraction == null
                    ? '--'
                    : (report.capacityLossFraction! * 100).toStringAsFixed(1),
                unit: '%',
                color: report.capacityLossFraction == null
                    ? AppTheme.textFaint
                    : _lossTone(report.capacityLossFraction! * 100),
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
