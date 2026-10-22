import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../ble/hands_free_controller.dart';
import '../theme.dart';
import 'common.dart';

/// The same setup remains reachable with a disconnected or silent BMS.
class HandsFreeCard extends StatelessWidget {
  const HandsFreeCard({required this.controller, super.key});

  final HandsFreeController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final t = AppL10n.of(context);
      final reason = controller.reason;
      final message = switch (reason) {
        'unsupported_android' ||
        'platform_unavailable' => t.handsFreeUnsupported,
        'bluetooth_permission' => t.handsFreeBluetoothPermission,
        'notification_permission' => t.handsFreeNotificationPermission,
        'precise_location_permission' => t.handsFreePrecisePermission,
        'background_location_permission' => t.handsFreeBackgroundPermission,
        'location_service_disabled' => t.handsFreeLocationOff,
        'bluetooth_off' => t.connectBluetoothOff,
        'association_required' => t.handsFreeAssociationRequired,
        'association_cancelled' => t.handsFreeCancelled,
        'finish_trip_before_setup' => t.handsFreeFinishTrip,
        'device_required' => t.proximityNoDevice,
        'present' => t.proximityFound,
        'running' => t.handsFreeRunning,
        'waiting_for_device' => t.handsFreeWaiting,
        'disabled' => t.handsFreeDisabled,
        _ => t.handsFreeFailed,
      };
      final needsSettings = const {
        'bluetooth_permission',
        'notification_permission',
        'precise_location_permission',
        'background_location_permission',
      }.contains(reason);
      return Section(
        title: t.proximityTitle,
        intro: t.proximityBody,
        children: [
          SwitchListTile(
            value: controller.enabled,
            contentPadding: EdgeInsets.zero,
            title: Text(t.handsFreeEnable),
            subtitle: Text(controller.deviceName ?? t.proximityNoDevice),
            onChanged:
                controller.ready && !controller.busy && controller.hasDevice
                ? controller.setEnabled
                : null,
          ),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (controller.busy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    controller.enabled
                        ? Icons.bluetooth_connected
                        : Icons.info_outline,
                    size: 20,
                    color: AppTheme.textSecondary,
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(controller.busy ? t.handsFreeSettingUp : message),
                ),
              ],
            ),
          ),
          if (needsSettings) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: controller.busy ? null : controller.openSettings,
              icon: const Icon(Icons.settings_outlined),
              label: Text(t.handsFreeOpenSettings),
            ),
          ],
          if (!controller.busy &&
              controller.enabled &&
              reason != 'running' &&
              reason != 'present' &&
              reason != 'waiting_for_device')
            TextButton(
              onPressed: () => controller.setEnabled(true),
              child: Text(t.handsFreeRepair),
            ),
          const SizedBox(height: 10),
          Text(t.proximityLimit, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
        ],
      );
    },
  );
}
