import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../ble/ble_transport.dart';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../app_settings.dart';
import '../../ble/proximity_watcher.dart';
import '../../data/exporter.dart';
import 'history_tab.dart';
import '../../ble/simulator/simulated_pack.dart';
import '../../bms_service.dart';
import '../../model/bms_snapshot.dart';
import '../../model/jk_device_info.dart';
import '../../model/jk_settings.dart';
import '../../protocol/jk_frame.dart';
import '../../protocol/protocol_variant.dart';
import '../live_console_screen.dart';
import '../locale_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../../update/update_service.dart';

/// Device identity, BMS settings, link quality, language, and the variant
/// override. Where you come when a number on another tab looks wrong.
class SystemTab extends StatefulWidget {
  const SystemTab({
    required this.service,
    required this.snapshot,
    required this.link,
    required this.localeController,
    required this.proximity,
    required this.settings,
    required this.updateService,
    super.key,
  });

  final BmsService service;
  final BmsSnapshot? snapshot;
  final BleLinkState link;
  final LocaleController localeController;
  final ProximityWatcher proximity;
  final AppSettings settings;
  final UpdateService updateService;

  @override
  State<SystemTab> createState() => _SystemTabState();
}

class _SystemTabState extends State<SystemTab> {
  final List<StreamSubscription<Object?>> _subs = [];
  final List<String> _problems = [];
  JkDeviceInfo? _info;
  JkSettings? _settings;
  FrameStats? _stats;

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    _info = s.lastDeviceInfo;
    _settings = s.lastSettings;
    _stats = s.stats;
    _subs.addAll([
      s.deviceInfo.listen((v) => setState(() => _info = v)),
      s.settings.listen((v) => setState(() => _settings = v)),
      s.frameStats.listen((v) => setState(() => _stats = v)),
      s.problems.listen((v) => setState(() {
            _problems.insert(0, v);
            if (_problems.length > 10) _problems.removeLast();
          })),
    ]);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final service = widget.service;
    final info = _info;
    final stats = _stats;

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 28),
      children: [
        if (service.isDemo) _demoSection(t),
        Section(
          title: t.systemDeviceTitle,
          children: info == null
              ? [
                  InfoRow(
                    t.systemDeviceTitle,
                    t.systemDeviceInfoMissing,
                    dim: true,
                    last: true,
                  ),
                ]
              : [
                  InfoRow(t.systemModel, info.model),
                  InfoRow(t.systemHardware, info.hardwareVersion),
                  InfoRow(t.systemSoftware, info.softwareVersion),
                  InfoRow(
                    t.systemSerial,
                    info.serialNumber.isEmpty
                        ? t.notReported
                        : info.serialNumber,
                    dim: info.serialNumber.isEmpty,
                  ),
                  InfoRow(
                    t.systemManufactured,
                    info.manufacturingDate.isEmpty
                        ? t.notReported
                        : info.manufacturingDate,
                    dim: info.manufacturingDate.isEmpty,
                  ),
                  InfoRow(t.systemPowerOnCount, '${info.powerOnCount}'),
                  InfoRow(t.systemUptime, _duration(info.uptimeSeconds)),
                  InfoRow(
                    t.systemPasscode,
                    info.devicePasscode.isEmpty
                        ? t.systemPasscodeEmpty
                        : info.devicePasscode,
                    dim: info.devicePasscode.isEmpty,
                    valueColor:
                        info.devicePasscode.isEmpty ? null : AppTheme.watch,
                    hint: t.systemPasscodeHint,
                    last: true,
                  ),
                ],
        ),
        _variantSection(t),
        Section(
          title: t.systemConnectionTitle,
          trailing: Pill(
            _linkLabel(t, widget.link),
            color: widget.link == BleLinkState.connected
                ? AppTheme.good
                : AppTheme.watch,
          ),
          children: [
            InfoRow(
              t.systemMtu,
              service.negotiatedMtu == null
                  ? t.unknown
                  : t.systemMtuValue(service.negotiatedMtu!),
            ),
            InfoRow(t.systemFramesOk, '${stats?.accepted ?? 0}'),
            InfoRow(
              t.systemFramesBadChecksum,
              '${stats?.badChecksum ?? 0}',
              valueColor:
                  (stats?.badChecksum ?? 0) > 0 ? AppTheme.watch : null,
            ),
            InfoRow(t.systemFramesUnsupported, '${stats?.unsupportedType ?? 0}'),
            InfoRow(
              t.systemAcceptRate,
              '${((stats?.acceptRate ?? 1) * 100).toStringAsFixed(1)} %',
            ),
            InfoRow(
              t.systemBytesReceived,
              '${stats?.bytesReceived ?? 0}',
            ),
            // A diagnosis was made from a backup after the fact, and the
            // next one should not have to be. These three tell apart the
            // two ways a recording gets holes in it: the link going away,
            // and the pack going quiet while the link stays up.
            InfoRow(
              t.systemDrops,
              '${service.linkHealth.drops}',
              valueColor:
                  service.linkHealth.drops > 5 ? AppTheme.watch : null,
            ),
            InfoRow(
              t.systemTimeDisconnected,
              _duration(service.linkHealth.timeDisconnected.inSeconds),
            ),
            InfoRow(
              t.systemNudges,
              '${service.linkHealth.nudges}',
              hint: t.systemNudgesHint,
              last: true,
            ),
          ],
        ),
        if (_settings != null) _bmsSettingsSection(t, _settings!),
        if (service.repository != null)
          StorageSection(repository: service.repository!, t: t),
        _settingsSection(t),
        _proximitySection(t),
        _exportSection(t),
        _languageSection(t),
        if (_problems.isNotEmpty)
          Section(
            title: t.systemNotices,
            accent: AppTheme.watch,
            children: [
              for (final p in _problems)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    p,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.terminal, size: 18),
            label: Text(t.systemRawConsole),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LiveConsoleScreen(
                  service: service,
                  deviceName: info?.model ?? t.consoleTitle,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Text(
            t.systemReadOnlyNote,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: AppTheme.textFaint,
            ),
          ),
        ),
      ],
    );
  }

  Widget _demoSection(AppL10n t) {
    final service = widget.service;
    return Section(
      title: t.demoTitle,
      accent: AppTheme.cool,
      intro: t.demoExplanation,
      children: [
        for (final scenario in DemoScenario.values)
          RadioListTile<DemoScenario>(
            value: scenario,
            // ignore: deprecated_member_use
            groupValue: service.demoScenario,
            // ignore: deprecated_member_use
            onChanged: (v) => setState(() => service.demoScenario = v),
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: EdgeInsets.zero,
            activeColor: AppTheme.cool,
            title: Text(
              _scenarioLabel(t, scenario),
              style: const TextStyle(fontSize: 14),
            ),
            subtitle: Text(
              _scenarioDescription(t, scenario),
              style: const TextStyle(fontSize: 11.5, color: AppTheme.textFaint),
            ),
          ),
        const SizedBox(height: 10),
        // Getting the simulated pack to a state worth looking at, without
        // waiting for it. Demo mode exists so the screens can be judged with
        // no hardware, and a capacity test that needs a real afternoon of
        // discharge defeats that entirely.
        Caption(t.demoSetCharge, color: AppTheme.textFaint),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => _setDemoCharge(1.0),
              child: Text(t.demoFull),
            ),
            OutlinedButton(
              onPressed: () => _setDemoCharge(0.10),
              child: Text(t.demoEmpty),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InfoRow(
          t.demoSpeed,
          _demoSpeed == 1
              ? t.demoSpeedNormal
              : '${_demoSpeed.toStringAsFixed(0)}x',
          hint: t.demoSpeedHint,
        ),
        Slider(
          value: _demoSpeed,
          min: 1,
          max: 300,
          divisions: 299,
          label: '${_demoSpeed.toStringAsFixed(0)}x',
          onChanged: (v) {
            setState(() => _demoSpeed = v.roundToDouble());
            widget.service.demoTimeScale = _demoSpeed;
          },
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  double _demoSpeed = 1;

  void _setDemoCharge(double fraction) {
    widget.service.setDemoCharge(fraction);
    setState(() {});
  }

  Widget _variantSection(AppL10n t) {
    final service = widget.service;
    final info = _info;
    return Section(
      title: t.systemVariantTitle,
      children: [
        InfoRow(
          t.systemVariantInUse,
          service.variant?.name ?? t.systemVariantUndecided,
          valueColor: service.variant == null ? AppTheme.watch : null,
          hint: info == null ? null : _variantReason(t, info.detection),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 10),
          child: Text(
            t.systemVariantWarning,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: AppTheme.textFaint,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text(t.systemVariantAuto),
              selected: service.variant == info?.variant,
              onSelected: (_) => setState(() => service.overrideVariant(null)),
            ),
            for (final v in [
              JkProtocolVariant.jk02_24s,
              JkProtocolVariant.jk02_32s,
            ])
              ChoiceChip(
                label: Text(v.name),
                selected: service.variant == v && v != info?.variant,
                onSelected: (_) => setState(() => service.overrideVariant(v)),
              ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _proximitySection(AppL10n t) {
    final watcher = widget.proximity;
    return Section(
      title: t.proximityTitle,
      accent: watcher.isEnabled ? AppTheme.good : AppTheme.textFaint,
      intro: t.proximityBody,
      trailing: Switch(
        value: watcher.isEnabled,
        onChanged: watcher.hasDevice
            ? (v) async {
                await watcher.setEnabled(v);
                if (mounted) setState(() {});
              }
            : null,
      ),
      children: [
        InfoRow(
          t.proximityRemembered,
          watcher.deviceName ?? '--',
          dim: !watcher.hasDevice,
          hint: watcher.hasDevice ? null : t.proximityNoDevice,
        ),
        InfoRow(
          t.systemConnectionTitle,
          watcher.isScanning ? t.proximityScanning : t.linkIdle,
          dim: !watcher.isScanning,
          hint: t.proximityLimit,
          last: true,
        ),
      ],
    );
  }



  /// Stores what this pack was sold as.
  ///
  /// Always against a specific pack. There is no app-wide version of this
  /// figure any more: one number shared by two batteries has to be wrong about
  /// at least one of them.
  Future<void> _setCatalogue(String deviceId, double ah) async {
    await widget.service.repository?.setDeviceCatalogue(deviceId, ah);
    await widget.service.refreshActiveDevice();
    widget.service.catalogueSetByUser = true;
    if (mounted) setState(() {});
  }
  Widget _settingsSection(AppL10n t) {
    final configured = widget.service.configuredCapacityAh;
    // The connected pack's own figure, or null when nobody has stated it.
    // There is deliberately no fallback: an unstated capacity that quietly
    // became 45 Ah is what made a 35 Ah battery report health against a number
    // this app invented.
    final catalogue = widget.service.catalogueCapacityAh;
    final device = widget.service.activeDevice;
    // Adopted from the pack rather than stated by the rider. Shown, not hidden:
    // the figures work either way, but only one of the two is a claim about
    // what was sold.
    final fromBms = device?.catalogueFromBms ?? false;
    // Half an amp-hour apart is rounding; more than that is two different
    // claims about the same pack.
    final mismatch = configured != null &&
        catalogue != null &&
        (configured - catalogue).abs() > 0.5;

    // Where the slider starts when there is nothing stated yet. A starting
    // position, not a stored value: nothing is written until it is moved.
    final sliderValue = catalogue ?? configured ?? 45.0;

    return Section(
      title: t.settingsSectionPack,
      children: [
        InfoRow(
          t.settingsCatalogue,
          catalogue == null
              ? t.catalogueUnset
              : fromBms
                  ? '${catalogue.toStringAsFixed(1)} Ah  ·  ${t.catalogueFromBmsTag}'
                  : '${catalogue.toStringAsFixed(1)} Ah',
          dim: catalogue == null,
          valueColor: catalogue == null
              ? AppTheme.watch
              : fromBms
                  ? AppTheme.cool
                  : null,
          hint: device == null
              ? t.settingsCatalogueHint
              : t.settingsCatalogueForPack(
                  device.name.isEmpty ? device.id : device.name,
                ),
        ),
        if (catalogue == null)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: Text(
              t.catalogueUnsetHint,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: AppTheme.watch,
              ),
            ),
          ),
        // What the BMS is set to is a different claim by a different person,
        // so it sits next to the catalogue figure instead of replacing it.
        if (configured != null)
          InfoRow(
            t.settingsBmsConfigured,
            '${configured.toStringAsFixed(1)} Ah',
            valueColor: mismatch ? AppTheme.watch : null,
          ),
        if (mismatch)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: Text(
              t.settingsCapacityMismatch(
                configured.toStringAsFixed(1),
                catalogue.toStringAsFixed(1),
              ),
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: AppTheme.watch,
              ),
            ),
          ),
        // A one-tap way to adopt the BMS's own configured figure, offered only
        // while nothing has been stated. It is a better starting point than a
        // guess, and still the rider's decision rather than the app's.
        if (fromBms && catalogue != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: Text(
              t.catalogueFromBmsHint,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: AppTheme.textFaint,
              ),
            ),
          ),
        // One tap to say the adopted figure is also what it was sold as, which
        // turns it from borrowed into stated and stops it being re-adopted.
        if (fromBms && catalogue != null && device != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: OutlinedButton(
              onPressed: () => _setCatalogue(device.id, catalogue),
              child: Text(t.catalogueConfirm),
            ),
          ),
        if (catalogue == null && configured != null && device != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: OutlinedButton(
              onPressed: () => _setCatalogue(device.id, configured),
              child: Text(t.catalogueUseBms(configured.toStringAsFixed(0))),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: Slider(
                  value: sliderValue.clamp(5, 200),
                  min: 5,
                  max: 200,
                  divisions: 195,
                  label: sliderValue.toStringAsFixed(0),
                  // Disabled with no pack connected: this figure describes a
                  // specific battery, and there is nowhere to put it otherwise.
                  onChanged: device == null
                      ? null
                      : (v) => _setCatalogue(device.id, v.roundToDouble()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _exportSection(AppL10n t) {
    final repo = widget.service.repository;
    if (repo == null) return const SizedBox.shrink();
    final exporter = BmsExporter(repo);

    Future<void> run(Future<File> Function() job) async {
      try {
        final file = await job();
        if (!mounted) return;
        // Exported files land in the app's private directory, which is a place
        // nobody can reach from a file manager. Handing them straight to the
        // share sheet is what actually makes the data portable.
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            fileNameOverrides: [p.basename(file.path)],
          ),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.exportDone(p.basename(file.path)))),
        );
      } on Exception catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.exportFailed)),
        );
      }
    }

    final device = widget.service.activeDeviceId;
    if (device == null) {
      return Section(
        title: t.exportTitle,
        intro: t.exportIntro,
        children: [
          InfoRow(t.exportTitle, t.exportNoPack, dim: true, last: true),
        ],
      );
    }

    return Section(
      title: t.exportTitle,
      intro: t.exportIntro,
      children: [
        TextButton.icon(
          onPressed: () => run(() => exporter.exportTrips(device)),
          icon: const Icon(Icons.table_chart_outlined, size: 18),
          label: Text(t.exportTrips),
        ),
        TextButton.icon(
          onPressed: () => run(() => exporter.exportReadings(device)),
          icon: const Icon(Icons.show_chart, size: 18),
          label: Text(t.exportReadings),
        ),
        TextButton.icon(
          onPressed: () => run(() => exporter.exportRawFrames(device)),
          icon: const Icon(Icons.data_object, size: 18),
          label: Text(t.exportFrames),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
  Widget _languageSection(AppL10n t) {
    final controller = widget.localeController;
    return Section(
      title: t.systemLanguageTitle,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(
            spacing: 8,
            children: [
              for (final choice in LanguageChoice.values)
                ChoiceChip(
                  label: Text(_languageLabel(t, choice)),
                  selected: controller.choice == choice,
                  onSelected: (_) => controller.set(choice),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bmsSettingsSection(AppL10n t, JkSettings s) {
    return Section(
      title: t.systemSettingsTitle,
      children: [
        InfoRow(t.settingCellCount, '${s.cellCount}'),
        InfoRow(
          t.settingNominalCapacity,
          '${s.nominalCapacityAh.toStringAsFixed(1)} Ah',
        ),
        InfoRow(t.settingCellOvp, '${s.cellOvp.toStringAsFixed(3)} V'),
        InfoRow(
          t.settingCellOvpRecovery,
          '${s.cellOvpRecovery.toStringAsFixed(3)} V',
        ),
        InfoRow(t.settingCellUvp, '${s.cellUvp.toStringAsFixed(3)} V'),
        InfoRow(
          t.settingCellUvpRecovery,
          '${s.cellUvpRecovery.toStringAsFixed(3)} V',
        ),
        InfoRow(t.settingPowerOff, '${s.powerOffVoltage.toStringAsFixed(3)} V'),
        InfoRow(
          t.settingMaxCharge,
          '${s.maxChargeCurrent.toStringAsFixed(1)} A',
        ),
        InfoRow(
          t.settingMaxDischarge,
          '${s.maxDischargeCurrent.toStringAsFixed(1)} A',
        ),
        InfoRow(
          t.settingMaxBalance,
          '${s.maxBalanceCurrent.toStringAsFixed(2)} A',
        ),
        InfoRow(
          t.settingBalanceStart,
          '${s.balanceStartVoltage.toStringAsFixed(3)} V',
        ),
        InfoRow(
          t.settingBalanceTrigger,
          '${(s.balanceTriggerVoltage * 1000).toStringAsFixed(0)} mV',
        ),
        InfoRow(t.settingChargeOtp, '${s.chargeOtp.toStringAsFixed(1)} °C'),
        InfoRow(
          t.settingDischargeOtp,
          '${s.dischargeOtp.toStringAsFixed(1)} °C',
        ),
        InfoRow(t.settingChargeUtp, '${s.chargeUtp.toStringAsFixed(1)} °C'),
        InfoRow(t.settingMosfetOtp, '${s.mosfetOtp.toStringAsFixed(1)} °C'),
        InfoRow(
          t.settingSwitches,
          '${s.chargeSwitchOn ? "charge" : "-"} / '
          '${s.dischargeSwitchOn ? "discharge" : "-"} / '
          '${s.balancerSwitchOn ? "balancer" : "-"}',
          last: true,
        ),
      ],
    );
  }

  String _languageLabel(AppL10n t, LanguageChoice c) => switch (c) {
        LanguageChoice.spanish => t.systemLanguageSpanish,
        LanguageChoice.english => t.systemLanguageEnglish,
        LanguageChoice.system => t.systemLanguageSystem,
      };

  String _scenarioLabel(AppL10n t, DemoScenario s) => switch (s) {
        DemoScenario.riding => t.demoScenarioRiding,
        DemoScenario.charging => t.demoScenarioCharging,
        DemoScenario.idle => t.demoScenarioIdle,
        DemoScenario.weakCell => t.demoScenarioWeakCell,
      };

  String _scenarioDescription(AppL10n t, DemoScenario s) => switch (s) {
        DemoScenario.riding => t.demoScenarioRidingDesc,
        DemoScenario.charging => t.demoScenarioChargingDesc,
        DemoScenario.idle => t.demoScenarioIdleDesc,
        DemoScenario.weakCell => t.demoScenarioWeakCellDesc,
      };

  String _linkLabel(AppL10n t, BleLinkState state) => switch (state) {
        BleLinkState.idle => t.linkIdle,
        BleLinkState.scanning => t.linkScanning,
        BleLinkState.connecting => t.linkConnecting,
        BleLinkState.negotiating => t.linkNegotiating,
        BleLinkState.connected => t.linkConnected,
        BleLinkState.reconnecting => t.linkReconnecting,
        BleLinkState.failed => t.linkFailed,
      };

  /// The detector reports a code, not a sentence, so the explanation can be
  /// written in the reader's language rather than baked into a protocol class.
  String _variantReason(AppL10n t, VariantDetection d) => switch (d.reason) {
        VariantReason.unreadableVersion =>
          t.variantReasonUnreadable(d.softwareVersion, d.model),
        VariantReason.modernFirmware =>
          t.variantReasonModern(d.softwareVersion, d.majorVersion ?? 0),
        VariantReason.legacyFirmware =>
          t.variantReasonLegacy(d.softwareVersion, d.majorVersion ?? 0),
      };

  static String _duration(int seconds) {
    final d = Duration(seconds: seconds);
    if (d.inDays > 0) return '${d.inDays} d ${d.inHours % 24} h';
    if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes % 60} min';
    return '${d.inMinutes} min';
  }
}
