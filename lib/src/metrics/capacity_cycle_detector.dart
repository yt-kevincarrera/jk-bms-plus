import '../data/database.dart';
import 'capacity_endpoints.dart';
import 'sampling.dart';

/// A full discharge found in the stored history.
class DetectedCycle {
  const DetectedCycle({
    required this.startedAt,
    required this.endedAt,
    required this.startSoc,
    required this.endSoc,
    required this.startPackVoltage,
    required this.endPackVoltage,
    required this.measuredAh,
    required this.measuredWh,
    required this.gapSeconds,
    this.endReason = CapacityEndReason.cellCutoff,
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final double startSoc;
  final double endSoc;
  final double startPackVoltage;
  final double endPackVoltage;
  final double measuredAh;
  final double measuredWh;

  /// Seconds of the discharge the app was not connected for.
  ///
  /// A cycle with a big hole in it undercounts, because the amp-hours that left
  /// the pack while nobody was watching cannot be recovered. Kept so the result
  /// can be thrown away rather than quietly believed.
  final int gapSeconds;

  /// What in the readings said the pack was empty.
  final CapacityEndReason endReason;

  Duration get duration => endedAt.difference(startedAt);
}

/// Finds full discharges in the readings that were already being stored.
///
/// The point is that nobody has to remember anything. Pressing a button before
/// a ride is a fine way to make a deliberate measurement, but it is a terrible
/// way to be the *only* way: you notice the pack is empty long after the
/// moment you needed to have started recording. Every reading is on disk
/// anyway, so a pass over the history finds the cycles that already happened.
///
/// What counts as a cycle: the last reading with the cells at the top and the
/// charger tapered off or gone, then a continuous run of discharge, then the
/// lowest cell at the cutoff or the BMS's undervoltage warning, with no charge
/// in between. Both ends are read off the cells ([CapacityEndpoints]), never
/// off the BMS's percentage: the percentage is remaining over the configured
/// capacity, so a run from 97 % to 3 % could only ever hand the configured
/// figure back. Anything else is a partial and says nothing about total
/// capacity.
class CapacityCycleDetector {
  const CapacityCycleDetector({
    this.endpoints = const CapacityEndpoints(
      fullCellVolts: 4.15,
      cutoffCellVolts: 3.0,
    ),
    this.chargingCurrent = 1.0,
    this.maxGap = const Duration(seconds: 10),
    this.voidAfter = const Duration(minutes: 30),
    this.maxRiseFraction = 0.02,
    this.restingJumpVoltsPerCell = 0.10,
    this.minimumAh = 1.0,
  });

  /// Where full and empty are, for this pack.
  final CapacityEndpoints endpoints;

  /// Amps in, above which the pack is being charged and the run is void.
  final double chargingCurrent;

  /// Longer than this between readings and the integration is not continued
  /// across it; the missing time is counted as a gap instead.
  final Duration maxGap;

  /// Longer than this between two readings and the run is void, whatever the
  /// readings on either side say. Half an hour unwatched is long enough to
  /// have been on a charger and back, and a run that spans a charge is two
  /// discharges added together.
  final Duration voidAfter;

  /// How far the charge, or the remaining amp-hours as a share of the
  /// capacity they imply, may rise from one reading to the next before the
  /// run is void. A discharge never gains two points; a charge the app did
  /// not see does, and that used to be invisible unless a reading happened
  /// to catch current going in.
  final double maxRiseFraction;

  /// How far the resting cell average may rise across an unwatched gap. A
  /// pack that rests higher than it rested before the gap was charged in
  /// between, whatever the counter says.
  final double restingJumpVoltsPerCell;

  /// Runs that drew less than this are noise, not cycles.
  final double minimumAh;

  /// Scans readings, oldest first, and returns every complete discharge.
  List<DetectedCycle> scan(List<Snapshot> readings) {
    final cycles = <DetectedCycle>[];

    _Run? run;
    Snapshot? previous;

    for (final s in readings) {
      final before = previous;
      previous = s;

      final cells = decodeCellVoltages(s.cellVoltagesJson);
      final topCell = cells.isEmpty
          ? 0.0
          : cells.reduce((a, b) => a > b ? a : b);

      // Every full reading (re)opens the run, so what opens it in the end is
      // the last moment the pack was full before it started emptying. A pack
      // resting full for an hour, or finishing its taper, does not measure
      // from the first of those readings.
      if (endpoints.isFull(topCell: topCell, current: s.current, soc: s.soc)) {
        run = _Run.from(s);
        continue;
      }

      if (run == null) continue;

      // Charging mid-run, below the top, means this was never a single
      // discharge.
      if (s.current > chargingCurrent) {
        run = null;
        continue;
      }

      if (before != null && _chargedUnseen(before, s)) {
        run = null;
        continue;
      }

      run.add(s, maxGap: maxGap);

      final reason = endpoints.emptyReason(
        minCell: cells.isEmpty ? 0 : cells.reduce((a, b) => a < b ? a : b),
        warningsMask: s.warningsMask,
      );
      if (reason == null) continue;

      final cycle = run.close(s, reason);
      if (cycle.measuredAh >= minimumAh) cycles.add(cycle);
      run = null;
    }

    return cycles;
  }

  /// Whether something between two consecutive readings can only have been
  /// a charge the app did not see: overnight on the charger with the phone
  /// elsewhere, and the next morning's ride read as the same discharge.
  bool _chargedUnseen(Snapshot a, Snapshot b) {
    final gap = b.timestamp.difference(a.timestamp);
    if (gap > voidAfter) return true;

    if (b.soc - a.soc > maxRiseFraction * 100) return true;
    final implied = a.soc > 0 ? a.remainingAh / (a.soc / 100) : 0.0;
    if (implied > 0 &&
        b.remainingAh - a.remainingAh > implied * maxRiseFraction) {
      return true;
    }

    // Only across a gap and only at rest on both sides: a pack coming off a
    // load rebounds upward on its own, and that is not a charge.
    if (gap > maxGap && a.current.abs() < 0.5 && b.current.abs() < 0.5) {
      final ca = decodeCellVoltages(a.cellVoltagesJson);
      final cb = decodeCellVoltages(b.cellVoltagesJson);
      if (ca.isNotEmpty && cb.isNotEmpty) {
        final meanA = ca.reduce((x, y) => x + y) / ca.length;
        final meanB = cb.reduce((x, y) => x + y) / cb.length;
        if (meanB - meanA > restingJumpVoltsPerCell) return true;
      }
    }
    return false;
  }
}

/// Whether a detected cycle is one already on record.
///
/// Rescanning the same history is normal: it happens at every start and after
/// every ride, so a cycle has to be recognised as one already stored or the
/// same discharge becomes a new measurement each time. Matched on the start
/// instant, loosely, since the reading that opens a run can differ by a sample
/// between scans.
bool cycleAlreadyRecorded(
  DateTime startedAt,
  Iterable<DateTime> knownStarts, {
  Duration tolerance = const Duration(minutes: 2),
}) =>
    knownStarts.any((k) => k.difference(startedAt).abs() < tolerance);

class _Run {

  _Run.from(Snapshot s)
      : startedAt = s.timestamp,
        startSoc = s.soc,
        startPackVoltage = s.packVoltage,
        _lastAt = s.timestamp,
        _lastCurrent = s.current,
        _lastPower = s.packVoltage * s.current;

  final DateTime startedAt;
  final double startSoc;
  final double startPackVoltage;

  DateTime _lastAt;
  double _lastCurrent;
  double _lastPower;

  double _ah = 0;
  double _wh = 0;
  int _gapSeconds = 0;

  void add(Snapshot s, {required Duration maxGap}) {
    final raw = s.timestamp.difference(_lastAt);
    final power = s.packVoltage * s.current;

    // Milliseconds. The old guard was inSeconds > 0, and the BMS pushes two or
    // three readings a second, so it was false for almost every interval and
    // the amp-hours between them were dropped. See [usableInterval].
    final dt = usableInterval(_lastAt, s.timestamp, maxGap: maxGap);
    if (dt != null) {
      final hours = hoursIn(dt);
      // Trapezoid, and only what left the pack.
      final averageCurrent = (_lastCurrent + s.current) / 2;
      final averagePower = (_lastPower + power) / 2;
      if (averageCurrent < 0) _ah += -averageCurrent * hours;
      if (averagePower < 0) _wh += -averagePower * hours;
    } else if (raw > maxGap) {
      _gapSeconds += raw.inSeconds;
    }

    _lastAt = s.timestamp;
    _lastCurrent = s.current;
    _lastPower = power;
  }

  DetectedCycle close(Snapshot s, CapacityEndReason reason) => DetectedCycle(
        startedAt: startedAt,
        endedAt: s.timestamp,
        startSoc: startSoc,
        endSoc: s.soc,
        startPackVoltage: startPackVoltage,
        endPackVoltage: s.packVoltage,
        measuredAh: _ah,
        measuredWh: _wh,
        gapSeconds: _gapSeconds,
        endReason: reason,
      );
}
