import 'dart:math' as math;

/// How much to trust the learned consumption figure.
enum RangeConfidence { low, medium, high }

/// Learns what the bike actually costs to ride, in watt-hours per kilometre,
/// and turns that into a range estimate that improves with use.
///
/// The BMS cannot do this. It has no idea how far the bike went — the JK
/// protocol carries GPS *lock* bits for immobilising the pack, but no position
/// data of any kind. The phone in your pocket does know, and that is the whole
/// reason this app is worth writing.
///
/// How it learns:
///
///  * Every segment of riding contributes one sample: watt-hours actually taken
///    out of the pack, and kilometres actually covered, both measured.
///  * Samples are folded into an exponentially weighted average, weighted by
///    the distance of the segment, so a 20 km ride counts for more than a 200 m
///    crawl out of the garage.
///  * Recent riding dominates. Winter, a new tyre, a heavier load or a tired
///    pack all change the number, and the estimate should follow rather than be
///    anchored to a lifetime average.
///
/// Until enough kilometres are in, it says so instead of pretending: the range
/// is quoted as a band, and the band is wide while the estimate is young.
class RangeEstimator {
  RangeEstimator({
    this.defaultWhPerKm = 28.0,
    this.halfLifeKm = 40.0,
    double? learnedWhPerKm,
    double learnedKm = 0,
  })  : _hasLearned = learnedWhPerKm != null,
        _learnedKm = learnedKm,
        // Seeded so a restored estimate carries the weight its distance earned
        // rather than starting again from one sample's worth.
        _weight = learnedWhPerKm == null ? 0 : (learnedKm <= 0 ? 1 : learnedKm),
        _weighted = learnedWhPerKm == null
            ? 0
            : learnedWhPerKm * (learnedKm <= 0 ? 1 : learnedKm);

  /// Used before anything has been learned. A sane figure for a 72 V urban
  /// motorcycle; it stops mattering after the first proper ride.
  final double defaultWhPerKm;

  /// Distance over which an old sample loses half its weight. Smaller means the
  /// estimate reacts faster and wanders more.
  final double halfLifeKm;

  /// Running distance-weighted totals, with old samples decayed.
  ///
  /// Kept as a pair rather than as a single running figure because the single
  /// figure had to be *initialised* from somewhere, and it took the first
  /// sample whole. That gave a 1.8 km trundle round the block the same
  /// authority as a 40 km commute, and once set, later samples could only move
  /// it by their own small fraction: a 6 km ride shifts a 40 km half-life
  /// average by about a tenth.
  ///
  /// On a real pack's first three rides that produced 29.7 Wh/km where the
  /// honest answer, total energy over total distance, was 21.5. Quoted as a
  /// full-pack range that is 100 km against a true 138: pessimistic by 40%,
  /// from arithmetic rather than from the battery.
  ///
  /// Self-normalising fixes it. The first sample gets the weight its own
  /// distance earns and no more, early samples average properly, and once
  /// there is real distance behind it the decay still favours recent riding.
  double _weight = 0;
  double _weighted = 0;

  bool _hasLearned;
  double _learnedKm;

  /// Below this a segment is GPS noise while stopped at a light, not riding,
  /// and would poison the average with an enormous Wh/km.
  static const double _minSegmentKm = 0.2;

  /// A 20S 45 Ah pack cannot sustain outside this band; a reading past either
  /// edge is a GPS glitch or a regen segment, not a sample of how the bike
  /// rides. Shared between [addSegment] and [projectedShiftFraction] so the
  /// two can never disagree about which rides count.
  static const double _maxSampleWhPerKm = 400;
  static const double _minSampleWhPerKm = 2;

  /// Watt-hours per kilometre the estimator currently believes.
  double get whPerKm => _weight <= 0 ? defaultWhPerKm : _weighted / _weight;

  /// True once at least one real segment has been folded in.
  bool get hasLearned => _hasLearned;

  /// Total distance the estimate is built from.
  double get learnedKm => _learnedKm;

  RangeConfidence get confidence {
    if (_learnedKm < 5) return RangeConfidence.low;
    if (_learnedKm < 50) return RangeConfidence.medium;
    return RangeConfidence.high;
  }

  /// How wide the quoted band is, as a fraction of the estimate.
  double get _spread => switch (confidence) {
        RangeConfidence.low => 0.30,
        RangeConfidence.medium => 0.18,
        RangeConfidence.high => 0.10,
      };

  /// Folds in one measured segment.
  ///
  /// [wh] is energy taken *out* of the pack, so it must be positive; a segment
  /// that regenerated more than it used is not a consumption sample and is
  /// ignored. Very short segments are ignored too: GPS noise while stopped at a
  /// light would otherwise poison the average with an enormous Wh/km.
  void addSegment({required double wh, required double km}) {
    if (km < _minSegmentKm || wh <= 0) return;

    final sampleWhPerKm = wh / km;
    // Reject the physically absurd. A 20S 45 Ah pack cannot sustain 400 Wh/km
    // over a segment; a reading like that is a GPS glitch, not a hill.
    if (sampleWhPerKm > _maxSampleWhPerKm || sampleWhPerKm < _minSampleWhPerKm) {
      return;
    }

    // Distance-weighted, and normalised by the weight actually accumulated:
    // a segment's influence grows with how far it went and decays with how far
    // has been ridden since, with no sample ever counting for more than its
    // own distance deserves.
    final decay = math.pow(0.5, km / halfLifeKm).toDouble();
    _weight = _weight * decay + km;
    _weighted = _weighted * decay + km * sampleWhPerKm;
    _hasLearned = true;
    _learnedKm += km;
  }

