import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'connect_recovery.dart';

/// The [RecoveryRadio] the app runs on: flutter_blue_plus, and below it the
/// plugin's Android code.
///
/// Every call is bounded and every failure swallowed. This runs when things
/// are already going wrong, and a recovery step that hangs or throws is a
/// recovery step that made it worse.
class FbpRecoveryRadio implements RecoveryRadio {
  FbpRecoveryRadio({AdvertBook? adverts})
    : _adverts = adverts ?? AdvertBook.shared;

  final AdvertBook _adverts;

  /// The plugin's own method channel, used for one call it does not expose.
  static const _channel = MethodChannel('flutter_blue_plus/methods');

  @override
  String adapterState() {
    try {
      return FlutterBluePlus.adapterStateNow.name;
    } on Object catch (_) {
      return '?';
    }
  }

  @override
  List<String> appConnectedIds() {
    try {
      return [for (final d in FlutterBluePlus.connectedDevices) d.remoteId.str];
    } on Object catch (_) {
      return const [];
    }
  }

  @override
  Future<List<String>?> systemConnectedIds() async {
    try {
      // Android ignores the filter and returns every GATT-connected device,
      // whichever app opened it.
      final held = await FlutterBluePlus.systemDevices(const [])
          .timeout(const Duration(seconds: 3));
      return [for (final d in held) d.remoteId.str];
    } on Object catch (_) {
      return null;
    }
  }

  @override
  Future<void> release(String deviceId) async {
    try {
      // `timeout` is how long the plugin waits for Android to confirm, and it
      // holds the device's disconnect mutex while it waits. The default 35 s
      // made every later connect on the device queue behind a confirmation
      // that, on a stuck stack, never comes.
      await BluetoothDevice.fromId(deviceId)
          .disconnect(queue: false, timeout: 6)
          .timeout(const Duration(seconds: 10));
    } on Object catch (_) {
      // Already gone, or not answering. Either way there is no more to do.
    }
  }

  @override
  Future<String> closeStranded(String deviceId) async {
    final device = BluetoothDevice.fromId(deviceId);
    try {
      // Joins the link Android already has, if it has one: connecting to a
      // device the stack is connected to completes at once. Then this app
      // owns a handle on it, and letting go of that handle is what lets the
      // stack drop a link no other client is using.
      await device
          .connect(
            license: License.nonprofit,
            timeout: const Duration(seconds: 5),
            mtu: null,
            autoConnect: false,
          )
          .timeout(const Duration(seconds: 8));
    } on Object catch (e) {
      await release(deviceId);
      return 'connect failed: $e';
    }
    String cache;
    try {
      // Android's hidden BluetoothGatt.refresh(). It clears the attribute
      // cache and nothing about the connection, and it needs a live link, so
      // this is the only moment it can run at all.
      await device.clearGattCache().timeout(const Duration(seconds: 3));
      cache = 'gatt cache cleared';
    } on Object catch (e) {
      cache = 'gatt cache not cleared: $e';
    }
    await release(deviceId);
    return 'joined and released, $cache';
  }

  @override
  Future<AdvertSighting?> freshAdvert(
    String deviceId, {
    required Duration within,
    required bool Function() stillWanted,
  }) async {
    final since = DateTime.now();
    AdvertSighting? heard;
    final sub = FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        _adverts.saw(r.device.remoteId.str, rssi: r.rssi, at: r.timeStamp);
        if (r.device.remoteId.str == deviceId && !r.timeStamp.isBefore(since)) {
          heard ??= AdvertSighting(rssi: r.rssi, at: r.timeStamp);
        }
      }
    });
    try {
      await FlutterBluePlus.startScan(
        timeout: within,
        androidUsesFineLocation: true,
      ).timeout(const Duration(seconds: 4));
      while (heard == null &&
          stillWanted() &&
          DateTime.now().difference(since) < within) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    } on Object catch (_) {
      // Could not scan. The attempt goes ahead without the advert.
    } finally {
      await sub.cancel();
      try {
        await FlutterBluePlus.stopScan().timeout(const Duration(seconds: 3));
      } on Object catch (_) {}
    }
    return heard;
  }

  @override
  Future<String> resetAll() async {
    final notes = <String>[];
    try {
      await FlutterBluePlus.stopScan().timeout(const Duration(seconds: 3));
    } on Object catch (_) {}
    final held = appConnectedIds();
    for (final id in held) {
      await release(id);
    }
    notes.add('released ${held.length} plugin link(s)');
    if (Platform.isAndroid) {
      try {
        // The plugin's own hot-restart reset, which it runs once at the start
        // of every process: disconnect and close every BluetoothGatt it still
        // has, and clear its maps. Closing is the part that matters. A
        // disconnect whose callback never arrived leaves a gatt the plugin
        // never closes, holding a client slot in Android's Bluetooth service
        // until the process dies; this is the one call that closes it without
        // killing the process. It goes straight to the channel because the
        // plugin does not expose it, which also takes it around the plugin's
        // single lock on every platform call.
        final left = await _channel
            .invokeMethod<int>('flutterRestart')
            .timeout(const Duration(seconds: 5));
        notes.add('native gatts closed, $left still listed');
      } on Object catch (e) {
        notes.add('native reset failed: $e');
      }
    }
    return notes.join(', ');
  }

  @override
  Stream<String> get adapterStates =>
      FlutterBluePlus.adapterState.map((s) => s.name);
}

/// [RecoveryMemory] in the app's preferences.
class PrefsRecoveryMemory implements RecoveryMemory {
  @override
  Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String key, String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value);
    }
  }
}

/// When the phone last booted, from the kernel's uptime. Null when it cannot
/// be read, which the caller reports as unknown rather than guessing.
Future<DateTime?> readBootTime() async {
  try {
    final text = await File('/proc/uptime').readAsString();
    final seconds = double.parse(text.split(' ').first);
    return DateTime.now().subtract(
      Duration(milliseconds: (seconds * 1000).round()),
    );
  } on Object catch (_) {
    return null;
  }
}
