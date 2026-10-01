import 'dart:math' as math;

import '../data/database.dart';
import 'capacity_endpoints.dart';
import 'pack_resistance.dart';
import 'trip_learning.dart';

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
    this.trusted = true,
    this.detected = false,
  });

  final DateTime at;
  final double measuredAh;

  /// Whether the run passes [CapacityTestTrust]. Only trusted points make
  /// the trend; the others are drawn hollow, so the rider can see a run
  /// happened and that it is not being believed.
  final bool trusted;

  /// Found by the app in ordinary riding rather than run as a test. Also
  /// drawn hollow: it is a measurement, but nobody watched it start.
  final bool detected;
  /// What the pack was sold as at the time, or null if it was never stated.
  final double? catalogueAh;

  /// Measured against the claim, or null when there is no claim to measure
  /// against. Zero used to stand in for that, and plotted as a pack at 0%.
  double? get fraction =>
      (catalogueAh ?? 0) <= 0 ? null : measuredAh / catalogueAh!;
}

/// A ride's apparent pack resistance.
class ResistancePoint {
  const ResistancePoint({required this.at, required this.milliohms});

  final DateTime at;
  final double milliohms;
}

/// The views that only mean something once there is history behind them.
///
/// All of it is computed from rows already being stored; none of it needs new
/// hardware or protocol work. It was built last because a degradation curve
/// drawn across two days is a drawing, not a measurement — and the code has no
/// way to tell the difference, so the screens say how much is behind each one.
class LongTermAnalysis {
  const LongTermAnalysis();

  /// Consumption per ride, oldest first: the rides the range learns from
  /// ([TripLearning]), over a kilometre, at a figure a bike can produce.
  ///
  /// Not a wear signal, and the screen no longer says it is: what a ride
  /// costs moves with the route, the rider, the wind, the tyres and the
  /// temperature far more than with the pack. Unmeasured rides and the ones
  /// marked as an exception used to be plotted too, as zeros and outliers.
  List<ConsumptionPoint> consumptionOverTime(
    List<Trip> trips, {
    double minWhPerKm = 5,
    double maxWhPerKm = 100,
  }) {
    final points = <ConsumptionPoint>[];
    for (final t in trips) {
      if (t.demo || t.distanceKm < 1.0 || !TripLearning.teaches(t)) continue;
      final net = t.energyOutWh - t.energyInWh;
      final whPerKm = net / t.distanceKm;
      if (whPerKm < minWhPerKm || whPerKm > maxWhPerKm) continue;
      points.add(
        ConsumptionPoint(at: t.startedAt, whPerKm: net / t.distanceKm),
      );
    }
    points.sort((a, b) => a.at.compareTo(b.at));
    return points;
  }

  /// Delta against charge level, at rest and under load, never charging.
  ///
  /// The shape is the diagnosis, with one caution the screen has to carry:
  /// the delta opens near both ends of the charge on almost any pack, because
  /// that is where the voltage curve is steep and the smallest difference in
  /// state between cells shows as millivolts. What tells something is the
  /// resting line opening more than it used to, or opening across the middle
  /// where the curve is flat, and the loaded line sitting well above the
  /// resting one, which is resistance.
  ///
  /// Rest is under [restAmps] either way; under load is a discharge past
  /// [loadAmps]. Everything else is left out, and charging above all: it used
  /// to count as rest, and a charger pushing 10 A into a full pack is the one
  /// time the delta peaks on every pack there is.
  ///
  /// One point per percent of charge, the median of the readings in it, and
  /// only where there are [minPerBucket] of them. It used to keep the worst
  /// reading per half percent, which plotted a pack's single worst moments
  /// as if they were its shape.
  List<DeltaPoint> deltaAgainstCharge(
    List<Snapshot> snapshots, {
    double restAmps = 1.0,
    double loadAmps = 5.0,
    int minPerBucket = 3,
  }) {
    final buckets = <(bool, int), List<double>>{};
    for (final s in snapshots) {
      if (s.soc <= 0) continue;
      final loaded = s.current <= -loadAmps;
      final resting = s.current.abs() < restAmps;
      if (!loaded && !resting) continue;
      (buckets[(loaded, s.soc.round())] ??= []).add(s.deltaVolts);
    }
    final points = <DeltaPoint>[];
    for (final MapEntry(key: (loaded, soc), value: deltas) in buckets.entries) {
      if (deltas.length < minPerBucket) continue;
      deltas.sort();
      final m = deltas.length ~/ 2;
      final median =
          deltas.length.isOdd ? deltas[m] : (deltas[m - 1] + deltas[m]) / 2;
      points.add(
        DeltaPoint(soc: soc.toDouble(), deltaVolts: median, underLoad: loaded),
      );
    }
    points.sort((a, b) => a.soc.compareTo(b.soc));
    return points;
  }

  /// Measured capacity over time, from every finished run. Each says
  /// whether it passes the [CapacityTestTrust] rule the range and the wear
  /// figures use; a trend is drawn through the ones that do, so the chart
  /// cannot show a drop the rest of the app threw out.
  List<CapacityPoint> capacityOverTime(List<CapacityTest> tests) {
    final points = <CapacityPoint>[];
    for (final t in tests) {
      if (!t.completed || t.measuredAh <= 0) continue;
      points.add(
        CapacityPoint(
          at: t.endedAt ?? t.startedAt,
          measuredAh: t.measuredAh,
          catalogueAh: t.catalogueAh,
          trusted: t.isTrustworthy,
          detected: t.automatic,
        ),
      );
    }
    points.sort((a, b) => a.at.compareTo(b.at));
    return points;
  }

  /// The pack's apparent resistance per ride, oldest first.
  ///
  /// The figure stored with the ride when there is one, otherwise worked out
  /// from [readings] filed under it, which is how rides from before it was
  /// stored still get a point while their readings are fine-grained enough.
  /// See [PackResistance] for why this replaced the ride's highest voltage
  /// minus its lowest over its peak current.
  List<ResistancePoint> resistanceOverTime(
    List<Trip> trips,
    List<Snapshot> readings,
  ) {
    final byTrip = <int, List<Snapshot>>{};
    for (final r in readings) {
      final id = r.tripId;
      if (id != null) (byTrip[id] ??= []).add(r);
    }
    final points = <ResistancePoint>[];
    for (final t in trips) {
      if (t.demo) continue;
      var mohm = t.packResistanceMilliohms;
      if (mohm == null) {
        final rows = byTrip[t.id];
        if (rows != null) {
          rows.sort((x, y) => x.timestamp.compareTo(y.timestamp));
          mohm = PackResistance.fromReadings([
            for (final r in rows) (r.timestamp, r.packVoltage, r.current),
          ]);
        }
      }
      if (mohm == null) continue;
      points.add(ResistancePoint(at: t.startedAt, milliohms: mohm));
    }
    points.sort((a, b) => a.at.compareTo(b.at));
    return points;
  }

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
