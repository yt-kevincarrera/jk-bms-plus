import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/first_contact.dart';

void main() {
  final tap = DateTime.utc(2026, 9, 3, 4, 17);
  Duration s(int seconds) => Duration(seconds: seconds);

  // Why this exists. The connect screen gave every attempt fourteen seconds
  // from the tap to produce a snapshot and called anything slower "almost
  // certainly not a JK BMS". A rider's own pack, advertising the JK service,
  // got that verdict on every tap. Three things were wrong with the rule, and
  // each test below pins one of them.

  FirstContact fresh() => FirstContact(startedAt: tap, bytesBefore: 1000);

  group('the link clock', () {
    test('does not start on the pack until the link exists', () {
      // A connect that fails once (eight seconds, the transport's cap) and
      // succeeds on the retry is a slow link, not a headset. Under the old
      // rule it had fourteen seconds in total and lost.
      final c = fresh();
      expect(c.judge(tap.add(s(14))), isNull);
      c.onLinkState(BleLinkState.connected, tap.add(s(16)));
      expect(c.judge(tap.add(s(20))), isNull);
      c.onDecoded();
      expect(c.judge(tap.add(s(21))), FirstContactOutcome.proven);
    });

    test('gives up on a link that never comes up, and says only that', () {
      final c = fresh();
      c.onLinkState(BleLinkState.connecting, tap);
      c.onLinkState(BleLinkState.failed, tap.add(s(8)));
      c.onLinkState(BleLinkState.connecting, tap.add(s(9)));
      expect(c.judge(tap.add(s(24))), isNull);
      expect(
        c.judge(tap.add(s(25))),
        FirstContactOutcome.linkNeverCameUp,
      );
    });
  });

  group('what counts as proof', () {
    test('device info alone opens the door', () {
      // The service holds cell info back until device info has named the
      // protocol variant. A pack whose variant the detector cannot place
      // never yields a snapshot, and the screen to pick the variant by hand
      // was behind the door the old rule kept shut.
      final c = fresh();
      c.onLinkState(BleLinkState.connected, tap.add(s(3)));
      c.onDecoded();
      expect(c.judge(tap.add(s(3))), FirstContactOutcome.proven);
    });

    test('proof arriving after the deadline still counts', () {
      // The judge is asked, not told: a frame decoded a moment before the
      // question must never lose to the clock.
      final c = fresh();
      c.onLinkState(BleLinkState.connected, tap.add(s(2)));
      c.onDecoded();
      expect(c.judge(tap.add(s(60))), FirstContactOutcome.proven);
    });
  });

  group('silence is told apart from noise', () {
    test('connected and mute for the silence budget', () {
      final c = fresh();
      c.onLinkState(BleLinkState.connected, tap.add(s(5)));
      expect(c.judge(tap.add(s(16))), isNull);
      expect(
        c.judge(tap.add(s(17))),
        FirstContactOutcome.connectedButSilent,
      );
    });

    test('bytes that never decode are a different failure', () {
      final c = fresh();
      c.onLinkState(BleLinkState.connected, tap.add(s(5)));
      c.onBytesTotal(1240);
      expect(c.bytesHeard, 240);
      expect(
        c.judge(tap.add(s(17))),
        FirstContactOutcome.talkingButUndecoded,
      );
    });

    test('bytes from before this attempt do not count', () {
      // The decoder's counter runs across connections. An earlier pack's
      // traffic must not make a mute one look talkative.
      final c = fresh();
      c.onLinkState(BleLinkState.connected, tap.add(s(5)));
      c.onBytesTotal(1000);
      expect(c.bytesHeard, 0);
      expect(
        c.judge(tap.add(s(17))),
        FirstContactOutcome.connectedButSilent,
      );
    });

    test('a drop after connecting does not restart the silence clock', () {
      final c = fresh();
      c.onLinkState(BleLinkState.connected, tap.add(s(5)));
      c.onLinkState(BleLinkState.reconnecting, tap.add(s(9)));
      c.onLinkState(BleLinkState.connected, tap.add(s(12)));
      expect(c.connectedAt, tap.add(s(5)));
      expect(
        c.judge(tap.add(s(17))),
        FirstContactOutcome.connectedButSilent,
      );
    });
  });
}
