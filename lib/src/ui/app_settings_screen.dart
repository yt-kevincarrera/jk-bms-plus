import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../app_settings.dart';
import '../bms_service.dart';
import '../metrics/charge_alerts.dart';
import '../metrics/ride_alerts.dart';
import '../update/update_service.dart';
import 'locale_controller.dart';
import 'theme.dart';
import '../license/entitlements.dart';
import 'license_scope.dart';
import 'license_screen.dart';
import 'inspection/certificate_verify_screen.dart';
import 'inspection/inspections_list_screen.dart';
import 'widgets/backup_card.dart';
import 'widgets/pro_gate.dart';
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
    final canWatchCharge = LicenseScope.allows(
      context,
      Feature.backgroundAlerts,
    );

    return Scaffold(
      appBar: AppBar(title: Text(t.appSettingsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            UpdateCard(service: widget.updateService, settings: settings),
            const LicenseCard(),
            PacksCard(service: widget.service),
            Section(
              title: t.inspectionsTitle,
              intro: t.inspectionsIntro,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          InspectionsListScreen(service: widget.service),
                    ),
                  ),
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: Text(t.inspectionsOpen),
                ),
                const SizedBox(height: 8),
                // The buyer's half: check a certificate somebody else's phone
                // produced, with no keys and no network.
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CertificateVerifyScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.verified_outlined, size: 18),
                  label: Text(t.certificateVerifyOpen),
                ),
                const SizedBox(height: 6),
              ],
            ),
            ProGate(
              feature: Feature.backupExportImport,
              child: BackupCard(service: widget.service),
            ),
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
                // Reaching a closed app is the Pro half of the alerts; the
                // ones that fire with the app open stay free. The switch
                // shows off when the licence does not cover it, whatever
                // the stored preference says, because the service is told
                // the same thing at startup.
                SwitchListTile(
                  value: canWatchCharge && settings.chargeWatchEnabled,
                  onChanged: canWatchCharge
                      ? (v) async {
                          await settings.setChargeWatch(v);
                          widget.service.chargeWatchEnabled = v;
                          if (mounted) setState(() {});
                        }
                      : null,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.chargeWatchTitle,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      if (!canWatchCharge) const ProBadge(),
                    ],
                  ),
                  subtitle: Text(
                    canWatchCharge
                        ? t.chargeWatchHint
                        : '${t.chargeWatchProHint}\n${t.chargeWatchHint}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: AppTheme.textFaint,
                    ),
                  ),
                ),
                if (!canWatchCharge)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => openLicenseScreen(context),
                      child: Text(t.licenseOpen),
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
            // Where an alert goes once it has fired. Separate from which
            // alerts exist, above: one is about what is worth saying and this
            // is about whether anybody will hear it.
            Section(
              title: t.alertsNotifyTitle,
              intro: t.alertsNotifyIntro,
              children: [
                SwitchListTile(
                  value: settings.notifyAlerts,
                  onChanged: (v) async {
                    await settings.setNotifyAlerts(v);
                    if (v) {
                      await widget.service.prepareAlertNotifications(
                        channelName: t.alertsNotifyTitle,
                        channelDescription: t.alertsNotifyIntro,
                      );
                    } else {
                      widget.service.notifyAlerts = false;
                    }
                    if (mounted) setState(() {});
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    t.alertsNotifyEnable,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                // Android can refuse, and a rider who believes alerts will
                // arrive when they will not is worse off than one who knows.
                if (settings.notifyAlerts &&
                    !widget.service.alertNotifications.isReady)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      t.alertsNotifyDenied,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.45,
                        color: AppTheme.watch,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 6),
                  child: Text(
                    t.alertsNotifyOneConnection,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.45,
                      color: AppTheme.textFaint,
                    ),
                  ),
                ),
              ],
            ),
            Section(
              title: t.alertsThresholdsTitle,
              intro: t.alertsThresholdsIntro,
              children: [
                _threshold(
                  label: t.alertsDeltaWarn,
                  value: settings.alertDeltaWarn,
                  min: 0.030,
                  max: 0.300,
                  divisions: 27,
                  format: (v) => '${(v * 1000).toStringAsFixed(0)} mV',
                  onChanged: (v) => settings.setAlertThresholds(delta: v),
                ),
                _threshold(
                  label: t.alertsTempWarn,
                  value: settings.alertTempWarn,
                  min: 35,
                  max: 75,
                  divisions: 40,
                  format: (v) => '${v.toStringAsFixed(0)} °C',
                  onChanged: (v) => settings.setAlertThresholds(temperature: v),
                ),
                _threshold(
                  label: t.alertsLowChargeWarn,
                  value: settings.alertLowChargeWarn,
                  min: 5,
                  max: 40,
                  divisions: 35,
                  format: (v) => '${v.toStringAsFixed(0)} %',
                  onChanged: (v) => settings.setAlertThresholds(lowCharge: v),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () async {
                      await settings.resetAlertThresholds();
                      _pushThresholds();
                      if (mounted) setState(() {});
                    },
                    child: Text(t.alertsResetDefaults),
                  ),
                ),
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

  /// One movable threshold. The value shows next to the label, because a
  /// slider with no number on it is a guess.
  Widget _threshold({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String Function(double) format,
    required Future<void> Function(double) onChanged,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5))),
          Text(
            format(value),
            style: const TextStyle(
              fontSize: 13.5,
              fontFeatures: AppTheme.tabular,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
      Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        onChanged: (v) async {
          await onChanged(v);
          _pushThresholds();
          if (mounted) setState(() {});
        },
      ),
    ],
  );

  /// Hands the thresholds to the running detector, so a change takes effect
  /// on the next reading rather than on the next launch.
  void _pushThresholds() {
    final settings = widget.settings;
    widget.service.applySettings(
      haptics: settings.hapticAlerts,
      rawFrames: settings.recordRawFrames,
      chargeTargetSoc: settings.chargeTargetSoc,
      watchCharge: widget.service.chargeWatchEnabled,
      autoTrip: settings.autoTripEnabled,
      watchLink: settings.linkWatchEnabled,
      muted: settings.mutedAlerts,
      alertDeltaWarn: settings.alertDeltaWarn,
      alertTempWarn: settings.alertTempWarn,
      alertLowChargeWarn: settings.alertLowChargeWarn,
    );
  }

  /// Every alert the app can raise, by the name it is stored under.
  List<({String name, String label})> _alertSwitches(AppL10n t) => [
    (
      name: ChargeAlert.targetReached.name,
      label: t.chargeAlertTargetReached('%'),
    ),
    (name: ChargeAlert.chargeComplete.name, label: t.chargeAlertComplete),
    (name: ChargeAlert.hotWhileCharging.name, label: t.chargeAlertHot),
    (name: ChargeAlert.spreadAtTop.name, label: t.chargeAlertSpread),
    (name: RideAlert.bmsFault.name, label: t.alertBmsFault),
    (name: RideAlert.cellSpread.name, label: t.alertCellSpread),
    (name: RideAlert.temperature.name, label: t.alertTemperature),
    (name: RideAlert.lowCharge.name, label: t.alertLowCharge),
    (name: RideAlert.criticalCharge.name, label: t.alertCriticalCharge),
    (name: RideAlert.cellNearCutoff.name, label: t.alertCellNearCutoff),
    (name: RideAlert.nearCurrentLimit.name, label: t.alertNearCurrentLimit),
    (name: BmsService.linkLostAlertKey, label: t.alertLinkLost),
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
