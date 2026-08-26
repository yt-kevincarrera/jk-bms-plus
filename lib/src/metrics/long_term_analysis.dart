import 'dart:math' as math;

import '../data/database.dart';

/// One point on the consumption-over-time curve.
class ConsumptionPoint {
  const ConsumptionPoint({required this.at, required this.whPerKm});
  final DateTime at;
  final double whPerKm;
}

/// One point of delta plotted against how full the pack was.
class DeltaPoint {
  const DeltaPoint({
    required this.soc,
    required this.deltaVolts,
    required this.underLoad,
  });

  final double soc;
  final double deltaVolts;

  /// Whether meaningful current was flowing. Kept because the two populations
  /// answer different questions and must not be averaged together.
  final bool underLoad;
}

/// One measured capacity, over time.
class CapacityPoint {
  const CapacityPoint({
    required this.at,
    required this.measuredAh,
    required this.catalogueAh,
  });

  final DateTime at;
  final double measuredAh;
  final double catalogueAh;

  double get fraction => catalogueAh <= 0 ? 0 : measuredAh / catalogueAh;
}

/// Sag observed at a given current.
class SagPoint {
  const SagPoint({
    required this.at,
    required this.current,
    required this.sagVolts,
  });

  final DateTime at;
  final double current;
  final double sagVolts;
}

/// The views that only mean something once there is history behind them.
///
/// All of it is computed from rows already being stored; none of it needs new
/// hardware or protocol work. It was built last because a degradation curve
/// drawn across two days is a drawing, not a measurement — and the code has no
/// way to tell the difference, so the screens say how much is behind each one.
class LongTermAnalysis {
  const LongTermAnalysis();

  /// Consumption per ride, oldest first, demo rides excluded.
  ///
  /// This is the closest thing to a degradation signal available without a full
  /// capacity test: the same bike over the same roads costing more watt-hours
  /// per kilometre as the months pass.
  List<ConsumptionPoint> consumptionOverTime(List<Trip> trips) {
    final points = <ConsumptionPoint>[];
    for (final t in trips) {
      if (t.demo || t.distanceKm < 1.0) continue;
      final net = t.energyOutWh - t.energyInWh;
      if (net <= 0) continue;
      points.add(
        ConsumptionPoint(at: t.startedAt, whPerKm: net / t.distanceKm),
      );
    }
    points.sort((a, b) => a.at.compareTo(b.at));
    return points;
  }

  /// Delta against charge level.
  ///
  /// The shape is the diagnosis. A pack whose delta is flat across the range
  /// but jumps near full has one cell with less capacity than the rest; a pack
  /// whose delta rises with current has a resistance problem instead. Loaded
  /// and resting points are kept apart so the two can be told from each other.
  List<DeltaPoint> deltaAgainstCharge(List<Snapshot> snapshots) {
    // Thinned to one point per half a percent of charge, per population. At
    // 1 Hz a week of riding is half a million rows, and a scatter plot of all
    // of them is a smear rather than a shape.
    final buckets = <String, DeltaPoint>{};
    for (final s in snapshots) {
      if (s.soc <= 0) continue;
      final loaded = s.current < -5;
      final key = '${loaded ? 'L' : 'R'}${(s.soc * 2).round()}';
      final existing = buckets[key];
      // Keep the worst delta in each bucket: the question is how far apart the
      // cells get, not where they sit on average.
      if (existing == null || s.deltaVolts > existing.deltaVolts) {
        buckets[key] = DeltaPoint(
          soc: s.soc,
          deltaVolts: s.deltaVolts,
          underLoad: loaded,
        );
      }
    }
    final points = buckets.values.toList()
      ..sort((a, b) => a.soc.compareTo(b.soc));
    return points;
  }

  /// Measured capacity over time, from completed capacity tests.
  List<CapacityPoint> capacityOverTime(List<CapacityTest> tests) {
    final points = <CapacityPoint>[];
    for (final t in tests) {
      if (!t.completed || t.measuredAh <= 0) continue;
      points.add(
        CapacityPoint(
          at: t.endedAt ?? t.startedAt,
          measuredAh: t.measuredAh,
          catalogueAh: t.catalogueAh,
        ),
      );
    }
    points.sort((a, b) => a.at.compareTo(b.at));
    return points;
  }

  /// Worst sag seen per ride, against the current that caused it.
  ///
  /// Watched over months this is the cheapest early warning there is: the same
  /// current producing a bigger drop means the pack's internal resistance is
  /// climbing, and that shows up long before capacity does.
  List<SagPoint> sagOverTime(List<Trip> trips) {
    final points = <SagPoint>[];
    for (final t in trips) {
      if (t.demo || t.maxDischargeCurrent < 10) continue;
      final sag = t.maxPackVoltage - t.minPackVoltage;
      if (sag <= 0) continue;
      points.add(
        SagPoint(
          at: t.startedAt,
          current: t.maxDischargeCurrent,
          sagVolts: sag,
        ),
      );
    }
    points.sort((a, b) => a.at.compareTo(b.at));
    return points;
  }

  /// Sag normalised to milliohms of apparent pack resistance, which is what
  /// makes two rides at different currents comparable at all.
  double? apparentResistanceMilliohms(SagPoint point) =>
      point.current <= 0 ? null : point.sagVolts / point.current * 1000;

  /// Fits a straight line and reports the slope per 30 days.
  ///
  /// Deliberately simple: with a handful of points spread over months, anything
  /// cleverer would be fitting noise. Returns null until there is enough spread
  /// in time for a slope to mean anything.
  double? trendPerMonth(List<({DateTime at, double value})> points) {
    if (points.length < 3) return null;

    final first = points.first.at;
    final span = points.last.at.difference(first).inDays;
    if (span < 14) return null;

    var sumX = 0.0;
    var sumY = 0.0;
    var sumXY = 0.0;
    var sumXX = 0.0;
    for (final p in points) {
      final x = p.at.difference(first).inHours / 24.0;
      sumX += x;
      sumY += p.value;
      sumXY += x * p.value;
      sumXX += x * x;
    }
    final n = points.length;
    final denominator = n * sumXX - sumX * sumX;
    if (denominator.abs() < 1e-9) return null;

    final slopePerDay = (n * sumXY - sumX * sumY) / denominator;
    return slopePerDay * 30;
  }

  /// How much history is behind a set of points, in days.
  int spanDays(List<DateTime> times) {
    if (times.length < 2) return 0;
    final sorted = List<DateTime>.from(times)..sort();
    return math.max(0, sorted.last.difference(sorted.first).inDays);
  }
}
