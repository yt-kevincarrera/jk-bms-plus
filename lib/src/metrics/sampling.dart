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
