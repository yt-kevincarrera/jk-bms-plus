import '../model/bms_snapshot.dart';

/// Where a capacity measurement is up to.
enum CapacityTestState {
  /// Nothing running.
  idle,

  /// Waiting for the pack to be full before the measurement can mean anything.
  waitingForFull,

  /// Counting amp-hours out.
  measuring,
}

/// Why a run cannot start yet.
enum CapacityTestBlock {
  /// The pack is not near full, so a measurement now would only cover part of
  /// it and the result would understate the capacity.
  notFull,

  /// Nothing is connected.
  noReadings,
}

/// Measures what the pack actually holds, by counting what comes out of it.
///
/// This is the only figure in the app that is a measurement rather than an
/// inference. Everything else — implied capacity, state of health, the range
/// estimate — is derived from numbers the BMS reports about itself. This counts
/// amp-hours leaving the pack between full and cutoff and compares the total
/// against what the pack was sold as.
///
/// It takes a full discharge to do, which is why it is a deliberate act rather
/// than something the app does quietly in the background: repeatedly running a
/// lithium pack to cutoff costs cycles.
class CapacityTestRunner {
  CapacityTestRunner({
    this.fullThresholdSoc = 97,
    this.fullThresholdCellVolts = 4.15,
    this.stopThresholdSoc = 3,
  });

  /// Charge at or above which the pack counts as full enough to start.
  final double fullThresholdSoc;

  /// Alternative to the charge reading: the highest cell being at the top.
  /// Useful when the coulomb counter has drifted, which is exactly the case
  /// this test exists to settle.
  final double fullThresholdCellVolts;

  /// Charge at or below which the run ends, if the BMS has not cut off first.
  final double stopThresholdSoc;

  CapacityTestState _state = CapacityTestState.idle;
  CapacityTestState get state => _state;

  bool get isRunning => _state != CapacityTestState.idle;

  int? _rowId;

  /// Database row this run is being written to.
  int? get rowId => _rowId;

  DateTime? _startedAt;
  DateTime? _lastAt;
  double? _lastCurrent;
  double? _lastPower;

  double _ah = 0;
  double _wh = 0;
  double _startSoc = 0;
  double _endSoc = 0;
  double _startPackVoltage = 0;
  double _endPackVoltage = 0;
  double _catalogueAh = 0;

  /// Amp-hours drawn out so far.
  double get measuredAh => _ah;
  double get measuredWh => _wh;
  double get startSoc => _startSoc;
  double get endSoc => _endSoc;
  double get startPackVoltage => _startPackVoltage;
  double get endPackVoltage => _endPackVoltage;
  double get catalogueAh => _catalogueAh;
  DateTime? get startedAt => _startedAt;

  /// How far through, as a fraction, using charge as the yardstick. Rough, but
  /// it is the only progress indicator available before the answer is known.
  double get progress {
    if (_state != CapacityTestState.measuring || _startSoc <= 0) return 0;
    final used = _startSoc - _endSoc;
    return (used / _startSoc).clamp(0.0, 1.0);
  }

  /// The result against what the pack was sold as, once there is enough to say.
  double? get fractionOfCatalogue =>
      _catalogueAh > 0 && _ah > 0 ? _ah / _catalogueAh : null;

  /// Whether a run could start right now.
  CapacityTestBlock? blockedBy(BmsSnapshot? snapshot) {
    if (snapshot == null) return CapacityTestBlock.noReadings;
    if (!_isFull(snapshot)) return CapacityTestBlock.notFull;
    return null;
  }

  bool _isFull(BmsSnapshot s) =>
      s.soc >= fullThresholdSoc ||
      s.maxCellVoltage >= fullThresholdCellVolts;

  /// Begins a run against a pack that is already full.
  void begin({
    required BmsSnapshot snapshot,
    required double catalogueAh,
    required int rowId,
  }) {
    _reset();
    _rowId = rowId;
    _catalogueAh = catalogueAh;
    _startedAt = snapshot.timestamp;
    _startSoc = snapshot.soc;
    _endSoc = snapshot.soc;
    _startPackVoltage = snapshot.packVoltage;
    _endPackVoltage = snapshot.packVoltage;
    _state = CapacityTestState.measuring;
  }

  /// Picks a run back up after the app was closed mid-test.
  void resume({
    required int rowId,
    required DateTime startedAt,
    required double ah,
    required double wh,
    required double startSoc,
    required double startPackVoltage,
    required double catalogueAh,
  }) {
    _reset();
    _rowId = rowId;
    _startedAt = startedAt;
    _ah = ah;
    _wh = wh;
    _startSoc = startSoc;
    _endSoc = startSoc;
    _startPackVoltage = startPackVoltage;
    _endPackVoltage = startPackVoltage;
    _catalogueAh = catalogueAh;
    _state = CapacityTestState.measuring;
  }

  /// Feeds one reading. Returns true when the run has just finished on its own.
  bool addSnapshot(BmsSnapshot s) {
    if (_state != CapacityTestState.measuring) return false;

    _endSoc = s.soc;
    _endPackVoltage = s.packVoltage;

    final previousAt = _lastAt;
    final previousCurrent = _lastCurrent;
    final previousPower = _lastPower;
    _lastAt = s.timestamp;
    _lastCurrent = s.current;
    _lastPower = s.power;

    if (previousAt != null &&
        previousCurrent != null &&
        previousPower != null) {
      final dt = s.timestamp.difference(previousAt);
      // A gap means the link dropped. Integrating across it would invent
      // amp-hours that never left the pack, which would inflate the answer.
      if (dt.inSeconds > 0 && dt.inSeconds <= 10) {
        final hours = dt.inMilliseconds / 3600000.0;
        // Trapezoid, and only what comes *out*: charging mid-test does not
        // subtract, it invalidates, and that is what [chargedDuringRun] is for.
        final averageCurrent = (previousCurrent + s.current) / 2;
        final averagePower = (previousPower + s.power) / 2;
        if (averageCurrent < 0) _ah += -averageCurrent * hours;
        if (averagePower < 0) _wh += -averagePower * hours;
        if (averageCurrent > 1.0) _chargedDuringRun = true;
      }
    }

    return _shouldStop(s);
  }

  bool _chargedDuringRun = false;

  /// True when the pack was charged part way through, which makes the total
  /// meaningless. Worth saying out loud rather than quietly reporting a number.
  bool get chargedDuringRun => _chargedDuringRun;

  /// The run ends when the BMS says it is done, not when a percentage says so.
  /// The discharge MOSFET opening is the ground truth: that is the pack
  /// actually refusing to give any more.
  bool _shouldStop(BmsSnapshot s) =>
      !s.dischargeMosfetOn ||
      s.soc <= stopThresholdSoc ||
      s.warnings.active.any((w) => w.name.contains('ndervoltage'));

  void finish() => _state = CapacityTestState.idle;

  void abort() {
    _reset();
    _state = CapacityTestState.idle;
  }

  void _reset() {
    _rowId = null;
    _startedAt = null;
    _lastAt = null;
    _lastCurrent = null;
    _lastPower = null;
    _ah = 0;
    _wh = 0;
    _startSoc = 0;
    _endSoc = 0;
    _startPackVoltage = 0;
    _endPackVoltage = 0;
    _catalogueAh = 0;
    _chargedDuringRun = false;
  }
}
