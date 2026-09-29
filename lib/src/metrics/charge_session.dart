import 'dart:convert';
import 'dart:math' as math;

import '../model/bms_snapshot.dart';
import 'sampling.dart';

/// What a charge turned out to be.
class ChargeReport {
  const ChargeReport({
    required this.startedAt,
    required this.endedAt,
    required this.startSoc,
    required this.endSoc,
    required this.ahIn,
    required this.whIn,
    required this.peakCurrent,
    required this.maxTemperature,
    required this.deltaAtStart,
    required this.deltaAtTop,
    required this.worstDeltaHigh,
    required this.weakCellAtTop,
    required this.strongCellAtTop,
    required this.balancerWorkedSeconds,
    required this.reachedTop,
    this.gapSeconds = 0,
  });

  /// Back from what [toJson] wrote, or null for anything that is not one.
  static ChargeReport? tryParse(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final m = jsonDecode(json) as Map<String, dynamic>;
      double d(String k) => (m[k] as num).toDouble();
      int i(String k) => (m[k] as num? ?? 0).toInt();
      return ChargeReport(
        startedAt: DateTime.parse(m['startedAt'] as String),
        endedAt: DateTime.parse(m['endedAt'] as String),
        startSoc: d('startSoc'),
        endSoc: d('endSoc'),
        ahIn: d('ahIn'),
        whIn: d('whIn'),
        peakCurrent: d('peakCurrent'),
        maxTemperature: (m['maxTemperature'] as num?)?.toDouble(),
        deltaAtStart: d('deltaAtStart'),
        deltaAtTop: d('deltaAtTop'),
        worstDeltaHigh: d('worstDeltaHigh'),
        weakCellAtTop: i('weakCellAtTop'),
        strongCellAtTop: i('strongCellAtTop'),
        balancerWorkedSeconds: i('balancerWorkedSeconds'),
        reachedTop: m['reachedTop'] as bool? ?? false,
        gapSeconds: i('gapSeconds'),
      );
    } on Object {
      return null;
    }
  }

  /// Stored with the pack, so the last charge survives a restart. It used to
  /// live only in memory, and after one the screen said no charge had ever
  /// been recorded.
  String toJson() => jsonEncode({
    'startedAt': startedAt.toUtc().toIso8601String(),
    'endedAt': endedAt.toUtc().toIso8601String(),
    'startSoc': startSoc,
    'endSoc': endSoc,
    'ahIn': ahIn,
    'whIn': whIn,
    'peakCurrent': peakCurrent,
    'maxTemperature': maxTemperature,
    'deltaAtStart': deltaAtStart,
    'deltaAtTop': deltaAtTop,
    'worstDeltaHigh': worstDeltaHigh,
    'weakCellAtTop': weakCellAtTop,
    'strongCellAtTop': strongCellAtTop,
    'balancerWorkedSeconds': balancerWorkedSeconds,
    'reachedTop': reachedTop,
    'gapSeconds': gapSeconds,
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final double startSoc;
  final double endSoc;
  final double ahIn;
  final double whIn;
  final double peakCurrent;
  /// Hottest battery probe over the charge, or null when the pack has none.
  final double? maxTemperature;

  /// Spread when charging began.
  final double deltaAtStart;

  /// Spread once the pack was near the top, which is where it matters.
  final double deltaAtTop;

  /// Worst spread seen anywhere above the high-voltage mark.
  final double worstDeltaHigh;

  /// The cells at each end of the pack near the top, 1-based. Zero when the
  /// charge never got high enough to tell.
  ///
  /// In series every cell takes the same current, so the one that fills
  /// first is the one reading highest: [strongCellAtTop], despite the name,
  /// is the cell with the least room, and [weakCellAtTop] the one furthest
  /// behind.
  final int weakCellAtTop;
  final int strongCellAtTop;

  final int balancerWorkedSeconds;

  /// Seconds of the charge the app did not see. The amp-hours across them
  /// are the BMS's own count, not the app's, and the card says so.
  final int gapSeconds;

  /// Whether the charge actually reached the region where imbalance shows.
  final bool reachedTop;

  Duration get duration => endedAt.difference(startedAt);

  /// How much wider the cells got between the start and the top.
  double? get spreadOpened =>
      reachedTop ? deltaAtTop - deltaAtStart : null;

  /// True when the pack looked fine most of the way and only came apart at the
  /// top. That pattern means one cell filling before the others, which is
  /// capacity mismatch rather than a bad connection.
  bool get opensAtTop {
    final opened = spreadOpened;
    return opened != null && opened > 0.030 && deltaAtStart < 0.030;
  }
}

/// Watches a charge and reports on it afterwards.
///
/// The top of a charge is the single most revealing window a pack ever offers.
/// Above roughly 4.0 V per cell the voltage curve turns steep, so a small
/// difference in how much charge two cells hold becomes a large difference in
/// voltage — a mismatch invisible at 60% is unmissable at 95%.
///
/// It is also the window nobody is watching, because charging happens overnight
/// with the phone somewhere else. So this records it whenever the app does
/// happen to be connected, and says plainly when the charge stopped short of
/// the interesting part.
class ChargeSessionRecorder {
  ChargeSessionRecorder({
    this.startCurrent = 1.0,
    this.stopCurrent = 0.3,
    this.highCellVolts = 4.0,
    this.minimumSoc = 5,
  });

  /// Charging is considered under way above this many amps in.
  final double startCurrent;

  /// And finished once it falls below this.
  final double stopCurrent;

  /// Where the revealing region begins, per cell.
  final double highCellVolts;

  /// Charges that add less than this many points of charge are not reported;
  /// topping up for two minutes says nothing.
  final double minimumSoc;

  bool _active = false;
  bool get isRecording => _active;

  DateTime? _startedAt;
  DateTime? _lastAt;
  double? _lastCurrent;
  double? _lastPower;
  double? _lastRemainingAh;
  double? _lastPackVoltage;

  double _ah = 0;
  double _wh = 0;
  double _startSoc = 0;
  double _endSoc = 0;
  double _peakCurrent = 0;
  double? _maxTemp;
  double _deltaAtStart = 0;
  double _deltaAtTop = 0;
  double _worstDeltaHigh = 0;
  int _weakCellAtTop = 0;
  int _strongCellAtTop = 0;
  /// Time the balancer was seen working, kept as a Duration.
  ///
  /// It used to be an int of whole seconds added up per reading, which is zero
  /// for a 400 ms interval, so the balancer could run for a whole charge and
  /// this would finish on nought. Anything reading it concluded the balancer
  /// had never done anything.
  Duration _balancing = Duration.zero;
  bool _reachedTop = false;
  int _gapSeconds = 0;

  /// Live figures while a charge is under way.
  double get ahIn => _ah;
  double get whIn => _wh;
  double get startSoc => _startSoc;

  /// Feeds a reading. Returns a report when a charge has just finished.
  ChargeReport? addSnapshot(BmsSnapshot s) {
    final charging = s.current > startCurrent;

    if (!_active) {
      if (charging) _begin(s);
      return null;
    }

    _accumulate(s);

    // Ends when current tails off, or when the pack starts being used again.
    final finished = s.current < stopCurrent;
    if (!finished) return null;

    final report = _finish(s);
    _active = false;
    return report;
  }

  void _begin(BmsSnapshot s) {
    _active = true;
    _startedAt = s.timestamp;
    // The reading that opened the charge is the first end of the first
    // interval. It used to be forgotten, so the stretch up to the second
    // reading, and a drop straight after plugging in, counted nothing.
    _lastAt = s.timestamp;
    _lastCurrent = s.current;
    _lastPower = s.power;
    _lastRemainingAh = s.remainingCapacityAh;
    _lastPackVoltage = s.packVoltage;
    _ah = 0;
    _wh = 0;
    _startSoc = s.soc;
    _endSoc = s.soc;
    _peakCurrent = 0;
    _maxTemp = null;
    _deltaAtStart = s.deltaCellVoltage;
    _deltaAtTop = 0;
    _worstDeltaHigh = 0;
    _weakCellAtTop = 0;
    _strongCellAtTop = 0;
    _balancing = Duration.zero;
    _reachedTop = false;
    _gapSeconds = 0;
  }

  void _accumulate(BmsSnapshot s) {
    _endSoc = s.soc;
    _peakCurrent = math.max(_peakCurrent, s.current);

    // Battery probes only. The MOSFET runs hotter than the cells by design,
    // and folding it in made every summary report the switch as the pack.
    final hottest = s.hottestBatteryTemp;
    if (hottest != null) {
      final before = _maxTemp;
      _maxTemp = before == null ? hottest : math.max(before, hottest);
    }

    // Everything above the high-voltage mark is the part worth remembering.
    if (s.maxCellVoltage >= highCellVolts) {
      _reachedTop = true;
      _deltaAtTop = s.deltaCellVoltage;
      if (s.deltaCellVoltage > _worstDeltaHigh) {
        _worstDeltaHigh = s.deltaCellVoltage;
        _weakCellAtTop = s.minCellIndex;
        _strongCellAtTop = s.maxCellIndex;
      }
    }

    final previousAt = _lastAt;
    final previousCurrent = _lastCurrent;
    final previousPower = _lastPower;
    final previousRemaining = _lastRemainingAh;
    final previousVoltage = _lastPackVoltage;
    _lastAt = s.timestamp;
    _lastCurrent = s.current;
    _lastPower = s.power;
    _lastRemainingAh = s.remainingCapacityAh;
    _lastPackVoltage = s.packVoltage;
    if (previousAt == null ||
        previousCurrent == null ||
        previousPower == null) {
      return;
    }

    final dt = usableInterval(
      previousAt,
      s.timestamp,
      maxGap: const Duration(seconds: 30),
    );
    if (dt == null) {
      // A drop. This used to be skipped in silence, so a charge that lost the
      // link for an hour reported an hour's less charge put in, with nothing
      // to say so. The BMS kept counting: its remaining amp-hours before and
      // after cover the gap, and the minutes go on the report.
      final raw = s.timestamp.difference(previousAt);
      if (raw > Duration.zero) _gapSeconds += raw.inSeconds;
      final before = previousRemaining;
      if (before != null) {
        final added = s.remainingCapacityAh - before;
        if (added > 0) {
          _ah += added;
          _wh += added *
              (previousVoltage == null
                  ? s.packVoltage
                  : (previousVoltage + s.packVoltage) / 2);
        }
      }
      return;
    }

    final hours = hoursIn(dt);
    _ah += (previousCurrent + s.current) / 2 * hours;
    _wh += (previousPower + s.power) / 2 * hours;
    // Milliseconds accumulated as a Duration rather than whole seconds added
    // up. The old version added inSeconds, which is zero for a 400 ms
    // interval, so the balancer could run for an entire charge and this would
    // finish on nought seconds. Anything reading it concluded the balancer had
    // never worked.
    if (s.balancerActive) _balancing += dt;
  }

  ChargeReport? _finish(BmsSnapshot s) {
    final started = _startedAt;
    if (started == null) return null;
    // A two-minute top-up is not a charge worth reporting on.
    if (_endSoc - _startSoc < minimumSoc) return null;

    return ChargeReport(
      startedAt: started,
      endedAt: s.timestamp,
      startSoc: _startSoc,
      endSoc: _endSoc,
      ahIn: _ah,
      whIn: _wh,
      peakCurrent: _peakCurrent,
      maxTemperature: _maxTemp,
      deltaAtStart: _deltaAtStart,
      deltaAtTop: _deltaAtTop,
      worstDeltaHigh: _worstDeltaHigh,
      weakCellAtTop: _weakCellAtTop,
      strongCellAtTop: _strongCellAtTop,
      balancerWorkedSeconds: _balancing.inSeconds,
      reachedTop: _reachedTop,
      gapSeconds: _gapSeconds,
    );
  }
}
