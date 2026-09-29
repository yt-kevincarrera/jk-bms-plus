import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/platform/alert_notifications.dart';

void main() {
  group('whether alerts will reach the shade', () {
    test('a refusal is a refusal', () {
      // The answer used to be thrown away and the channel called ready, so
      // the settings screen never said the permission had been refused.
      expect(AlertNotifications.notificationsAllowed(requested: false), isFalse);
      expect(
        AlertNotifications.notificationsAllowed(requested: true, enabled: false),
        isFalse,
      );
    });

    test('granted, or nothing to ask on an older Android, is allowed', () {
      expect(
        AlertNotifications.notificationsAllowed(requested: true, enabled: true),
        isTrue,
      );
      expect(AlertNotifications.notificationsAllowed(), isTrue);
    });

    test('nothing is ready before it has been set up', () {
      final n = AlertNotifications();
      expect(n.isReady, isFalse);
      expect(n.permissionDenied, isFalse);
    });

    test('the alert channels are new, so they can vibrate', () {
      // A channel's vibration is fixed when it is created, and the old one
      // was created without any.
      expect(AlertNotifications.channelId, isNot('jk_bms_alerts'));
      expect(AlertNotifications.quietChannelId, isNot('jk_bms_alerts'));
      expect(AlertNotifications.vibrationPattern, isNotEmpty);
    });
  });
}
