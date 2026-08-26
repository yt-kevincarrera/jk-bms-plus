import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../metrics/charge_session.dart';
import '../theme.dart';
import 'common.dart';

/// What the last charge revealed.
class ChargeReportCard extends StatelessWidget {
  const ChargeReportCard({required this.report, super.key});

  final ChargeReport? report;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final r = report;

    if (r == null) {
      return Section(
        title: t.chargeReportTitle,
        intro: t.chargeReportIntro,
        children: [
          InfoRow(t.chargeNone, '', dim: true, last: true),
          const SizedBox(height: 6),
        ],
      );
    }

    return Section(
      title: t.chargeReportTitle,
      accent: r.opensAtTop ? AppTheme.watch : AppTheme.good,
      intro: t.chargeReportIntro,
      trailing: Text(
        _date(r.startedAt),
        style: const TextStyle(fontSize: 11, color: AppTheme.textFaint),
      ),
      children: [
        InfoRow(
          t.chargeAdded,
          '${r.ahIn.toStringAsFixed(1)} Ah  ·  ${r.whIn.toStringAsFixed(0)} Wh',
          hint: t.chargeFrom(
            r.startSoc.toStringAsFixed(0),
            r.endSoc.toStringAsFixed(0),
          ),
        ),
        InfoRow(t.chargeDeltaStart, r.deltaAtStart.toStringAsFixed(3)),
        if (r.reachedTop) ...[
          InfoRow(
            t.chargeWorstDelta,
            r.worstDeltaHigh.toStringAsFixed(3),
            valueColor:
                r.worstDeltaHigh > 0.05 ? AppTheme.watch : null,
          ),
          InfoRow(
            t.chargeWeakCell,
            r.weakCellAtTop == 0 ? '--' : '${r.weakCellAtTop}',
            valueColor: AppTheme.watch,
          ),
        ],
        InfoRow(
          t.chargeBalancerTime,
          _duration(r.balancerWorkedSeconds),
          dim: r.balancerWorkedSeconds == 0,
          last: true,
        ),
        if (!r.reachedTop)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              t.chargeNeverReachedTop,
              style: const TextStyle(
                fontSize: 12,
                height: 1.45,
                color: AppTheme.textFaint,
              ),
            ),
          ),
        if (r.opensAtTop)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2, right: 10),
                  child: Icon(
                    Icons.error_outline,
                    size: 16,
                    color: AppTheme.watch,
                  ),
                ),
                Expanded(
                  child: Text(
                    t.chargeOpensAtTop(r.weakCellAtTop),
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
        const SizedBox(height: 8),
      ],
    );
  }

  static String _date(DateTime utc) {
    final d = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}  ${two(d.hour)}:${two(d.minute)}';
  }

  static String _duration(int seconds) {
    if (seconds == 0) return '--';
    final d = Duration(seconds: seconds);
    if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes % 60} min';
    return '${d.inMinutes} min';
  }
}
