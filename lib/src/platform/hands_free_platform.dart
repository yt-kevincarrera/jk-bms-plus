import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android's current authority to wake this app for its associated battery.
@immutable
class HandsFreeStatus {
  const HandsFreeStatus({
    this.supported = false,
    this.enabled = false,
    this.associated = false,
    this.present = false,
    this.running = false,
    this.deviceId,
    this.deviceName,
    this.reason = 'disabled',
  });

  factory HandsFreeStatus.fromMap(Map<Object?, Object?> value) =>
      HandsFreeStatus(
        supported: value['supported'] == true,
        enabled: value['enabled'] == true,
        associated: value['associated'] == true,
        present: value['present'] == true,
        running: value['running'] == true,
        deviceId: value['deviceId'] as String?,
        deviceName: value['deviceName'] as String?,
        reason: value['reason'] as String? ?? 'disabled',
      );

  final bool supported;
  final bool enabled;
  final bool associated;
  final bool present;
  final bool running;
  final String? deviceId;
  final String? deviceName;
  final String reason;

  bool get ownsForeground => supported && enabled && associated;

  HandsFreeStatus withReason(String value) => HandsFreeStatus(
    supported: supported,
    enabled: enabled,
    associated: associated,
    present: present,
    running: running,
    deviceId: deviceId,
    deviceName: deviceName,
    reason: value,
  );
}

/// One channel shared by the UI and notification owner. It never creates
/// another Dart isolate or another BMS connection.
class HandsFreePlatform extends ChangeNotifier {
  HandsFreePlatform({MethodChannel? channel, bool? isAndroid})
    : _channel =
          channel ?? const MethodChannel('dev.selector.jk_bms/hands_free'),
      isAndroid = isAndroid ?? Platform.isAndroid {
    if (this.isAndroid) _channel.setMethodCallHandler(_onNativeEvent);
  }

  static final shared = HandsFreePlatform();

  final MethodChannel _channel;
  final bool isAndroid;
  HandsFreeStatus _status = const HandsFreeStatus();
  HandsFreeStatus get status => _status;
  String? lastFailure;
  bool _disposed = false;

  Future<void> _onNativeEvent(MethodCall call) async {
    if (call.method != 'stateChanged' && call.method != 'presenceChanged') {
      return;
    }
    final value = call.arguments;
    if (value is Map) _accept(HandsFreeStatus.fromMap(value));
  }

  void _accept(HandsFreeStatus value) {
    if (_disposed) return;
    _status = value;
    notifyListeners();
  }

  Future<HandsFreeStatus> _state(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    if (!isAndroid) return _status;
    try {
      final value = await _channel.invokeMapMethod<Object?, Object?>(
        method,
        arguments,
      );
      if (value != null) _accept(HandsFreeStatus.fromMap(value));
      lastFailure = null;
    } on MissingPluginException {
      lastFailure = 'hands_free_unavailable';
      _accept(_status.withReason('platform_unavailable'));
    } on PlatformException catch (error) {
      lastFailure = error.code;
      _accept(_status.withReason(error.code));
    }
    return _status;
  }

  Future<HandsFreeStatus> refresh() => _state('refresh');

  Future<HandsFreeStatus> requestPrerequisites({required bool usesLocation}) =>
      _state('requestPrerequisites', {'usesLocation': usesLocation});

  Future<HandsFreeStatus> enable({
    required String deviceId,
    required String deviceName,
    required bool usesLocation,
  }) => _state('enable', {
    'deviceId': deviceId,
    'deviceName': deviceName,
    'usesLocation': usesLocation,
  });

  Future<HandsFreeStatus> disable() => _state('disable');

  Future<HandsFreeStatus> forget() => _state('forget');

  Future<void> openAppSettings() async {
    if (!isAndroid) return;
    await _channel.invokeMethod<void>('openAppSettings');
  }

  Future<bool> notificationStart({
    required String title,
    required String text,
    required bool usesLocation,
  }) async {
    if (!isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('notificationStart', {
        'title': title,
        'text': text,
        'usesLocation': usesLocation,
      });
      lastFailure = result == true ? null : 'start_failed';
      return result == true;
    } on PlatformException catch (error) {
      lastFailure = error.code;
      return false;
    } on MissingPluginException {
      lastFailure = 'hands_free_unavailable';
      return false;
    }
  }

  Future<void> notificationUpdate({
    required String title,
    required String text,
  }) => _sendNotification('notificationUpdate', {'title': title, 'text': text});

  Future<void> notificationStop() => _sendNotification('notificationStop');

  Future<void> notificationPower({required bool active}) =>
      _sendNotification('notificationPower', {'active': active});

  Future<void> _sendNotification(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on PlatformException catch (error) {
      lastFailure = error.code;
    } on MissingPluginException {
      lastFailure = 'hands_free_unavailable';
    }
  }

  Future<bool> notificationRunning() async {
    if (!isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('notificationRunning') ?? false;
    } on PlatformException catch (error) {
      lastFailure = error.code;
      return false;
    } on MissingPluginException {
      lastFailure = 'hands_free_unavailable';
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (isAndroid) _channel.setMethodCallHandler(null);
    super.dispose();
  }
}
