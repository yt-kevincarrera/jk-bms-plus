import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../theme.dart';

/// What to try when the phone's Bluetooth looks stuck, in an order that is
/// also an experiment.
///
/// The steps are not interchangeable. The first reaches only what this app
/// holds; the second kills the process, which also makes Android release
/// every GATT handle the process had; the third restarts Android's Bluetooth
/// for real, which a plain toggle does not do while "Bluetooth scanning" is
/// on; the fourth resets everything. Whichever one works says where the fault
/// was, which is why the card asks the rider to say which it was, and why the
/// app writes down the ones it can see.
class BluetoothStuckCard extends StatelessWidget {
  const BluetoothStuckCard({
    super.key,
    required this.onReset,
    this.resetting = false,
  });

  /// The first step's button.
  final VoidCallback onReset;

  /// True while the reset runs, so the button cannot be pressed twice.
  final bool resetting;

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    const body = TextStyle(
      fontSize: 12.5,
      height: 1.4,
      color: AppTheme.textSecondary,
    );
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.watch.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.watch.withValues(alpha: 0.45)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bluetooth_disabled,
                size: 18,
                color: AppTheme.watch,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.stuckTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.watch,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(t.stuckBody, style: body),
          _Step(
            number: 1,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: resetting ? null : onReset,
                icon: const Icon(Icons.restart_alt, size: 18),
                label: Text(
                  resetting ? t.stuckResetRunning : t.stuckResetButton,
                ),
              ),
            ),
          ),
          _Step(number: 2, child: Text(t.stuckStepForceStop, style: body)),
          _Step(number: 3, child: Text(t.stuckStepScanning, style: body)),
          _Step(number: 4, child: Text(t.stuckStepRestart, style: body)),
          const SizedBox(height: 8),
          Text(
            t.stuckAskWhichStep,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              fontStyle: FontStyle.italic,
              color: AppTheme.textFaint,
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.child});

  final int number;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22,
          child: Text(
            '$number.',
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    ),
  );
}
