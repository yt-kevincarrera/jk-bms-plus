import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../bms_service.dart';
import '../../metrics/advice_engine.dart';
import '../../metrics/weak_cell_ranking.dart';
import '../../model/bms_snapshot.dart';
import '../../protocol/ant_constants.dart';
import '../../protocol/bms_brand.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/gauges.dart';

/// Every cell at once, coloured by how far it sits from the pack average.
///
/// A grid rather than a twenty-row list: twenty cells fit on one screen, and a
/// cell out of line should be findable without scrolling or reading a number.
class CellsTab extends StatelessWidget {
  const CellsTab({required this.service, required this.snapshot, super.key});

  final BmsService service;
  final BmsSnapshot? snapshot;

  static const double _watchDeviation = 0.015;
  static const double _badDeviation = 0.035;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final s = snapshot;
    if (s == null) {
      return WaitingForData(message: t.waitingFor(t.waitingCellVoltages));
    }

    final avg = s.averageCellVoltage;
    final hasResistances = s.cellResistances?.isNotEmpty ?? false;
    // The BMS's own list where it gives one (an ANT does), the inference
    // from the cell voltages where it does not (a JK).
    final balancing = s.balancingCells;
    final reported = s.reportedBalancingCells;
    final ant = s.brand == BmsBrand.ant ? service.lastAntStatus : null;
    // An ANT balancer stopped by heat is not "idle" and is not "working".
    final stoppedByHeat =
        ant != null && antBalancerFaultCodes.contains(ant.balancerCode);

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: MetricTile(
                  label: t.cellDelta,
                  value: s.deltaCellVoltage.toStringAsFixed(3),
                  unit: 'V',
                  color: _colourFor(s.deltaCellVoltage / 2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricTile(
                  label: t.average,
                  value: avg.toStringAsFixed(3),
                  unit: 'V',
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _extremeLine(
                Icons.arrow_downward,
                AppTheme.watch,
                t.cellsLowest(
                  s.minCellIndex,
                  s.minCellVoltage.toStringAsFixed(3),
                ),
              ),
              const SizedBox(height: 4),
              _extremeLine(
                Icons.arrow_upward,
                AppTheme.cool,
                t.cellsHighest(
                  s.maxCellIndex,
                  s.maxCellVoltage.toStringAsFixed(3),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.05,
            ),
            itemCount: s.cellVoltages.length,
            itemBuilder: (context, i) => CellTile(
              index: i + 1,
              voltage: s.cellVoltages[i],
              deviation: s.cellVoltages[i] - avg,
              color: _cellColour(s, i + 1, s.cellVoltages[i] - avg),
              balancing: i < balancing.length && balancing[i],
              isExtreme: i + 1 == s.minCellIndex || i + 1 == s.maxCellIndex,
              resistance:
                  s.cellResistances != null && i < s.cellResistances!.length
                  ? s.cellResistances![i]
                  : null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          // The figure under each tile is what JK reports per cell, which is
          // the balance lead and its connection. Unlabelled it read as the
          // cell's own resistance.
          child: Text(
            hasResistances
                ? '${t.cellsDeviationHint} ${t.cellsResistanceNote}'
                : t.cellsDeviationHint,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: AppTheme.textFaint,
            ),
          ),
        ),
        Section(
          title: t.balancingTitle,
          trailing: Pill(
            s.balancerActive
                ? t.balancerWorking
                : stoppedByHeat
                ? t.balancerStoppedByHeat
                : t.balancerIdle,
            color: s.balancerActive
                ? AppTheme.cool
                : stoppedByHeat
                ? AppTheme.bad
                : AppTheme.textFaint,
            icon: s.balancerActive ? Icons.bolt : null,
          ),
          // Said of a JK, which is an active balancer. An ANT's balancer can
          // be either kind and the frame does not say, so nothing is claimed.
          intro: s.brand == BmsBrand.jk ? t.balanceActiveNote : null,
          children: [
            if (ant != null)
              InfoRow(
                t.antBalancer,
                ant.balancerCode < antBalancerText.length
                    ? t.antBalancerCode('${ant.balancerCode}')
                    : t.antUnknownCode(
                        ant.balancerCode.toRadixString(16).padLeft(2, '0'),
                      ),
                valueColor: stoppedByHeat ? AppTheme.bad : null,
              ),
            if (s.balanceCurrent != null)
              InfoRow(
                t.balanceCurrent,
                '${s.balanceCurrent!.toStringAsFixed(3)} A',
                valueColor: s.balancerActive ? AppTheme.cool : null,
              ),
            if (s.balancingAction != null)
              InfoRow(t.balanceDirection, switch (s.balancingAction!) {
                0x01 => t.balanceDirectionCharge,
                0x02 => t.balanceDirectionDischarge,
                _ => t.balanceDirectionOff,
              }, dim: s.balancingAction == 0),
            InfoRow(
              t.balanceWhichCells,
              reported == null
                  ? t.balanceWhichCellsValue
                  : reported.contains(true)
                  ? t.balanceWhichCellsReported(
                      [
                        for (var i = 0; i < reported.length; i++)
                          if (reported[i]) '${i + 1}',
                      ].join(', '),
                    )
                  : t.balanceWhichCellsNoneReported,
              dim: reported == null || !reported.contains(true),
            ),
            // Which cells were clearly the lowest at rest over the last
            // month, from the stored readings. It used to count only the
            // current connection, loaded readings included, so it started
            // from nothing every time and ranked lead resistance alongside
            // charge.
            WeakCellRankingRow(service: service),
          ],
        ),
        // An "estimated internal resistance" row used to sit here reading
        // "needs current steps" for ever: nothing computes it. An ANT reports
        // neither lead resistances nor their warnings, so it gets no section.
        if (hasResistances || s.wireResistanceWarningMask != null)
          Section(
            title: t.resistanceTitle,
            children: [
              InfoRow(
                t.resistanceSource,
                t.resistanceSourceValue,
                dim: true,
                last: s.wireResistanceWarningMask == null,
              ),
              if (s.wireResistanceWarningMask != null)
                InfoRow(
                  t.resistanceWireWarnings,
                  s.wireResistanceWarningMask == 0
                      ? t.none
                      : '0x${s.wireResistanceWarningMask!.toRadixString(16)}',
                  valueColor: s.wireResistanceWarningMask == 0
                      ? null
                      : AppTheme.watch,
                  last: true,
                ),
            ],
          ),
      ],
    );
  }

