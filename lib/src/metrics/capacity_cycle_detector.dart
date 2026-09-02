import '../data/database.dart';
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

  Duration get duration => endedAt.difference(startedAt);
}

/// Finds full discharges in the readings that were already being stored.
///
/// The point is that nobody has to remember anything. Pressing a button before
/// a ride is a fine way to make a deliberate measurement, but it is a terrible
/// way to be the *only* way — you notice the pack is empty long after the moment
/// you needed to have started recording. Every reading is on disk anyway, so a
/// pass over the history finds the cycles that already happened.
///
/// What counts as a cycle: a reading with the pack full, then a continuous run
/// of discharge, then the BMS cutting off or the charge reaching the floor,
/// with no charging in between. Anything else is a partial and says nothing
/// about total capacity.
class CapacityCycleDetector {
  const CapacityCycleDetector({
    this.fullSoc = 97,
    this.fullCellVolts = 4.15,
    this.emptySoc = 3,
    this.chargingCurrent = 1.0,
    this.maxGap = const Duration(seconds: 10),
    this.minimumAh = 1.0,
  });

  /// Charge, or top cell voltage, at which the pack counts as full.
  final double fullSoc;
  final double fullCellVolts;

  /// Charge at which it counts as done, if the BMS has not cut off first.
  final double emptySoc;

  /// Amps in, above which the pack is being charged and the run is void.
  final double chargingCurrent;

  /// Longer than this between readings and the integration is not continued
  /// across it; the missing time is counted as a gap instead.
  final Duration maxGap;

  /// Runs that drew less than this are noise, not cycles.
  final double minimumAh;

  /// Scans readings, oldest first, and returns every complete discharge.
  List<DetectedCycle> scan(List<Snapshot> readings) {
    final cycles = <DetectedCycle>[];

    _Run? run;

    for (var i = 0; i < readings.length; i++) {
      final s = readings[i];
      final cells = decodeCellVoltages(s.cellVoltagesJson);
      final topCell = cells.isEmpty
          ? 0.0
          : cells.reduce((a, b) => a > b ? a : b);
      final isFull = s.soc >= fullSoc || topCell >= fullCellVolts;

      if (run == null) {
        // Only a full pack opens a run. Starting anywhere else would measure a
        // slice and call it the whole.
        if (isFull) run = _Run.from(s);
        continue;
      }

      // Charging mid-run means this was never a single discharge. If the pack
      // is full again, the charge that just happened opens a fresh run.
      if (s.current > chargingCurrent) {
        run = isFull ? _Run.from(s) : null;
        continue;
      }

      run.add(s, maxGap: maxGap);

      final cutOff = s.soc <= emptySoc;
      if (!cutOff) continue;

      final cycle = run.close(s);
      if (cycle != null && cycle.measuredAh >= minimumAh) cycles.add(cycle);
      run = null;
    }

    return cycles;
  }
}

/// Whether a detected cycle is one already on record.
///
/// Rescanning the same history is normal — it happens at every start and after
/// every ride — so a cycle has to be recognised as one already stored or the
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

  DetectedCycle? close(Snapshot s) => DetectedCycle(
        startedAt: startedAt,
        endedAt: s.timestamp,
        startSoc: startSoc,
        endSoc: s.soc,
        startPackVoltage: startPackVoltage,
        endPackVoltage: s.packVoltage,
        measuredAh: _ah,
        measuredWh: _wh,
        gapSeconds: _gapSeconds,
      );
}
