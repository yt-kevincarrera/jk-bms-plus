/// What the app decided, in the vocabulary of the questions it has to answer.
///
/// Three problems were open at once with nothing to go on, all of them only
/// reproducible on a moving motorcycle with the phone in a pocket:
///
///  * a ride that never started itself,
///  * a link that dropped mid-ride and never came back,
///  * a phone that sometimes had to be restarted before it would connect.
///
/// Each was argued from the source, and the first confident answer, a missing
/// background location permission, was wrong: the rider granted it and nothing
/// changed. This enum exists so the next answer comes from a record instead of
/// an argument.
///
/// Each value earns its place by ruling something in or out. Nothing here is
/// logged because it might be interesting.
enum LinkEventKind {
  // --- Why a ride did or did not start itself ---

  /// The detector saw enough current to believe the bike is working, and
  /// started waiting for movement to agree. Detail carries the amps.
  ///
  /// Its absence answers the first question outright: no current, no ride, and
  /// the fault is upstream of anything to do with GPS.
  ridingCurrentSeen,

  /// A fresh fix arrived while no ride was open. Detail carries the speed.
  ///
  /// The pair of this and [ridingCurrentSeen] is what a start needs, sustained
  /// for twenty seconds. Seeing one and never the other says which half fails,
  /// and seeing both says the timing is what fails.
  idleSpeedSeen,

  /// The GPS was switched on because the pack started drawing.
  locationArmed,

  /// And switched off again, because it stopped.
  locationStoodDown,

  /// Location refused to start. Detail carries which problem.
  locationRefused,

  /// A ride has been recording with no GPS fix for a while. Detail carries
  /// how long, the fixes seen so far, and the last one's age.
  tripWithoutFixes,

  /// The location stream reported an error. Detail carries it.
  locationStreamError,

  /// Android refused to start the foreground service. Detail carries which
  /// claim wanted it and whether it was location-typed.
  foregroundServiceRefused,

  /// The service this app held was found stopped by Android. Detail carries
  /// which claim held it.
  foregroundServiceLost,

  /// A ride opened itself.
  autoTripStarted,

  /// A ride closed itself. Detail says which rule fired: stillness, or the
  /// long fuse for a pack that went quiet with no fix to judge it by.
  autoTripStopped,

  /// The detector wanted to open a ride and could not. Detail carries why.
  autoTripBlocked,

  // --- What the link did ---

  /// A reading decoded. Written once on the first one after a gap rather than
  /// per reading: at two or three a second, one row each would bury everything
  /// else here and answer nothing that [Snapshots] does not already answer.
  /// Detail carries how long the gap was.
  readingsResumed,

  /// The link went down. Detail carries how long it had been up.
  linkDropped,

  /// The link was up and silent, so the app let go of it deliberately.
  muteLinkReleased,

  /// A reconnect attempt was made. Detail carries which attempt in the run.
  ///
  /// This is the row that settles the third question. If a phone needing a
  /// restart correlates with a long run of these, the app's own retrying is
  /// the suspect, exactly as the transport's comments fear.
  reconnectAttempted,

  /// An attempt failed. Detail carries the error.
  reconnectFailed,

  /// The loop stopped trying. Off the bike this is correct and the screen says
  /// so; during a ride it is the bug that cost whole rides.
  reconnectGaveUp,

  /// The loop was told a ride is in progress and it may not give up.
  reconnectPersisting,

  /// And told the ride is over, so the usual rules apply again.
  reconnectRelaxed,

  // --- Why the phone would not connect ---
  //
  // For the morning a phone restart was the only fix. Each attempt says what
  // the app could see before it, so a backup can tell a pack that was not
  // advertising (it thought it was still connected) from one that was and
  // could not be reached (the phone was the problem).

