import '../data/database.dart';

/// Why the range estimate has, or has not, learned anything.
///
/// "Learned: 0 km" next to eight recorded rides is the app declining to say
/// what it knows. The rides are there, they were rejected, and every reason a
/// ride can be rejected points at something specific and fixable. So the count
/// is reported alongside the reasons rather than on its own.
///
/// The reasons are not equally likely and one of them is much more
/// interesting than the others: a ride with distance but no measured energy out
/// means the pack's current is not arriving with the sign this app expects.
/// That would be a decoding fault, not a riding one, and it would quietly
/// disable range learning, consumption, trip energy and the capacity scan all
/// at once while every other figure on screen looked fine.
class LearningReport {
  const LearningReport({
    required this.considered,
    required this.used,
    required this.noDistance,
    required this.noEnergyOut,
    required this.learnedKm,
  });

  /// Finished rides on record for this pack.
  final int considered;

  /// Rides that actually taught the estimator something.
  final int used;

  /// Rejected for being too short to divide by. GPS noise over 50 m produces
  /// an enormous Wh/km, and one of those poisons the average for a long time.
  final int noDistance;

  /// Rejected because no net energy left the pack over the ride.
  ///
  /// The interesting one. A recorded ride that drew nothing is either a ride
  /// spent on a trailer, or a current whose sign is the opposite of what the
  /// parser assumes.
  final int noEnergyOut;

  final double learnedKm;

  bool get hasLearned => used > 0;

  /// True when rides exist and every one of them was thrown away.
  bool get allRejected => considered > 0 && used == 0;

  /// The single most likely explanation, when there is one.
  LearningBlocker? get blocker {
    if (!allRejected) return null;
    if (noEnergyOut >= noDistance) return LearningBlocker.noEnergyOut;
    return LearningBlocker.ridesTooShort;
  }

  /// Reads the stored rides and applies exactly the estimator's own rules.
  ///
  /// Deliberately duplicating the thresholds rather than asking the estimator:
  /// the estimator silently returns from `addSegment`, which is right for it
  /// and useless for explaining anything.
  static LearningReport from(List<Trip> trips, {required double learnedKm}) {
    var used = 0;
    var noDistance = 0;
    var noEnergyOut = 0;
    var considered = 0;

    for (final t in trips) {
      // A row exists from the moment recording starts, so the ride in progress
      // is in this list and is not a finished ride.
      if (t.endedAt.isBefore(t.startedAt) ||
          t.endedAt.isAtSameMomentAs(t.startedAt)) {
        continue;
      }
      considered++;

      final net = t.energyOutWh - t.energyInWh;
      if (t.distanceKm < 0.2) {
        noDistance++;
      } else if (net <= 0) {
        noEnergyOut++;
      } else {
        used++;
      }
    }

    return LearningReport(
      considered: considered,
      used: used,
      noDistance: noDistance,
      noEnergyOut: noEnergyOut,
      learnedKm: learnedKm,
    );
  }
}

/// What is standing between the recorded rides and a learned figure.
enum LearningBlocker {
  /// Rides recorded distance but no energy leaving the pack.
  noEnergyOut,

  /// Every ride was too short to divide by.
  ridesTooShort,
}
