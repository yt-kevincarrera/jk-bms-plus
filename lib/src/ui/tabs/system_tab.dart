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
import '../../model/bms_device_info.dart';
import '../../model/jk_settings.dart';
import '../../protocol/ant_constants.dart';
import '../../protocol/ant_parser.dart';
import '../../protocol/bms_brand.dart';
import '../../protocol/jk_frame.dart';
import '../../protocol/protocol_variant.dart';
import '../live_console_screen.dart';
import '../../license/entitlements.dart';
import '../pack/config_audit_screen.dart';
import '../pack/pack_profile_card.dart';
import '../bms_code_labels.dart';
import '../fault_history_screen.dart';
import '../link_events_screen.dart';
import '../../ble/bms_write_gate.dart';
import '../widgets/bms_switches.dart';
import '../widgets/pro_gate.dart';
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
  /// How far back the readings and frames exports reach. It used to be a
  /// week of readings and a day of frames, fixed, and a problem from last
  /// month could not be exported at all.
  Duration _exportRange = const Duration(days: 7);

  final List<StreamSubscription<Object?>> _subs = [];
  final List<String> _problems = [];
  BmsDeviceInfo? _info;
  JkSettings? _settings;
  FrameStats? _stats;
  AntStatus? _antStatus;

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    _info = s.lastDeviceInfo;
    _settings = s.lastSettings;
    _stats = s.stats;
    _antStatus = s.lastAntStatus;
    _subs.addAll([
      s.deviceInfo.listen((v) => setState(() => _info = v)),
      s.settings.listen((v) => setState(() => _settings = v)),
      s.frameStats.listen((v) => setState(() => _stats = v)),
      s.antStatus.listen((v) => setState(() => _antStatus = v)),
      s.problems.listen(
        (v) => setState(() {
          _problems.insert(0, v);
          if (_problems.length > 10) _problems.removeLast();
        }),
      ),
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
        PackProfileCard(service: service),
        Section(
          title: t.systemDeviceTitle,
          children: [
            // First, because it decides how to read every row below it: a
            // pack's own reported fields only mean what they say once you
            // know which BMS filled them in.
            InfoRow(
              t.systemBrand,
              service.brand.name.toUpperCase(),
              last: info == null,
            ),
            ...info == null
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
                    // JK is the only brand that hands out a device passcode,
                    // a power-on count and an uptime, so this is the last row
                    // for anything else.
                    last: info.jk == null,
                  ),
                  // Everything below only JK reports: manufacturing date,
                  // power-on count, uptime and the device's own passcode.
                  // Hidden rather than shown blank for a brand that has none.
                  if (info.jk case final jk?) ...[
                    InfoRow(
                      t.systemManufactured,
                      jk.manufacturingDate.isEmpty
                          ? t.notReported
                          : jk.manufacturingDate,
                      dim: jk.manufacturingDate.isEmpty,
                    ),
                    InfoRow(t.systemPowerOnCount, '${jk.powerOnCount}'),
                    InfoRow(t.systemUptime, _duration(jk.uptimeSeconds)),
                    InfoRow(
                      t.systemPasscode,
                      jk.devicePasscode.isEmpty
                          ? t.systemPasscodeEmpty
                          : jk.devicePasscode,
                      dim: jk.devicePasscode.isEmpty,
                      valueColor: jk.devicePasscode.isEmpty
                          ? null
                          : AppTheme.watch,
                      hint: t.systemPasscodeHint,
                    ),
                    // The settings passcode travels in the same frame, in
                    // the same clear text. It was decoded and never shown,
                    // which only meant the rider could not see what any
                    // Bluetooth client nearby can.
                    InfoRow(
                      t.systemSetupPasscode,
                      jk.setupPasscode.isEmpty
                          ? t.systemPasscodeEmpty
                          : jk.setupPasscode,
                      dim: jk.setupPasscode.isEmpty,
                      valueColor: jk.setupPasscode.isEmpty
                          ? null
                          : AppTheme.watch,
                      last: true,
                    ),
                  ],
                ],
          ],
        ),
        // Variant detection is a JK concept: ANT has no framing to guess.
        if (service.brand == BmsBrand.jk) _variantSection(t),
        if (_antStatus case final st?) _antStatusSection(t, st),
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
            // The frame counters restart on every connect now and the three
            // link-health rows below do not, so the section says which is
            // which rather than leaving two periods side by side unmarked.
            InfoRow(
              t.systemFramesOk,
              '${stats?.accepted ?? 0}',
              hint: t.systemCountersThisConnection,
            ),
            InfoRow(
              t.systemFramesBadChecksum,
              '${stats?.badChecksum ?? 0}',
              valueColor: (stats?.badChecksum ?? 0) > 0 ? AppTheme.watch : null,
            ),
            InfoRow(
              t.systemFramesUnsupported,
              '${stats?.unsupportedType ?? 0}',
            ),
            InfoRow(
              t.systemAcceptRate,
              '${((stats?.acceptRate ?? 1) * 100).toStringAsFixed(1)} %',
            ),
            InfoRow(t.systemBytesReceived, '${stats?.bytesReceived ?? 0}'),
            // A diagnosis was made from a backup after the fact, and the
            // next one should not have to be. These three tell apart the
            // two ways a recording gets holes in it: the link going away,
            // and the pack going quiet while the link stays up.
            InfoRow(
              t.systemDrops,
              '${service.linkHealth.drops}',
              valueColor: service.linkHealth.drops > 5 ? AppTheme.watch : null,
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
        if (widget.snapshot case final snap?) _bmsStateSection(t, snap),
        if (_settings != null)
          _bmsSettingsSection(t, _settings!)
        else if (service.brand == BmsBrand.ant)
          Section(
            title: t.systemSettingsTitle,
            children: [
              InfoRow(t.systemSettingsTitle, t.settingsNotExposed, dim: true, last: true),
            ],
          ),
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
        // What the BMS raised on this pack, from the stored readings. The
        // live tabs only ever show a fault while it is up.
        if (service.repository case final repo?)
          if (service.activeDeviceId case final id?)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.history, size: 18),
                label: Text(t.faultHistoryTitle),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FaultHistoryScreen(
                      repository: repo,
                      deviceId: id,
                      packName: _packName(id),
                    ),
                  ),
                ),
              ),
            ),
        // The app's own record of what it decided about the link and the
        // rides, which used to be readable only inside a backup file.
        if (service.repository case final repo?)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.list_alt, size: 18),
              label: Text(t.linkEventsTitle),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LinkEventsScreen(
                    repository: repo,
                    deviceId: service.activeDeviceId,
                  ),
                ),
              ),
            ),
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
        // Read-only again (bmsWritesShipped is false), whatever the
        // preference stored by 2.29 says, so the note does not look at it.
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

  /// The connected pack as the rider named it, or its address.
  String _packName(String id) {
    final name = widget.service.activeDevice?.name ?? '';
    return name.isEmpty ? id : name;
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
          hint: info?.jk == null ? null : _variantReason(t, info!.jk!.detection),
        ),
        if (service.variantProved)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              service.variantCorrections > 0
                  ? t.systemVariantCorrected
                  : t.systemVariantProved,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: AppTheme.good,
              ),
            ),
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

  /// What ANT reports that JK does not: MOSFET and balancer state in the
  /// pack's own vocabulary, and the balancer's temperature. Rebuilt from
  /// every plausible status, the same ones the readings come from: a status
  /// held back as implausible never reaches it, so it cannot contradict the
  /// numbers shown beside it.
  Widget _antStatusSection(AppL10n t, AntStatus st) => Section(
    title: t.antStatusTitle,
    children: [
      InfoRow(
        t.antBatteryState,
        _antCode(
          t,
          antBatteryStateText,
          t.antBatteryStateCode,
          st.batteryState,
        ),
      ),
      InfoRow(
        t.antChargeMosfet,
        _antCode(
          t,
          antChargeMosfetText,
          t.antChargeMosfetCode,
          st.chargeMosfetCode,
        ),
      ),
      InfoRow(
        t.antDischargeMosfet,
        _antCode(
          t,
          antDischargeMosfetText,
          t.antDischargeMosfetCode,
          st.dischargeMosfetCode,
        ),
      ),
      InfoRow(
        t.antBalancer,
        _antCode(t, antBalancerText, t.antBalancerCode, st.balancerCode),
      ),
      InfoRow(
        t.antBalancerTemp,
        '${st.balancerTemp.toStringAsFixed(0)} °C',
        last: true,
      ),
    ],
  );

  /// An ANT state code in the rider's language. The English table stays the
  /// authority on which codes exist, so the logs and this screen agree on
  /// where the known codes end; past that, the code itself is shown.
  static String _antCode(
    AppL10n t,
    List<String> table,
    String Function(String code) text,
    int code,
  ) => code < table.length
      ? text('$code')
      : t.antUnknownCode(code.toRadixString(16).padLeft(2, '0'));

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
    final mismatch =
        configured != null &&
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
        final result = await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            fileNameOverrides: [p.basename(file.path)],
          ),
        );
        if (!mounted) return;
        // What happened to it, as far as Android says. It used to say "saved
        // in" a path nobody can open, whether or not anything was shared.
        final message = switch (result.status) {
          ShareResultStatus.success => t.exportShared,
          ShareResultStatus.dismissed => null,
          ShareResultStatus.unavailable => t.exportDone(p.basename(file.path)),
        };
        if (message == null) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      } on Exception catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.exportFailed)));
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
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            t.exportRange,
            style: const TextStyle(fontSize: 12, color: AppTheme.textFaint),
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final (days, label) in [
              (1, t.exportRangeDay),
              (7, t.exportRangeWeek),
              (30, t.exportRangeMonth),
              (36500, t.exportRangeAll),
            ])
              ChoiceChip(
                label: Text(label),
                selected: _exportRange.inDays == days,
                onSelected: (_) =>
                    setState(() => _exportRange = Duration(days: days)),
              ),
          ],
        ),
        TextButton.icon(
          onPressed: () => run(
            () => exporter.exportReadings(device, since: _exportRange),
          ),
          icon: const Icon(Icons.show_chart, size: 18),
          label: Text(t.exportReadings),
        ),
        TextButton.icon(
          onPressed: () => run(
            () => exporter.exportRawFrames(device, since: _exportRange),
          ),
          icon: const Icon(Icons.data_object, size: 18),
          label: Text(t.exportFrames),
        ),
        Text(
          t.exportRangeNote,
          style: const TextStyle(
            fontSize: 11,
            height: 1.4,
            color: AppTheme.textFaint,
          ),
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
        // The write controls exist only in a build that ships writes; this
        // one does not (bmsWritesShipped), so the three switches are plain
        // rows further down, in their groups. The brand check stays so an
        // ANT could never be offered a write, whatever changes around it.
        if (bmsWritesShipped && widget.service.brand == BmsBrand.jk)
          BmsSwitchesGroup(
            service: widget.service,
            settings: s,
            appSettings: widget.settings,
          ),
        // The settings themselves are below; this reads them against what
        // the declared chemistry can take. Read only: the audit never writes.
        ProGate(
          feature: Feature.configAudit,
          compact: true,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ConfigAuditScreen(service: widget.service),
                ),
              ),
              icon: const Icon(Icons.rule, size: 18),
              label: Text(t.configAuditOpen),
            ),
          ),
        ),
        // Grouped by what each figure protects, because a flat list of thirty
        // read as thirty unrelated numbers, and half of what the frame
        // carries (every delay, every recovery, the short-circuit timing,
        // the lead resistances) was decoded and never shown at all.
        ..._settingsGroup(t.settingsGroupCell, [
          InfoRow(t.settingCellOvp, _v(s.cellOvp)),
          InfoRow(t.settingCellOvpRecovery, _v(s.cellOvpRecovery)),
          InfoRow(t.settingCellUvp, _v(s.cellUvp)),
          InfoRow(t.settingCellUvpRecovery, _v(s.cellUvpRecovery)),
          InfoRow(t.settingPowerOff, _v(s.powerOffVoltage)),
          InfoRow(t.settingSmartSleep, _v(s.smartSleepVoltage), last: true),
        ]),
        ..._settingsGroup(t.settingsGroupCurrent, [
          InfoRow(
            t.settingMaxCharge,
            '${s.maxChargeCurrent.toStringAsFixed(1)} A',
          ),
          InfoRow(t.settingChargeOcpDelay, '${s.chargeOcpDelaySeconds} s'),
          InfoRow(
            t.settingChargeOcpRecovery,
            '${s.chargeOcpRecoverySeconds} s',
          ),
          InfoRow(
            t.settingMaxDischarge,
            '${s.maxDischargeCurrent.toStringAsFixed(1)} A',
          ),
          InfoRow(
            t.settingDischargeOcpDelay,
            '${s.dischargeOcpDelaySeconds} s',
          ),
          InfoRow(
            t.settingDischargeOcpRecovery,
            '${s.dischargeOcpRecoverySeconds} s',
          ),
          // Microseconds on the wire. The BMS cuts a short circuit in a few
          // hundred of them, and rounding that to "0 s" would read as no
          // delay at all.
          InfoRow(t.settingScpDelay, '${s.scpDelayMicroseconds} µs'),
          InfoRow(
            t.settingScpRecovery,
            '${s.scpRecoverySeconds} s',
            last: true,
          ),
        ]),
        ..._settingsGroup(t.settingsGroupTemperature, [
          InfoRow(t.settingChargeOtp, _c(s.chargeOtp)),
          InfoRow(t.settingChargeOtpRecovery, _c(s.chargeOtpRecovery)),
          InfoRow(t.settingDischargeOtp, _c(s.dischargeOtp)),
          InfoRow(t.settingDischargeOtpRecovery, _c(s.dischargeOtpRecovery)),
          InfoRow(t.settingChargeUtp, _c(s.chargeUtp)),
          InfoRow(t.settingChargeUtpRecovery, _c(s.chargeUtpRecovery)),
          InfoRow(t.settingMosfetOtp, _c(s.mosfetOtp)),
          InfoRow(
            t.settingMosfetOtpRecovery,
            _c(s.mosfetOtpRecovery),
            last: true,
          ),
        ]),
        ..._settingsGroup(t.settingsGroupBalance, [
          if (!bmsWritesShipped)
            InfoRow(t.configBalancerSwitch, _onOff(t, s.balancerSwitchOn)),
          InfoRow(
            t.settingMaxBalance,
            '${s.maxBalanceCurrent.toStringAsFixed(2)} A',
          ),
          InfoRow(t.settingBalanceStart, _v(s.balanceStartVoltage)),
          InfoRow(
            t.settingBalanceTrigger,
            '${(s.balanceTriggerVoltage * 1000).toStringAsFixed(0)} mV',
            last: true,
          ),
        ]),
        ..._settingsGroup(t.settingsGroupOther, [
          InfoRow(t.settingCellCount, '${s.cellCount}'),
          InfoRow(
            t.settingNominalCapacity,
            '${s.nominalCapacityAh.toStringAsFixed(1)} Ah',
          ),
          if (!bmsWritesShipped) ...[
            InfoRow(t.configChargeSwitch, _onOff(t, s.chargeSwitchOn)),
            InfoRow(t.configDischargeSwitch, _onOff(t, s.dischargeSwitchOn)),
          ],
          InfoRow(t.configSoc100, _v(s.soc100Voltage)),
          InfoRow(t.configSoc0, _v(s.soc0Voltage)),
          InfoRow(t.settingRequestCharge, _v(s.cellRequestChargeVoltage)),
          InfoRow(t.settingRequestFloat, _v(s.cellRequestFloatVoltage)),
          _wireResistances(t, s),
        ]),
      ],
    );
  }

  /// A heading inside the settings section, then its rows.
  List<Widget> _settingsGroup(String title, List<Widget> rows) => [
    Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Caption(title, color: AppTheme.textFaint),
    ),
    ...rows,
  ];

  static String _v(double volts) => '${volts.toStringAsFixed(3)} V';
  static String _c(double celsius) => '${celsius.toStringAsFixed(1)} °C';
  static String _onOff(AppL10n t, bool on) => on ? t.configOn : t.configOff;

  /// The lead resistances the BMS compensates for, one per cell in use. The
  /// frame carries a slot for every cell the framing allows, so the ones past
  /// the configured count are left out rather than shown as zeros.
  Widget _wireResistances(AppL10n t, JkSettings s) {
    final count = s.cellCount.clamp(0, s.connectionWireResistances.length);
    final values = s.connectionWireResistances.take(count).toList();
    return InfoRow(
      t.settingWireResistances,
      values.isEmpty ? t.notReported : t.settingWireResistancesCount(count),
      dim: values.isEmpty,
      hint: values.isEmpty
          ? null
          : '${t.settingWireResistancesHint}\n'
                '${[for (var i = 0; i < values.length; i++) '${i + 1}: ${(values[i] * 1000).toStringAsFixed(0)} mΩ'].join('  ·  ')}',
      last: true,
    );
  }

  /// What the BMS says about itself in every reading, beyond the figures the
  /// other tabs already show: whether it is precharging, whether it sees a
  /// charger, the charge phase and battery type it was set up for, how long
  /// it has run, which cell inputs are enabled, and its own throughput
  /// counter. All of it was decoded and none of it shown.
  ///
  /// A field the BMS does not report is left out, not shown as "no": the
  /// precharge flag, the charge phase and the battery type exist only in a
  /// JK02_32S frame, and an ANT has no cell mask.
  Widget _bmsStateSection(AppL10n t, BmsSnapshot s) => Section(
    title: t.bmsStateTitle,
    intro: t.bmsStateIntro,
    children: [
      if (s.prechargeOn case final on?)
        InfoRow(t.bmsStatePrecharge, _onOff(t, on)),
      if (s.chargerPlugged case final on?)
        InfoRow(t.bmsStateChargerPlugged, _onOff(t, on)),
      if (s.chargeStatusCode case final code?)
        InfoRow(t.bmsStateChargeStatus, chargeStatusLabel(t, code)),
      if (s.batteryTypeCode case final code?)
        InfoRow(
          t.bmsStateBatteryType,
          batteryTypeLabel(t, code),
          hint: t.bmsStateBatteryTypeHint,
        ),
      InfoRow(t.bmsStateRuntime, _duration(s.totalRuntimeSeconds)),
      if (s.enabledCellMask case final mask?)
        InfoRow(
          t.bmsStateEnabledCells,
          '${_bitCount(mask)}  ·  '
          '0x${mask.toRadixString(16).padLeft(8, '0').toUpperCase()}',
        ),
      InfoRow(
        t.bmsStateCycleCapacity,
        '${s.cycleCapacityAh.toStringAsFixed(1)} Ah',
        hint: t.bmsStateCycleCapacityHint,
        last: true,
      ),
    ],
  );

  static int _bitCount(int mask) {
    var n = 0;
    for (var m = mask; m != 0; m >>= 1) {
      n += m & 1;
    }
    return n;
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
    DemoScenario.inspection => t.demoScenarioInspection,
  };

  String _scenarioDescription(AppL10n t, DemoScenario s) => switch (s) {
    DemoScenario.riding => t.demoScenarioRidingDesc,
    DemoScenario.charging => t.demoScenarioChargingDesc,
    DemoScenario.idle => t.demoScenarioIdleDesc,
    DemoScenario.weakCell => t.demoScenarioWeakCellDesc,
    DemoScenario.inspection => t.demoScenarioInspectionDesc,
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
    VariantReason.unreadableVersion => t.variantReasonUnreadable(
      d.softwareVersion,
      d.model,
    ),
    VariantReason.modernFirmware => t.variantReasonModern(
      d.softwareVersion,
      d.majorVersion ?? 0,
    ),
    VariantReason.legacyFirmware => t.variantReasonLegacy(
      d.softwareVersion,
      d.majorVersion ?? 0,
    ),
  };

  static String _duration(int seconds) {
    final d = Duration(seconds: seconds);
    if (d.inDays > 0) return '${d.inDays} d ${d.inHours % 24} h';
    if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes % 60} min';
    return '${d.inMinutes} min';
  }
}
