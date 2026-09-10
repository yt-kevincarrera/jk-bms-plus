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
}
