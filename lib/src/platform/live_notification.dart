import 'dart:async';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'hands_free_platform.dart';

/// The notification that keeps a trip alive and readable from anywhere.
///
/// Two jobs in one object, because on Android they are the same thing:
///
///  * It is a foreground service, which is what stops the system throttling
///    location and killing the process the moment you switch to your music app.
///  * It is a live readout, updated as the ride goes, so speed, distance and
///    charge are on the lock screen and in the shade without reopening the app.
///
/// Declared as `location` type: that is the category that grants continued GPS
/// access, and it is the honest label for what the service is actually doing.
class LiveNotification {
  LiveNotification({HandsFreePlatform? handsFree, bool? isAndroid})
    : _handsFree = handsFree ?? HandsFreePlatform.shared,
      _isAndroid = isAndroid ?? Platform.isAndroid;

  final HandsFreePlatform _handsFree;
  final bool _isAndroid;
  bool _nativeOwned = false;
  bool get _wantsNative => _handsFree.status.ownsForeground;
  bool _locationActive = false;

  /// The foreground type can stay location-capable while GPS rests. Only a
  /// live location source needs the companion host to hold the CPU awake.
  set locationActive(bool value) {
    _locationActive = value;
    if (_isAndroid && _nativeOwned) {
      unawaited(_handsFree.notificationPower(active: value));
    }
  }

  static const _channelId = 'jk_bms_trip';
  static const _serviceId = 5510;

  bool _initialised = false;
  bool _running = false;

  bool get isRunning => _running;

  /// Sets up the channel. Safe to call more than once.
  void ensureInitialised({
    required String channelName,
    required String channelDescription,
  }) {
    if (_initialised || !_isAndroid) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _channelId,
        channelName: channelName,
        channelDescription: channelDescription,
        // Low importance and no sound: this notification is a readout, not an
        // alert. It should sit there quietly for the length of a ride.
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
        showWhen: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        // No repeating callback: the app's own isolate updates the text while
        // it is alive, which is the case that matters — backgrounded, not
        // killed. Spawning a second isolate to duplicate the trip recorder
        // would mean two sources of truth.
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: false,
        // Deliberately not set here. `stopWithTask: true` in these options
        // does more than its name says: the plugin also installs an activity
        // watcher (TrackVisibilityUtils) that stops the service the moment no
        // activity is resumed, which is every time the screen goes off or the
        // phone goes in a pocket. Shipped in 2.28.0, it took the service away
        // from every ride, Android stopped the GPS for the backgrounded app,
        // and a 45-minute ride came back with 0 km.
        //
        // Left as it was before 2.28: the service is not stopped with the
        // task either. The rider's call: a ride must not end because the app
        // was swiped from the recent list. Null here also removes the `true`
        // that 2.28 and 2.29 left in the plugin's stored options on the phone.
      ),
    );
    _initialised = true;
  }

  /// Asks for the notification permission Android 13+ requires.
  ///
  /// Returns false when it was refused, in which case the service cannot start
  /// and the caller should say so rather than silently recording nothing.
  Future<bool> requestPermission() async {
    if (!_isAndroid) return true;
    // Setup already requested consent while an Activity was visible. A
    // presence callback must never try to show a permission dialog headlessly.
    if (_wantsNative) {
      return _handsFree.status.reason != 'notification_permission';
    }
    final status = await FlutterForegroundTask.checkNotificationPermission();
    if (status == NotificationPermission.granted) return true;
    final result = await FlutterForegroundTask.requestNotificationPermission();
    return result == NotificationPermission.granted;
  }

  /// [usesRealLocation] picks the service type, and the choice is not cosmetic:
  /// Android 14 refuses to start a `location`-typed foreground service unless
  /// the app already holds a location permission. Demo mode has no GPS and asks
  /// for no permission, so it declares itself as `dataSync` instead — which is
  /// also the honest description of what it is doing there.
  Future<bool> start({
    required String title,
    required String text,
    bool usesRealLocation = true,
  }) async {
    if (!_isAndroid) return true;
    _checkedAt = null;
    if (_wantsNative) {
      final wasNative = _nativeOwned;
      final started = await _handsFree.notificationStart(
        title: title,
        text: text,
        usesLocation: usesRealLocation,
      );
      if (started) {
        if (await FlutterForegroundTask.isRunningService) {
          await FlutterForegroundTask.stopService();
        }
        _nativeOwned = true;
        _running = true;
        await _handsFree.notificationPower(active: _locationActive);
      } else {
        _nativeOwned = wasNative;
        _running = wasNative || await FlutterForegroundTask.isRunningService;
      }
      lastFailure = _handsFree.lastFailure;
      return started;
    }
    final handingOffNative = _nativeOwned;
    // Asked of Android, not of the flag. The flag only knew what this object
    // had done, and Android also stops services on its own (a dataSync one
    // after six hours on Android 15): a flag still saying "running" made this
    // return true for a service that was gone, and a ride went without one.
    if (_running &&
        !handingOffNative &&
        await FlutterForegroundTask.isRunningService) {
      return true;
    }

    final result = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: [
        usesRealLocation
            ? ForegroundServiceTypes.location
            : ForegroundServiceTypes.dataSync,
      ],
      notificationTitle: title,
      notificationText: text,
    );
    final started = result is ServiceRequestSuccess;
    if (handingOffNative && started) {
      // Keep the old location owner alive until Android accepts its successor.
      // Disabling proximity from a notification can happen with no Activity.
      await _handsFree.notificationStop();
      _nativeOwned = false;
    }
    _running = started || handingOffNative;
    lastFailure = result is ServiceRequestFailure ? '${result.error}' : null;
    return started;
  }

  /// Why the last start or stop failed, for writing down. Null after one
  /// that worked.
  String? lastFailure;

  DateTime? _checkedAt;

  /// Whether Android still has the service running, asked at most every 30 s.
  ///
  /// For the caller that holds a service for hours: it is the only way to find
  /// out Android stopped it, short of the fixes or the radio quietly stopping.
  Future<bool> stillRunning() async {
    if (!_isAndroid) return true;
    // A changed backend needs the service arbiter to reclaim the notification
    // even if the old Android service is still running.
    if (_wantsNative != _nativeOwned) return false;
    if (!_running) return false;
    final now = DateTime.now();
    final last = _checkedAt;
    if (last != null && now.difference(last) < const Duration(seconds: 30)) {
      return true;
    }
    _checkedAt = now;
    final running = _nativeOwned
        ? await _handsFree.notificationRunning()
        : await FlutterForegroundTask.isRunningService;
    if (!running) _running = false;
    return running;
  }

  /// Rewrites the notification. Cheap enough to call once a second.
  Future<void> update({required String title, required String text}) async {
    if (!_running || !_isAndroid) return;
    if (_nativeOwned) {
      await _handsFree.notificationPower(active: _locationActive);
      await _handsFree.notificationUpdate(title: title, text: text);
      return;
    }
    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }

  Future<void> stop() async {
    if (!_isAndroid) return;
    _checkedAt = null;
    if (_nativeOwned) {
      await _handsFree.notificationStop();
      _nativeOwned = false;
      _running = false;
      return;
    }
    // Not gated on the flag: a service this object lost track of is still a
    // service, and the start after this stop would be refused as "already
    // started" with it in the way.
    if (!await FlutterForegroundTask.isRunningService) {
      _running = false;
      return;
    }
    final result = await FlutterForegroundTask.stopService();
    lastFailure = result is ServiceRequestFailure ? '${result.error}' : null;
    _running = await FlutterForegroundTask.isRunningService;
  }
}
