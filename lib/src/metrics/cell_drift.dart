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
    this.days = 0,
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

  /// Resting readings the figures were built from.
  final int samples;

  /// How many days the trend spans, first day with data to last.
  final int spanDays;

  /// On how many different days there were resting readings to judge by.
  /// What a sentence about the trend can honestly say it rests on: a span of
  /// six weeks with readings on five of its days is five days of data.
  final int days;

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
/// Every reading is compared against its own pack average, which cancels the
/// whole pack moving up and down, but not everything: how far a weak cell sits
/// under the others depends on where in the charge it is read, because a cell
/// with less capacity runs ahead of the rest along the discharge curve. A
/// reading at 90% and one at 30% are not comparable, and a trend built from a
/// month of full packs followed by a month of empty ones would be a trend in
/// how the pack was used. So only readings inside one band of charge
/// ([socLow] to [socHigh]) are used, on both sides of the comparison.
///
/// Rest is judged strictly: under [restingCurrentAmps] either way, and at
/// least [settleAfter] after the last reading that was not. The tail of a
/// charge, a balancer at work and the minute after a ride all pass a looser
/// test, and each of them moves the cells apart for reasons that are not wear.
///
/// The trend is a straight line fitted through one figure per day (the median
/// of that day's resting readings), so a day with five hundred readings counts
/// once, like a day with ten.
class CellDriftAnalysis {
  const CellDriftAnalysis({
    this.minimumDays = 5,
    this.minimumDaysPerHalf = 3,
    this.minimumReadingsPerDay = 3,
    this.minimumSpanDays = 14,
    this.restingCurrentAmps = 1.0,
    this.settleAfter = const Duration(seconds: 60),
    this.socLow = 40,
    this.socHigh = 80,
  });

  /// Fewer days than this and any trend is imagination.
  final int minimumDays;

  /// And this many in each half of the span, so the line is not one cluster
  /// of days at the start joined to a single day at the end.
  final int minimumDaysPerHalf;

  /// A day with fewer resting readings than this does not get a figure.
  final int minimumReadingsPerDay;

  /// Shorter than this, a "per month" figure extrapolated from a few days is
  /// a number with a unit and no meaning.
  final int minimumSpanDays;

  /// Only readings taken at rest are used. Under load the cell with the
  /// highest resistance sags most, which looks exactly like the cell with the
  /// least capacity and is a different fault with a different fix.
  final double restingCurrentAmps;

  /// How long after the pack last worked a reading counts as rest.
  final Duration settleAfter;

  /// The band of charge every reading used has to be in, in percent.
  final double socLow;
  final double socHigh;

  /// Returns one entry per cell, worsening cells first and the fastest of
  /// those first, then the rest; or an empty list when there is not enough
  /// history to say anything.
  List<CellDrift> analyse(List<Snapshot> readings) {
    final sorted = [...readings]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Each resting reading's deviations, filed under its day.
    final byDay = <DateTime, List<List<double>>>{};
    DateTime? lastActive;
    var used = 0;
    int? cellCount;
    for (final r in sorted) {
      if (r.current.abs() >= restingCurrentAmps) {
        lastActive = r.timestamp;
        continue;
      }
      final active = lastActive;
      if (active != null && r.timestamp.difference(active) < settleAfter) {
        continue;
      }
      if (r.soc < socLow || r.soc > socHigh) continue;
      final cells = decodeCellVoltages(r.cellVoltagesJson);
      if (cells.length < 2) continue;
      cellCount ??= cells.length;
      if (cells.length != cellCount) continue;
      final mean = cells.reduce((a, b) => a + b) / cells.length;
      final t = r.timestamp.toUtc();
      final day = DateTime.utc(t.year, t.month, t.day);
      // Positive means below the pack, so "bigger is worse" reads naturally
      // everywhere downstream.
      (byDay[day] ??= []).add([for (final c in cells) mean - c]);
      used++;
    }
    final n = cellCount;
    if (n == null) return const [];

    final days = byDay.keys
        .where((d) => byDay[d]!.length >= minimumReadingsPerDay)
        .toList()
      ..sort();
    if (days.length < minimumDays) return const [];
    final spanDays = days.last.difference(days.first).inDays;
    if (spanDays < minimumSpanDays) return const [];
    final midpoint = days.first.add(Duration(hours: spanDays * 12));
    final earlyDays = days.where((d) => d.isBefore(midpoint)).length;
    if (earlyDays < minimumDaysPerHalf ||
        days.length - earlyDays < minimumDaysPerHalf) {
      return const [];
    }

    final x = [for (final d in days) d.difference(days.first).inHours / 24.0];
    // The median of each cell's deviation, per day.
    final perDay = [
      for (final d in days)
        [
          for (var i = 0; i < n; i++)
            _median([for (final dev in byDay[d]!) dev[i]]),
        ],
    ];

    final out = <CellDrift>[];
    for (var i = 0; i < n; i++) {
      final y = [for (final row in perDay) row[i]];
      // The ends are read from the days themselves rather than from the
      // fitted line, so the figure quoted as "now" is one the pack showed:
      // the median of the last three days, and of the first three.
      out.add(
        CellDrift(
          index: i,
          currentDeviationVolts: _median(y.sublist(y.length - 3)),
          earlyDeviationVolts: _median(y.sublist(0, 3)),
          changeVoltsPerMonth: _slope(x, y) * 30,
          samples: used,
          spanDays: spanDays,
          days: days.length,
        ),
      );
    }
    out.sort((a, b) {
      if (a.isWorsening != b.isWorsening) return a.isWorsening ? -1 : 1;
      return b.changeVoltsPerMonth.compareTo(a.changeVoltsPerMonth);
    });
    return out;
  }

