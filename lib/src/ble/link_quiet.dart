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
