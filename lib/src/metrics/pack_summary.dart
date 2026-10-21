import '../data/database.dart';
import '../pack/chemistry.dart';
import 'capacity_endpoints.dart';
import 'degradation.dart';
import 'pack_energy.dart';
import 'range_estimator.dart';
import 'range_outlook.dart';
import 'trip_learning.dart';

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

  /// A stored snapshot has no nominal-Ah field. Read the BMS scale back only
  /// from a recent, usable charge percentage in this pack's own history.
  /// The window is relative to the last stored reading, not today's clock.
  static const Duration configuredCapacityEvidenceReach = Duration(days: 1);

  static Snapshot? _latestReadingFor(
    Device device,
    List<Snapshot> readings,
    Snapshot? latestReading,
  ) {
    if (latestReading?.deviceId == device.id) return latestReading;
    for (final r in readings.reversed) {
      if (r.deviceId == device.id) return r;
    }
    return null;
  }

  static double? _configuredCapacityOf(Snapshot reading) {
    if (!reading.soc.isFinite || !reading.remainingAh.isFinite) return null;
    final capacity = Degradation.configuredCapacityFrom(
      soc: reading.soc,
      remainingAh: reading.remainingAh,
    );
    return capacity != null && capacity.isFinite && capacity > 0
        ? capacity
        : null;
  }

  static double? configuredCapacityFromHistory({
    required Device device,
    required List<Snapshot> readings,
    Snapshot? latestReading,
  }) {
    final newest = _latestReadingFor(device, readings, latestReading);
    if (newest != null) {
      final latestCapacity = _configuredCapacityOf(newest);
      if (latestCapacity != null) return latestCapacity;
      for (final r in readings.reversed) {
        if (r.deviceId != device.id) continue;
        final age = newest.timestamp.difference(r.timestamp);
        if (age.isNegative) continue;
        if (age > configuredCapacityEvidenceReach) break;
        final capacity = _configuredCapacityOf(r);
        if (capacity != null) return capacity;
      }
    }
    final borrowed = device.catalogueCapacityAh;
    return device.catalogueFromBms &&
            borrowed != null &&
            borrowed.isFinite &&
            borrowed > 0
        ? borrowed
        : null;
  }

  /// The saved-pack screen and comparison use the same operational range as
  /// live, with only the evidence that survived in storage. A sales claim
  /// cannot be relabelled as a BMS setting when no useful counter was saved.
  static RangeOutlook rangeOutlookFrom({
    required Device device,
    required List<Snapshot> readings,
    required RangeEstimator estimator,
    double? measuredCapacityAh,
    Snapshot? latestReading,
  }) {
    final last = _latestReadingFor(device, readings, latestReading);
    final configured = configuredCapacityFromHistory(
      device: device,
      readings: readings,
      latestReading: last,
    );
    final reference = RangeCapacityReference.best(
      measuredCapacityAh: measuredCapacityAh,
      configuredCapacityAh: configured,
      catalogueCapacityAh: device.catalogueCapacityAh,
    );
    var highestCell = last?.maxCellVoltage ?? 0.0;
    for (final r in readings) {
      if (r.deviceId == device.id && r.maxCellVoltage > highestCell) {
        highestCell = r.maxCellVoltage;
      }
    }
    final chemistry = PackEnergy.chemistryFor(
      declared: device.chemistry,
      highestCellVolts: highestCell > 0 ? highestCell : null,
    );
    final cutoff =
        ChemistryLimits.of(chemistry)?.typicalCutoffVolts ??
        ChemistryLimits.unknownCutoffVolts;
    final cells = last == null
        ? const <double>[]
        : decodeCellVoltages(last.cellVoltagesJson);
    double averageOf(List<double> values) =>
        values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;

    // As on the saved-pack screen before this shared calculation: only a
    // resting reading close enough to the last charge may derate its energy.
    bool isResting(Snapshot r) => r.current > -1.0 && r.current <= 0.05;
    Snapshot? resting = last != null && isResting(last) ? last : null;
    if (last != null && resting == null) {
      for (final r in readings.reversed) {
        if (r.deviceId != device.id) continue;
        final age = last.timestamp.difference(r.timestamp);
        if (age.isNegative) continue;
        if (age > const Duration(minutes: 30)) break;
        if (isResting(r)) {
          resting = r;
          break;
        }
      }
    }
    final restingCells = resting == null
        ? const <double>[]
        : decodeCellVoltages(resting.cellVoltagesJson);
    final energy = last == null || cells.isEmpty
        ? PackEnergy.none
        : PackEnergy.operationalRemaining(
            remainingAh: last.remainingAh,
            nominalCapacityAh: configured,
            referenceCapacityAh: reference?.capacityAh,
            soc: last.soc,
            cellCount: cells.length,
            chemistry: chemistry,
            cutoffVoltagePerCell: cutoff,
            resting: resting == null || restingCells.isEmpty
                ? null
                : RestingCells(
                    minCellVoltage: resting.minCellVoltage,
                    averageCellVoltage: averageOf(restingCells),
                    at: resting.timestamp,
                  ),
            liveAverageCellVoltage: averageOf(cells),
          );
    return RangeOutlook.from(
      estimator: estimator,
      usableWhNow: energy.usableWh,
      fullCapacityAh: reference?.capacityAh,
      fullPackVoltage: PackEnergy.operationalFullPackVoltage(
        cellCount: cells.length,
        chemistry: chemistry,
      ),
      usableFraction: energy.usableFraction ?? 1,
      capacityWasMeasured: reference?.source == RangeCapacitySource.measured,
      capacityFromBmsConfig: reference?.source == RangeCapacitySource.bmsConfig,
      fullNeedsChemistry: reference != null && !chemistry.isKnown,
    );
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

    // Remaining over charge reads back what the BMS is configured with, and
    // nothing else: it computes remaining amp-hours as charge times configured
    // capacity, so the division cancels. Only readable away from the extremes,
    // where the rounded percentage makes even that noisy.
    final implied = last == null
        ? null
        : Degradation.configuredCapacityFrom(
            soc: last.soc,
            remainingAh: last.remainingAh,
          );

    final catalogue = device.catalogueCapacityAh;

    // Health from measured discharges, or nothing. This used to be the implied
    // capacity over the catalogue figure, which on a pack whose catalogue came
    // from the BMS is 40 divided by 40: a permanent 100% that the home-screen
    // widget was showing as though it meant something.
    final wear = Degradation.from(
      tests: tests,
      readings: const [],
      advertisedAh: device.catalogueFromBms ? null : catalogue,
    );
    final lost = wear.lostFraction;
    final health = lost == null ? null : ((1 - lost) * 100).clamp(0.0, 100.0);

    // The honest cycle count needs a capacity to divide by. The implied one is
    // closer to the truth than the catalogue claim, so it is preferred.
    final forCycles = implied ?? catalogue;
    final honest = last != null && forCycles != null && forCycles > 0
        ? last.cycleCapacityAh / forCycles
        : null;

    // The live service's rule, oldest first: see [TripLearning].
    final estimator = TripLearning.estimatorFrom(trips);

    // The same trust rule as the live screen, so a pack whose only "best"
    // is a test with a hole in it does not win the comparison on it.
    final measured = [
      for (final x in tests)
        if (x.isTrustworthy) x.measuredAh,
    ];

    final deltas = readings.map((r) => r.deltaVolts).toList();

    final bestMeasured = measured.isEmpty
        ? null
        : measured.reduce((a, b) => a > b ? a : b);
    final outlook = rangeOutlookFrom(
      device: device,
      readings: readings,
      estimator: estimator,
      measuredCapacityAh: bestMeasured,
      latestReading: last,
    );

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
      rangeKm: outlook.fullKm,
      bestMeasuredAh: bestMeasured,
      worstDeltaVolts: deltas.isEmpty
          ? null
          : deltas.reduce((a, b) => a > b ? a : b),
    );
  }
}
