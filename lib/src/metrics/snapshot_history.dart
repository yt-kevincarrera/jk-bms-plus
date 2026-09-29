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
    session.add(snapshot);
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
    session.clear();
  }

  /// What the whole connection has shown, for the advice engine.
  final SessionAggregates session = SessionAggregates();

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

/// One reading taken under load, as the loaded-delta figure keeps it.
class LoadedFrame {
  const LoadedFrame({
    required this.delta,
    required this.lowestCell,
    required this.current,
  });

  final double delta;

  /// 1-based cell that was lowest in this reading.
  final int lowestCell;
  final double current;
}

/// What the advice engine reads about the whole connection.
///
/// Accumulated in [SnapshotHistory.add] rather than scanned off the buffer.
/// The buffer holds twenty-odd minutes, and the findings built on it were
/// labelled "in this session" and "never all session" while describing the
/// last twenty minutes. Frames the JK merely repeats (same cell voltages as
/// the one before) count once: it resends a reading across consecutive
/// frames, and counting each copy weighed a stuck moment as many.
class SessionAggregates {
  /// Discharge current from which a reading counts as under load.
  static const double loadAmps = 10;

  /// How many of the widest loaded readings the loaded delta is the median
  /// of. One reading is not evidence: current and cell voltages in one frame
  /// are not always the same instant, and a single mismatched frame used to
  /// be the whole figure.
  static const int loadedTopFrames = 5;

  /// A weakest-cell reading only counts with the cells at least this far
  /// apart. Below it, which cell is lowest is measurement noise: the finding
  /// used to fire on a pack 2 mV apart.
  static const double weakCellMinDelta = 0.010;

  /// And only when the lowest cell is lowest by this much. A tie went to the
  /// lowest-numbered cell, so cell 1 won every level reading.
  static const double weakCellMinLead = 0.002;

  double? _restingDelta;
  int? _restingDeltaCell;
  final List<LoadedFrame> _loadedTop = [];
  int _loadedFrames = 0;
  int _heavyFrames = 0;
  double _peakLoadAmps = 0;
  final Map<int, int> _weakCellCounts = {};
  bool _balancerSeen = false;
  List<double>? _previousCells;

  void clear() {
    _restingDelta = null;
    _restingDeltaCell = null;
    _loadedTop.clear();
    _loadedFrames = 0;
    _heavyFrames = 0;
    _peakLoadAmps = 0;
    _weakCellCounts.clear();
    _balancerSeen = false;
    _previousCells = null;
  }

  void add(BmsSnapshot s) {
    if (s.balancerActive) _balancerSeen = true;
    final cells = s.cellVoltages;
    if (cells.length < 2) return;
    final repeat = _sameAs(_previousCells, cells);
    _previousCells = cells;
    if (repeat) return;

    final delta = s.deltaCellVoltage;
    if (SnapshotHistory.isResting(s)) {
      if (_restingDelta == null || delta > _restingDelta!) {
        _restingDelta = delta;
        _restingDeltaCell = s.minCellIndex;
      }
    }

    if (s.current <= -loadAmps) {
      _loadedFrames++;
      final amps = -s.current;
      if (amps > _peakLoadAmps) _peakLoadAmps = amps;
      if (amps >= heavyLoadAmps(s.nominalCapacityAh)) _heavyFrames++;
      _loadedTop.add(
        LoadedFrame(delta: delta, lowestCell: s.minCellIndex, current: s.current),
      );
      _loadedTop.sort((a, b) => b.delta.compareTo(a.delta));
      if (_loadedTop.length > loadedTopFrames) _loadedTop.removeLast();
    }

    if (delta >= weakCellMinDelta) {
      final lowest = s.minCellVoltage;
      var second = double.infinity;
      var lowestSeen = false;
      for (final v in cells) {
        if (v == lowest && !lowestSeen) {
          lowestSeen = true;
          continue;
        }
        if (v < second) second = v;
      }
      if (second - lowest >= weakCellMinLead) {
        final index = s.minCellIndex;
        _weakCellCounts[index] = (_weakCellCounts[index] ?? 0) + 1;
      }
    }
  }

  /// Current from which a load is heavy enough to show a resistive fault: a
  /// third of the pack's capacity per hour, or 15 A, whichever is lower. On
  /// the 40 Ah pack this was measured on, 12 A.
  static double heavyLoadAmps(double capacityAh) {
    final cRate = capacityAh > 0 ? capacityAh * 0.3 : double.infinity;
    return cRate < 15 ? cRate : 15;
  }

  static bool _sameAs(List<double>? a, List<double> b) {
    if (a == null || a.length != b.length) return false;
    for (var i = 0; i < b.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Widest cell delta seen at rest since the pack connected, charging
  /// excluded: a charger tapering off holds the cells apart by more than
  /// they sit.
  ///
  /// Separating this from the loaded delta is what tells a mismatched cell
  /// apart from a resistive connection: a cell that only falls behind when
  /// current flows is a resistance problem, and resistance is often a
  /// connection rather than a bad cell.
  double? get restingDelta => _restingDelta;

  /// The cell that was lowest in that resting reading. Not the cell lowest
  /// now, which under load or on the charger can be any of them.
  int? get restingDeltaCell => _restingDeltaCell;

  /// The delta under load that several readings reached: the median of the
  /// [loadedTopFrames] widest. Null until that many distinct loaded readings
  /// have been seen.
  double? get loadedDelta => _loadedMedian?.delta;

  /// The cell that was lowest in that median reading.
  int? get loadedDeltaCell => _loadedMedian?.lowestCell;

  LoadedFrame? get _loadedMedian =>
      _loadedTop.length < loadedTopFrames ? null : _loadedTop[loadedTopFrames ~/ 2];

  /// Distinct readings taken under load, and how many of those at a heavy
  /// one (see [heavyLoadAmps]).
  int get loadedFrames => _loadedFrames;
  int get heavyLoadFrames => _heavyFrames;

  /// The most current seen going out, in amps.
  double get peakLoadAmps => _peakLoadAmps;

  /// How often each cell has been clearly the lowest, 1-based, counting only
  /// readings where the cells were apart and the lowest was not tied.
  Map<int, int> get weakCellCounts => Map.unmodifiable(_weakCellCounts);

  /// Whether the balancer has been seen doing anything since the pack
  /// connected.
  bool get balancerEverSeen => _balancerSeen;
}