  /// Fraction of the current figure that one more sample would move it by.
  ///
  /// The question a rider is asked has to be worth the interruption, and what
  /// makes it worth it is consequence, not oddity. A 2 km errand at triple the
  /// usual consumption cannot budge a 40 km half-life average, so asking about
  /// it would be a notification about nothing.
  ///
  /// Returns 0 for a sample [addSegment] would reject, so a rejected ride is
  /// never the subject of a question about a change that will not happen.
  ///
  /// Pure: it computes what the fold would do without folding anything in.
  double projectedShiftFraction({required double wh, required double km}) {
    if (km < _minSegmentKm || wh <= 0) return 0;
    final sampleWhPerKm = wh / km;
    if (sampleWhPerKm > _maxSampleWhPerKm || sampleWhPerKm < _minSampleWhPerKm) {
      return 0;
    }

    final current = whPerKm;
    if (current <= 0) return 0;

    final decay = math.pow(0.5, km / halfLifeKm).toDouble();
    final weight = _weight * decay + km;
    if (weight <= 0) return 0;
    final weighted = _weighted * decay + km * sampleWhPerKm;

    return ((weighted / weight) - current).abs() / current;
  }

  /// How much a ride has to move the figure before the rider is asked whether
  /// it represents them.
  ///
  /// Not a law of anything. With a real pack at 17.5 Wh/km and 100 km of
  /// weight behind the estimate, 5% means a 40 km ride asks at 11% off, a
  /// 20 km ride at 23% off, and a 10 km ride at 47% off. Quiet on an ordinary
  /// fast day, which is the point. Named so recalibrating it is one line.
  static const double askThresholdFraction = 0.05;

  /// Best estimate of how far the bike can still go, in kilometres.
  double rangeKm(double usableWh) =>
      whPerKm <= 0 ? 0 : usableWh / whPerKm;

  /// The honest version: a band, wide while the estimate is young.
  (double low, double high) rangeBandKm(double usableWh) {
    final centre = rangeKm(usableWh);
    return (centre * (1 - _spread), centre * (1 + _spread));
  }

  /// Energy still available, in watt-hours, accounting for the weakest cell.
  ///
  /// This is the number the manufacturer's SOC quietly overstates. The pack
  /// stops when the *lowest* cell reaches cutoff, not when the average does, so
  /// whatever the other cells still hold above that point is stranded. The
  /// bigger the imbalance, the more optimistic a plain SOC reading is.
  static double usableWh({
    required double remainingAh,
    required double packVoltage,
    required int cellCount,
    required double minCellVoltage,
    required double averageCellVoltage,
    required double cutoffVoltagePerCell,
  }) {
    if (cellCount <= 0) return 0;
    final gross = remainingAh * packVoltage;
    if (gross <= 0) return 0;

    final headroomAverage = averageCellVoltage - cutoffVoltagePerCell;
    final headroomWeakest = minCellVoltage - cutoffVoltagePerCell;
    if (headroomAverage <= 0) return 0;
    if (headroomWeakest <= 0) return 0;

    return gross * usableFractionOf(
      minCellVoltage: minCellVoltage,
      averageCellVoltage: averageCellVoltage,
      cutoffVoltagePerCell: cutoffVoltagePerCell,
    );
  }

  /// How much of the pack's charge the imbalance actually lets you use.
  ///
  /// The weakest cell runs out first; the fraction of the average cell's
  /// remaining headroom that it actually has is the fraction of the pack you
  /// can really reach. Exposed on its own because it applies to a full pack as
  /// much as to this moment's charge: shipped without it, the full-pack range
  /// came out *higher* than the remaining range on a fully charged battery,
  /// which is nonsense the rider would have found before anybody else.
  static double usableFractionOf({
    required double minCellVoltage,
    required double averageCellVoltage,
    required double cutoffVoltagePerCell,
  }) {
    final headroomAverage = averageCellVoltage - cutoffVoltagePerCell;
    final headroomWeakest = minCellVoltage - cutoffVoltagePerCell;
    if (headroomAverage <= 0 || headroomWeakest <= 0) return 0;
    return (headroomWeakest / headroomAverage).clamp(0.0, 1.0);
  }

  Map<String, Object?> toJson() => {
        'whPerKm': whPerKm,
        'hasLearned': _hasLearned,
        'learnedKm': _learnedKm,
      };

  static RangeEstimator fromJson(Map<String, Object?> json) => RangeEstimator(
        learnedWhPerKm:
            json['hasLearned'] == true ? json['whPerKm'] as double? : null,
        learnedKm: (json['learnedKm'] as num?)?.toDouble() ?? 0,
      );
}
