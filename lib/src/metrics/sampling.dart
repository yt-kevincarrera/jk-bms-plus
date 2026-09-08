/// The gap between two readings, or null when nothing can be integrated
/// across it.
///
/// This exists because of a bug that silently threw away almost every reading
/// this app took, in three separate places, for the same reason: each one
/// guarded its integration with `dt.inSeconds <= 0`.
///
/// `inSeconds` truncates. A JK BMS pushes two or three cell-info frames a
/// second, so the real gap between readings is 300 to 500 ms, and
/// `inSeconds` is **zero for every single one of them**. Each site then
/// returned early, having already advanced its anchor, so the energy for that
/// interval was not deferred, it was gone. The only intervals that survived
/// were the accidents: the handful that happened to straddle a whole second,
/// usually because the Bluetooth link had briefly dropped.
///
/// A real 22 km ride recorded 4.3 Wh. The pack's own coulomb counter said 102.
/// Everything downstream inherited it and behaved exactly as designed on
/// nonsense input: consumption came out at 0.7 Wh/km, and the range
/// estimator's own sanity check rejected every sample for being under
/// 2 Wh/km, which is why eight recorded rides taught it nothing at all.
///
/// So: milliseconds, one implementation, and a name that says what the
/// question is.
Duration? usableInterval(
  DateTime from,
  DateTime to, {
  Duration maxGap = const Duration(seconds: 10),
}) {
  final dt = to.difference(from);
  // Zero or negative: the same reading twice, or a clock that went backwards.
  if (dt <= Duration.zero) return null;
  // A gap this long is a dropped link, not a long slow stretch of riding.
  // Integrating a straight line across it would invent whatever the bike
  // happened to be doing at each end.
  if (dt > maxGap) return null;
  return dt;
}

/// Hours in a duration, at full resolution.
///
/// The other half of the same mistake: `inSeconds / 3600` on a 400 ms sample
/// is zero. Only `inMicroseconds` is safe at these intervals.
double hoursIn(Duration d) => d.inMicroseconds / 3600000000.0;

/// How much of a ride may go unwatched before the readings taken during it
/// stop being a measurement of it.
///
/// Three minutes at a real 17 Wh/km and 25 km/h is about 21 Wh: around 5% of a
/// 22 km ride, and small enough to ignore. It is also loose enough to cover
/// the ordinary slop between a ride's own start and stop and the readings
/// nearest them.
const Duration counterEdgeTolerance = Duration(minutes: 3);

/// Whether readings spanning [firstReading] to [lastReading] actually cover a
/// ride that lasted [rideDuration].
///
/// This is the guard the coulomb counter was always missing, and the reason it
/// is needed is the same reason the counter is preferred in the first place.
///
/// The BMS accumulates amp-hours inside itself, so a dropped link costs its
/// figure nothing: whatever passed while the phone was deaf is still in the
/// difference between the reading before the gap and the one after it. One
/// real ride blacked out for 63 of its 108 minutes and still measured
/// correctly, which is why the gaps inside a ride are not counted here.
///
/// What the counter cannot do is measure a stretch of the ride it was never
/// read across. A link that died a minute into a 53-minute ride leaves a
/// difference that measures that one minute -- 0.13 Ah -- and attributing it
/// to the whole ride reported 0.5 Wh/km on a bike that really does 17. The
/// figure was not noisy or approximate; it was a measurement of a different,
/// much shorter journey. Worse, it looked authoritative, so nothing
/// downstream ever questioned it.
///
/// So what matters is how much of the ride falls outside the readings
/// altogether, which is the ride's own duration less the span the readings
/// cover. Comparing the two ends against the ride's clock directly would mean
/// subtracting a BMS timestamp from a wall-clock one; this way each clock is
/// only ever compared with itself.
///
/// Readings from either side of the ride -- what the bracketing repair finds
/// -- span more than the ride lasted, which is better than covered, not worse.
bool readingsCoverRide({
  required Duration rideDuration,
  required DateTime firstReading,
  required DateTime lastReading,
  Duration tolerance = counterEdgeTolerance,
}) =>
    rideDuration - lastReading.difference(firstReading) <= tolerance;
