import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The notifications that are meant to interrupt.
///
/// Separate from [LiveNotification] on purpose, and not just for tidiness.
/// That one is the foreground service: a quiet, low-importance readout that
/// sits in the shade for the length of a ride and must never make a sound.
/// This one is the opposite — a cell going out of range at three in the
/// morning while the pack charges in the garage is exactly the thing worth
/// waking somebody for, and Android will only do that from a channel created
/// with high importance in the first place. A channel's importance is fixed
/// when it is created, so it has to be its own channel.
///
/// Everything here fails soft. A phone that refuses the permission, an old
/// Android, a plugin that throws on a device nobody has tested: none of that
/// is worth taking the app down for, and the alert still reaches the screen
/// and the haptics either way.
class AlertNotifications {
  AlertNotifications({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const String channelId = 'jk_bms_alerts';

  /// Away from the foreground service's id, which is 5510.
  static const int _baseId = 5600;

  bool _ready = false;

  /// Whether the last attempt to set up or post worked. Read by the settings
  /// screen so a refused permission can be said out loud rather than leaving
  /// the rider believing alerts will arrive.
  bool get isReady => _ready;

  /// Creates the channel and asks for permission. Safe to call repeatedly.
  ///
  /// Returns false when notifications will not reach the rider, for whatever
  /// reason. Callers are expected to carry on regardless.
  Future<bool> ensureReady({
    required String channelName,
    required String channelDescription,
  }) async {
    if (_ready) return true;
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        await android.createNotificationChannel(
          AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDescription,
            // The whole point of this class. A charge finishing overnight or
            // a cell falling off a cliff has to be able to light the screen.
            importance: Importance.high,
          ),
        );
        // Android 13 and later. A refusal is an answer: the app carries on
        // with banners and haptics and does not ask again.
        await android.requestNotificationsPermission();
      }
      _ready = true;
      return true;
    } on Object {
      _ready = false;
      return false;
    }
  }

  /// Posts one alert.
  ///
  /// [key] is the alert's own name, so the same alert firing twice replaces
  /// its own notification instead of stacking a pile of them in the shade.
  Future<void> show({
    required String key,
    required String title,
    required String body,
    bool critical = false,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: _idFor(key),
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelId,
            importance: Importance.high,
            priority: critical ? Priority.max : Priority.high,
            // A pack fault is worth a second look at the lock screen; a
            // charge finishing is not worth a permanent one.
            category: critical
                ? AndroidNotificationCategory.alarm
                : AndroidNotificationCategory.status,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } on Object {
      // Nothing to do about it, and nothing worth crashing a ride over.
    }
  }

  /// Clears one alert's notification, for when the thing it warned about is
  /// over.
  Future<void> clear(String key) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _idFor(key));
    } on Object {
      // As above.
    }
  }

  /// A stable id per alert name, so repeats replace rather than stack.
  ///
  /// A hash rather than a counter: the ids have to survive the app being
  /// restarted, or a second run would pile a duplicate on top of whatever is
  /// already showing.
  static int _idFor(String key) {
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = (hash * 31 + unit) & 0x3FF;
    }
    return _baseId + hash;
  }
}
