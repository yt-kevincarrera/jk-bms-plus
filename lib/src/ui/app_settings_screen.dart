import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../app_settings.dart';
import '../bms_service.dart';
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

  Widget _localeChip(String label, LanguageChoice choice) => ChoiceChip(
        label: Text(label),
        selected: widget.localeController.choice == choice,
        onSelected: (_) async {
          await widget.localeController.set(choice);
          if (mounted) setState(() {});
        },
      );
}
