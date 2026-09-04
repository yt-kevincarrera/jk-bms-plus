import '../../data/database.dart';
import '../../metrics/trip_recorder.dart';

/// Everything the end-of-ride sheet shows, from either of the two places a
/// ride can be read.
///
/// The sheet used to take a [TripOutcome], which only exists in the moment the
/// stop button is pressed. Rides end in a pocket more often than that, and a
/// ride that closed itself was stored with its conclusions and shown to
/// nobody. This is the one shape both paths produce, so the pocket ride gets
/// the same screen and not a lesser version of it.
class TripSummaryView {
  const TripSummaryView({
    required this.tripId,
    required this.distanceKm,
    required this.movingDuration,
    required this.totalDuration,
    required this.maxSpeedKmh,
    required this.climbM,
    required this.descentM,
    required this.energyOutWh,
    required this.energyInWh,
    required this.startSoc,
    required this.endSoc,
    required this.minPackVoltage,
    required this.maxPackVoltage,
    required this.maxDischargeCurrent,
    required this.maxTemperature,
    required this.maxDeltaVolts,
    required this.whPerKmBefore,
    required this.whPerKmAfter,
    required this.representative,
    required this.conclusions,
  });

  /// Null only for a ride that was never given a row, which happens when
  /// there is no repository at all. The question needs an id to record an
  /// answer against, and hides itself without one.
  final int? tripId;

  final double distanceKm;
  final Duration movingDuration;
  final Duration totalDuration;
  final double maxSpeedKmh;
  final double climbM;
  final double descentM;
  final double energyOutWh;
  final double energyInWh;

  /// What the pack was doing over the ride, for the "how the pack behaved"
  /// section. Not part of a [TripOutcome]'s or a stored [Trip]'s riding
  /// figures, so it needs its own fields rather than reusing distance/speed.
  final double startSoc;
  final double endSoc;
  final double minPackVoltage;
  final double maxPackVoltage;
  final double maxDischargeCurrent;
  final double maxTemperature;
  final double maxDeltaVolts;

  /// What the estimate said before and after this ride was folded in.
  final double? whPerKmBefore;
  final double? whPerKmAfter;

  /// Null means nobody has been asked yet.
  final bool? representative;

  /// What the ride taught the range estimate, for [TripLearnedSection].
  ///
  /// Not in the field list the sheet's first sections need, but the sheet
  /// also has a "learned" section, and that section takes a whole
  /// [TripConclusions] rather than its fields piecemeal. Null exactly when
  /// there is nothing to show: a ride from before conclusions were kept, or
  /// one whose confidence was never recorded.
  final TripConclusions? conclusions;

  /// Consumption over this ride. Null under 200 m, where it means nothing.
  double? get whPerKm {
    if (distanceKm < 0.2) return null;
    final net = energyOutWh - energyInWh;
    return net <= 0 ? null : net / distanceKm;
  }

  double get averageSpeedKmh {
    final hours = movingDuration.inMilliseconds / 3600000.0;
    return hours <= 0 ? 0 : distanceKm / hours;
  }

  /// Time the bike stood still without the ride being paused.
  Duration get stoppedDuration {
    final idle = totalDuration - movingDuration;
    return idle.isNegative ? Duration.zero : idle;
  }

  /// Percentage points of charge used.
  double get socUsed => startSoc - endSoc;

  /// How much of the pack one kilometre costs, in percentage points.
  double? get socPerKm =>
      distanceKm < 0.2 || socUsed <= 0 ? null : socUsed / distanceKm;

  /// Voltage the pack dropped under load over the trip.
  double get sagVolts => maxPackVoltage - minPackVoltage;

  factory TripSummaryView.fromOutcome(TripOutcome outcome, {int? tripId}) {
    final s = outcome.summary;
    return TripSummaryView(
      tripId: tripId,
      distanceKm: s.distanceKm,
      movingDuration: s.movingDuration,
      totalDuration: s.totalDuration,
      maxSpeedKmh: s.maxSpeedKmh,
      climbM: s.climbM,
      descentM: s.descentM,
      energyOutWh: s.energyOutWh,
      energyInWh: s.energyInWh,
      startSoc: s.startSoc,
      endSoc: s.endSoc,
      minPackVoltage: s.minPackVoltage,
      maxPackVoltage: s.maxPackVoltage,
      maxDischargeCurrent: s.maxDischargeCurrent,
      maxTemperature: s.maxTemperature,
      maxDeltaVolts: s.maxDeltaVolts,
      whPerKmBefore: outcome.conclusions.whPerKmBefore,
      whPerKmAfter: outcome.conclusions.whPerKmAfter,
      // A ride that has only just ended has not been asked about yet.
      representative: null,
      conclusions: outcome.conclusions,
    );
  }

  factory TripSummaryView.fromStored(Trip trip) => TripSummaryView(
    tripId: trip.id,
    distanceKm: trip.distanceKm,
    movingDuration: Duration(seconds: trip.movingSeconds),
    totalDuration: Duration(seconds: trip.totalSeconds),
    maxSpeedKmh: trip.maxSpeedKmh,
    climbM: trip.climbM,
    descentM: trip.descentM,
    energyOutWh: trip.energyOutWh,
    energyInWh: trip.energyInWh,
    startSoc: trip.startSoc,
    endSoc: trip.endSoc,
    minPackVoltage: trip.minPackVoltage,
    maxPackVoltage: trip.maxPackVoltage,
    maxDischargeCurrent: trip.maxDischargeCurrent,
    maxTemperature: trip.maxTemperature,
    maxDeltaVolts: trip.maxDeltaVolts,
    whPerKmBefore: trip.whPerKmBefore,
    whPerKmAfter: trip.whPerKmAfter,
    representative: trip.representative,
    conclusions: TripConclusions.restore(
      whPerKmBefore: trip.whPerKmBefore,
      whPerKmAfter: trip.whPerKmAfter,
      learnedKm: trip.learnedKm,
      rangeKmAtEnd: trip.rangeKmAtEnd,
      confidence: trip.confidence,
    ),
  );
}
