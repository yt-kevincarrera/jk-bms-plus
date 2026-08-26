import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../bms_service.dart';
import '../../model/bms_snapshot.dart';
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
    final balancing = s.inferredBalancingCells;

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
                  i < s.cellResistances.length ? s.cellResistances[i] : null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: Text(
            t.cellsDeviationHint,
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
            s.balancerActive ? t.balancerWorking : t.balancerIdle,
            color: s.balancerActive ? AppTheme.cool : AppTheme.textFaint,
            icon: s.balancerActive ? Icons.bolt : null,
          ),
          intro: t.balanceActiveNote,
          children: [
            InfoRow(
              t.balanceCurrent,
              '${s.balanceCurrent.toStringAsFixed(3)} A',
              valueColor: s.balancerActive ? AppTheme.cool : null,
            ),
            InfoRow(
              t.balanceDirection,
              switch (s.balancingAction) {
                0x01 => t.balanceDirectionCharge,
                0x02 => t.balanceDirectionDischarge,
                _ => t.balanceDirectionOff,
              },
              dim: s.balancingAction == 0,
            ),
            InfoRow(t.balanceWhichCells, t.balanceWhichCellsValue, dim: true),
            InfoRow(t.balanceRanking, t.needsDatabase, dim: true, last: true),
          ],
        ),
        Section(
          title: t.resistanceTitle,
          children: [
            InfoRow(t.resistanceSource, t.resistanceSourceValue, dim: true),
            InfoRow(t.resistanceEstimated, t.needsSteps, dim: true),
            InfoRow(
              t.resistanceWireWarnings,
              s.wireResistanceWarningMask == 0
                  ? t.none
                  : '0x${s.wireResistanceWarningMask.toRadixString(16)}',
              valueColor:
                  s.wireResistanceWarningMask == 0 ? null : AppTheme.watch,
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
