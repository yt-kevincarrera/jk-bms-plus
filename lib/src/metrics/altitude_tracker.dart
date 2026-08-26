/// Turns a noisy stream of GPS altitudes into climb and descent totals.
///
/// This needs explaining, because the obvious approach is wrong.
///
/// GPS altitude is the weakest thing a phone reports: typically ±5 to ±10 m,
/// and it wanders continuously even with the phone sitting still on a table.
/// Adding up every rise between consecutive fixes therefore invents hundreds of
/// metres of climbing on a flat ride — the classic bug in every first attempt
/// at this.
///
/// What this does instead is what a bike computer does:
///
///  1. **Smooth.** An exponential moving average takes the edge off the noise.
///     The weight is deliberately low, so a genuine climb still comes through
///     within a few fixes while jitter mostly cancels.
///
///  2. **Hysteresis against a reference.** Rather than comparing each reading
///     to the one before it, everything is compared to a *reference* altitude
///     that only moves when the smoothed value has departed from it by more
///     than [thresholdM]. Below that threshold nothing is counted at all, so
///     wander never accumulates. Once the threshold is crossed, the whole
///     departure is committed and the reference jumps to where you now are —
///     which means a long steady climb is counted in full, in chunks, rather
///     than being thresholded away.
///
/// The consequence worth knowing: rolling terrain with bumps smaller than
/// [thresholdM] reads as flat. That is the right trade. Counting those bumps
/// would mean counting noise, and there is no way to tell them apart from a
/// GPS altitude alone.
///
/// A barometric altimeter — which the Pixel has — would be far better at this,
/// and is the obvious upgrade if these numbers ever need to be precise.
class AltitudeTracker {
  AltitudeTracker({this.smoothing = 0.25, this.thresholdM = 3.0});

  /// Weight of each new reading in the moving average, 0 to 1. Lower is
  /// smoother and slower.
  final double smoothing;

  /// How far the smoothed altitude must depart from the reference before any
  /// of it counts. Around three metres sits above typical GPS wander and below
  /// a real hill.
  final double thresholdM;

  double? _smoothed;
  double? _reference;

  double _climbM = 0;
  double _descentM = 0;

  double get climbM => _climbM;
  double get descentM => _descentM;

  /// Smoothed altitude, or null before the first reading.
  double? get altitudeM => _smoothed;

  /// Net change since the first reading, positive for higher.
  double get netM => (_smoothed ?? 0) - (_firstM ?? 0);
  double? _firstM;

  /// Feeds one raw altitude and returns the smoothed value.
  double add(double rawAltitudeM) {
    final previous = _smoothed;
    if (previous == null) {
      _smoothed = rawAltitudeM;
      _reference = rawAltitudeM;
      _firstM = rawAltitudeM;
      return rawAltitudeM;
    }

    final smoothed = previous + (rawAltitudeM - previous) * smoothing;
    _smoothed = smoothed;

    final reference = _reference!;
    final delta = smoothed - reference;

    if (delta > thresholdM) {
      _climbM += delta;
      _reference = smoothed;
    } else if (delta < -thresholdM) {
      _descentM += -delta;
      _reference = smoothed;
    }

    return smoothed;
  }

  void reset() {
    _smoothed = null;
    _reference = null;
    _firstM = null;
    _climbM = 0;
    _descentM = 0;
  }
}
