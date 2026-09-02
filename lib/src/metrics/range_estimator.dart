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
  })  : _whPerKm = learnedWhPerKm ?? defaultWhPerKm,
        _hasLearned = learnedWhPerKm != null,
        _learnedKm = learnedKm;

  /// Used before anything has been learned. A sane figure for a 72 V urban
  /// motorcycle; it stops mattering after the first proper ride.
  final double defaultWhPerKm;

  /// Distance over which an old sample loses half its weight. Smaller means the
  /// estimate reacts faster and wanders more.
  final double halfLifeKm;

  double _whPerKm;
  bool _hasLearned;
  double _learnedKm;

  /// Watt-hours per kilometre the estimator currently believes.
  double get whPerKm => _whPerKm;

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
    if (km < 0.2 || wh <= 0) return;

    final sampleWhPerKm = wh / km;
    // Reject the physically absurd. A 20S 45 Ah pack cannot sustain 400 Wh/km
    // over a segment; a reading like that is a GPS glitch, not a hill.
    if (sampleWhPerKm > 400 || sampleWhPerKm < 2) return;

    if (!_hasLearned) {
      _whPerKm = sampleWhPerKm;
      _hasLearned = true;
    } else {
      // Distance-weighted exponential average: a segment's influence grows with
      // how far it went, and decays with how far has been ridden since.
      final alpha = 1 - math.pow(0.5, km / halfLifeKm).toDouble();
      _whPerKm = _whPerKm * (1 - alpha) + sampleWhPerKm * alpha;
    }
    _learnedKm += km;
  }

  /// Best estimate of how far the bike can still go, in kilometres.
  double rangeKm(double usableWh) =>
      _whPerKm <= 0 ? 0 : usableWh / _whPerKm;

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
        'whPerKm': _whPerKm,
        'hasLearned': _hasLearned,
        'learnedKm': _learnedKm,
      };

  static RangeEstimator fromJson(Map<String, Object?> json) => RangeEstimator(
        learnedWhPerKm:
            json['hasLearned'] == true ? json['whPerKm'] as double? : null,
        learnedKm: (json['learnedKm'] as num?)?.toDouble() ?? 0,
      );
}
