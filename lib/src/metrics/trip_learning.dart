import '../data/database.dart';
import 'range_estimator.dart';
import 'trip_recorder.dart';

/// Which stored rides teach the range, in one place.
///
/// The live service, the saved-pack screen, the pack comparison, the history
/// totals, the learning report and the consumption trend each used to apply
/// their own version of this. They disagreed: the saved-pack screen fed rides
/// newest first to an estimator that weights the later ones, so the oldest
/// ride dominated, and it never left out a ride marked "it was an
/// exception", so marking one there changed nothing while the snackbar said
/// the range had moved.
class TripLearning {
  const TripLearning._();

  /// Shorter than this a ride is GPS noise to divide by. The estimator's own
  /// floor, repeated so a sentence about it can quote the number.
  static const double minimumKm = 0.2;

  /// Energy sources that mean the ride was not measured, whatever figure the
  /// row holds.
  static const Set<String> unmeasuredSources = {
    'partialCoulombCount',
    'unmeasurable',
    'unmeasurableBracketed',
  };

  /// Whether the ride's energy is a measurement.
  ///
  /// An integrated ride that came to nothing is the link having dropped
  /// before the first reading could be integrated, not a ride that cost
  /// nothing, and the repair already reads it that way.
  static bool isMeasured(Trip t) => isMeasuredParts(
    energySource: t.energySource,
    energyOutWh: t.energyOutWh,
  );

  /// [isMeasured], for a ride that is not a stored row yet.
  static bool isMeasuredParts({
    required String? energySource,
    required double energyOutWh,
  }) {
    if (unmeasuredSources.contains(energySource)) return false;
    if (energySource == EnergySource.integrated.name && energyOutWh <= 0) {
      return false;
    }
    return true;
  }

  /// Whether the ride's start and end charge came from readings that may
  /// stop well short of either end of it: the link was down for part of the
  /// ride, so the percentage used is a lower bound, not a figure.
  static bool socIsPartial(String? energySource) =>
      energySource == EnergySource.partialCoulombCount.name ||
      energySource == EnergySource.bracketedCoulombCount.name ||
      energySource == EnergySource.unmeasurable.name ||
      energySource == EnergySource.unmeasurableBracketed.name;

  /// Whether the ride teaches the range: finished, long enough, measured,
  /// with energy leaving the pack, and not marked as an exception.
  ///
  /// Demo rides are not left out here: demo mode learns from its own rides,
  /// and they are kept from real figures by being filed under the demo pack.
  static bool teaches(Trip t) =>
      t.distanceKm >= minimumKm &&
      isMeasured(t) &&
      t.energyOutWh > t.energyInWh &&
      // Null is not false: a ride nobody was asked about counts, which keeps
      // the behaviour of every ride recorded before the question existed.
      // Only an explicit no takes one out.
      t.representative != false;

  /// The rides that teach, oldest first, which is the order the estimator
  /// expects: it weights later rides more.
  static List<Trip> forLearning(Iterable<Trip> trips) =>
      trips.where(teaches).toList()
        ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

  /// The estimate those rides teach.
  static RangeEstimator estimatorFrom(Iterable<Trip> trips) {
    final estimator = RangeEstimator();
    for (final t in forLearning(trips)) {
      estimator.addSegment(wh: t.energyOutWh - t.energyInWh, km: t.distanceKm);
    }
    return estimator;
  }
}
