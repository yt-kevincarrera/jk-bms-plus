import 'dart:math' as math;

/// How long the automatic reconnect should wait, and when it should stop.
///
/// The transport used to retry every 400 ms, for ever, with nothing counting
/// the failures. Next door, the connect screen has [ConnectGuard], and that
/// class's own comment explains why the loop was a bad idea: every failed
/// attempt "is a chance to leave a connection Android never closes", the
/// plugin needs the disconnect callback before it can close the GATT client,
/// and without that close "we will quickly run out of bluetooth resources,
/// preventing new connections" — resources shared by the whole phone.
///
/// That is the rider's report, arrived at from the other end: reconnection
/// commonly does not work, and going to the connect screen then shows a
/// connect error. A tap was already protected from doing this. The loop
/// running unattended for a whole ride was not.
///
/// Same idea as [ConnectGuard], different question. That one answers "may this
/// tap become an attempt"; this one answers "how long until the next one, and
/// is there any point". Kept separate rather than shared because the first
/// retry after a plain drop must stay fast, and a tap's first retry must not.
class ReconnectBackoff {
  ReconnectBackoff({
    this.firstDelay = const Duration(milliseconds: 400),
    this.growFrom = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 40),
    this.giveUpAfter = 12,
  });

  /// The pause before the first attempt after a link that was up went down.
  ///
  /// Not to be lost in the fix. 400 ms was measured and deliberate: a link
  /// that merely dropped comes back at once, which turns a thirty-second hole
  /// in the recording into a few seconds of one. The backoff below only starts
  /// once an attempt has actually failed, which is a different situation.
  final Duration firstDelay;

  /// Where the doubling starts, once the quick retry has failed.
  final Duration growFrom;

  /// The ceiling. A pack that has been unreachable for minutes is not going to
  /// be reached any sooner by asking more often.
  final Duration maxDelay;

  /// Consecutive failures after which there is no point asking again.
  ///
  /// Twelve, which sounds like a lot and is the point. The schedule below
  /// spends about four and a half minutes waiting across those twelve, plus
  /// the attempts themselves: roughly six minutes of trying before the app
  /// stops and says so. A real ride's worst gap was 169 seconds and it closed
  /// on its own, so anything tighter would break the recovery that already
  /// works in order to fix the one that does not.
  final int giveUpAfter;

  int _failures = 0;

  /// Failures in a row, with no reading in between.
  int get failures => _failures;

  /// Whether the loop has stopped. The screen says so and offers a retry;
  /// nothing here starts again on its own.
  bool get hasGivenUp => _failures >= giveUpAfter;

  /// How long to wait before the next attempt, or null once there is no next
  /// attempt.
  Duration? nextDelay() {
    if (hasGivenUp) return null;
    if (_failures == 0) return firstDelay;
    final grown = growFrom * math.pow(2, _failures - 1).toDouble();
    return grown > maxDelay ? maxDelay : grown;
  }

  /// [nextDelay], but never shorter than [floor].
  ///
  /// For a caller that knows something about *this* retry that the ledger does
  /// not: letting go of a mute link and coming straight back gives the module
  /// no time to notice it was let go, so that path names three seconds. What
  /// it must not do is name a delay *instead of* asking, which is what it used
  /// to do -- that skipped [hasGivenUp] as well, and a loop that never asks
  /// whether to stop never stops.
  Duration? nextDelayAtLeast(Duration? floor) {
    final grown = nextDelay();
    if (grown == null || floor == null) return grown;
    return floor > grown ? floor : grown;
  }

  void recordFailure() => _failures++;

  /// The pack answered. Everything the failures implied is disproved.
  void recordSuccess() => _failures = 0;

  /// Clears the ledger because the rider asked for another go. Restarting
  /// Bluetooth, or walking back to the bike, is exactly what makes the next
  /// attempt worth trying.
  void forgive() => _failures = 0;
}
