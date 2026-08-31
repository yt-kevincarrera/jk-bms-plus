import '../data/database.dart';
import 'range_estimator.dart';

/// What can be said about one battery from what is on disk.
///
/// Pulled out of the offline screen so the comparison screen computes the same
/// figures the same way. Two screens deriving "health" with slightly different
/// arithmetic is how an app ends up disagreeing with itself, and the rider has
/// no way to tell which one is lying.
class PackSummary {
  const PackSummary({
    required this.device,
    required this.rides,
    required this.totalKm,
    required this.readings,
    this.lastReadingAt,
    this.firstReadingAt,
    this.lastSoc,
    this.impliedCapacityAh,
    this.healthPercent,
    this.bmsSoh,
    this.reportedCycles,
    this.honestCycles,
    this.whPerKm,
    this.rangeKm,
    this.bestMeasuredAh,
    this.worstDeltaVolts,
  });

  final Device device;

  final int rides;
  final double totalKm;
  final int readings;
  final DateTime? lastReadingAt;
  final DateTime? firstReadingAt;
  final double? lastSoc;

  /// Capacity the BMS's own coulomb counter implies. Arithmetic on what the
  /// BMS says about itself, not a measurement.
  final double? impliedCapacityAh;

  /// That capacity against what the pack was sold as, when anybody has said.
  final double? healthPercent;

  final double? bmsSoh;
  final double? reportedCycles;

  /// Total throughput divided by capacity. The BMS counter increments on
  /// partial charges, so it always reads higher than this.
  final double? honestCycles;

  final double? whPerKm;
  final double? rangeKm;

  /// The largest capacity actually measured, which is the one figure here that
  /// is not arithmetic on the BMS's own claims.
  final double? bestMeasuredAh;

  final double? worstDeltaVolts;

  String get label => device.name.isEmpty ? device.id : device.name;

  /// How much of the BMS's cycle count is inflation, as a multiple.
  double? get cycleInflation {
    final reported = reportedCycles;
    final honest = honestCycles;
    if (reported == null || honest == null || honest <= 0) return null;
    return reported / honest;
  }

  /// Builds a summary from rows already read off disk.
  ///
  /// Takes the rows rather than the repository so it stays testable and so the
  /// caller decides how much history to pull.
  static PackSummary from({
    required Device device,
    required List<Snapshot> readings,
    required List<Trip> trips,
    required List<CapacityTest> tests,
  }) {
    final last = readings.isEmpty ? null : readings.last;

    // Only away from the extremes of charge, where dividing by a rounded
    // percentage is noise rather than a figure.
    final socFraction = last == null ? 0.0 : last.soc / 100.0;
    final implied = last != null && socFraction >= 0.15 && socFraction <= 0.95
        ? last.remainingAh / socFraction
        : null;

    final catalogue = device.catalogueCapacityAh;
    final health = implied != null && catalogue != null && catalogue > 0
        ? (implied / catalogue * 100).clamp(0.0, 120.0).toDouble()
        : null;

    // The honest cycle count needs a capacity to divide by. The implied one is
    // closer to the truth than the catalogue claim, so it is preferred.
    final forCycles = implied ?? catalogue;
    final honest = last != null && forCycles != null && forCycles > 0
        ? last.cycleCapacityAh / forCycles
        : null;

    final usable = trips
        .where((t) => t.distanceKm >= 0.2 && t.energyOutWh > t.energyInWh)
        .toList();
    final estimator = RangeEstimator();
    for (final t in usable) {
      estimator.addSegment(wh: t.energyOutWh - t.energyInWh, km: t.distanceKm);
    }

    final completed = tests.where((x) => x.completed).toList();
    final measured = completed.map((x) => x.measuredAh).toList();

    final deltas = readings.map((r) => r.deltaVolts).toList();

    return PackSummary(
      device: device,
      rides: trips.length,
      totalKm: trips.fold<double>(0, (a, b) => a + b.distanceKm),
      readings: readings.length,
      lastReadingAt: last?.timestamp,
      firstReadingAt: readings.isEmpty ? null : readings.first.timestamp,
      lastSoc: last?.soc,
      impliedCapacityAh: implied,
      healthPercent: health,
      bmsSoh: last?.soh,
      reportedCycles: last?.cycleCount,
      honestCycles: honest != null && honest > 0 ? honest : null,
      whPerKm: estimator.hasLearned ? estimator.whPerKm : null,
      rangeKm: estimator.hasLearned && catalogue != null && last != null
          ? estimator.rangeKm(catalogue * last.packVoltage)
          : null,
      bestMeasuredAh:
          measured.isEmpty ? null : measured.reduce((a, b) => a > b ? a : b),
      worstDeltaVolts:
          deltas.isEmpty ? null : deltas.reduce((a, b) => a > b ? a : b),
    );
  }
}
