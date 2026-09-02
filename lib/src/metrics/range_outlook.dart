import 'range_estimator.dart';

/// How far the bike can go now, and how far it could go on a full pack.
///
/// These were the same number wearing one label, and that was a real problem:
/// "autonomy: 34 km" on a pack sitting at 60% invites the reading that the bike
/// does 34 km, which is the figure somebody plans a route around. The two
/// questions are different and only one of them changes when you charge.
///
/// - [nowKm] is what is left, from the charge in the pack at this moment.
/// - [fullKm] is what a full pack is worth, from what the app has learned.
///   It is a property of the battery and the riding, not of today.
///
/// Both are null when there is nothing honest to say, and they go null
/// independently: a pack whose capacity has never been measured can still
/// answer the first question and must not guess at the second.
class RangeOutlook {
  const RangeOutlook({
    this.nowKm,
    this.fullKm,
    this.nowBandKm,
    this.fullBandKm,
    required this.confidence,
    required this.hasLearned,
    this.fullFromMeasuredCapacity = false,
  });

  /// Kilometres left at the current charge.
  final double? nowKm;

  /// Kilometres a full pack is worth.
  final double? fullKm;

  final (double, double)? nowBandKm;
  final (double, double)? fullBandKm;

  final RangeConfidence confidence;

  /// Whether any of this rests on measured riding rather than a starting
  /// default. False means every figure here is a placeholder.
  final bool hasLearned;

  /// Whether [fullKm] rests on a capacity that was actually measured, rather
  /// than on what the pack was sold as.
  ///
  /// Worth surfacing: a full-pack range built on an advertised capacity
  /// inherits whatever that advert got wrong, and the rider is the only one
  /// who knows which they are looking at.
  final bool fullFromMeasuredCapacity;

  static const RangeOutlook unknown = RangeOutlook(
    confidence: RangeConfidence.low,
    hasLearned: false,
  );

  /// Builds both figures.
  ///
  /// [usableWhNow] comes from [RangeEstimator.usableWh] against the live
  /// reading. [fullCapacityAh] is the best figure available for what the pack
  /// holds when full, and [fullPackVoltage] the voltage it sits at there.
  ///
  /// The full-pack figure deliberately does *not* scale the current one by
  /// charge. Usable energy is not linear in percent near the cutoff, and the
  /// weakest-cell correction that shapes [usableWhNow] is a fact about right
  /// now rather than about a full pack.
  static RangeOutlook from({
    required RangeEstimator estimator,
    required double usableWhNow,
    double? fullCapacityAh,
    double? fullPackVoltage,
    bool capacityWasMeasured = false,
  }) {
    if (!estimator.hasLearned) {
      // No learned consumption means no range worth quoting, at any charge.
      // The estimator will happily divide by its starting default; that is a
      // number about a hypothetical motorcycle.
      return RangeOutlook(
        confidence: estimator.confidence,
        hasLearned: false,
      );
    }

    final now = usableWhNow > 0 ? estimator.rangeKm(usableWhNow) : null;

    double? full;
    if (fullCapacityAh != null &&
        fullCapacityAh > 0 &&
        fullPackVoltage != null &&
        fullPackVoltage > 0) {
      full = estimator.rangeKm(fullCapacityAh * fullPackVoltage);
    }

    return RangeOutlook(
      nowKm: now,
      fullKm: full,
      nowBandKm: now == null ? null : estimator.rangeBandKm(usableWhNow),
      fullBandKm: full == null || fullCapacityAh == null ||
              fullPackVoltage == null
          ? null
          : estimator.rangeBandKm(fullCapacityAh * fullPackVoltage),
      confidence: estimator.confidence,
      hasLearned: true,
      fullFromMeasuredCapacity: capacityWasMeasured,
    );
  }
}
