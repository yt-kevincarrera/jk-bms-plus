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
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _errorSub?.cancel();
    _foundSub?.cancel();
    super.dispose();
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
    // Remember it, so the proximity watcher has something to look for later.
    await widget.proximity.remember(device.id, device.name);
    unawaited(widget.service.connect(device.id, name: device.name));
    await _openHome(device.name);
    await widget.service.disconnect();
    _connecting = false;
  }

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
      appBar: AppBar(title: Text(t.appTitle)),
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
                          _scanning ? t.connectScanning : t.connectScanFinished,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        // Only once the search has actually ended. While it is
                        // running there is nothing to explain yet, and the
                        // whole bug this replaced was a screen that could
                        // never reach this state at all.
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
                    onPressed: () =>
                        _cancelScan(message: t.connectScanCancelled),
                    icon: const Icon(Icons.stop_circle_outlined, size: 19),
                    label: Text(t.connectCancelScan),
                  )
                : FilledButton.icon(
                    onPressed: _startScan,
                    icon: const Icon(Icons.bluetooth_searching, size: 19),
                    label: Text(t.connectScan),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: OutlinedButton.icon(
              onPressed: _startDemo,
              icon: const Icon(Icons.play_circle_outline, size: 19),
              label: Text(t.connectDemoButton),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
            child: Text(
              t.connectDemoHint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: AppTheme.textFaint,
              ),
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
