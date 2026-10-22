import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ble_transport.dart';
import 'connect_recovery.dart';

/// A radio sighting keeps its original timestamp, including across suspension.
class ProximityAdvertisement {
  const ProximityAdvertisement(this.device, this.at);
  final DiscoveredBms device;
  final DateTime at;
}

/// Cancellation releases this listener, never a scan belonging to another user.
abstract interface class ProximityScanSession {
  bool get didStart;
  Future<void> cancel();
}

/// The same source is used by the watcher in production and by radio tests.
abstract interface class ProximityScanSource {
  Future<ProximityScanSession> start({
    required Duration duration,
    required bool Function() stillWanted,
    required void Function(ProximityAdvertisement) onAdvertisement,
  });
}

/// Watches a remembered pack. Android companion presence is supplied through
/// [offerPresence]; periodic Dart scans are only the legacy fallback.
class ProximityWatcher {
  ProximityWatcher({
    this.scanInterval = const Duration(seconds: 45),
    this.scanDuration = const Duration(seconds: 5),
    bool Function()? radioBusy,
    AdvertBook? adverts,
    ProximityScanSource? scanSource,
    DateTime Function()? clock,
  }) : _radioBusy = radioBusy,
       _adverts = adverts ?? AdvertBook.shared,
       _scanSource = scanSource ?? _FbpProximityScanSource(),
       _now = clock ?? DateTime.now;

  static const _enabledKey = 'proximity_enabled';
  static const _deviceIdKey = 'proximity_device_id';
  static const _deviceNameKey = 'proximity_device_name';
  static const presenceFreshness = Duration(seconds: 15);

  final Duration scanInterval;
  final Duration scanDuration;
  final bool Function()? _radioBusy;
  final AdvertBook _adverts;
  final ProximityScanSource _scanSource;
  final DateTime Function() _now;
  final _found = StreamController<DiscoveredBms>.broadcast(sync: true);
  final _departed = StreamController<String>.broadcast(sync: true);
  final _enabledChanges = StreamController<bool>.broadcast(sync: true);

  Stream<DiscoveredBms> get found => _found.stream;
  Stream<String> get departed => _departed.stream;
  Stream<bool> get enabledChanges => _enabledChanges.stream;

  bool _enabled = false;
  bool _nativeDiscovery = false;
  bool _suspended = false;
  bool _disposed = false;
  bool _scanning = false;
  int _generation = 0;
  String? _deviceId;
  String? _deviceName;
  DateTime? _lastEventAt;
  ProximityAdvertisement? _presence;
  Timer? _timer;
  Timer? _deadline;
  ProximityScanSession? _session;
  Future<ProximityScanSession>? _pendingStart;

  bool get isEnabled => _enabled;
  bool get isScanning => _scanning;
  bool get hasDevice => _deviceId != null;
  String? get deviceId => _deviceId;
  String? get deviceName => _deviceName;

  /// Native companion presence is a state until an explicit absence. Legacy
  /// scan advertisements expire; receiving one never proves continued presence.
  ProximityAdvertisement? get presentAdvertisement {
    final sighting = _presence;
    return sighting != null && (_nativeDiscovery || _fresh(sighting.at))
        ? sighting
        : null;
  }

  DiscoveredBms? get presentDevice => presentAdvertisement?.device;

  bool _fresh(DateTime at) {
    final age = _now().difference(at);
    return !age.isNegative && age <= presenceFreshness;
  }

