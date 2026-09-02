import 'dart:collection';

import '../model/bms_snapshot.dart';
import 'sampling.dart';

/// In-memory ring buffer of snapshots at full resolution, plus the smoothing
/// the screens read.
///
/// Full resolution matters: the derived metrics in section 7 of the PRD key off
/// current *steps*, and averaging those away in the buffer would destroy the
/// signal before it ever reached them. Smoothing happens on the way out, for
/// display only.
class SnapshotHistory {
  SnapshotHistory({
    this.capacity = 3600,
    this.smoothingWindow = 5,
  });

  /// One hour at 1 Hz. Persistence, not memory, is what keeps the long history.
  final int capacity;

  /// How many samples the displayed current and power are averaged over.
  final int smoothingWindow;

  final Queue<BmsSnapshot> _buffer = Queue<BmsSnapshot>();

  void add(BmsSnapshot snapshot) {
    _buffer.addLast(snapshot);
    while (_buffer.length > capacity) {
      _buffer.removeFirst();
    }
  }

  void clear() => _buffer.clear();

  bool get isEmpty => _buffer.isEmpty;
  int get length => _buffer.length;

  BmsSnapshot? get latest => _buffer.isEmpty ? null : _buffer.last;

  /// Oldest first.
  List<BmsSnapshot> get all => List.unmodifiable(_buffer);

  /// Everything newer than [window], oldest first.
  List<BmsSnapshot> recent(Duration window) {
    final last = latest;
    if (last == null) return const [];
    final cutoff = last.timestamp.subtract(window);
    return [
      for (final s in _buffer)
        if (s.timestamp.isAfter(cutoff)) s,
    ];
  }

  /// Moving average of current, in amps.
  ///
  /// Raw current jumps around too much to read on a moving motorcycle. Cell
  /// voltages are deliberately never smoothed: there the exact value is the
  /// whole point.
  double get smoothedCurrent => _average((s) => s.current);

  /// Moving average of power, in watts.
  double get smoothedPower => _average((s) => s.power);

  double _average(double Function(BmsSnapshot) field) {
    if (_buffer.isEmpty) return 0;
    final n = smoothingWindow.clamp(1, _buffer.length);
    var sum = 0.0;
    var i = 0;
    for (final s in _buffer.toList().reversed) {
      sum += field(s);
      if (++i >= n) break;
    }
    return sum / i;
  }

  /// Sag: how far the pack has dropped below its recent unloaded voltage.
  ///
  /// Returns null until there is an idle reading to compare against, which is
  /// honest — with no baseline there is no sag to report.
  double? get sagVolts {
    final last = latest;
    if (last == null) return null;
    double? restingVoltage;
    for (final s in _buffer) {
      if (s.current.abs() < 1.0) restingVoltage = s.packVoltage;
    }
    if (restingVoltage == null) return null;
    final sag = restingVoltage - last.packVoltage;
    return sag > 0 ? sag : 0;
  }

  /// Energy through the pack over the buffered window, in watt-hours.
  /// Positive means energy in.
  double get energyWh {
    if (_buffer.length < 2) return 0;
    final list = _buffer.toList();
    var wh = 0.0;
    for (var i = 1; i < list.length; i++) {
      // Ignore gaps: a dropped connection is not ten seconds of current.
      // Milliseconds, because the readings are 300 to 500 ms apart and the old
      // guard threw all of them away. See [usableInterval].
      final dt = usableInterval(
        list[i - 1].timestamp,
        list[i].timestamp,
      );
      if (dt == null) continue;
      final avgPower = (list[i].power + list[i - 1].power) / 2;
      wh += avgPower * hoursIn(dt);
    }
    return wh;
  }
}

/// Aggregates over the buffered session that the advice engine reads.
extension SnapshotHistoryAnalysis on SnapshotHistory {
  /// Widest cell delta seen with essentially no current flowing.
  ///
  /// Separating this from the loaded delta is what tells a genuinely mismatched
  /// cell apart from a resistive connection: a cell that only falls behind when
  /// current flows is a resistance problem, and resistance is usually a loose
  /// busbar rather than a bad cell.
  double? get restingDelta {
    double? worst;
    for (final s in all) {
      if (s.current.abs() > 1.0) continue;
      if (worst == null || s.deltaCellVoltage > worst) {
        worst = s.deltaCellVoltage;
      }
    }
    return worst;
  }

  /// Widest cell delta seen while pulling meaningful current.
  double? get loadedDelta {
    double? worst;
    for (final s in all) {
      if (s.current > -10) continue;
      if (worst == null || s.deltaCellVoltage > worst) {
        worst = s.deltaCellVoltage;
      }
    }
    return worst;
  }

  /// How often each cell has been the lowest one, 1-based.
  ///
  /// A pack where the same cell wins this every time has a weakest cell; one
  /// where it moves around does not, and the delta is just noise.
  Map<int, int> get weakCellCounts {
    final counts = <int, int>{};
    for (final s in all) {
      final index = s.minCellIndex;
      if (index > 0) counts[index] = (counts[index] ?? 0) + 1;
    }
    return counts;
  }

  /// Whether the balancer has been seen doing anything at all.
  bool get balancerEverSeen => all.any((s) => s.balancerActive);
}