  /// One connect attempt, first or retry, on the connect screen or in the
  /// reconnect loop. Detail carries the outcome and how long it took, its
  /// number in the streak, what was done before it, whether and how loudly
  /// the pack was heard advertising, what the plugin and Android list as
  /// connected, the adapter state, process uptime and time since the last
  /// success. At most 30 an hour; the row after a gap says how many were
  /// skipped.
  connectAttempt,

  /// Enough attempts in a row failed that the phone, not the pack, is the
  /// suspect, and the rider was shown what to try.
  bluetoothLooksStuck,

  /// One of those steps was taken, or the app saw it happen: the in-app
  /// reset, Bluetooth switched off, the app restarted, the phone rebooted.
  bluetoothRemedy,

  /// The first connection after the phone looked stuck. Detail says what had
  /// been tried by then, which is the answer: app-side or Android-side.
  bluetoothRecovered,

  // --- Which protocol the pack speaks ---

  /// The bytes said the pack speaks another brand than the one chosen, and
  /// the app switched. Detail carries from and to.
  protocolSwitched,

  /// The ANT assembler threw a buffer away. Detail carries the reason and the
  /// hex, so a decoding mistake can be fixed from a backup. At most 20 per
  /// connection.
  antFrameRejected,

  /// An ANT frame passed its CRC and still could not be decoded. Detail
  /// carries the error and the hex.
  antDecodeFailed,

  /// Bytes starting AA 55 AA FF arrived: the pre-2021 ANT protocol, which the
  /// app does not read yet.
  oldAntProtocolSeen,

  /// The JK assembler threw bytes away: a frame that failed its checksum, or,
  /// before anything on the connection has framed, bytes that never became a
  /// frame. Detail carries the reason and the hex, as [antFrameRejected]
  /// does for ANT. Shares ANT's budget of 20 per connection.
  ///
  /// Exists because a JK that never decodes never becomes an active pack,
  /// and raw frames are only kept for an active one: the connect that most
  /// needed its bytes read afterwards was the one that kept none.
  jkFrameRejected,

  /// A checksum-valid JK frame whose record type the app has no decoder for,
  /// or one the parser refused. Detail carries the type or the error, and the
  /// hex.
  jkFrameUndecoded,

  /// An ANT reported its current with the opposite sign to its own battery
  /// state for several frames running, and the app reversed it for that
  /// pack from then on. Detail carries the state and the raw current that
  /// settled it. Written once per pack per session.
  antCurrentSignInverted,
}

/// The kind a stored row names, or null for a name this build does not know
/// (a row written by a newer version, or by an older one whose kind was
/// since retired). Rows are stored by name precisely so this can be asked.
LinkEventKind? linkEventKindNamed(String name) {
  for (final k in LinkEventKind.values) {
    if (k.name == name) return k;
  }
  return null;
}

/// A row's detail split into its words and the bytes it carries, if any.
///
/// The frame-rejection kinds write the bytes as one run of hex after the
/// reason, which on a screen is a wall of characters burying the reason. A
/// run of at least eight bytes of hex is taken as that; anything shorter is
/// left in the text, where a checksum or a code belongs.
({String text, String? hex}) splitLinkEventDetail(String detail) {
  final match = _hexRun.firstMatch(detail);
  if (match == null) return (text: detail, hex: null);
  final hex = match.group(0)!;
  final text = (detail.substring(0, match.start) + detail.substring(match.end))
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
  return (text: text, hex: hex);
}

final RegExp _hexRun = RegExp(
  r'(?<![0-9A-Za-z])(?:[0-9a-fA-F]{2}){8,}(?![0-9A-Za-z])',
);

/// Hex as pairs, sixteen to a line, the way the console prints bytes.
String spacedHex(String hex) {
  final pairs = [
    for (var i = 0; i + 1 < hex.length; i += 2) hex.substring(i, i + 2),
  ];
  final lines = <String>[];
  for (var i = 0; i < pairs.length; i += 16) {
    lines.add(pairs.skip(i).take(16).join(' ').toUpperCase());
  }
  return lines.join('\n');
}
