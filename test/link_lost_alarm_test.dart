import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/link_lost_alarm.dart';

void main() {
  final t0 = DateTime.utc(2026, 9, 7, 9, 0);

  // Why this exists. "The link went down" used to be posted on every
  // connected-to-not-connected transition, with no wait and no condition
  // beyond a setting that is on by default and means something else
  // (linkWatchEnabled is the foreground service, not a request for alerts).
  //
  // A real ride: 26 gaps in 21 minutes, the largest 169 seconds, every one of
  // them recovered on its own. That is 26 high-importance notifications with
  // the alarm category, on a phone in a jacket pocket, for a link that was
  // never going to stay down. The rider's word for it was "extremadamente
  // molesta", and they were right.

  group('a link that drops mid-ride', () {
    test('says nothing while a ride is being recorded', () {
      // The whole 26-in-21-minutes case. Riding is when the link flaps by
      // design: the phone is in a pocket, the pack is under the seat, and the
      // app recovers on its own every time.
      const alarm = LinkLostAlarm();
      expect(
        alarm.shouldWarn(
          downSince: t0,
          now: t0.add(const Duration(minutes: 30)),
          riding: true,
          alreadyWarned: false,
        ),
        isFalse,
      );
    });

    test('says nothing for a gap that closes inside the grace period', () {
      // 169 seconds was the worst gap on that ride, but the ordinary ones
      // were seconds. Nothing that heals itself is worth waking anybody for.
      const alarm = LinkLostAlarm();
      expect(
        alarm.shouldWarn(
          downSince: t0,
          now: t0.add(const Duration(seconds: 90)),
          riding: false,
          alreadyWarned: false,
        ),
        isFalse,
      );
    });
  });

  group('a link that stays down', () {
    test('warns once the grace period has passed', () {
      // The case the notification was written for: left overnight watching a
      // charge, and the app stopped looking four hours ago.
      const alarm = LinkLostAlarm();
      expect(
        alarm.shouldWarn(
          downSince: t0,
          now: t0.add(const Duration(minutes: 2)),
          riding: false,
          alreadyWarned: false,
        ),
        isTrue,
      );
    });

    test('warns only once per outage', () {
      const alarm = LinkLostAlarm();
      expect(
        alarm.shouldWarn(
          downSince: t0,
          now: t0.add(const Duration(hours: 4)),
          riding: false,
          alreadyWarned: true,
        ),
        isFalse,
      );
    });

    test('says nothing while the link is up', () {
      const alarm = LinkLostAlarm();
      expect(
        alarm.shouldWarn(
          downSince: null,
          now: t0,
          riding: false,
          alreadyWarned: false,
        ),
        isFalse,
      );
    });
  });
}
