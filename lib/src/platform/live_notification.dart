import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

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
  LiveNotification();

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
    if (_initialised || !Platform.isAndroid) return;
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
    if (!Platform.isAndroid) return true;
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
    if (!Platform.isAndroid) return true;
    // Asked of Android, not of the flag. The flag only knew what this object
    // had done, and Android also stops services on its own (a dataSync one
    // after six hours on Android 15): a flag still saying "running" made this
    // return true for a service that was gone, and a ride went without one.
    if (_running && await FlutterForegroundTask.isRunningService) return true;

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
    _running = result is ServiceRequestSuccess;
    lastFailure = result is ServiceRequestFailure ? '${result.error}' : null;
    return _running;
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
    if (!Platform.isAndroid) return true;
    if (!_running) return false;
    final now = DateTime.now();
    final last = _checkedAt;
    if (last != null && now.difference(last) < const Duration(seconds: 30)) {
      return true;
    }
    _checkedAt = now;
    final running = await FlutterForegroundTask.isRunningService;
    if (!running) _running = false;
    return running;
  }

  /// Rewrites the notification. Cheap enough to call once a second.
  Future<void> update({required String title, required String text}) async {
    if (!_running || !Platform.isAndroid) return;
    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }

  Future<void> stop() async {
    if (!Platform.isAndroid) return;
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
