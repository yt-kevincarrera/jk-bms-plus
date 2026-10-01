import '../data/database.dart';
import 'trip_learning.dart';

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
    required this.implausible,
    required this.learnedKm,
    this.unmeasured = 0,
    this.excluded = 0,
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

  /// Rejected for a consumption figure no motorcycle could produce.
  ///
  /// This is the one that actually happened. Eight recorded rides, real
  /// distance, real energy, and every sample came out at 0.7 Wh/km because
  /// almost every reading was being dropped before it could be integrated.
  /// The estimator's own floor of 2 Wh/km caught it and refused all of them,
  /// correctly and silently, which left "learned: 0 km" as the only visible
  /// symptom of a bug three layers down.
  final int implausible;

  /// Rejected because the ride's energy was never measured: the link dropped
  /// for so much of it that no figure could be put on what left the pack.
  ///
  /// Counted apart from [noEnergyOut], which it used to be lumped into. That
  /// sentence blamed a trailer or a reversed current sign, and on the
  /// owner's pack the real cause was nearly always the link.
  final int unmeasured;

  /// Rides the rider marked as an exception, which the estimator leaves out
  /// on purpose.
  final int excluded;

  final double learnedKm;

  bool get hasLearned => used > 0;

  /// True when rides exist and every one of them was thrown away.
  bool get allRejected => considered > 0 && used == 0;

  /// The single most likely explanation, when there is one.
  LearningBlocker? get blocker {
    if (!allRejected) return null;
    // Ordered by how much each one tells you. An implausible figure is a
    // fault in the app, not a fact about the riding, so it outranks the
    // explanations that merely describe short trips.
    if (implausible >= noEnergyOut &&
        implausible >= noDistance &&
        implausible >= unmeasured) {
      return LearningBlocker.implausible;
    }
    if (unmeasured >= noEnergyOut && unmeasured >= noDistance) {
      return LearningBlocker.unmeasured;
    }
    if (noEnergyOut >= noDistance) return LearningBlocker.noEnergyOut;
    return LearningBlocker.ridesTooShort;
  }

  /// Reads the stored rides and applies exactly the rules the estimator is
  /// fed by ([TripLearning]) and its own limits, so [used] is the number of
  /// rides that really taught it. It used to skip the measurement and the
  /// "exception" filters, and could count as used a ride the estimator was
  /// never given.
  static LearningReport from(List<Trip> trips, {required double learnedKm}) {
    var used = 0;
    var noDistance = 0;
    var noEnergyOut = 0;
    var implausible = 0;
    var unmeasured = 0;
    var excluded = 0;
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
      final whPerKm = t.distanceKm <= 0 ? null : net / t.distanceKm;
      if (t.distanceKm < TripLearning.minimumKm) {
        noDistance++;
      } else if (!TripLearning.isMeasured(t)) {
        unmeasured++;
      } else if (net <= 0) {
        noEnergyOut++;
      } else if (whPerKm == null || whPerKm < 2 || whPerKm > 400) {
        // The estimator's own limits, repeated here rather than asked of it:
        // addSegment returns silently, which is right for it and useless for
        // explaining anything.
        implausible++;
      } else if (t.representative == false) {
        excluded++;
      } else {
        used++;
      }
    }

    return LearningReport(
      considered: considered,
      used: used,
      noDistance: noDistance,
      noEnergyOut: noEnergyOut,
      implausible: implausible,
      unmeasured: unmeasured,
      excluded: excluded,
      learnedKm: learnedKm,
    );
  }
}

/// What is standing between the recorded rides and a learned figure.
enum LearningBlocker {
  /// Consumption came out at a figure no motorcycle could produce, which is a
  /// fault in the app rather than a fact about the riding.
  implausible,

  /// Rides recorded distance but no energy leaving the pack.
  noEnergyOut,

  /// The link dropped through the rides, and their energy was never measured.
  unmeasured,

  /// Every ride was too short to divide by.
  ridesTooShort,
}
