import '../data/database.dart';

/// How one cell has behaved against the rest of the pack, over time.
class CellDrift {
  const CellDrift({
    required this.index,
    required this.currentDeviationVolts,
    required this.earlyDeviationVolts,
    required this.changeVoltsPerMonth,
    required this.samples,
    this.spanDays = 0,
  });

  /// Zero-based position in the pack. Add one for the number on the label.
  final int index;

  /// How far below the pack average this cell sits now, in volts. Positive
  /// means below average, which is the direction that matters.
  final double currentDeviationVolts;

  /// Where it sat at the start of the window.
  final double earlyDeviationVolts;

  /// How fast the gap is opening, in volts per month. Positive is worsening.
  final double changeVoltsPerMonth;

  final int samples;

  /// How many days of readings the trend spans. What "per month" was
  /// measured over, and what "for three weeks" in a sentence refers to.
  final int spanDays;

  /// Whether this cell is drifting away rather than just sitting low.
  ///
  /// A cell that has always been 5 mV under is a pack that was built that way.
  /// A cell that was level six weeks ago and is 30 mV under now is a cell on
  /// its way out, and that is the one worth catching: it is the difference
  /// between replacing one cell and replacing a pack.
  bool get isWorsening =>
      changeVoltsPerMonth >= 0.004 && currentDeviationVolts >= 0.010;
}

/// Looks for a cell that is getting worse, not just one that is worst.
///
/// A single reading answers "which cell is lowest right now", which is mostly
/// noise: cells wander with temperature, load and where in the charge you look.
/// The useful question needs history, which this app has and a live view never
/// does.
///
/// Every reading is compared against its own pack average, so a measurement
/// taken at 90% and one taken at 30% are still comparable: the whole pack
/// moving up and down cancels out, and what is left is one cell against its
/// neighbours.
class CellDriftAnalysis {
  const CellDriftAnalysis({
    this.minimumSamples = 40,
    this.minimumSpanDays = 14,
    this.restingCurrentAmps = 2.0,
  });

  /// Fewer readings than this and any trend is imagination.
  final int minimumSamples;

  /// And shorter than this, a "per month" figure extrapolated from a few days
  /// is a number with a unit and no meaning.
  final int minimumSpanDays;

  /// Only readings taken at rest are used. Under load the cell with the
  /// highest resistance sags most, which looks exactly like the cell with the
  /// least capacity and is a different fault with a different fix.
  final double restingCurrentAmps;

  /// Returns one entry per cell, worst first, or an empty list when there is
  /// not enough history to say anything.
  List<CellDrift> analyse(List<Snapshot> readings) {
    final resting = readings
        .where((r) => r.current.abs() <= restingCurrentAmps)
        .toList();
    if (resting.length < minimumSamples) return const [];

    final span = resting.last.timestamp.difference(resting.first.timestamp);
    if (span.inDays < minimumSpanDays) return const [];

    // Split at the midpoint in time rather than by count, so a burst of
    // readings on one day cannot stand in for a period.
    final midpoint = resting.first.timestamp.add(span ~/ 2);
    final early = <List<double>>[];
    final late = <List<double>>[];
    for (final r in resting) {
      final cells = decodeCellVoltages(r.cellVoltagesJson);
      if (cells.length < 2) continue;
      (r.timestamp.isBefore(midpoint) ? early : late).add(cells);
    }
    if (early.isEmpty || late.isEmpty) return const [];

    final cellCount = late.first.length;
    if (early.first.length != cellCount) return const [];

    final earlyDev = _averageDeviations(early, cellCount);
    final lateDev = _averageDeviations(late, cellCount);
    if (earlyDev == null || lateDev == null) return const [];

    // Months between the two halves' centres, which is what the rate is per.
    final months = (span.inSeconds / 2) / (30 * 24 * 3600);
    if (months <= 0) return const [];

    final out = <CellDrift>[
      for (var i = 0; i < cellCount; i++)
        CellDrift(
          index: i,
          currentDeviationVolts: lateDev[i],
          earlyDeviationVolts: earlyDev[i],
          changeVoltsPerMonth: (lateDev[i] - earlyDev[i]) / months,
          samples: resting.length,
          spanDays: span.inDays,
        ),
    ]..sort((a, b) => b.changeVoltsPerMonth.compareTo(a.changeVoltsPerMonth));
    return out;
  }

  /// The cell that is drifting away, if any is.
  CellDrift? worsening(List<Snapshot> readings) {
    final all = analyse(readings);
    if (all.isEmpty) return null;
    return all.first.isWorsening ? all.first : null;
  }

  /// Mean shortfall against the pack average, per cell, across many readings.
  static List<double>? _averageDeviations(
    List<List<double>> samples,
    int cellCount,
  ) {
    final totals = List<double>.filled(cellCount, 0);
    var used = 0;
    for (final cells in samples) {
      if (cells.length != cellCount) continue;
      final mean = cells.reduce((a, b) => a + b) / cellCount;
      for (var i = 0; i < cellCount; i++) {
        // Positive means below the pack, so "bigger is worse" reads naturally
        // everywhere downstream.
        totals[i] += mean - cells[i];
      }
      used++;
    }
    if (used == 0) return null;
    return [for (final t in totals) t / used];
  }
}
