import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../app_settings.dart';
import '../../ble/bms_write_gate.dart';
import '../../bms_service.dart';
import '../../model/jk_settings.dart';
import '../theme.dart';
import 'common.dart';

/// The charge, discharge and balancer switches of a JK, as the settings frame
/// last reported them, and the one place in the app that can change them.
///
/// Each row shows what the BMS said, never what was asked for: a tap does not
/// move the switch, the next settings frame does. With the write permission
/// off the rows are there to read and cannot be touched.
class BmsSwitchesGroup extends StatefulWidget {
  const BmsSwitchesGroup({
    required this.service,
    required this.settings,
    required this.appSettings,
    super.key,
  });

  final BmsService service;
  final JkSettings settings;
  final AppSettings appSettings;

  @override
  State<BmsSwitchesGroup> createState() => _BmsSwitchesGroupState();
}

class _BmsSwitchesGroupState extends State<BmsSwitchesGroup> {
  /// The switch whose write is waiting for the BMS's answer.
  BmsSwitch? _pending;

  static String _action(BmsSwitch target, bool on) =>
      '${target.name}${on ? 'On' : 'Off'}';

  String _label(AppL10n t, BmsSwitch target) => switch (target) {
    BmsSwitch.charge => t.configChargeSwitch,
    BmsSwitch.discharge => t.configDischargeSwitch,
    BmsSwitch.balancer => t.configBalancerSwitch,
  };

  Future<bool> _confirm(AppL10n t, BmsSwitch target, bool on) async {
    final action = _action(target, on);
    // Off is the direction that takes something away, and discharge off
    // takes the bike's power.
    final danger = !on;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceRaised,
        title: Text(t.bmsSwitchConfirmTitle(action)),
        content: Text(
          t.bmsSwitchConfirmBody(action),
          style: const TextStyle(fontSize: 13, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: danger
                ? TextButton.styleFrom(foregroundColor: AppTheme.bad)
                : null,
            child: Text(t.bmsSwitchConfirmAction),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _change(AppL10n t, BmsSwitch target, bool on) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    // Asked first without writing, so a write that would be refused (the
    // bike moving, no recent reading) says so straight away instead of
    // after a confirmation the rider then cannot act on. The service asks
    // the gate again for the write itself, and records the attempt either
    // way.
    final pre = widget.service.checkSwitchWrite(target, on);
    if (pre is WriteGranted && !await _confirm(t, target, on)) return;
    if (!mounted) return;
    setState(() => _pending = target);
    final outcome = await widget.service.setBmsSwitch(target, on);
    if (!mounted) return;
    setState(() => _pending = null);
    final message = switch (outcome.status) {
      SwitchWriteStatus.confirmed => t.bmsSwitchApplied,
      SwitchWriteStatus.unconfirmed => t.bmsSwitchUnconfirmed,
      SwitchWriteStatus.notSent => t.bmsSwitchNotSent,
      SwitchWriteStatus.refused => t.bmsSwitchRefused(
        outcome.refusal?.name ?? 'other',
      ),
    };
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    return ListenableBuilder(
      listenable: widget.appSettings,
      builder: (context, _) {
        final allowed = widget.appSettings.allowBmsWrites;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Caption(t.settingSwitches, color: AppTheme.textFaint),
            ),
            for (final target in BmsSwitch.values)
              SwitchListTile(
                key: ValueKey('bms-switch-${target.name}'),
                value: target.stateIn(widget.settings),
                onChanged: allowed && _pending == null
                    ? (v) => _change(t, target, v)
                    : null,
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _label(t, target),
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: _pending == target
                    ? Text(
                        t.bmsSwitchSending,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.watch,
                        ),
                      )
                    : null,
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                allowed ? t.bmsSwitchesHint : t.bmsSwitchesLocked,
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: AppTheme.textFaint,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
