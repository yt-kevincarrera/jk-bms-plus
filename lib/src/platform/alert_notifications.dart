import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The notifications that are meant to interrupt.
///
/// Separate from [LiveNotification] on purpose, and not just for tidiness.
/// That one is the foreground service: a quiet, low-importance readout that
/// sits in the shade for the length of a ride and must never make a sound.
/// This one is the opposite: a cell going out of range at three in the
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

  /// The channel that vibrates. A new id, because a channel's vibration is
  /// fixed when it is created just like its importance, and the old
  /// `jk_bms_alerts` channel was created without any: the in-app haptic buzz
  /// needs a visible view, so with the screen off or the phone in a pocket
  /// the "vibrate with alerts" setting did nothing at all.
  static const String channelId = 'jk_bms_alerts_vibrate';

  /// The same, for a rider who switched vibration off: Android will not
  /// silence one notification on a vibrating channel, so it takes a second.
  static const String quietChannelId = 'jk_bms_alerts_quiet';

  /// The channel every earlier version created. Removed, so the phone's
  /// notification settings do not list a channel nothing posts to.
  static const String _legacyChannelId = 'jk_bms_alerts';

  /// Short, strong, short: distinct from a message tone, felt through a
  /// pocket.
  static final Int64List vibrationPattern = Int64List.fromList([
    0,
    400,
    200,
    400,
  ]);

  /// Away from the foreground service's id, which is 5510.
  static const int _baseId = 5600;

  bool _ready = false;
  bool _permissionDenied = false;

  /// Whether the last attempt to set up or post worked. Read by the settings
  /// screen so a refused permission can be said out loud rather than leaving
  /// the rider believing alerts will arrive.
  bool get isReady => _ready;

  /// True when Android said no to notifications, as opposed to anything
  /// else going wrong.
  bool get permissionDenied => _permissionDenied;

  /// Whether notifications will reach the rider, from Android's two answers:
  /// the one to the permission request and whether notifications are enabled
  /// for the app at all. Either may be null on an Android that has no such
  /// question to ask (before 13 there is no runtime permission), and null is
  /// not a refusal. A refusal is.
  ///
  /// It used to ignore both: the request's answer was thrown away and the
  /// channel called ready, so a refusal never reached the settings screen,
  /// which went on promising alerts that Android was dropping.
  @visibleForTesting
  static bool notificationsAllowed({bool? requested, bool? enabled}) =>
      requested != false && enabled != false;

  /// Creates the channels and asks for permission. Safe to call repeatedly.
  ///
  /// Returns false when notifications will not reach the rider, for whatever
  /// reason. Callers are expected to carry on regardless.
  Future<bool> ensureReady({
    required String channelName,
    required String channelDescription,
    String? quietChannelName,
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
            enableVibration: true,
            vibrationPattern: vibrationPattern,
          ),
        );
        await android.createNotificationChannel(
          AndroidNotificationChannel(
            quietChannelId,
            quietChannelName ?? channelName,
            description: channelDescription,
            importance: Importance.high,
            enableVibration: false,
          ),
        );
        try {
          await android.deleteNotificationChannel(channelId: _legacyChannelId);
        } on Object {
          // Nothing to remove on a fresh install.
        }
        // Android 13 and later. The answer is kept: a refusal means nothing
        // posted here will be seen, and the screen has to say so.
        final requested = await android.requestNotificationsPermission();
        final enabled = await android.areNotificationsEnabled();
        final allowed = notificationsAllowed(
          requested: requested,
          enabled: enabled,
        );
        _permissionDenied = !allowed;
        _ready = allowed;
        return allowed;
      }
      _permissionDenied = false;
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
  /// [vibrate] picks the channel: the rider's "vibrate with alerts" setting,
  /// which is what makes a pocketed phone buzz.
  Future<void> show({
    required String key,
    required String title,
    required String body,
    bool critical = false,
    bool vibrate = true,
  }) async {
    if (!_ready) return;
    try {
      final channel = vibrate ? channelId : quietChannelId;
      await _plugin.show(
        id: _idFor(key),
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel,
            channel,
            importance: Importance.high,
            priority: critical ? Priority.max : Priority.high,
            enableVibration: vibrate,
            vibrationPattern: vibrate ? vibrationPattern : null,
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
