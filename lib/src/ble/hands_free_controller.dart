import 'dart:async';

import 'package:flutter/foundation.dart';

import '../bms_service.dart';
import '../platform/hands_free_platform.dart';
import 'ble_transport.dart';
import 'proximity_connection.dart';
import 'proximity_watcher.dart';

/// Joins Android presence to the one connection owner, including headless starts.
/// Permission and association dialogs are only requested by an explicit UI action.
class HandsFreeController extends ChangeNotifier {
  HandsFreeController({
    required this.platform,
    required this.watcher,
    required this.connection,
    required this.service,
  });

  final HandsFreePlatform platform;
  final ProximityWatcher watcher;
  final ProximityConnection connection;
  final BmsService service;
  bool _disposed = false;
  bool _busy = false;
  bool _ready = false;
  bool _syncing = false;
  Completer<void>? _syncCompletion;
  bool _dirty = false;
  bool _owned = false;
  bool _present = false;
  String? _presentId;
  String? _actionReason;

  bool get busy => _busy;
  bool get ready => _ready;
  HandsFreeStatus get status => platform.status;
  String get reason => _actionReason ?? status.reason;
  bool get enabled => status.supported ? status.enabled : watcher.isEnabled;
  String? get deviceId => enabled
      ? status.deviceId ?? watcher.deviceId
      : watcher.deviceId ?? status.deviceId;
  String? get deviceName => enabled
      ? status.deviceName ?? watcher.deviceName
      : watcher.deviceName ?? status.deviceName;
  bool get hasDevice => deviceId != null;

  Future<void> initialize() async {
    // Suppress the old timer before loading its persisted ON preference. An
    // old preference is not Android's consent to a companion association.
    await watcher.setNativeDiscovery(platform.isAndroid);
    await watcher.load();
    platform.addListener(_nativeChanged);
    await platform.refresh();
    await _synchronize();
    if (_disposed) return;
    _ready = true;
    notifyListeners();
  }

  void _nativeChanged() {
    _actionReason = null;
    unawaited(_synchronize());
  }

  Future<void> _synchronize() async {
    _dirty = true;
    if (_disposed) return;
    if (_syncing) return _syncCompletion?.future;
    _syncing = true;
    final completion = Completer<void>();
    _syncCompletion = completion;
    try {
      while (_dirty && !_disposed) {
        _dirty = false;
        final value = status;
        // Android versions without companion presence keep manual connection
        // available; a timer cannot promise recovery after process death.
        await watcher.setNativeDiscovery(value.supported || platform.isAndroid);
        final nativeEnabled = value.ownsForeground;
        if (value.supported || platform.isAndroid) {
          if (nativeEnabled &&
              value.deviceId != null &&
              (watcher.deviceId != value.deviceId ||
                  watcher.deviceName != value.deviceName)) {
            await watcher.remember(value.deviceId!, value.deviceName ?? '');
          }
          if (watcher.isEnabled != nativeEnabled) {
            await watcher.setEnabled(nativeEnabled);
          }
        }
        final nextPresent = nativeEnabled && value.present;
        if (_present && (!nextPresent || _presentId != value.deviceId)) {
          watcher.offerAbsence(_presentId!);
        }
        if (nextPresent &&
            (!_present || _presentId != value.deviceId) &&
            value.deviceId != null) {
          watcher.offerPresence(
            DiscoveredBms(
              id: value.deviceId!,
              name: value.deviceName ?? '',
              // CDM reports presence without an RSSI or protocol hint.
              rssi: 0,
            ),
          );
        }
        _present = nextPresent;
        _presentId = value.deviceId;
        if (_owned != nativeEnabled) {
          _owned = nativeEnabled;
          await service.refreshForegroundRuntime();
        }
      }
    } finally {
      _syncing = false;
      _syncCompletion = null;
      completion.complete();
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_disposed) return;
    await platform.refresh();
    await _synchronize();
  }

  Future<void> setEnabled(bool value) async {
    if (_busy || !_ready || _disposed) return;
    _busy = true;
    _actionReason = null;
    notifyListeners();
    String? restoreId;
    String? restoreName;
    try {
      await connection.suspendForManual();
      if (!value) {
        await platform.disable();
        await watcher.setEnabled(false);
        await _synchronize();
        return;
      }
      if (!status.supported) {
        _actionReason = 'unsupported_android';
        return;
      }
      final target = deviceId;
      if (target == null) {
        _actionReason = 'device_required';
        return;
      }
      // Android's first chooser needs an advertising BMS. Never release the
      // connection that is currently recording a ride to make it advertise.
      final needsAssociation = !status.associated || status.deviceId != target;
      if (needsAssociation && service.trip.isActive) {
        _actionReason = 'finish_trip_before_setup';
        return;
      }
      final prerequisites = await platform.requestPrerequisites(
        usesLocation: true,
      );
      const blocked = {
        'bluetooth_permission',
        'notification_permission',
        'precise_location_permission',
        'background_location_permission',
        'location_service_disabled',
        'bluetooth_off',
        'activity_required',
        'hands_free_failed',
        'platform_unavailable',
      };
      if (blocked.contains(prerequisites.reason) ||
          platform.lastFailure != null) {
        return;
      }
      if (needsAssociation &&
          !service.isDemo &&
          (service.activeDeviceId != null || service.radioBusy)) {
        restoreId = service.activeDeviceId;
        restoreName = service.activeDevice?.name;
        await service.disconnect();
      }
      final result = await platform.enable(
        deviceId: target,
        deviceName: deviceName ?? target,
        usesLocation: true,
      );
      await _synchronize();
      if (result.ownsForeground) {
        connection.rearm();
      } else if (restoreId != null) {
        await service.connect(restoreId, name: restoreName ?? '');
      }
    } finally {
      connection.resumeAfterManual();
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> rememberConnectedDevice(String id, String name) async {
    // A manual inspection/connection must not silently move an association to
    // another motorcycle. Changing it requires disabling the old setup first.
    if (status.ownsForeground && status.deviceId != id) return;
    await watcher.remember(id, name);
    if (!_disposed) notifyListeners();
  }

  Future<void> forgetDevice(String id) async {
    if (deviceId != id) return;
    connection.suppressUntilReturn();
    await platform.forget();
    await watcher.clear();
    await _synchronize();
  }

  Future<void> openSettings() => platform.openAppSettings();

  @override
  void dispose() {
    _disposed = true;
    platform.removeListener(_nativeChanged);
    super.dispose();
  }
}