  /// Which cell sat lowest most often, over the resting readings of the
  /// [window] before the newest one, by the same rule of rest as the trend.
  ///
  /// The single last reading cannot answer "which is the weakest cell": it
  /// may have been taken under load, where the cell with the most resistance
  /// sags lowest, and even at rest the lowest one wanders between cells that
  /// are a millivolt apart. Null when there is no resting reading to count.
  LowestCellTally? mostOftenLowest(
    List<Snapshot> readings, {
    Duration window = const Duration(days: 30),
  }) {
    if (readings.isEmpty) return null;
    final sorted = [...readings]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final from = sorted.last.timestamp.subtract(window);
    final counts = <int, int>{};
    var total = 0;
    DateTime? lastActive;
    for (final r in sorted) {
      if (r.current.abs() >= restingCurrentAmps) {
        lastActive = r.timestamp;
        continue;
      }
      if (r.timestamp.isBefore(from)) continue;
      final active = lastActive;
      if (active != null && r.timestamp.difference(active) < settleAfter) {
        continue;
      }
      final cells = decodeCellVoltages(r.cellVoltagesJson);
      if (cells.length < 2) continue;
      var idx = 0;
      for (var i = 1; i < cells.length; i++) {
        if (cells[i] < cells[idx]) idx = i;
      }
      counts[idx] = (counts[idx] ?? 0) + 1;
      total++;
    }
    if (total == 0) return null;
    final top = counts.entries.reduce((a, b) => b.value > a.value ? b : a);
    return LowestCellTally(
      index: top.key,
      share: top.value / total,
      readings: total,
    );
  }

  /// The cell that is drifting away, if any is. See [worstWorsening].
  CellDrift? worsening(List<Snapshot> readings) =>
      worstWorsening(analyse(readings));

  /// Of [ranking], the worsening cell furthest under the pack, if any.
  ///
  /// Every cell is looked at. Reading only the fastest-changing one let a
  /// cell moving quickly inside a small gap stand for the whole pack, and a
  /// second cell that really was sinking went unmentioned under "no cell is
  /// drifting".
  static CellDrift? worstWorsening(List<CellDrift> ranking) {
    CellDrift? worst;
    for (final c in ranking) {
      if (!c.isWorsening) continue;
      if (worst == null ||
          c.currentDeviationVolts > worst.currentDeviationVolts) {
        worst = c;
      }
    }
    return worst;
  }

  /// The cell furthest under the pack average, worsening or not: what "the
  /// lowest one" in a sentence refers to.
  static CellDrift? lowest(List<CellDrift> ranking) {
    CellDrift? low;
    for (final c in ranking) {
      if (low == null || c.currentDeviationVolts > low.currentDeviationVolts) {
        low = c;
      }
    }
    return low;
  }

  static double _median(List<double> v) {
    final s = [...v]..sort();
    final m = s.length ~/ 2;
    return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
  }

  /// Least-squares slope of [y] against [x].
  static double _slope(List<double> x, List<double> y) {
    final n = x.length;
    final mx = x.reduce((a, b) => a + b) / n;
    final my = y.reduce((a, b) => a + b) / n;
    var num = 0.0;
    var den = 0.0;
    for (var i = 0; i < n; i++) {
      num += (x[i] - mx) * (y[i] - my);
      den += (x[i] - mx) * (x[i] - mx);
    }
    return den == 0 ? 0 : num / den;
  }
}

/// Which cell was lowest most often, and how often.
class LowestCellTally {
  const LowestCellTally({
    required this.index,
    required this.share,
    required this.readings,
  });

  /// Zero-based.
  final int index;

  /// Of the resting readings counted, the fraction in which it was lowest.
  final double share;

  /// How many resting readings were counted.
  final int readings;
}
