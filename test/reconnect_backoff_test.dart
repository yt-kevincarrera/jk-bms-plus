import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/reconnect_backoff.dart';

void main() {
  // Why this exists. The transport's automatic reconnect retried every 400 ms,
  // for ever, with no backoff and no cap — while the connect screen next door
  // has ConnectGuard, whose own comment says that every failed attempt "is a
  // chance to leave a connection Android never closes" and that those
  // resources "are shared by the whole phone".
  //
  // The rider's report is the second half of that comment word for word:
  // reconnection commonly does not work, and going to the connect screen shows
  // a connect error. A loop hammering the stack all ride is the suspect.

  group('the first attempt after a drop', () {
    test('is still quick', () {
      // Not to be lost in the fix. 400 ms was measured and deliberate: a link
      // that merely dropped comes back at once, which turns a thirty-second
      // hole in the recording into a few seconds of one.
      final backoff = ReconnectBackoff();
      expect(backoff.nextDelay(), const Duration(milliseconds: 400));
    });
  });

  group('attempts that keep failing', () {
    test('are spaced further and further apart', () {
      final backoff = ReconnectBackoff();
      final delays = <Duration>[];
      for (var i = 0; i < 6; i++) {
        delays.add(backoff.nextDelay()!);
        backoff.recordFailure();
      }
      expect(delays, [
        const Duration(milliseconds: 400),
        const Duration(seconds: 1),
        const Duration(seconds: 2),
        const Duration(seconds: 4),
        const Duration(seconds: 8),
        const Duration(seconds: 16),
      ]);
    });

    test('never wait longer than the ceiling', () {
      // The doubling would be past ten minutes by the last attempt. A pack
      // that has been unreachable for minutes is not reached any sooner by
      // asking less often than this.
      final backoff = ReconnectBackoff();
      for (var i = 0; i < backoff.giveUpAfter - 1; i++) {
        expect(backoff.nextDelay(), isNot(greaterThan(backoff.maxDelay)));
        backoff.recordFailure();
      }
      expect(backoff.nextDelay(), backoff.maxDelay);
    });

    test('stop altogether once enough have failed in a row', () {
      // The point of the whole thing: stop feeding a stack that has run out.
      final backoff = ReconnectBackoff();
      for (var i = 0; i < backoff.giveUpAfter; i++) {
        expect(backoff.hasGivenUp, isFalse);
        backoff.recordFailure();
      }
      expect(backoff.hasGivenUp, isTrue);
      expect(backoff.nextDelay(), isNull);
    });

    test('give the ride long enough to close a real gap first', () {
      // A ride's own worst gap was 169 seconds and it closed on its own. Give
      // up before that and the fix breaks the thing that already worked.
      final backoff = ReconnectBackoff();
      var total = Duration.zero;
      while (!backoff.hasGivenUp) {
        total += backoff.nextDelay()!;
        backoff.recordFailure();
      }
      expect(total, greaterThan(const Duration(minutes: 3)));
    });
  });

  group('an attempt that works', () {
    test('puts the next drop back to a quick retry', () {
      final backoff = ReconnectBackoff();
      for (var i = 0; i < 4; i++) {
        backoff.recordFailure();
      }
      backoff.recordSuccess();
      expect(backoff.failures, 0);
      expect(backoff.nextDelay(), const Duration(milliseconds: 400));
    });
  });

  group('a rider who taps retry', () {
    test('gets one more go after it has given up', () {
      // Restarting Bluetooth, or walking back to the bike, is exactly what
      // makes the next attempt worth trying.
      final backoff = ReconnectBackoff();
      for (var i = 0; i < backoff.giveUpAfter; i++) {
        backoff.recordFailure();
      }
      backoff.forgive();
      expect(backoff.hasGivenUp, isFalse);
      expect(backoff.nextDelay(), const Duration(milliseconds: 400));
    });
  });
}
