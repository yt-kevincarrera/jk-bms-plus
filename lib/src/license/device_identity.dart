import 'dart:io';

import 'package:android_id/android_id.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_code.dart';

/// Where the device code comes from.
///
/// Abstract so the controller can be tested with a fixed code, and so the
/// Android specifics stay in one place.
abstract class DeviceIdentity {
  Future<DeviceCode> code();
}

/// A fixed code, for tests and for the tool.
class FixedDeviceIdentity implements DeviceIdentity {
  const FixedDeviceIdentity(this._code);
  final DeviceCode _code;

  @override
  Future<DeviceCode> code() async => _code;
}

/// The real thing.
///
/// On Android the code is derived from `Settings.Secure.ANDROID_ID`, which on
/// Android 8 and later is scoped to the app's signing key and the user, and
/// survives a reinstall of the same app. That is the property a lifetime
/// licence needs: a buyer who uninstalls and reinstalls keeps their key
/// working. It resets on a factory reset, which is the accepted cost, and
/// the reason the author can reissue by hand.
///
/// Anywhere else, or when Android hands back nothing, a random code is drawn
/// once and kept in preferences. It does not survive clearing the app's data,
/// and there is no way round that without a server, which this app does not
/// have.
class PlatformDeviceIdentity implements DeviceIdentity {
  static const _fallbackKey = 'license_device_code_fallback';

  DeviceCode? _cached;

  @override
  Future<DeviceCode> code() async {
    final cached = _cached;
    if (cached != null) return cached;

    final stable = await _androidId();
    final DeviceCode code;
    if (stable != null && stable.isNotEmpty) {
      code = await DeviceCode.derive(stable);
    } else {
      code = await _storedFallback();
    }
    _cached = code;
    return code;
  }

  Future<String?> _androidId() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      return await const AndroidId().getId();
    } on Object catch (_) {
      return null;
    }
  }

  Future<DeviceCode> _storedFallback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_fallbackKey);
      final parsed = stored == null ? null : DeviceCode.parse(stored);
      if (parsed != null) return parsed;
      final fresh = DeviceCode.random();
      await prefs.setString(_fallbackKey, fresh.display);
      return fresh;
    } on Object catch (_) {
      // No preferences at all. A code that changes every launch is useless
      // for a licence, but it lets the screen render rather than crash.
      return DeviceCode.random();
    }
  }
}
