import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/link_lost_alarm.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/platform/alert_notifications.dart';

import 'support/fakes.dart';

/// Records what would have reached the shade, instead of reaching it.
class RecordingAlerts extends AlertNotifications {
  final List<String> shown = [];
  final List<String> cleared = [];

  @override
  bool get isReady => true;

  @override
  Future<bool> ensureReady({
    required String channelName,
    required String channelDescription,
  }) async => true;

  @override
  Future<void> show({
    required String key,
    required String title,
    required String body,
    bool critical = false,
  }) async => shown.add(key);

  @override
  Future<void> clear(String key) async => cleared.add(key);
}

void main() {
  // The rider's report: the disconnect notification "se lanza super seguido
  // cuando estoy rodando y es extremadamente molesta". A backup of a real ride
  // says why — 26 gaps in 21 minutes, every one of them closed by the app on
  // its own — and the old code posted one notification per gap, at once.

  late RecordingAlerts alerts;
  late FakeLink link;
  late BmsService service;

  setUp(() {
    alerts = RecordingAlerts();
    link = FakeLink();
    service = BmsService(transport: link)
      ..alertNotifications = alerts
      ..notifyAlerts = true
      ..linkWatchEnabled = true
      ..linkLostText = (() => ('Se perdió la conexión', 'algo'))
      // Milliseconds rather than minutes, so the test does not sit through
      // the real wait. The rule itself is covered in link_lost_alarm_test.
      ..linkLostAlarm = const LinkLostAlarm(
        graceBefore: Duration(milliseconds: 20),
      );
  });

  tearDown(() async => service.dispose());

  test('says nothing in the first moments of a gap', () async {
    // The link is still down when this asserts. What stops the notification
    // here is the wait itself, not the link coming back.
    service.linkLostAlarm = const LinkLostAlarm(
      graceBefore: Duration(milliseconds: 400),
    );
    link.announce(BleLinkState.connected);
    await pumpEventQueue();
    link.announce(BleLinkState.reconnecting);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(alerts.shown, isEmpty);
  });

  test('a gap that closes on its own never reaches the shade', () async {
    link.announce(BleLinkState.connected);
    await pumpEventQueue();
    link.announce(BleLinkState.reconnecting);
    await pumpEventQueue();

    // Back before the grace period is up, the way every gap on that ride was.
    link.announce(BleLinkState.connected);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(alerts.shown, isEmpty);
  });

  test('a link that stays down is still reported', () async {
    // The case the notification exists for: a charge left overnight, and the
    // app stopped looking hours ago.
    link.announce(BleLinkState.connected);
    await pumpEventQueue();
    link.announce(BleLinkState.reconnecting);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(alerts.shown, [BmsService.linkLostAlertKey]);
  });

  test('is reported once, not once per attempt', () async {
    link.announce(BleLinkState.connected);
    await pumpEventQueue();
    link.announce(BleLinkState.reconnecting);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    // The transport cycles reconnecting, connecting, failed, over and over
    // while it retries. None of that is a new outage.
    link.announce(BleLinkState.connecting);
    link.announce(BleLinkState.failed);
    link.announce(BleLinkState.reconnecting);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(alerts.shown, [BmsService.linkLostAlertKey]);
  });

  test('is taken back down once the pack answers again', () async {
    link.announce(BleLinkState.connected);
    await pumpEventQueue();
    link.announce(BleLinkState.reconnecting);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(alerts.shown, isNotEmpty);

    link.announce(BleLinkState.connected);
    await pumpEventQueue();

    expect(alerts.cleared, contains(BmsService.linkLostAlertKey));
  });
}
