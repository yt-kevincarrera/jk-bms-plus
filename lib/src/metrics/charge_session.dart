import 'dart:math' as math;

import '../model/bms_snapshot.dart';

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
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final double startSoc;
  final double endSoc;
  final double ahIn;
  final double whIn;
  final double peakCurrent;
  final double maxTemperature;

  /// Spread when charging began.
  final double deltaAtStart;

  /// Spread once the pack was near the top, which is where it matters.
  final double deltaAtTop;

  /// Worst spread seen anywhere above the high-voltage mark.
  final double worstDeltaHigh;

  /// The cells at each end of the pack near the top, 1-based. Zero when the
  /// charge never got high enough to tell.
  final int weakCellAtTop;
  final int strongCellAtTop;

  final int balancerWorkedSeconds;

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

  double _ah = 0;
  double _wh = 0;
  double _startSoc = 0;
  double _endSoc = 0;
  double _peakCurrent = 0;
  double _maxTemp = -100;
  double _deltaAtStart = 0;
  double _deltaAtTop = 0;
  double _worstDeltaHigh = 0;
  int _weakCellAtTop = 0;
  int _strongCellAtTop = 0;
  int _balancerSeconds = 0;
  bool _reachedTop = false;

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
    _lastAt = null;
    _lastCurrent = null;
    _lastPower = null;
    _ah = 0;
    _wh = 0;
    _startSoc = s.soc;
    _endSoc = s.soc;
    _peakCurrent = 0;
    _maxTemp = -100;
    _deltaAtStart = s.deltaCellVoltage;
    _deltaAtTop = 0;
    _worstDeltaHigh = 0;
    _weakCellAtTop = 0;
    _strongCellAtTop = 0;
    _balancerSeconds = 0;
    _reachedTop = false;
  }

  void _accumulate(BmsSnapshot s) {
    _endSoc = s.soc;
    _peakCurrent = math.max(_peakCurrent, s.current);

    final temps = <double>[
      ...s.temperatures,
      if (s.mosfetTemp != null) s.mosfetTemp!,
    ];
    if (temps.isNotEmpty) {
      _maxTemp = math.max(_maxTemp, temps.reduce(math.max));
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
    _lastAt = s.timestamp;
    _lastCurrent = s.current;
    _lastPower = s.power;
    if (previousAt == null ||
        previousCurrent == null ||
        previousPower == null) {
      return;
    }

    final dt = s.timestamp.difference(previousAt);
    if (dt.inSeconds <= 0 || dt.inSeconds > 30) return;

    final hours = dt.inMilliseconds / 3600000.0;
    _ah += (previousCurrent + s.current) / 2 * hours;
    _wh += (previousPower + s.power) / 2 * hours;
    if (s.balancerActive) _balancerSeconds += dt.inSeconds;
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
      maxTemperature: _maxTemp > -100 ? _maxTemp : 0,
      deltaAtStart: _deltaAtStart,
      deltaAtTop: _deltaAtTop,
      worstDeltaHigh: _worstDeltaHigh,
      weakCellAtTop: _weakCellAtTop,
      strongCellAtTop: _strongCellAtTop,
      balancerWorkedSeconds: _balancerSeconds,
      reachedTop: _reachedTop,
    );
  }
}
