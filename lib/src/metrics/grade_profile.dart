import 'dart:math' as math;

/// One point of a track, with only what a slope is worked out from.
///
/// A record rather than an interface so both the recorder's [TrackPoint] and
/// the database's `TripPoint` can be mapped into it in one line, without
/// either of them having to know this file exists.
typedef GradeSample = ({double latitude, double longitude, double altitudeM});

/// A stored fix, with what the recorder judged its distance by.
typedef GradeFix = ({
  double latitude,
  double longitude,
  double altitudeM,
  DateTime at,
  double speedKmh,
});

/// How far a ride went uphill, downhill, and along the flat.
///
/// This replaces total climb and descent, which were two numbers nobody could
/// act on. "You gained 86 m" is trivia; "2.9 km of this ride was uphill" is
/// the thing a rider already has an opinion about.
///
/// It is worked out from the stored track rather than accumulated while
/// recording, which is deliberate: it needs no new columns, and it applies to
/// every ride already on disk instead of only to rides taken from now on.
class GradeProfile {
  const GradeProfile({
    required this.uphillKm,
    required this.flatKm,
    required this.downhillKm,
  });

  static const GradeProfile empty =
      GradeProfile(uphillKm: 0, flatKm: 0, downhillKm: 0);

  final double uphillKm;
  final double flatKm;
  final double downhillKm;

  double get totalKm => uphillKm + flatKm + downhillKm;

  /// Whether there is enough of a ride here to be worth three figures.
  ///
  /// Below a couple of kilometres the split is three numbers that all round to
  /// nothing, which reads as a bug rather than as a short ride.
  bool get hasAnything => totalKm >= 1.0;
}

/// Splits a track by how steep it was.
///
/// Two decisions do the work here, and both exist because GPS altitude is the
/// weakest thing a phone reports.
///
/// **Resampling.** The grade is taken across fixed distances rather than
/// between consecutive fixes. Fixes land every 35 to 45 m on a real ride, and
/// over that little ground the altitude's own wander is the same size as the
/// terrain, so a grade taken between neighbours is mostly noise. Across
/// [binMetres] the wander averages out and the slope survives. On the rider's
/// real tracks the resulting split held to a percentage point whether measured
/// at 50, 100 or 200 m -- which is the test that it is terrain and not noise,
/// and the test that summing every altitude step conspicuously fails.
///
/// **A flat band.** Anything gentler than [flatGrade] is flat. One percent
/// over two kilometres is 20 m of climbing and nobody rides it differently.
/// Their real terrain has nothing sustained above 4%, so a finer set of bands
/// than three would report zeroes: steep-uphill and steep-downhill came out at
/// 0 to 1% of every ride they have recorded.
GradeProfile profileOf(
  List<GradeSample> samples, {
  double binMetres = 100,
  double flatGrade = 0.015,
}) {
  if (samples.length < 2) return GradeProfile.empty;

  // Cumulative distance alongside altitude, so a position can be interpolated
  // at any point along the track.
  final along = <double>[0];
  final altitude = <double>[samples.first.altitudeM];
  var travelled = 0.0;
  for (var i = 1; i < samples.length; i++) {
    travelled += _metresBetween(samples[i - 1], samples[i]);
    along.add(travelled);
    altitude.add(samples[i].altitudeM);
  }
  return _split(along, altitude, binMetres: binMetres, flatGrade: flatGrade);
}

/// [profileOf] for a stored track, counting distance the way the recorder
/// did, so the three figures add up to the ride's distance tile.
///
/// The plain version summed every step between fixes, including the jitter
/// of a phone standing still and straight lines across GPS gaps, all of which
/// the recorder leaves out: the split added up to more than the ride. Here a
/// step counts only where the recorder counted it (under [maxGap], at least
/// 1.5 m and 1.5 km/h), and the altitude is first put through a running
/// median of five fixes, which takes out the single-fix spikes a phone's
/// altitude is prone to before a grade is read from it.
GradeProfile profileOfTrack(
  List<GradeFix> fixes, {
  double binMetres = 100,
  double flatGrade = 0.015,
  Duration maxGap = const Duration(seconds: 30),
}) {
  if (fixes.length < 2) return GradeProfile.empty;
  final smoothed = _runningMedian([for (final f in fixes) f.altitudeM], 5);
  final along = <double>[0];
  final altitude = <double>[smoothed.first];
  var travelled = 0.0;
  for (var i = 1; i < fixes.length; i++) {
    final a = fixes[i - 1];
    final b = fixes[i];
    final dt = b.at.difference(a.at);
    final metres = _metresBetween(
      (latitude: a.latitude, longitude: a.longitude, altitudeM: 0),
      (latitude: b.latitude, longitude: b.longitude, altitudeM: 0),
    );
    final counted = dt > Duration.zero &&
        dt <= maxGap &&
        metres >= 1.5 &&
        b.speedKmh >= 1.5;
    if (!counted) {
      // No distance, but the altitude moves on to where the ride resumed,
      // so a gap is not read later as a cliff.
      altitude[altitude.length - 1] = smoothed[i];
      continue;
    }
    travelled += metres;
    along.add(travelled);
    altitude.add(smoothed[i]);
  }
  return _split(along, altitude, binMetres: binMetres, flatGrade: flatGrade);
}

List<double> _runningMedian(List<double> v, int width) {
  final half = width ~/ 2;
  return [
    for (var i = 0; i < v.length; i++)
      () {
        final lo = math.max(0, i - half);
        final hi = math.min(v.length, i + half + 1);
        final w = v.sublist(lo, hi)..sort();
        final m = w.length ~/ 2;
        return w.length.isOdd ? w[m] : (w[m - 1] + w[m]) / 2;
      }(),
  ];
}

GradeProfile _split(
  List<double> along,
  List<double> altitude, {
  required double binMetres,
  required double flatGrade,
}) {
  final travelled = along.last;
  if (along.length < 2 || travelled <= 0) return GradeProfile.empty;

  var cursor = 1;
  double altitudeAt(double target) {
    while (cursor < along.length - 1 && along[cursor] < target) {
      cursor++;
    }
    final span = along[cursor] - along[cursor - 1];
    if (span <= 0) return altitude[cursor];
    final fraction = ((target - along[cursor - 1]) / span).clamp(0.0, 1.0);
    return altitude[cursor - 1] +
        (altitude[cursor] - altitude[cursor - 1]) * fraction;
  }

  var uphill = 0.0;
  var flat = 0.0;
  var downhill = 0.0;

  var from = 0.0;
  var fromAltitude = altitude.first;
  while (from < travelled) {
    // The last stretch is whatever is left, so the three figures always add
    // up to the distance actually ridden.
    final to = math.min(from + binMetres, travelled);
    final length = to - from;
    final toAltitude = altitudeAt(to);
    final grade = (toAltitude - fromAltitude) / length;
    final km = length / 1000;
    if (grade > flatGrade) {
      uphill += km;
    } else if (grade < -flatGrade) {
      downhill += km;
    } else {
      flat += km;
    }
    from = to;
    fromAltitude = toAltitude;
  }

  return GradeProfile(uphillKm: uphill, flatKm: flat, downhillKm: downhill);
}

/// Great-circle distance in metres. Same sphere the recorder measures with.
double _metresBetween(GradeSample a, GradeSample b) {
  const r = 6371000.0;
  final dLat = (b.latitude - a.latitude) * math.pi / 180;
  final dLon = (b.longitude - a.longitude) * math.pi / 180;
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(a.latitude * math.pi / 180) *
          math.cos(b.latitude * math.pi / 180) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return 2 * r * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}
