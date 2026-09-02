import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/link_quiet.dart';

void main() {
  final t0 = DateTime.utc(2026, 9, 2, 8, 49);

  // Why this exists. The transport wrote a cell-info request every five
  // seconds, unconditionally, and its own comment claimed to be "a nudge, not
  // a poll loop". A real ride cost 52 stretches of 20 seconds or more with no
  // cell info at all, most of them 27 to 33 seconds. In 48 of them frames were
  // still arriving, so the link was never down; what arrived was device-info
  // responses at two- to six-second intervals, in step with the poll.
  //
  // The pack streams cell info two or three times a second on its own. Writing
  // to it every five seconds while it does that is what appears to interrupt
  // it, so the nudge only goes out when the pack has genuinely gone silent.

  group('when to nudge a quiet pack', () {
    test('never, while it is streaming normally', () {
      // Two or three readings a second: the healthy case, and the one where a
      // write is pure interference.
      var at = t0;
      for (var i = 0; i < 200; i++) {
        at = at.add(const Duration(milliseconds: 350));
        expect(
          shouldNudge(lastHeardAt: at, now: at, quietBefore: const Duration(seconds: 6)),
          isFalse,
        );
      }
    });

    test('not for ordinary jitter either', () {
      // A couple of seconds between readings happens and is not silence.
      expect(
        shouldNudge(
          lastHeardAt: t0,
          now: t0.add(const Duration(seconds: 3)),
          quietBefore: const Duration(seconds: 6),
        ),
        isFalse,
      );
    });

    test('yes, once it has really stopped', () {
      expect(
        shouldNudge(
          lastHeardAt: t0,
          now: t0.add(const Duration(seconds: 7)),
          quietBefore: const Duration(seconds: 6),
        ),
        isTrue,
      );
    });

    test('yes, when nothing has ever been heard', () {
      // Just connected, or just reconnected. Something has to start the
      // stream, and that first request is the one the pack does need.
      expect(
        shouldNudge(
          lastHeardAt: null,
          now: t0,
          quietBefore: const Duration(seconds: 6),
        ),
        isTrue,
      );
    });

    test('exactly at the threshold is not yet silence', () {
      expect(
        shouldNudge(
          lastHeardAt: t0,
          now: t0.add(const Duration(seconds: 6)),
          quietBefore: const Duration(seconds: 6),
        ),
        isFalse,
      );
    });
  });
}
