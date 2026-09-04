import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/connect_guard.dart';

void main() {
  final t0 = DateTime.utc(2026, 9, 4, 9, 0);
  const a = 'AA:BB:CC:DD:EE:01';
  const b = 'AA:BB:CC:DD:EE:02';

  // Why this exists. The rider's habit was to tap, get nothing, and tap again,
  // ten or fifteen times, until one attempt landed. That habit is the thing
  // that broke his phone's Bluetooth: every cancelled attempt can leave a
  // connection Android never closes, the pool of them is shared by every app,
  // and when it ran dry even the official JK app hung on "connecting" until he
  // rebooted. So a tap is no longer free.

  group('one attempt at a time', () {
    test('a tap while an attempt is running is refused', () {
      final g = ConnectGuard();
      expect(
        g.judge(deviceId: a, now: t0, busy: true),
        TapVerdict.busy,
      );
    });

    test('and allowed once nothing is running', () {
      final g = ConnectGuard();
      expect(g.judge(deviceId: a, now: t0, busy: false), TapVerdict.go);
    });
  });

  group('the cooldown after a failure', () {
    test('holds the pack, then lets it go', () {
      final g = ConnectGuard()..recordFailure(deviceId: a, at: t0);
      expect(
        g.judge(deviceId: a, now: t0.add(const Duration(seconds: 4)), busy: false),
        TapVerdict.cooling,
      );
      expect(
        g.judge(deviceId: a, now: t0.add(const Duration(seconds: 6)), busy: false),
        TapVerdict.go,
      );
    });

    test('counts down, so the screen can say how long is left', () {
      final g = ConnectGuard()..recordFailure(deviceId: a, at: t0);
      expect(
        g.cooldownLeft(deviceId: a, now: t0.add(const Duration(seconds: 2)))!
            .inSeconds,
        3,
      );
      expect(
        g.cooldownLeft(deviceId: a, now: t0.add(const Duration(seconds: 9))),
        isNull,
      );
    });

    test('doubles with each further failure, up to the ceiling', () {
      final g = ConnectGuard();
      // A second failure in a row means something a moment will not fix.
      g.recordFailure(deviceId: a, at: t0);
      g.recordFailure(deviceId: a, at: t0);
      expect(g.cooldownLeft(deviceId: a, now: t0)!.inSeconds, 10);
      g.recordFailure(deviceId: a, at: t0);
      expect(g.cooldownLeft(deviceId: a, now: t0)!.inSeconds, 20);
      for (var i = 0; i < 8; i++) {
        g.recordFailure(deviceId: a, at: t0);
      }
      expect(g.cooldownLeft(deviceId: a, now: t0)!.inSeconds, 40);
    });

    test('is the tapped pack\'s own, not every pack\'s', () {
      final g = ConnectGuard()..recordFailure(deviceId: a, at: t0);
      expect(g.cooldownLeft(deviceId: b, now: t0), isNull);
    });
  });

  group('when the phone itself is the problem', () {
    test('failures across different packs still count together', () {
      // What runs out belongs to the phone, not to a pack, so a failure on the
      // neighbour's BMS is evidence about the same shared pool.
      final g = ConnectGuard();
      g.recordFailure(deviceId: a, at: t0);
      g.recordFailure(deviceId: b, at: t0);
      g.recordFailure(deviceId: a, at: t0);
      expect(g.saturated, isFalse);
      g.recordFailure(deviceId: b, at: t0);
      expect(g.saturated, isTrue);
      expect(g.consecutiveFailures, 4);
    });

    test('saturation refuses every pack, cooldown or not', () {
      final g = ConnectGuard();
      for (var i = 0; i < 4; i++) {
        g.recordFailure(deviceId: a, at: t0);
      }
      // A pack that never failed, hours later: still refused, because the next
      // attempt would spend a resource the phone has not got.
      expect(
        g.judge(
          deviceId: b,
          now: t0.add(const Duration(hours: 1)),
          busy: false,
        ),
        TapVerdict.saturated,
      );
    });

    test('and the refusal is lifted once, after the advice', () {
      // Restarting Bluetooth or the phone is what makes another attempt worth
      // trying, so the screen has to be able to offer one.
      final g = ConnectGuard();
      for (var i = 0; i < 4; i++) {
        g.recordFailure(deviceId: a, at: t0);
      }
      g.forgive();
      expect(g.saturated, isFalse);
      expect(g.judge(deviceId: a, now: t0, busy: false), TapVerdict.go);
    });
  });

  test('a reading disproves everything the failures implied', () {
    final g = ConnectGuard();
    for (var i = 0; i < 4; i++) {
      g.recordFailure(deviceId: a, at: t0);
    }
    g.recordSuccess(deviceId: a);
    expect(g.saturated, isFalse);
    expect(g.consecutiveFailures, 0);
    expect(g.cooldownLeft(deviceId: a, now: t0), isNull);
  });
}
