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

  /// How many readings are kept. A JK sends two or three a second, so the
  /// default holds some 20 to 30 minutes, not the hour it was once described
  /// as. Anything meant to cover the whole connection is accumulated in
  /// [add] instead of read off this buffer; persistence, not memory, is what
  /// keeps the long history.
  final int capacity;

  /// How many samples the displayed current and power are averaged over.
  final int smoothingWindow;

  final Queue<BmsSnapshot> _buffer = Queue<BmsSnapshot>();

  void add(BmsSnapshot snapshot) {
    final previous = latest;
    if (previous != null) _accumulateEnergy(previous, snapshot);
    if (isResting(snapshot)) _latestResting = snapshot;
    if (snapshot.cellVoltages.isNotEmpty &&
        snapshot.maxCellVoltage > (_maxCellVoltageSeen ?? 0)) {
      _maxCellVoltageSeen = snapshot.maxCellVoltage;
    }
    _buffer.addLast(snapshot);
    while (_buffer.length > capacity) {
      _buffer.removeFirst();
    }
  }

  void clear() {
    _buffer.clear();
    _latestResting = null;
    _maxCellVoltageSeen = null;
    _sessionOutWh = 0;
    _sessionInWh = 0;
  }

  /// Whether a reading was taken with essentially nothing flowing, so its cell
  /// voltages say where the charge is.
  ///
  /// Under an amp of discharge: the lights alone draw 0.44 A on the pack this
  /// was measured on, and a wheel spinning on a stand 1.5 A. Nothing going
  /// in: a charger tapering off at the end of a charge is under an amp too,
  /// and it holds every cell above where it will settle.
  static bool isResting(BmsSnapshot s) => s.current > -1.0 && !s.isCharging;

  BmsSnapshot? _latestResting;

  /// The newest resting reading since the pack connected, even if it has
  /// since left the buffer.
  BmsSnapshot? get latestResting => _latestResting;

  double? _maxCellVoltageSeen;

  /// The highest cell voltage seen since the pack connected. What settles an
  /// unknown chemistry for the rest of the connection: a pack seen above
  /// 3.8 V a cell is not LFP, whatever it reads now.
  double? get maxCellVoltageSeen => _maxCellVoltageSeen;

  double _sessionOutWh = 0;
  double _sessionInWh = 0;

  /// Energy taken out of the pack since it connected, in watt-hours.
  ///
  /// Kept apart from [sessionInWh] and accumulated reading by reading. The
  /// figure this replaced was the net over the buffer, so a charge and a
  /// discharge cancelled each other out, and anything older than the buffer
  /// fell off the end of a row labelled as the whole session.
  double get sessionOutWh => _sessionOutWh;

  /// Energy put into the pack since it connected, in watt-hours.
  double get sessionInWh => _sessionInWh;

  void _accumulateEnergy(BmsSnapshot from, BmsSnapshot to) {
    // Gaps are skipped as everywhere else: a dropped link is not ten seconds
    // of current. See [usableInterval].
    final dt = usableInterval(from.timestamp, to.timestamp);
    if (dt == null) return;
    final wh = (from.power + to.power) / 2 * hoursIn(dt);
    if (wh >= 0) {
      _sessionInWh += wh;
    } else {
      _sessionOutWh -= wh;
    }
  }

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

  /// Sag: how far the pack has dropped below its unloaded voltage.
  ///
  /// Only against a resting reading from the last minute and within two
  /// points of charge of now. Against any resting reading in the buffer, as it
  /// used to be, a ride with no stops compared the pack now with the pack
  /// twenty minutes earlier, and quoted the charge used on the way as drop
  /// under load. Null, honestly, when there is no such reference.
  double? get sagVolts {
    final last = latest;
    final resting = _latestResting;
    if (last == null || resting == null) return null;
    if (last.timestamp.difference(resting.timestamp) > sagReferenceMaxAge) {
      return null;
    }
    if ((last.soc - resting.soc).abs() > sagReferenceMaxSocPoints) return null;
    final sag = resting.packVoltage - last.packVoltage;
    return sag > 0 ? sag : 0;
  }

  static const Duration sagReferenceMaxAge = Duration(seconds: 60);
  static const double sagReferenceMaxSocPoints = 2;
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
