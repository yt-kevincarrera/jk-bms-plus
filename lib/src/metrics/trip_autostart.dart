/// What the detector thinks should happen.
enum AutoTripAction { none, start, stop }

/// Decides when a ride has begun and when it has ended, from the pack and the
/// GPS.
///
/// The point is that the learning stops depending on anybody remembering to
/// press start. Consumption is learned from recorded rides, so a ride nobody
/// recorded teaches the app nothing, and the rides people forget to record are
/// not a random sample: they are the short ones, the rushed ones, the ones
/// where you were late.
///
/// Both failure modes here corrupt data rather than merely annoy, which is why
/// this is so conservative:
///
/// - A false start records a trip that never happened, and its made-up Wh/km
///   goes straight into the range estimate.
/// - A false stop cuts one ride into two short ones, and the app treats short
///   rides as less trustworthy, so the good data gets discounted too.
///
/// So starting needs current *and* movement, sustained. Current alone fires
/// with the bike switched on at the kerb; movement alone fires with the phone
/// in a car while the bike sits in range.
class TripAutoStart {
  TripAutoStart({
    this.minCurrentAmps = 3.0,
    this.minSpeedKmh = 6.0,
    this.startAfter = const Duration(seconds: 20),
    this.idleCurrentAmps = 1.5,
    this.idleSpeedKmh = 3.0,
    this.stopAfter = const Duration(minutes: 3),
  });

  /// Discharge, in amps, that counts as the bike doing work.
  final double minCurrentAmps;

  /// And the speed that counts as going somewhere.
  final double minSpeedKmh;

  /// How long both have to hold before a ride is declared. Long enough that
  /// rolling the bike out of a doorway does not open a trip.
  final Duration startAfter;

  final double idleCurrentAmps;
  final double idleSpeedKmh;

  /// How long stillness has to last before the ride is declared over.
  ///
  /// Deliberately longer than a traffic light. Ending a ride at every red and
  /// starting a new one after is how one commute becomes eight trips, none of
  /// them long enough for the estimator to trust.
  final Duration stopAfter;

  DateTime? _movingSince;
  DateTime? _stillSince;

  /// Whether conditions currently look like riding.
  bool get looksLikeRiding => _movingSince != null;

  /// Feeds one reading. [recording] is whether a trip is already open.
  ///
  /// [speedKmh] is null when there is no GPS fix yet, which is treated as not
  /// moving: starting a ride on current alone is exactly the mistake this is
  /// built to avoid.
  AutoTripAction evaluate({
    required DateTime at,
    required double current,
    required double? speedKmh,
    required bool recording,
  }) {
    // Discharge is negative in this app's convention, so work is a current
    // below the negated threshold.
    final drawing = current <= -minCurrentAmps;
    final moving = (speedKmh ?? 0) >= minSpeedKmh;
    final riding = drawing && moving;

    final idle = current.abs() <= idleCurrentAmps &&
        (speedKmh ?? 0) <= idleSpeedKmh;

    if (riding) {
      _stillSince = null;
      _movingSince ??= at;
      if (!recording && at.difference(_movingSince!) >= startAfter) {
        // Cleared so a stop and a later start do not inherit this run.
        _movingSince = null;
        return AutoTripAction.start;
      }
      return AutoTripAction.none;
    }

    // Not riding right now. Only sustained stillness ends anything; a hill
    // where the current drops or a moment of lost GPS is not the end of a ride.
    if (!idle) {
      _movingSince = null;
      _stillSince = null;
      return AutoTripAction.none;
    }

    _movingSince = null;
    _stillSince ??= at;
    if (recording && at.difference(_stillSince!) >= stopAfter) {
      _stillSince = null;
      return AutoTripAction.stop;
    }
    return AutoTripAction.none;
  }

  /// Forgets everything, for a disconnection or a pack change.
  void reset() {
    _movingSince = null;
    _stillSince = null;
  }
}
