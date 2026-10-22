import 'dart:async';

import '../bms_service.dart';
import 'ble_transport.dart';
import 'proximity_watcher.dart';

/// Owns proximity's one connection request, independently of any screen.
/// The transport owns the complete retry budget after that request starts.
class ProximityConnection {
  ProximityConnection({
    required this.watcher,
    required this.service,
    this.failedCooldown = const Duration(minutes: 5),
    this.departureDwell = const Duration(seconds: 15),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now {
    _foundSub = watcher.found.listen(_onPresence);
    _departedSub = watcher.departed.listen(_onDeparture);
    _enabledSub = watcher.enabledChanges.listen((enabled) {
      if (enabled) {
        rearm();
      } else {
        _present = false;
        _cooldownTimer?.cancel();
        unawaited(_cancelOwnedAttempt());
      }
    });
    _stateSub = service.linkState.listen(_onLinkState);
  }

  final ProximityWatcher watcher;
  final BmsService service;
  final Duration failedCooldown;
  final Duration departureDwell;
  final DateTime Function() _now;
  late final StreamSubscription<DiscoveredBms> _foundSub;
  late final StreamSubscription<String> _departedSub;
  late final StreamSubscription<bool> _enabledSub;
  late final StreamSubscription<BleLinkState> _stateSub;
  Timer? _cooldownTimer;
  Timer? _departureTimer;
  Future<void>? _manualSuspension;
  DateTime? _retryAfter;
  bool _disposed = false;
  bool _manualSuspended = false;
  bool _present = false;
  bool _requiresReturn = false;
  bool _departedLongEnough = false;
  bool _suppressed = false;
  bool _ownsAttempt = false;
  bool _starting = false;
  String? _attemptId;
  String? _presenceId;
  int _generation = 0;

  void _onPresence(DiscoveredBms device) {
    if (_disposed || device.id != watcher.deviceId) return;
    _departureTimer?.cancel();
    if (_presenceId != null && _presenceId != device.id) {
      _present = false;
      _requiresReturn = false;
      _suppressed = false;
      _departedLongEnough = false;
      _retryAfter = null;
    }
    _presenceId = device.id;
    final returned = !_present;
    _present = true;
    if (_suppressed || _requiresReturn) {
      if (!returned || !_departedLongEnough) return;
      _suppressed = false;
      _requiresReturn = false;
      _departedLongEnough = false;
    }
    _consider();
  }

  void _onDeparture(String deviceId) {
    if (_disposed || deviceId != watcher.deviceId) return;
    _present = false;
    _cooldownTimer?.cancel();
    // JK stops advertising while connected. Dropping GATT can therefore make
    // native BLE|BT presence briefly false before BLE returns, with the rider
    // still next to the bike. Only a sustained absence counts as departure.
    if (_suppressed || _requiresReturn) _waitForDeparture();
  }

  void _waitForDeparture() {
    final departedAt = _now();
    _departureTimer?.cancel();
    _departureTimer = Timer(departureDwell, () {
      if (_disposed ||
          !(_suppressed || _requiresReturn) ||
          _present ||
          _now().difference(departedAt) < departureDwell ||
          service.trip.isActive ||
          service.lastLinkState == BleLinkState.connected ||
          service.lastLinkState == BleLinkState.connecting ||
          service.lastLinkState == BleLinkState.negotiating ||
          service.lastLinkState == BleLinkState.reconnecting) {
        return;
      }
      _departedLongEnough = true;
    });
  }

  bool get _serviceOccupied =>
      service.radioBusy ||
      service.inspecting ||
      service.trip.isActive ||
      (service.lastLinkState != BleLinkState.idle &&
          service.lastLinkState != BleLinkState.failed);

  void _consider() {
    if (_disposed ||
        _manualSuspended ||
        !watcher.isEnabled ||
        !_present ||
        _suppressed ||
        _requiresReturn ||
        _starting ||
        _ownsAttempt ||
        _serviceOccupied) {
      return;
    }
    final sighting = watcher.presentAdvertisement;
    if (sighting == null || sighting.device.id != watcher.deviceId) return;
    final remaining = _retryAfter?.difference(_now());
    if (remaining != null && remaining > Duration.zero) {
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer(remaining, _consider);
      return;
    }
    _cooldownTimer?.cancel();
    final generation = ++_generation;
    _attemptId = sighting.device.id;
    _ownsAttempt = true;
    _starting = true;
    unawaited(_connect(sighting.device, generation));
  }

  Future<void> _connect(DiscoveredBms device, int generation) async {
    try {
      await service.connect(device.id, name: device.name);
      if (generation != _generation || !_ownsAttempt) return;
      if (service.lastLinkState == BleLinkState.failed &&
          service.linkRetry.gaveUp) {
        _failed();
      }
    } catch (_) {
      if (generation == _generation && _ownsAttempt) _failed();
    } finally {
      if (generation == _generation) _starting = false;
    }
  }

  void _onLinkState(BleLinkState state) {
    if (_disposed || !_ownsAttempt) return;
    if (state == BleLinkState.failed && service.linkRetry.gaveUp) {
      _failed();
    }
    // A connected GATT without snapshots is still this same attempt. Its
    // silence watchdog and recovery must finish without another connect().
  }

  void _failed() {
    ++_generation;
    _starting = false;
    _ownsAttempt = false;
    _attemptId = null;
    _retryAfter = _now().add(failedCooldown);
    _requiresReturn = true;
    _departedLongEnough = false;
    _departureTimer?.cancel();
    if (!_present) _waitForDeparture();
    _cooldownTimer?.cancel();
  }

  /// Await before manual scan/connect or inspection. It cannot cancel the
  /// manual request that follows, even when our old connect completes late.
  Future<void> suspendForManual() {
    _manualSuspended = true;
    _cooldownTimer?.cancel();
    return _manualSuspension ??= _suspendManual();
  }

  Future<void> _suspendManual() async {
    try {
      // Every concurrent caller must await the same pending scan startup. A
      // second watcher.suspend() alone could see the detached session as null
      // and hand the radio over before the first caller finished releasing it.
      await watcher.suspend();
      if (!_disposed) await _cancelOwnedAttempt();
    } finally {
      _manualSuspension = null;
    }
  }

  Future<void> _cancelOwnedAttempt() async {
    final owned = _ownsAttempt;
    final target = _attemptId;
    ++_generation;
    _starting = false;
    _ownsAttempt = false;
    _attemptId = null;
    if (owned &&
        !service.hasCurrentReadings &&
        !service.trip.isActive &&
        !service.inspecting &&
        (service.activeDeviceId == null || service.activeDeviceId == target)) {
      await service.disconnect();
    }
  }

  void resumeAfterManual() {
    if (_disposed) return;
    _manualSuspended = false;
    watcher.resume();
    // A presence event can arrive while the manual radio owner is active.
    // Keep its original time; native presence lasts until an explicit absence.
    // A legacy advertisement must still be fresh.
    if (watcher.presentAdvertisement != null) _present = true;
    _consider();
  }

  /// Call before the user's explicit disconnect. Existing absence events do
  /// not count: a new departure and fresh return must follow this decision.
  void suppressUntilReturn() {
    if (_disposed) return;
    ++_generation;
    _starting = false;
    _ownsAttempt = false;
    _attemptId = null;
    _suppressed = true;
    _departedLongEnough = false;
    _departureTimer?.cancel();
    _cooldownTimer?.cancel();
  }

  /// Explicitly enabling proximity again is also an explicit new attempt.
  void rearm() {
    if (_disposed) return;
    _suppressed = false;
    _departedLongEnough = false;
    _departureTimer?.cancel();
    _requiresReturn = false;
    _retryAfter = null;
    _present = watcher.presentAdvertisement != null;
    _consider();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    _cooldownTimer?.cancel();
    _departureTimer?.cancel();
    await _foundSub.cancel();
    await _departedSub.cancel();
    await _enabledSub.cancel();
    await _stateSub.cancel();
  }
}
