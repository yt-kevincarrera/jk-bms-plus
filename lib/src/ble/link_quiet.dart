/// Whether the pack has gone quiet long enough to be worth writing to.
///
/// Its own function so it can be tested without a radio, because the rule it
/// replaced was not a rule at all: the transport wrote a cell-info request
/// every five seconds regardless, while its own comment claimed to be "a
/// nudge, not a poll loop".
///
/// What that cost, measured on a real ride: 52 stretches of 20 seconds or more
/// with no cell info, most of them 27 to 33 seconds. In 48 of them frames were
/// still arriving, so the link was never down. What arrived during them was
/// device-info responses at two- to six-second intervals, in step with the
/// poll. The pack streams cell info two or three times a second on its own,
/// and being written to every five seconds while it does that is what appears
/// to interrupt it.
///
/// [lastHeardAt] null means nothing has arrived yet, which is the one case
/// that genuinely needs a request: something has to start the stream.
bool shouldNudge({
  required DateTime? lastHeardAt,
  required DateTime now,
  required Duration quietBefore,
}) {
  if (lastHeardAt == null) return true;
  return now.difference(lastHeardAt) > quietBefore;
}

/// How long a connected link may go without a reading before the screen says
/// so.
///
/// Well under the twenty seconds the transport gives a mute link before
/// letting go, and well over the two or three seconds a healthy pack may pause
/// for. The rider's report was a link that came back, a banner that went
/// away, and cells frozen at the last reading with nothing on screen saying
/// they were old; ten seconds is early enough that the freeze is never taken
/// for a live reading, and late enough that ordinary jitter never colours the
/// screen.
const Duration staleReadingAfter = Duration(seconds: 10);

/// Whether the reading on screen is old enough to be called out.
///
/// Null means no reading has ever arrived, and nothing on screen can be stale.
/// That wait belongs to the connect screen, which says something more specific
/// about it.
bool readingIsStale({
  required DateTime? lastReadingAt,
  required DateTime now,
  Duration after = staleReadingAfter,
}) {
  if (lastReadingAt == null) return false;
  return now.difference(lastReadingAt) > after;
}
