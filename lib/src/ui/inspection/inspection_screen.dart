import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../bms_service.dart';
import '../../inspection/inspection_result.dart';
import '../../inspection/inspection_session.dart';
import '../../model/bms_snapshot.dart';
import '../theme.dart';
import 'inspection_verdict_screen.dart';

/// The guided quick test, one instruction at a time in large letters.
///
/// The person holding the phone only executes. This screen watches the
/// current the BMS reports and the session advances by itself when the step
/// happened; nothing here has a "next" button. When the session finishes, the
/// analysis runs once over everything captured and the verdict screen takes
/// over.
class InspectionScreen extends StatefulWidget {
  const InspectionScreen({
    required this.service,
    required this.bmsId,
    required this.bmsName,
    super.key,
  });

  final BmsService service;

  /// The BLE address of the pack under inspection. Never adopted as a
  /// battery; kept only so two inspections of the same pack can be told
  /// apart later.
  final String bmsId;
  final String bmsName;

  @override
  State<InspectionScreen> createState() => _InspectionScreenState();
}

class _InspectionScreenState extends State<InspectionScreen> {
  final InspectionSession _session = InspectionSession();
  StreamSubscription<BmsSnapshot>? _sub;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    // A reading already on the service counts: the connect screen waited for
    // proof before opening this, and that proof is the first sample.
    final last = widget.service.lastSnapshot;
    if (last != null) _feed(last);
    _sub = widget.service.snapshots.listen(_feed);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _feed(BmsSnapshot s) {
    if (_finished) return;
    final done = _session.feed(s);
    if (mounted) setState(() {});
    if (done) _finish();
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    await _sub?.cancel();
    _sub = null;

    final service = widget.service;
    final info = service.lastDeviceInfo;
    final settings = service.lastSettings;
    final last = service.lastSnapshot;
    final reported = ReportedFigures(
      model: info?.model ?? '',
      serialNumber: info?.serialNumber ?? '',
      softwareVersion: info?.softwareVersion ?? '',
      cycleCount: last?.cycleCount,
      configuredCapacityAh:
          settings?.nominalCapacityAh ?? last?.nominalCapacityAh,
      soc: last?.soc,
      soh: last?.soh,
    );
    final result = const InspectionAnalysis().compute(
      _session,
      reported: reported,
    );

    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => InspectionVerdictScreen(
          service: service,
          result: result,
          samples: _session.samples,
          bmsId: widget.bmsId,
          bmsName: widget.bmsName,
        ),
      ),
    );
  }

  void _skip() {
    _session.skipStep();
    if (_session.isDone) {
      _finish();
    } else if (mounted) {
      setState(() {});
    }
  }

  void _abort() {
    _session.abortToDone();
    _finish();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final prompt = _session.prompt;
    final th = _session.thresholds;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.inspectionTitle),
        actions: [
          TextButton(onPressed: _abort, child: Text(t.inspectionAbort)),
        ],
      ),
      body: SafeArea(
        child: prompt == null
            ? _waiting(t)
            : Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _stepper(prompt.step),
                    const SizedBox(height: 22),
                    Text(
                      _stepTitle(t, prompt.step),
                      style: const TextStyle(
                        fontSize: 30,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _stepBody(t, prompt.step),
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    _currentReadout(t, prompt),
                    const SizedBox(height: 18),
                    _progress(t, prompt),
                    const SizedBox(height: 16),
                    if (prompt.step == InspectionStep.lightLoad ||
                        prompt.step == InspectionStep.heavyLoad) ...[
                      Text(
                        t.inspectionStepSkipHint(
                          '${(th.stepTimeoutSeconds - prompt.elapsedInStep.inSeconds).clamp(0, th.stepTimeoutSeconds)}',
                        ),
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: AppTheme.textFaint,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _skip,
                        child: Text(t.inspectionSkipStep),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _waiting(AppL10n t) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.goodDim,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          t.inspectionWaitingReadings,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      ],
    ),
  );

  /// Four dots, one lit: where in the test we are.
  Widget _stepper(InspectionStep step) {
    const steps = [
      InspectionStep.rest,
      InspectionStep.lightLoad,
      InspectionStep.heavyLoad,
      InspectionStep.recovery,
    ];
    return Row(
      children: [
        for (final s in steps) ...[
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: s.index < step.index
                    ? AppTheme.good
                    : s == step
                    ? AppTheme.cool
                    : AppTheme.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (s != steps.last) const SizedBox(width: 6),
        ],
      ],
    );
  }

  Widget _currentReadout(AppL10n t, InspectionPrompt p) {
    final amps = p.currentAmps.toStringAsFixed(1);
    final wantsQuiet =
        p.step == InspectionStep.rest || p.step == InspectionStep.recovery;
    final status = wantsQuiet
        ? (p.loadDetected ? t.inspectionQuietOk : t.inspectionNotQuiet(amps))
        : (p.loadDetected
              ? t.inspectionLoadEnough(amps)
              : t.inspectionLoadTooLow(amps));
    final tone = p.loadDetected ? AppTheme.good : AppTheme.watch;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.inspectionCurrentNow.toUpperCase(),
                  style: AppTheme.caption(context),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(amps, style: AppTheme.readout(40, color: tone)),
                    const SizedBox(width: 4),
                    const Text(
                      'A',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  status,
                  style: TextStyle(fontSize: 12.5, height: 1.35, color: tone),
                ),
              ],
            ),
          ),
          Icon(
            p.loadDetected ? Icons.check_circle_outline : Icons.hourglass_top,
            color: tone,
            size: 28,
          ),
        ],
      ),
    );
  }

  Widget _progress(AppL10n t, InspectionPrompt p) => Row(
    children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: p.progress,
            minHeight: 6,
            backgroundColor: AppTheme.hairline,
            color: p.loadDetected ? AppTheme.good : AppTheme.textFaint,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Text(
        t.inspectionSecondsLeft('${p.secondsLeft}'),
        style: const TextStyle(
          fontSize: 13,
          fontFeatures: AppTheme.tabular,
          color: AppTheme.textSecondary,
        ),
      ),
    ],
  );

  static String _stepTitle(AppL10n t, InspectionStep s) => switch (s) {
    InspectionStep.rest => t.inspectionStepRestTitle,
    InspectionStep.lightLoad => t.inspectionStepLightTitle,
    InspectionStep.heavyLoad => t.inspectionStepHeavyTitle,
    InspectionStep.recovery => t.inspectionStepRecoveryTitle,
    InspectionStep.done => t.inspectionStepDoneTitle,
  };

  static String _stepBody(AppL10n t, InspectionStep s) => switch (s) {
    InspectionStep.rest => t.inspectionStepRestBody,
    InspectionStep.lightLoad => t.inspectionStepLightBody,
    InspectionStep.heavyLoad => t.inspectionStepHeavyBody,
    InspectionStep.recovery => t.inspectionStepRecoveryBody,
    InspectionStep.done => '',
  };
}
