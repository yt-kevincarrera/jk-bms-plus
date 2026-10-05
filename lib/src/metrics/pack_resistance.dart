/// The pack's apparent internal resistance over a ride, from the stretches in
/// which the current swung.
///
/// Replaces "worst sag": the ride's highest pack voltage minus its lowest,
/// divided by the peak current. That difference took in the whole fall in
/// charge over the ride as well as any sag, and the peak current came from a
/// different moment, so the milliohms it implied were mostly a measure of how
/// long the ride was. On the owner's rides it read 32 to 102 mOhm depending
/// on the ride, from the same pack.
///
/// Resistance shows where the current changes and the charge has no time to:
/// inside twenty seconds the state of charge barely moves, so a straight line
/// through the readings' voltage against their current has the resistance as
/// its slope (the pack's, plus the wiring's). Single steps between two
/// readings do not work at this data rate: a reading's current and voltage
/// are not always the same instant, and on real rides the steps came out at a
/// few milliohms, scattered. A line through a window of readings averages
/// that out, and the figure is the median over the ride's windows. On the
/// same rides it reads 18 to 26 mOhm, ride after ride.
///
/// Approximate, and said so on screen: it is good for watching the same pack
/// over months, not for comparing with a datasheet.
class PackResistance {
  PackResistance({
    this.window = const Duration(seconds: 20),
    this.maxGap = const Duration(seconds: 5),
    this.minReadings = 8,
    this.minSwingAmps = 10,
    this.minWindows = 5,
  });

  /// How long one stretch is.
  final Duration window;

  /// A silence longer than this breaks a stretch.
  final Duration maxGap;

  /// Fewer readings than this in a stretch and the line is two points.
  final int minReadings;

  /// The current has to swing at least this much inside a stretch, or the
  /// voltage moves by too little to read.
  final double minSwingAmps;

  /// Fewer usable stretches than this and the median is a handful of guesses.
  final int minWindows;

  final List<double> _ohms = [];
  final List<(DateTime, double, double)> _open = [];

  /// Usable stretches so far.
  int get windows => _ohms.length;

  /// Feeds one reading, discharge negative.
  void add(DateTime at, double packVolts, double amps) {
    if (packVolts <= 0) return;
    if (_open.isNotEmpty) {
      final (firstAt, _, _) = _open.first;
      final (lastAt, _, _) = _open.last;
      final gap = at.difference(lastAt);
      if (gap.isNegative || gap > maxGap || at.difference(firstAt) >= window) {
        _close();
      }
    }
    _open.add((at, packVolts, amps));
  }

  /// Ends the stretch in progress, so a pause or a gap is not part of one.
  void breakChain() => _close();

  void reset() {
    _ohms.clear();
    _open.clear();
  }

  void _close() {
    final w = List.of(_open);
    _open.clear();
    if (w.length < minReadings) return;
    var lo = double.infinity;
    var hi = -double.infinity;
    var sumI = 0.0;
    var sumV = 0.0;
    for (final (_, v, i) in w) {
      if (i < lo) lo = i;
      if (i > hi) hi = i;
      sumI += i;
      sumV += v;
    }
    // A charger holds the voltage up, and what a line implies there is the
    // charger's behaviour, not the pack's.
    if (hi > 1 || hi - lo < minSwingAmps) return;
    final mi = sumI / w.length;
    final mv = sumV / w.length;
    var num = 0.0;
    var den = 0.0;
    for (final (_, v, i) in w) {
      num += (i - mi) * (v - mv);
      den += (i - mi) * (i - mi);
    }
    if (den <= 0) return;
    // More discharge (more negative current) pulls the voltage down, so the
    // slope is positive and is the resistance. Past half an ohm the stretch
    // was not one instant's worth of pack.
    final ohms = num / den;
    if (ohms <= 0 || ohms > 0.5) return;
    _ohms.add(ohms);
  }

  /// The median, in milliohms, or null with too few stretches. Closes the
  /// stretch in progress first.
  double? get milliohms {
    _close();
    if (_ohms.length < minWindows) return null;
    final s = [..._ohms]..sort();
    final m = s.length ~/ 2;
    final median = s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
    return median * 1000;
  }

  /// The same, from stored readings (time, pack volts, amps) in time order.
  static double? fromReadings(Iterable<(DateTime, double, double)> readings) {
    final r = PackResistance();
    for (final (at, v, i) in readings) {
      r.add(at, v, i);
    }
    return r.milliohms;
  }
}
