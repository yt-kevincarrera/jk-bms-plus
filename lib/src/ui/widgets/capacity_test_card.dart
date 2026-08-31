import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../bms_service.dart';
import '../../data/database.dart';
import '../../metrics/capacity_test_runner.dart';
import '../theme.dart';
import 'common.dart';

/// Runs and reports the one honest measurement in the app.
class CapacityTestCard extends StatefulWidget {
  const CapacityTestCard({required this.service, super.key});

  final BmsService service;

  @override
  State<CapacityTestCard> createState() => _CapacityTestCardState();
}

class _CapacityTestCardState extends State<CapacityTestCard> {
  Timer? _tick;
  List<CapacityTest> _history = const [];

  @override
  void initState() {
    super.initState();
    _load();
    // The runner is driven by the snapshot stream, not by setState.
    _tick = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted && widget.service.capacityTest.isRunning) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final device = widget.service.activeDeviceId;
    if (device == null) return;
    final tests = await widget.service.repository?.capacityTests(device);
    if (mounted && tests != null) setState(() => _history = tests);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final runner = widget.service.capacityTest;
    final completed = _history.where((h) => h.completed).toList();

    return Section(
      title: t.capacityTitle,
      accent: runner.isRunning ? AppTheme.cool : AppTheme.good,
      intro: t.capacityIntro,
      trailing: runner.isRunning
          ? Pill(t.capacityRunning, color: AppTheme.cool)
          : null,
      children: [
        if (runner.isRunning) ..._running(t, runner) else ..._idle(t),
        if (completed.isNotEmpty) ...[
          const SizedBox(height: 6),
          Caption(t.capacityHistory, color: AppTheme.textFaint),
          const SizedBox(height: 6),
          for (final test in completed.take(5)) ...[
            InfoRow(
              // A measurement the app found says so, because it is a weaker
              // claim than one someone stood over.
              test.automatic
                  ? '${_date(test.endedAt ?? test.startedAt)}  ·  '
                      '${t.capacityAutoTag}'
                  : _date(test.endedAt ?? test.startedAt),
              // The amp-hours measured are the fact; the percentage is a
              // comparison against a claim, so it only appears when a claim
              // exists.
              test.catalogueAh == null
                  ? '${test.measuredAh.toStringAsFixed(1)} Ah'
                  : '${test.measuredAh.toStringAsFixed(1)} Ah  ·  '
                      '${(test.measuredAh / test.catalogueAh! * 100).toStringAsFixed(0)} %',
              valueColor: test.catalogueAh == null
                  ? null
                  : _resultTone(test.measuredAh / test.catalogueAh!),
              last: test == completed.last && test.gapSeconds < 120,
            ),
            if (test.gapSeconds >= 120)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  t.capacityGapWarning(
                    (test.gapSeconds / 60).round().toString(),
                  ),
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: AppTheme.watch,
                  ),
                ),
              ),
          ],
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  List<Widget> _running(AppL10n t, CapacityTestRunner runner) => [
        InfoRow(
          t.capacityDrawn,
          '${runner.measuredAh.toStringAsFixed(2)} Ah  ·  '
          '${runner.measuredWh.toStringAsFixed(0)} Wh',
        ),
        InfoRow(
          t.capacityProgress,
          '${(runner.progress * 100).toStringAsFixed(0)} %',
        ),
        InfoRow(
          t.capacityStartedAt,
          runner.startedAt == null ? '--' : _date(runner.startedAt!),
          last: !runner.chargedDuringRun,
        ),
        if (runner.chargedDuringRun)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              t.capacityCharged,
              style: const TextStyle(
                fontSize: 12,
                height: 1.45,
                color: AppTheme.watch,
              ),
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            await widget.service.abortCapacityTest();
            if (mounted) setState(() {});
            await _load();
          },
          icon: const Icon(Icons.stop, size: 18),
          label: Text(t.capacityAbort),
        ),
      ];

  List<Widget> _idle(AppL10n t) {
    final blocked = widget.service.capacityTestBlockedBy;
    final reason = switch (blocked) {
      CapacityTestBlock.notFull => t.capacityNotFull,
      CapacityTestBlock.noReadings => t.capacityNoReadings,
      null => t.capacityCost,
    };

    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          t.capacityAutoNote,
          style: const TextStyle(
            fontSize: 12,
            height: 1.45,
            color: AppTheme.textFaint,
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          reason,
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: blocked == null ? AppTheme.textFaint : AppTheme.watch,
          ),
        ),
      ),
      FilledButton.icon(
        onPressed: blocked != null
            ? null
            : () async {
                await widget.service.startCapacityTest();
                if (mounted) setState(() {});
              },
        icon: const Icon(Icons.play_arrow, size: 19),
        label: Text(t.capacityStart),
      ),
    ];
  }

  static Color? _resultTone(double fraction) {
    if (fraction < 0.8) return AppTheme.bad;
    if (fraction < 0.92) return AppTheme.watch;
    return AppTheme.good;
  }

  static String _date(DateTime utc) {
    final d = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }
}
