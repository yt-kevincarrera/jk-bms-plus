import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ble_transport.dart';

/// Watches for a known BMS and connects to it on its own.
///
/// Meant to be switched on for a stretch — while a new pack is being learned —
/// and switched off again, not left running forever. Two reasons it is not a
/// set-and-forget feature:
///
///  * The BMS accepts one Bluetooth connection at a time. While this is
///    connected, the official JK app cannot get in.
///  * Scanning costs phone battery. Not much at this duty cycle, but not
///    nothing either.
///
/// How it works, and its honest limitation: this scans periodically while the
/// app's process is alive. It is not a system-level background trigger — that
/// would need a `PendingIntent` scan registered with Android, which is platform
/// code this app does not have. So it picks up the bike when the app is running
/// or backgrounded, not after the process has been killed.
class ProximityWatcher {
  ProximityWatcher({
    this.scanInterval = const Duration(seconds: 45),
    this.scanDuration = const Duration(seconds: 5),
  });

  static const _enabledKey = 'proximity_enabled';
  static const _deviceIdKey = 'proximity_device_id';
  static const _deviceNameKey = 'proximity_device_name';

  /// How often to look. With a five-second window this leaves the radio idle
  /// about nine tenths of the time.
  final Duration scanInterval;

  /// How long each look lasts.
  final Duration scanDuration;

  final _foundController = StreamController<DiscoveredBms>.broadcast();

  /// Fires when the remembered BMS turns up.
  Stream<DiscoveredBms> get found => _foundController.stream;

  Timer? _timer;
  StreamSubscription<List<ScanResult>>? _scanSub;
  bool _scanning = false;

  bool _enabled = false;
  bool get isEnabled => _enabled;

  String? _deviceId;
  String? _deviceName;

  /// The BMS this will watch for, if one has been remembered.
  String? get deviceId => _deviceId;
  String? get deviceName => _deviceName;

  bool get hasDevice => _deviceId != null;

  /// True while a scan is in flight, for the UI to show something is happening.
  bool get isScanning => _scanning;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _deviceId = prefs.getString(_deviceIdKey);
      _deviceName = prefs.getString(_deviceNameKey);
      _enabled = prefs.getBool(_enabledKey) ?? false;
    } on Exception catch (_) {
      // An unreadable preference store just means the feature starts off.
    }
    if (_enabled && hasDevice) _startTimer();
  }

  /// Remembers the BMS that was just connected to, so it can be found again.
  Future<void> remember(String id, String name) async {
    _deviceId = id;
    _deviceName = name;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_deviceIdKey, id);
      await prefs.setString(_deviceNameKey, name);
    } on Exception catch (_) {
      // Remembered for this session at least.
    }
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, value);
    } on Exception catch (_) {
      // Same: it still applies to this session.
    }
    if (value && hasDevice) {
      _startTimer();
    } else {
      await _stop();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    // Look once straight away, then on the interval. Waiting half a minute
    // before the first look would make it feel broken.
    unawaited(_sweep());
    _timer = Timer.periodic(scanInterval, (_) => _sweep());
  }

  Future<void> _sweep() async {
    if (!_enabled || _scanning || _deviceId == null) return;

    try {
      if (!await FlutterBluePlus.isSupported) return;
      final adapter = await FlutterBluePlus.adapterState.first;
      if (adapter != BluetoothAdapterState.on) return;
    } on Exception catch (_) {
      return;
    }

    _scanning = true;
    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (r.device.remoteId.str != _deviceId) continue;
        _foundController.add(
          DiscoveredBms(
            id: r.device.remoteId.str,
            name: r.advertisementData.advName.isNotEmpty
                ? r.advertisementData.advName
                : r.device.platformName,
            rssi: r.rssi,
          ),
        );
        unawaited(_stopScan());
        return;
      }
    });

    try {
      // Low-power scan mode rather than low-latency. The radio duty-cycles hard
      // instead of listening continuously, which costs a second or two of
      // detection delay and saves most of the current. Nobody notices the
      // delay when the thing being detected is a motorcycle being unlocked.
      await FlutterBluePlus.startScan(
        timeout: scanDuration,
        androidScanMode: AndroidScanMode.lowPower,
        // Same reason as in BleTransport.scan: without this Android 12+ hands
        // back an empty result set and says nothing.
        androidUsesFineLocation: true,
      );
    } on Exception catch (_) {
      // Another scan may already be running; the next sweep will try again.
    }

    // Give the scan its window, then close it whether or not it found anything.
    Timer(scanDuration + const Duration(seconds: 1), _stopScan);
  }

  Future<void> _stopScan() async {
    _scanning = false;
    await _scanSub?.cancel();
    _scanSub = null;
    try {
      await FlutterBluePlus.stopScan();
    } on Exception catch (_) {
      // Nothing to stop.
    }
  }

  Future<void> _stop() async {
    _timer?.cancel();
    _timer = null;
    await _stopScan();
  }

  Future<void> dispose() async {
    await _stop();
    await _foundController.close();
  }
}
