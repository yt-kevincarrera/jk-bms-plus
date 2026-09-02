import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../app_settings.dart';
import '../bms_service.dart';
import '../metrics/charge_alerts.dart';
import '../metrics/ride_alerts.dart';
import '../update/update_service.dart';
import 'locale_controller.dart';
import 'theme.dart';
import 'widgets/backup_card.dart';
import 'widgets/packs_card.dart';
import 'widgets/common.dart';
import 'widgets/update_card.dart';

/// Settings that belong to the app rather than to any one battery.
///
/// Reachable without a connection, which is the whole point: checking for a
/// new version, switching language or looking over the stored packs are things
/// you do sitting down, not straddling the bike with the BMS in range. They
/// used to live inside the System tab, which only existed after connecting.
///
/// Updates come first because it is the one thing here anybody opens this
/// screen deliberately to do.
class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({
    required this.service,
    required this.settings,
    required this.localeController,
    required this.updateService,
    super.key,
  });

  final BmsService service;
  final AppSettings settings;
  final LocaleController localeController;
  final UpdateService updateService;

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final settings = widget.settings;

    return Scaffold(
      appBar: AppBar(title: Text(t.appSettingsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            UpdateCard(
              service: widget.updateService,
              settings: settings,
            ),
            PacksCard(service: widget.service),
            BackupCard(service: widget.service),
            Section(
              title: t.chargeAlertsTitle,
              intro: t.chargeAlertsIntro,
              children: [
                InfoRow(
                  t.chargeTarget,
                  settings.chargeTargetSoc == null
                      ? t.chargeTargetOff
                      : '${settings.chargeTargetSoc!.toStringAsFixed(0)} %',
                  dim: settings.chargeTargetSoc == null,
                ),
                Slider(
                  // 50 is the off position rather than a level anybody wants
                  // announced: below that the alert would fire on the way up
                  // from every ride.
                  value: (settings.chargeTargetSoc ?? 50).clamp(50, 100),
                  min: 50,
                  max: 100,
                  divisions: 50,
                  label: settings.chargeTargetSoc == null
                      ? t.chargeTargetOff
                      : settings.chargeTargetSoc!.toStringAsFixed(0),
                  onChanged: (v) async {
                    final soc = v.roundToDouble();
                    await settings.setChargeTarget(soc <= 50 ? null : soc);
                    widget.service.chargeAlerts.targetSoc =
                        settings.chargeTargetSoc;
                    if (mounted) setState(() {});
                  },
                ),
                SwitchListTile(
                  value: settings.chargeWatchEnabled,
                  onChanged: (v) async {
                    await settings.setChargeWatch(v);
                    widget.service.chargeWatchEnabled = v;
                    if (mounted) setState(() {});
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    t.chargeWatchTitle,
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    t.chargeWatchHint,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: AppTheme.textFaint,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
            // Rides had ended up inside the charging section, along with the
            // link and the screen. Four of that section's five controls had
            // nothing to do with charging: it had quietly become the place new
            // settings went, which is how a rider stops being able to find
            // anything.
            Section(
              title: t.settingsSectionRides,
              children: [
                SwitchListTile(
                  value: settings.autoTripEnabled,
                  onChanged: (v) async {
                    await settings.setAutoTrip(v);
                    widget.service.autoTripEnabled = v;
                    if (mounted) setState(() {});
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    t.autoTripTitle,
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    t.autoTripHint,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: AppTheme.textFaint,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
            Section(
              title: t.settingsSectionLink,
              intro: t.settingsSectionLinkHint,
              children: [
                SwitchListTile(
                  value: settings.linkWatchEnabled,
                  onChanged: (v) async {
                    await settings.setLinkWatch(v);
                    widget.service.linkWatchEnabled = v;
                    if (mounted) setState(() {});
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    t.linkWatchTitle,
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    t.linkWatchHint,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: AppTheme.textFaint,
                    ),
                  ),
                ),
                // Three positions rather than a switch: "never" and "always"
                // are both real answers, and the middle one is the reason the
                // wakelock existed in the first place.
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.screenAwakeTitle,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t.screenAwakeHint,
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: AppTheme.textFaint,
                        ),
                      ),
                      if (settings.linkWatchEnabled) ...[
                        const SizedBox(height: 3),
                        Text(
                          t.screenAwakeReason,
                          style: const TextStyle(
                            fontSize: 11.5,
                            height: 1.4,
                            color: AppTheme.good,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      SegmentedButton<ScreenAwake>(
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                        segments: [
                          ButtonSegment(
                            value: ScreenAwake.never,
                            label: Text(
                              t.screenAwakeNever,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          ButtonSegment(
                            value: ScreenAwake.whileRiding,
                            label: Text(
                              t.screenAwakeRiding,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          ButtonSegment(
                            value: ScreenAwake.always,
                            label: Text(
                              t.screenAwakeAlways,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                        selected: {settings.screenAwake},
                        onSelectionChanged: (picked) async {
                          await settings.setScreenAwake(picked.first);
                          if (mounted) setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
            // Every alert, each with its own switch, in one place that is
            // easy to find. The alternative people reach for when they cannot
            // find this is switching the whole app's notifications off.
            Section(
              title: t.alertsSectionTitle,
              intro: t.alertsSectionHint,
              children: [
                for (final a in _alertSwitches(t))
                  SwitchListTile(
                    value: !settings.isMuted(a.name),
                    onChanged: (on) async {
                      await settings.setAlertMuted(a.name, !on);
                      widget.service.mutedAlerts = settings.mutedAlerts;
                      if (mounted) setState(() {});
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      a.label,
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  ),
                const SizedBox(height: 4),
              ],
            ),
            Section(
              title: t.settingsSectionApp,
              children: [
                SwitchListTile(
                  value: settings.hapticAlerts,
                  onChanged: (v) async {
                    await settings.setHapticAlerts(v);
                    widget.service.hapticAlerts = v;
                    if (mounted) setState(() {});
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    t.settingsHaptics,
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    t.settingsHapticsHint,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textFaint,
                    ),
                  ),
                ),
                SwitchListTile(
                  value: settings.recordRawFrames,
                  onChanged: (v) async {
                    await settings.setRecordRawFrames(v);
                    widget.service.repository?.recordRawFrames = v;
                    if (mounted) setState(() {});
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    t.settingsRawFrames,
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    t.settingsRawFramesHint,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textFaint,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Caption(t.systemLanguageTitle, color: AppTheme.textFaint),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    _localeChip(
                      t.systemLanguageSpanish,
                      LanguageChoice.spanish,
                    ),
                    _localeChip(
                      t.systemLanguageEnglish,
                      LanguageChoice.english,
                    ),
                    _localeChip(t.systemLanguageSystem, LanguageChoice.system),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Every alert the app can raise, by the name it is stored under.
  List<({String name, String label})> _alertSwitches(AppL10n t) => [
        (name: ChargeAlert.targetReached.name, label: t.chargeAlertTargetReached('%')),
        (name: ChargeAlert.chargeComplete.name, label: t.chargeAlertComplete),
        (name: ChargeAlert.hotWhileCharging.name, label: t.chargeAlertHot),
        (name: ChargeAlert.spreadAtTop.name, label: t.chargeAlertSpread),
        (name: RideAlert.bmsFault.name, label: t.alertBmsFault),
        (name: RideAlert.cellSpread.name, label: t.alertCellSpread),
        (name: RideAlert.temperature.name, label: t.alertTemperature),
        (name: RideAlert.lowCharge.name, label: t.alertLowCharge),
        (name: RideAlert.criticalCharge.name, label: t.alertCriticalCharge),
        (name: RideAlert.cellNearCutoff.name, label: t.alertCellNearCutoff),
      ];

  Widget _localeChip(String label, LanguageChoice choice) => ChoiceChip(
        label: Text(label),
        selected: widget.localeController.choice == choice,
        onSelected: (_) async {
          await widget.localeController.set(choice);
          if (mounted) setState(() {});
        },
      );
}