  Future<void> load() async {
    if (_disposed) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_disposed) return;
      _deviceId = prefs.getString(_deviceIdKey);
      _deviceName = prefs.getString(_deviceNameKey);
      _enabled = prefs.getBool(_enabledKey) ?? false;
    } on Exception catch (_) {
      // An unreadable preference store starts with the in-memory settings.
    }
    if (_disposed) return;
    _enabledChanges.add(_enabled);
    _startTimer();
  }

  Future<void> remember(String id, String name) async {
    if (_disposed) return;
    final changed = _deviceId != id;
    _deviceId = id;
    _deviceName = name;
    if (changed) {
      _presence = null;
      _lastEventAt = null;
      await _stopLocal();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_deviceIdKey, id);
      await prefs.setString(_deviceNameKey, name);
    } on Exception catch (_) {
      // Remembered for this session at least.
    }
    _startTimer();
  }

  Future<void> clear() async {
    if (_disposed) return;
    _enabled = false;
    _deviceId = null;
    _deviceName = null;
    _presence = null;
    _lastEventAt = null;
    _enabledChanges.add(false);
    await _stopLocal();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_deviceIdKey);
      await prefs.remove(_deviceNameKey);
      await prefs.setBool(_enabledKey, false);
    } on Exception catch (_) {
      // Clearing applies in memory even if persistence is unavailable.
    }
  }

  /// Call only after native association/permissions have succeeded.
  Future<void> setEnabled(bool value) async {
    if (_disposed) return;
    final changed = _enabled != value;
    _enabled = value;
    if (!value) {
      _presence = null;
      _lastEventAt = null;
    }
    if (changed) _enabledChanges.add(value);
    await _stopLocal();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, value);
    } on Exception catch (_) {
      // The choice still applies for this session.
    }
    _startTimer();
  }

  Future<void> setNativeDiscovery(bool native) async {
    if (_disposed || _nativeDiscovery == native) return;
    _nativeDiscovery = native;
    _presence = null;
    _lastEventAt = null;
    await _stopLocal();
    _startTimer();
  }

  /// Native presence is still remembered during manual scanning/inspection.
  void offerPresence(DiscoveredBms device, {DateTime? seenAt}) {
    final at = seenAt ?? _now();
    if (_disposed || !_enabled || device.id != _deviceId || !_fresh(at)) return;
    if (_lastEventAt != null && at.isBefore(_lastEventAt!)) return;
    if (_presence != null && !at.isAfter(_presence!.at)) return;
    _lastEventAt = at;
    _presence = ProximityAdvertisement(device, at);
    // Presence is evidence of proximity, not a measured advertisement RSSI.
    if (!_nativeDiscovery) {
      _adverts.saw(device.id, rssi: device.rssi, at: at);
    }
    _found.add(device);
  }

  void offerAbsence(String deviceId, {DateTime? seenAt}) {
    final at = seenAt ?? _now();
    if (_disposed || !_enabled || deviceId != _deviceId || !_fresh(at)) return;
    if (_lastEventAt != null && at.isBefore(_lastEventAt!)) return;
    _lastEventAt = at;
    _presence = null;
    _departed.add(deviceId);
  }

  Future<void> suspend() async {
    if (_disposed) return;
    _suspended = true;
    await _stopLocal();
  }

  void resume() {
    if (_disposed) return;
    _suspended = false;
    _startTimer();
  }

  bool get _canScan =>
      !_disposed && _enabled && hasDevice && !_nativeDiscovery && !_suspended;

  void _startTimer() {
    _timer?.cancel();
    _timer = null;
    if (!_canScan) return;
    unawaited(_sweep());
    _timer = Timer.periodic(scanInterval, (_) => unawaited(_sweep()));
  }

  Future<void> _sweep() async {
    if (!_canScan || _scanning || (_radioBusy?.call() ?? false)) return;
    final generation = ++_generation;
    final startedAt = _now();
    ProximityAdvertisement? candidate;
    _scanning = true;
    bool wanted() =>
        generation == _generation && _canScan && !(_radioBusy?.call() ?? false);
    try {
      final pending = _scanSource.start(
        duration: scanDuration,
        stillWanted: wanted,
        onAdvertisement: (sighting) {
          if (!wanted() ||
              sighting.at.isBefore(startedAt) ||
              !_fresh(sighting.at)) {
            return;
          }
          _adverts.saw(
            sighting.device.id,
            rssi: sighting.device.rssi,
            at: sighting.at,
          );
          if (sighting.device.id == _deviceId) candidate = sighting;
          if (candidate != null && _session != null) {
            unawaited(_finishSweep(generation, candidate));
          }
        },
      );
      _pendingStart = pending;
      final session = await pending;
      if (identical(_pendingStart, pending)) _pendingStart = null;
      if (!wanted()) {
        await session.cancel();
        if (generation == _generation) _scanning = false;
        return;
      }
      _session = session;
      if (!session.didStart) {
        await _finishSweep(generation, null, reportAbsence: false);
        return;
      }
      if (candidate != null) {
        await _finishSweep(generation, candidate);
        return;
      }
      // The retained deadline is cancelled on every handoff. It can only
      // release this session's subscription, never the next owner's scan.
      _deadline = Timer(scanDuration + const Duration(seconds: 1), () {
        unawaited(_finishSweep(generation, candidate));
      });
    } catch (_) {
      if (generation == _generation) {
        _pendingStart = null;
        await _finishSweep(generation, null, reportAbsence: false);
      }
    }
  }

  Future<void> _finishSweep(
    int generation,
    ProximityAdvertisement? candidate, {
    bool reportAbsence = true,
  }) async {
    if (generation != _generation) return;
    final session = _session;
    _session = null;
    _deadline?.cancel();
    _deadline = null;
    _scanning = false;
    await session?.cancel();
    if (generation != _generation ||
        !_canScan ||
        (_radioBusy?.call() ?? false)) {
      return;
    }
    if (candidate != null) {
      offerPresence(candidate.device, seenAt: candidate.at);
    } else if (reportAbsence && _deviceId != null) {
      offerAbsence(_deviceId!);
    }
  }

  Future<void> _stopLocal() async {
    ++_generation;
    _timer?.cancel();
    _timer = null;
    _deadline?.cancel();
    _deadline = null;
    _scanning = false;
    final session = _session;
    _session = null;
    final pending = _pendingStart;
    _pendingStart = null;
    await session?.cancel();
    // A manual scan waits until an already-starting legacy request has handed
    // the plugin back. Otherwise that old request could start after the manual
    // one and replace it while unwinding a support/adapter/plugin await.
    if (pending != null) {
      try {
        await (await pending).cancel();
      } catch (_) {
        // A failed scan has no remaining listener to release.
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _stopLocal();
    await _found.close();
    await _departed.close();
    await _enabledChanges.close();
  }
}

class _FbpProximityScanSource implements ProximityScanSource {
  @override
  Future<ProximityScanSession> start({
    required Duration duration,
    required bool Function() stillWanted,
    required void Function(ProximityAdvertisement) onAdvertisement,
  }) async {
    if (!await FlutterBluePlus.isSupported.timeout(
          const Duration(seconds: 3),
        ) ||
        !stillWanted()) {
      return _FbpProximityScanSession(null, false);
    }
    final adapter = await FlutterBluePlus.adapterState
        .firstWhere(
          (state) =>
              state == BluetoothAdapterState.on ||
              state == BluetoothAdapterState.off ||
              state == BluetoothAdapterState.unavailable ||
              state == BluetoothAdapterState.unauthorized,
        )
        .timeout(const Duration(seconds: 3));
    if (!stillWanted() ||
        adapter != BluetoothAdapterState.on ||
        FlutterBluePlus.isScanningNow) {
      return _FbpProximityScanSession(null, false);
    }
    // onScanResults excludes the previous stopped scan's replayed result list.
    final subscription = FlutterBluePlus.onScanResults.listen(
      (results) {
        if (!stillWanted()) return;
        for (final result in results) {
          final name = result.advertisementData.advName;
          onAdvertisement(
            ProximityAdvertisement(
              classifyAdvertisement(
                id: result.device.remoteId.str,
                name: name.isNotEmpty ? name : result.device.platformName,
                rssi: result.rssi,
                serviceUuids: result.advertisementData.serviceUuids.map(
                  (u) => u.str,
                ),
              ),
              result.timeStamp,
            ),
          );
        }
      },
      onError: (Object error, StackTrace stack) {
        // The bounded sweep will finish normally; a plugin scan failure must
        // not become an unhandled stream error or trigger a connection.
      },
    );
    final session = _FbpProximityScanSession(subscription, true);
    try {
      if (!stillWanted()) {
        await session.cancel();
        return _FbpProximityScanSession(null, false);
      }
      await FlutterBluePlus.startScan(
        timeout: duration,
        androidScanMode: AndroidScanMode.lowPower,
        androidUsesFineLocation: true,
      ).timeout(const Duration(seconds: 4));
      return session;
    } catch (_) {
      await session.cancel();
      rethrow;
    }
  }
}

class _FbpProximityScanSession implements ProximityScanSession {
  _FbpProximityScanSession(this._subscription, this.didStart);
  StreamSubscription<List<ScanResult>>? _subscription;
  @override
  final bool didStart;
  @override
  Future<void> cancel() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    // FlutterBluePlus has one global scan and no cancellation ownership token.
    // Its own bounded timeout ends our scan; a manual start replaces that
    // timeout. Calling stopScan here could instead stop that new manual scan.
  }
}
