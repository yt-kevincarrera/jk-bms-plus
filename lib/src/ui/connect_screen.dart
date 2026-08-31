import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';

import '../../l10n/app_localizations.dart';
import '../ble/ble_transport.dart';
import '../app_settings.dart';
import '../ble/proximity_watcher.dart';
import '../ble/simulator/simulated_pack.dart';
import '../bms_service.dart';
import 'home_shell.dart';
import 'locale_controller.dart';
import 'theme.dart';
import '../data/database.dart';
import 'app_settings_screen.dart';
import 'offline_pack_screen.dart';
import 'widgets/common.dart';
import '../update/update_service.dart';

/// Scan, pick a BMS, or open demo mode.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({
    required this.service,
    required this.localeController,
    required this.proximity,
    required this.settings,
    required this.updateService,
    super.key,
  });

  final BmsService service;
  final LocaleController localeController;
  final ProximityWatcher proximity;
  final AppSettings settings;
  final UpdateService updateService;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  StreamSubscription<List<DiscoveredBms>>? _scanSub;
  StreamSubscription<BleLinkError>? _errorSub;
  StreamSubscription<DiscoveredBms>? _foundSub;
  bool _connecting = false;
  List<DiscoveredBms> _devices = const [];
  bool _scanning = false;

  /// Whether a scan has been run and finished. Distinguishes "you have not
  /// looked yet" from "we looked and found nothing", which need different
  /// things said to them.
  bool _searched = false;

  /// Packs already on record, so their history is reachable with nothing
  /// connected.
  List<Device> _stored = const [];
  String? _message;
  bool _busyMessage = false;

  @override
  void initState() {
    super.initState();
    // When the watcher spots the bike, walk straight in. This is the whole
    // point of the feature: get on, ride, and the app is already recording.
    _foundSub = widget.proximity.found.listen((device) {
      if (!mounted || _connecting) return;
      _connecting = true;
      _connect(device);
    });

    _errorSub = widget.service.linkErrors.listen((e) {
      if (mounted) {
        setState(() {
          _message = e.message;
          _busyMessage = e.likelyBusy;
        });
      }
    });

    _loadStored();
    unawaited(_checkForUpdateQuietly());

    // Scanning is what anybody opens this screen to do, so it starts on its
    // own. The button below becomes a retry rather than the way in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startScan();
    });
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _errorSub?.cancel();
    _foundSub?.cancel();
    super.dispose();
  }

  /// Announces a new build, once a day at most, and only until waved away.
  ///
  /// Deliberately a banner and not a dialog: nothing here is urgent, and an app
  /// that interrupts you to talk about itself is an app you stop opening.
  Widget _updateBanner(AppL10n t) {
    final check = widget.updateService.lastCheck;
    if (check == null || !check.hasUpdate) return const SizedBox.shrink();

    final version = check.release!.version.toString();
    if (widget.settings.dismissedUpdateVersion == version) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.cool.withValues(alpha: 0.5)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 6),
        // A column, not a row. With the text and both buttons on one line the
        // Expanded was squeezed to a couple of pixels and the message wrapped
        // one letter per line. Any translation longer than the English would
        // have done it again, so the layout stops depending on how long the
        // words are.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.system_update_alt,
                  size: 18,
                  color: AppTheme.cool,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t.updateBannerTitle(version),
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppTheme.cool,
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () async {
                      await widget.settings.dismissUpdate(version);
                      if (mounted) setState(() {});
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textFaint,
                      textStyle: const TextStyle(fontSize: 12.5),
                    ),
                    child: Text(t.updateBannerDismiss),
                  ),
                  const SizedBox(width: 6),
                  FilledButton(
                    onPressed: _openSettings,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(fontSize: 12.5),
                    ),
                    child: Text(t.updateBannerAction),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkForUpdateQuietly() async {
    widget.updateService.token = widget.settings.updateToken;
    final found = await widget.updateService.checkQuietly(
      lastCheckedAt: widget.settings.lastUpdateCheck,
      interval: const Duration(hours: 24),
      onChecked: widget.settings.markUpdateChecked,
    );
    if (found && mounted) setState(() {});
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppSettingsScreen(
          service: widget.service,
          settings: widget.settings,
          localeController: widget.localeController,
          updateService: widget.updateService,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _loadStored() async {

    final devices = await widget.service.repository?.devices();
    if (mounted && devices != null) setState(() => _stored = devices);
  }


  /// The batteries already on record, openable with nothing connected.
  ///
  /// Sits above the scan results because most of the time you already know
  /// which pack you care about, and half the reasons to open this app -- how
  /// is it doing, how far does it go, what did the last rides cost -- need no
  /// radio at all.
  /// One row, not a list.
  ///
  /// Scanning is why this screen exists. The stored batteries are for the
  /// occasional "how is it doing" from the sofa, and a list of them was
  /// pushing the thing everybody actually came for down the screen.
  Widget _storedPacks(AppL10n t) {
    if (_stored.isEmpty) return const SizedBox.shrink();

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: const Icon(Icons.history, size: 20, color: AppTheme.textFaint),
      title: Text(
        t.storedTitle,
        style: const TextStyle(fontSize: 13.5, color: AppTheme.textSecondary),
      ),
      trailing: Text(
        t.storedCount('${_stored.length}'),
        style: const TextStyle(fontSize: 12, color: AppTheme.textFaint),
      ),
      onTap: () => _openStoredSheet(t),
    );
  }

  Future<void> _openStoredSheet(AppL10n t) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
              child: Row(
                children: [
                  Text(
                    t.storedTitle,
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  t.storedManageHint,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: AppTheme.textFaint,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final d in _stored)
                    ListTile(
                      leading: Icon(
                        d.demo ? Icons.science_outlined : Icons.battery_full,
                        size: 20,
                        color: AppTheme.textSecondary,
                      ),
                      title: Text(
                        d.name.isEmpty ? d.id : d.name,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        t.storedLastSeen(_shortDate(d.lastSeenAt)),
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(this.context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => OfflinePackScreen(
                              service: widget.service,
                              device: d,
                            ),
                          ),
                        );
                      },
                      onLongPress: () {
                        Navigator.of(context).pop();
                        _managePack(t, d);
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    await _loadStored();
  }


  /// Rename or delete a stored battery, from the list itself.
  ///
  /// Deleting takes everything recorded on that pack with it, so it asks
  /// first and says what goes.
  Future<void> _managePack(AppL10n t, Device d) async {
    final label = d.name.isEmpty ? d.id : d.name;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                label,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(t.packsRename),
              onTap: () => Navigator.of(context).pop('rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppTheme.bad),
              title: Text(
                t.packsDelete,
                style: const TextStyle(color: AppTheme.bad),
              ),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    if (action == 'rename') {
      final controller = TextEditingController(text: d.name);
      final name = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t.packsRename),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: t.packsRenameHint),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.packsCancel),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: Text(t.packsSave),
            ),
          ],
        ),
      );
      controller.dispose();
      if (name != null && name.isNotEmpty) {
        await widget.service.repository?.setDeviceName(d.id, name);
        await _loadStored();
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.packsDelete),
        content: Text(t.packsDeleteConfirm(label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.packsCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.bad),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.packsDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await widget.service.repository?.deleteDevice(d.id);
    await _loadStored();
  }

  static String _shortDate(DateTime utc) {
    final d = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  Future<void> _startScan() async {
    final t = AppL10n.of(context);
    setState(() {
      _scanning = true;
      _searched = false;
      _message = null;
      _devices = const [];
    });

    if (!await FlutterBluePlus.isSupported) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _message = t.connectNoBle;
      });
      return;
    }

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _message = t.connectBluetoothOff;
      });
      return;
    }

    // Android ties BLE scanning to location being switched on, not just to the
    // permission being granted. With it off the scan succeeds and returns
    // nothing, which looks exactly like no BMS being present -- so this is
    // checked and named rather than left to be guessed at.
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _message = t.connectLocationOff;
      });
      return;
    }

    // And the permission, not just the service. This app declares
    // BLUETOOTH_SCAN without `neverForLocation`, so Android 12+ will not
    // return a single scan result without it -- the scan reports success and
    // hands back nothing. Asked here, with a reason, rather than left to fail
    // silently.
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _message = t.connectLocationDenied;
      });
      return;
    }

    await _scanSub?.cancel();
    _scanSub = widget.service.scan().listen(
      (devices) {
        if (mounted) setState(() => _devices = devices);
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _scanning = false;
            _searched = true;
          });
        }
      },
    );
  }


  /// The scan results, with the likely ones first and everything else below.
  ///
  /// The "other devices" group is the whole point of the fix: a rider whose BMS
  /// does not announce itself as a JK can still see it and tap it, instead of
  /// being told nothing was found.
  Widget _deviceList(AppL10n t) {
    final likely = _devices.where((d) => d.likelyBms).toList();
    final others = _devices.where((d) => !d.likelyBms).toList();

    return ListView(
      padding: const EdgeInsets.only(top: 12),
      children: [
        for (final d in likely) _deviceTile(t, d, likely: true),
        if (others.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.connectOtherDevices.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.8,
                    color: AppTheme.textFaint,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t.connectOtherDevicesHint,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: AppTheme.textFaint,
                  ),
                ),
              ],
            ),
          ),
          for (final d in others) _deviceTile(t, d, likely: false),
        ],
      ],
    );
  }

  Widget _deviceTile(AppL10n t, DiscoveredBms d, {required bool likely}) =>
      ListTile(
        leading: Icon(
          likely ? Icons.battery_charging_full : Icons.bluetooth,
          color: likely ? AppTheme.good : AppTheme.textFaint,
        ),
        title: Text(
          d.name.isEmpty ? d.id : d.name,
          style: TextStyle(color: likely ? null : AppTheme.textSecondary),
        ),
        subtitle: Text(
          d.advertisesJkService
              ? '${d.id}   ${d.rssi} dBm  ·  ${t.connectByService}'
              : '${d.id}   ${d.rssi} dBm',
          style: const TextStyle(fontSize: 11.5),
        ),
        trailing: Pill('${d.rssi}', color: _rssiColour(d.rssi)),
        onTap: () => _connect(d),
      );

  /// Stops a scan the user started. Cancelling the subscription also stops the
  /// radio, so this genuinely ends the scan rather than just hiding it.
  Future<void> _cancelScan({String? message}) async {
    await _scanSub?.cancel();
    _scanSub = null;
    await FlutterBluePlus.stopScan();
    if (mounted) {
      setState(() {
        _scanning = false;
        if (message != null) _message = message;
      });
    }
  }

  Future<void> _connect(DiscoveredBms device) async {
    await _cancelScan();
    if (mounted) {
      setState(() {
        _connecting = true;
        _message = t0(context).connectWaitingFirst;
        _busyMessage = true;
      });
    }

    unawaited(widget.service.connect(device.id, name: device.name));

    // Wait for proof that this is actually a BMS before opening anything.
    // Tapping a pair of headphones used to connect, open the live screens, and
    // sit on "waiting for the first reading" for as long as you let it: a
    // dead end with no way to tell a slow pack from the wrong device.
    var isBms = true;
    try {
      await widget.service.snapshots.first
          .timeout(const Duration(seconds: 14));
    } on Object catch (_) {
      isBms = false;
    }

    if (!isBms) {
      await widget.service.disconnect();
      _connecting = false;
      if (mounted) {
        setState(() {
          _message = t0(context).connectNotABms;
          _busyMessage = false;
        });
      }
      return;
    }

    // Only now is it worth remembering: the proximity watcher exists to
    // reconnect to a BMS, and remembering whatever was tapped last would have
    // it chasing a speaker.
    await widget.proximity.remember(device.id, device.name);
    if (mounted) setState(() => _message = null);

    await _openHome(device.name);
    await widget.service.disconnect();
    _connecting = false;
  }

  /// Localisations without needing them threaded through every helper.
  AppL10n t0(BuildContext context) => AppL10n.of(context);

  Future<void> _startDemo() async {
    final t = AppL10n.of(context);
    await _cancelScan();
    await widget.service.enterDemoMode(scenario: DemoScenario.riding);
    await _openHome(t.demoPackName);
    await widget.service.exitDemoMode();
  }

  Future<void> _openHome(String name) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HomeShell(
          service: widget.service,
          deviceName: name,
          localeController: widget.localeController,
          proximity: widget.proximity,
          settings: widget.settings,
          updateService: widget.updateService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.appTitle),
        actions: [
          IconButton(
            tooltip: t.appSettingsTitle,
            icon: const Icon(Icons.tune),
            onPressed: _openSettings,          ),
        ],
      ),
      body: SafeArea(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceRaised,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.hairline),
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 17,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t.connectOneConnectionWarning,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Text(
                _message!,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: _busyMessage ? AppTheme.watch : AppTheme.bad,
                ),
              ),
            ),
          _updateBanner(t),
          // Always, not only when the scan came up empty. A battery you have
          // already used outranks whatever headphones happen to be in the
          // room, and opening its history needs no radio at all.
          _storedPacks(t),
          Expanded(
            child: _devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_scanning) ...[
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.goodDim,
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        Text(
                          _scanning
                              ? t.connectScanning
                              : _searched
                                  ? t.connectScanFinished
                                  : t.connectNoDevices,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        // Only once the search has actually ended. While it is
                        // running there is nothing to explain yet, and the
                        // whole bug this replaced was a screen that could
                        // never reach this state at all.
                        if (!_scanning && _searched) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              t.connectSeenCount('${_devices.length}'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textFaint,
                              ),
                            ),
                          ),
                        ],
                        if (!_scanning && _searched)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                            child: Text(
                              t.connectNothingFoundHelp,
                              style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.5,
                                color: AppTheme.textFaint,
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                : _deviceList(t),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _scanning
                ? OutlinedButton.icon(
                    // No message. Cancelling is something the rider chose to
                    // do, and reporting it in the same red banner the app uses
                    // for genuine failures makes a deliberate act look like
                    // something went wrong.
                    onPressed: _cancelScan,
                    icon: const Icon(Icons.stop_circle_outlined, size: 19),
                    label: Text(t.connectCancelScan),
                  )
                : FilledButton.icon(
                    onPressed: _startScan,
                    icon: const Icon(
                      Icons.bluetooth_searching,
                      size: 19,
                    ),
                    label: Text(_searched ? t.connectRetry : t.connectScan),
                  ),
          ),
          // Demo is a way to look around with no hardware, not something a
          // rider with a bike outside wants competing with the scan button.
          // A quiet text link, and the paragraph explaining it moves into the
          // screen it opens.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextButton(
              onPressed: _startDemo,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textFaint,
                textStyle: const TextStyle(fontSize: 12.5),
              ),
              child: Text(t.connectDemoButton),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Color _rssiColour(int rssi) {
    if (rssi > -60) return AppTheme.good;
    if (rssi > -80) return AppTheme.watch;
    return AppTheme.bad;
  }
}
