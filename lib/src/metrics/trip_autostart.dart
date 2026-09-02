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
///
/// The two failure modes are not equally bad, and this used to treat them as
/// if they were. A trip left open too long can be stopped by hand and the
/// extra minutes trimmed; a trip cut off mid-ride cannot be rejoined, and the
/// kilometres after the cut are gone. So where the evidence runs out, this
/// keeps recording.
class TripAutoStart {
  TripAutoStart({
    this.minCurrentAmps = 3.0,
    this.minSpeedKmh = 6.0,
    this.startAfter = const Duration(seconds: 20),
    this.idleCurrentAmps = 1.5,
    this.idleSpeedKmh = 3.0,
    this.stopAfter = const Duration(minutes: 3),
    this.stopWithoutFixAfter = const Duration(minutes: 20),
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

  /// The fuse for a pack drawing nothing with no fix to judge it by.
  ///
  /// Without this a ride whose GPS died would stay open forever, which is its
  /// own kind of data loss: the next real ride gets appended to it. Long
  /// enough that it can only fire on a bike that is genuinely done, since a
  /// dead-GPS ride still shows current whenever it is moving.
  final Duration stopWithoutFixAfter;

  DateTime? _movingSince;
  DateTime? _stillSince;

  /// When the pack went quiet, whether or not there was a fix to confirm it.
  DateTime? _quietSince;

  /// Whether conditions currently look like riding.
  bool get looksLikeRiding => _movingSince != null;

  /// Feeds one reading. [recording] is whether a trip is already open.
  ///
  /// [speedKmh] is null when there is no fresh GPS fix. That means *unknown*,
  /// and the two questions read it in opposite directions on purpose:
  ///
  /// - For starting, unknown is not moving. Opening a ride on current alone is
  ///   exactly the mistake this is built to avoid.
  /// - For stopping, unknown is not stillness either. Reading a missing fix as
  ///   a stationary bike is what ended real rides mid-route: the pack draw
  ///   dips below the idle threshold often enough on a coast or at a light,
  ///   and with no fix to contradict it three of those minutes looked exactly
  ///   like a bike parked in a garage.
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

    // Stillness has to be witnessed, not assumed from silence.
    final idle = current.abs() <= idleCurrentAmps &&
        speedKmh != null &&
        speedKmh <= idleSpeedKmh;

    // A quiet pack, judged on current alone. Tracked even when a fix says the
    // bike is moving, because that is the only thing left to go on if the fix
    // stops arriving.
    final quiet = current.abs() <= idleCurrentAmps;
    if (quiet) {
      _quietSince ??= at;
    } else {
      _quietSince = null;
    }

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

    // Not riding right now. Only witnessed, sustained stillness ends anything.
    // A hill where the current drops, a moment of lost GPS, or a pause the
    // rider asked for is not the end of a ride.
    if (!idle) {
      _movingSince = null;
      _stillSince = null;
      // The long fuse, for a ride whose GPS never came back. Only a pack that
      // has drawn nothing for twenty minutes gets here.
      if (recording && _quietSince != null &&
          at.difference(_quietSince!) >= stopWithoutFixAfter) {
        _quietSince = null;
        return AutoTripAction.stop;
      }
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
    _quietSince = null;
  }
}