  Widget _extremeLine(IconData icon, Color colour, String text) => Row(
    children: [
      Icon(icon, size: 13, color: colour),
      const SizedBox(width: 6),
      Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          color: AppTheme.textSecondary,
          fontFeatures: AppTheme.tabular,
        ),
      ),
    ],
  );

  /// Colour for the delta readout, where any value is a magnitude rather than a
  /// direction.
  Color _colourFor(double deviation) {
    final d = deviation.abs();
    if (d > _badDeviation) return AppTheme.bad;
    if (d > _watchDeviation) return AppTheme.watch;
    return AppTheme.good;
  }

  /// Colour for one cell in the grid.
  ///
  /// Neutral is the default on purpose: colour every cell and none of them
  /// stands out. Only the two that matter get a tone — the lowest in amber,
  /// because that is the cell that decides when the pack cuts off, and the
  /// highest in cyan — plus anything genuinely out of range in red.
  Color _cellColour(BmsSnapshot s, int oneBased, double deviation) {
    if (deviation.abs() > _badDeviation) return AppTheme.bad;
    if (oneBased == s.minCellIndex) return AppTheme.watch;
    if (oneBased == s.maxCellIndex) return AppTheme.cool;
    if (deviation.abs() > _watchDeviation) return AppTheme.watch;
    return AppTheme.textPrimary;
  }
}

/// The weak-cell ranking row, read from the stored month rather than the
/// connection. Loads once per pack: a ranking over thirty days does not move
/// in the minutes a tab stays open.
class WeakCellRankingRow extends StatefulWidget {
  const WeakCellRankingRow({required this.service, super.key});

  final BmsService service;

  @override
  State<WeakCellRankingRow> createState() => _WeakCellRankingRowState();
}

class _WeakCellRankingRowState extends State<WeakCellRankingRow> {
  String? _device;
  Future<WeakCellRanking>? _ranking;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final repo = widget.service.repository;
    final device = widget.service.activeDeviceId;
    if (device != _device) {
      _device = device;
      _ranking = repo == null || device == null
          ? null
          : repo.weakCellRanking(device);
    }
    final needed = VerdictThresholds.defaults.weakCellMinReadings;
    return FutureBuilder<WeakCellRanking>(
      future: _ranking,
      builder: (context, snap) {
        final r = snap.data;
        if (r == null) {
          return InfoRow(
            t.balanceRanking,
            _ranking == null ? t.balanceRankingNeedsHistory : '...',
            dim: true,
            last: true,
          );
        }
        if (!r.isEnough(needed)) {
          return InfoRow(
            t.balanceRanking,
            t.balanceRankingNeedsHistory,
            dim: true,
            hint: t.balanceRankingProgress('${r.readings}', '$needed'),
            last: true,
          );
        }
        return InfoRow(
          t.balanceRanking,
          [
            for (final e in r.top)
              t.balanceRankingEntry(
                '${e.cell}',
                (e.share * 100).toStringAsFixed(0),
              ),
          ].join(',  '),
          hint: t.balanceRankingBasis('${r.readings}'),
          last: true,
        );
      },
    );
  }
}
