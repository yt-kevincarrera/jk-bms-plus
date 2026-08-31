import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../bms_service.dart';
import '../metrics/pack_summary.dart';
import 'theme.dart';

/// Two or more batteries side by side.
///
/// Every figure here already existed, one screen per pack, which answers "how
/// is this one doing" but not "which of the two is worse" without holding both
/// in your head. That second question is the one a rider with a spare actually
/// has.
class ComparePacksScreen extends StatefulWidget {
  const ComparePacksScreen({required this.service, super.key});

  final BmsService service;

  @override
  State<ComparePacksScreen> createState() => _ComparePacksScreenState();
}

class _ComparePacksScreenState extends State<ComparePacksScreen> {
  bool _loading = true;
  List<PackSummary> _packs = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = widget.service.repository;
    if (repo == null) {
      setState(() => _loading = false);
      return;
    }

    final devices = await repo.devices();
    final summaries = <PackSummary>[];
    for (final d in devices) {
      // The demo pack is not a battery anybody is deciding about.
      if (d.demo) continue;
      summaries.add(
        PackSummary.from(
          device: d,
          readings: await repo.allSnapshots(d.id, days: 3650),
          trips: await repo.db.recentTrips(d.id, limit: 500),
          tests: await repo.capacityTests(d.id),
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _packs = summaries;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.compareTitle)),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _packs.length < 2
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        t.compareNeedsTwo,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: AppTheme.textFaint,
                        ),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 28),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          t.compareIntro,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: AppTheme.textFaint,
                          ),
                        ),
                      ),
                      // Horizontal scroll rather than shrinking the type: with
                      // three packs the columns would be unreadable, and a
                      // health figure nobody can read is not a health figure.
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _table(t),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _table(AppL10n t) {
    final rows = <_Row>[
      _Row(
        t.compareHealth,
        (p) => p.healthPercent == null
            ? null
            : '${p.healthPercent!.toStringAsFixed(0)} %',
        tone: (p) => p.healthPercent == null
            ? null
            : _healthTone(p.healthPercent!),
        best: (p) => p.healthPercent,
        higherIsBetter: true,
      ),
      _Row(
        t.offlineImplied,
        (p) => p.impliedCapacityAh == null
            ? null
            : '${p.impliedCapacityAh!.toStringAsFixed(1)} Ah',
        best: (p) => p.impliedCapacityAh,
        higherIsBetter: true,
      ),
      _Row(
        t.settingsCatalogue,
        (p) => p.device.catalogueCapacityAh == null
            ? null
            : '${p.device.catalogueCapacityAh!.toStringAsFixed(0)} Ah',
      ),
      _Row(
        t.offlineBestMeasured,
        (p) => p.bestMeasuredAh == null
            ? null
            : '${p.bestMeasuredAh!.toStringAsFixed(1)} Ah',
        best: (p) => p.bestMeasuredAh,
        higherIsBetter: true,
      ),
      _Row(
        t.compareHonestCycles,
        (p) => p.honestCycles?.toStringAsFixed(0),
        best: (p) => p.honestCycles,
        higherIsBetter: false,
      ),
      _Row(
        t.offlineCycles,
        (p) => p.reportedCycles?.toStringAsFixed(0),
      ),
      _Row(
        t.compareConsumption,
        (p) => p.whPerKm == null
            ? null
            : '${p.whPerKm!.toStringAsFixed(1)} Wh/km',
        best: (p) => p.whPerKm,
        higherIsBetter: false,
      ),
      _Row(
        t.compareWorstDelta,
        (p) => p.worstDeltaVolts == null
            ? null
            : '${p.worstDeltaVolts!.toStringAsFixed(3)} V',
        best: (p) => p.worstDeltaVolts,
        higherIsBetter: false,
      ),
      _Row(t.offlineTrips, (p) => '${p.rides}'),
      _Row(t.offlineTotalKm, (p) => '${p.totalKm.toStringAsFixed(0)} km'),
    ];

    const labelWidth = 150.0;
    const colWidth = 118.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: labelWidth),
              for (final p in _packs)
                SizedBox(
                  width: colWidth,
                  child: Text(
                    p.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (final row in rows) ...[
            _buildRow(row, labelWidth, colWidth),
            const Divider(height: 14, color: AppTheme.hairline),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(_Row row, double labelWidth, double colWidth) {
    // Which pack wins this row, when the row is one where winning means
    // anything. Only marked when the packs actually differ: highlighting a tie
    // suggests a difference that is not there.
    double? bestValue;
    if (row.best != null) {
      final values = _packs.map(row.best!).whereType<double>().toList();
      if (values.length > 1) {
        final sorted = [...values]..sort();
        if (sorted.first != sorted.last) {
          bestValue = row.higherIsBetter ? sorted.last : sorted.first;
        }
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            row.label,
            style: const TextStyle(fontSize: 12.5, color: AppTheme.textFaint),
          ),
        ),
        for (final p in _packs)
          SizedBox(
            width: colWidth,
            child: Builder(
              builder: (context) {
                final text = row.value(p);
                final isBest = bestValue != null &&
                    row.best != null &&
                    row.best!(p) == bestValue;
                return Text(
                  text ?? '--',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: text == null
                        ? AppTheme.textFaint
                        : isBest
                            ? AppTheme.good
                            : row.tone?.call(p),
                    fontWeight: isBest ? FontWeight.w600 : null,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  static Color _healthTone(double percent) {
    if (percent >= 92) return AppTheme.good;
    if (percent >= 80) return AppTheme.watch;
    return AppTheme.bad;
  }
}

class _Row {
  const _Row(
    this.label,
    this.value, {
    this.tone,
    this.best,
    this.higherIsBetter = true,
  });

  final String label;
  final String? Function(PackSummary) value;
  final Color? Function(PackSummary)? tone;

  /// The comparable number behind the text, when there is one. Rows like the
  /// catalogue capacity have no better or worse.
  final double? Function(PackSummary)? best;
  final bool higherIsBetter;
}
