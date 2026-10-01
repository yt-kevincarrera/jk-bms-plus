import '../model/bms_snapshot.dart';
import 'capacity_endpoints.dart';
import 'sampling.dart';

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
  /// The pack is not full by its cells, so a measurement now would only cover
  /// part of it and the result would understate the capacity.
  notFull,

  /// Neither the chemistry nor the BMS says where full is, so there is no
  /// honest mark to start from. Opening on the percentage instead is exactly
  /// what made the old test hand back the configured capacity.
  noFullMark,

  /// Nothing is connected.
  noReadings,
}

/// The last reading a run saw before the app lost sight of it, so the next
/// reading can be bridged from it.
class CapacityBridgePoint {
  const CapacityBridgePoint({
    required this.at,
    required this.remainingAh,
    required this.packVoltage,
    required this.soc,
  });

  final DateTime at;
  final double remainingAh;
  final double packVoltage;
  final double soc;
}

/// Measures what the pack actually holds, by counting what comes out of it.
///
/// This is the only figure in the app that is a measurement rather than an
/// inference. Everything else (implied capacity, state of health, the range
/// estimate) is derived from numbers the BMS reports about itself. This counts
/// amp-hours leaving the pack between the cells at the top and the cells at
/// the cutoff, and compares the total against what the pack was sold as.
///
/// Both ends are the cells, by [endpoints], and never the BMS's percentage.
/// The percentage is remaining over the configured capacity: a run from 97 %
/// to 3 % of it counted 0.94 of that configuration by construction, and could
/// never have found a pack bigger, or smaller, than its setting.
///
/// It takes a full discharge to do, which is why it is a deliberate act rather
/// than something the app does quietly in the background: repeatedly running a
/// lithium pack to cutoff costs cycles.
class CapacityTestRunner {
  CapacityTestRunner({
    this.endpoints = const CapacityEndpoints(
      fullCellVolts: 4.15,
      cutoffCellVolts: 3.0,
    ),
    this.maxInterval = const Duration(seconds: 10),
    this.maxRiseFraction = 0.02,
  });

  /// Where full and empty are for the pack being measured. Set by the
  /// service from its chemistry and settings as they become known.
  CapacityEndpoints endpoints;

  /// Longer than this between readings and the interval is not integrated
  /// from the current; it is bridged from the BMS's own counter and counted
  /// as a gap.
  final Duration maxInterval;

  /// A rise in remaining amp-hours across a gap larger than this share of
  /// the capacity they imply is a charge the app did not see.
  final double maxRiseFraction;

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
  double? _lastRemainingAh;
  double? _lastPackVoltage;
  double? _lastSoc;

  double _ah = 0;
  double _wh = 0;
  double _startSoc = 0;
  double _endSoc = 0;
  double _startPackVoltage = 0;
  double _endPackVoltage = 0;
  double? _catalogueAh;
  int _gapSeconds = 0;
  CapacityEndReason? _endReason;

  /// Amp-hours drawn out so far.
  double get measuredAh => _ah;
  double get measuredWh => _wh;
  double get startSoc => _startSoc;
  double get endSoc => _endSoc;
  double get startPackVoltage => _startPackVoltage;
  double get endPackVoltage => _endPackVoltage;
  double? get catalogueAh => _catalogueAh;
  DateTime? get startedAt => _startedAt;

  /// Seconds of the run the app did not see: link drops longer than
  /// [maxInterval], and the whole stretch the app was closed. Bridged from
  /// the BMS's counter so the total is not short, and counted so the result
  /// is not believed past what was watched.
  int get gapSeconds => _gapSeconds;

  /// What closed the run, once it has closed.
  CapacityEndReason? get endReason => _endReason;

  /// How far through, as a fraction, using charge as the yardstick. Rough, but
  /// it is the only progress indicator available before the answer is known.
  double get progress {
    if (_state != CapacityTestState.measuring || _startSoc <= 0) return 0;
    final used = _startSoc - _endSoc;
    return (used / _startSoc).clamp(0.0, 1.0);
  }

  /// The result against what the pack was sold as, once there is enough to say.
  double? get fractionOfCatalogue =>
      (_catalogueAh ?? 0) > 0 && _ah > 0 ? _ah / _catalogueAh! : null;

  /// Whether a run could start right now.
  CapacityTestBlock? blockedBy(BmsSnapshot? snapshot) {
    if (snapshot == null) return CapacityTestBlock.noReadings;
    if (snapshot.cellVoltages.isNotEmpty && endpoints.fullCellVolts == null) {
      return CapacityTestBlock.noFullMark;
    }
    if (!_isFull(snapshot)) return CapacityTestBlock.notFull;
    return null;
  }

  bool _isFull(BmsSnapshot s) => endpoints.isFull(
    topCell: s.cellVoltages.isEmpty ? 0 : s.maxCellVoltage,
    current: s.current,
    soc: s.soc,
  );

  /// Begins a run against a pack that is already full.
  void begin({
    required BmsSnapshot snapshot,
    required double? catalogueAh,
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
    _remember(snapshot);
    _state = CapacityTestState.measuring;
  }

  /// Picks a run back up after the app was closed mid-test.
  ///
  /// [lastSeen] is the last reading stored before the app lost sight of the
  /// pack. The first reading after it is bridged from it on the BMS's own
  /// counter, so the amp-hours drawn while the app was closed are not lost,
  /// and the whole stretch is counted as a gap, so the result is not
  /// believed as a watched measurement. Without it the run used to restart
  /// from nothing, and everything drawn in between simply vanished.
  void resume({
    required int rowId,
    required DateTime startedAt,
    required double ah,
    required double wh,
    required double startSoc,
    required double startPackVoltage,
    required double? catalogueAh,
    int gapSeconds = 0,
    bool chargedDuringRun = false,
    CapacityBridgePoint? lastSeen,
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
    _gapSeconds = gapSeconds;
    _chargedDuringRun = chargedDuringRun;
    if (lastSeen != null) {
      _lastAt = lastSeen.at;
      _lastRemainingAh = lastSeen.remainingAh;
      _lastPackVoltage = lastSeen.packVoltage;
      _lastSoc = lastSeen.soc;
      _endSoc = lastSeen.soc;
      _endPackVoltage = lastSeen.packVoltage;
    }
    _state = CapacityTestState.measuring;
  }

  /// Feeds one reading. Returns true when the run has just finished on its own.
  bool addSnapshot(BmsSnapshot s) {
    if (_state != CapacityTestState.measuring) return false;
    // Already closed and waiting to be written: a second reading must not
    // close it again, or count past the cutoff.
    if (_endReason != null) return false;

    _endSoc = s.soc;
    _endPackVoltage = s.packVoltage;

    final previousAt = _lastAt;
    final previousCurrent = _lastCurrent;
    final previousPower = _lastPower;
    final previousRemaining = _lastRemainingAh;
    final previousVoltage = _lastPackVoltage;
    final previousSoc = _lastSoc;
    _remember(s);

    if (previousAt != null) {
      // Integrated from the current only across a short interval with both
      // ends known. This was the same truncation as everywhere else, and
      // here it did the most damage of all: the capacity test is the app's
      // one real measurement of wear, and it was counting only the
      // intervals that happened to straddle a whole second.
      final dt = previousCurrent == null || previousPower == null
          ? null
          : usableInterval(previousAt, s.timestamp, maxGap: maxInterval);
      if (dt != null) {
        final hours = hoursIn(dt);
        // Trapezoid, and only what comes *out*: charging mid-test does not
        // subtract, it invalidates, and that is what [chargedDuringRun] is
        // for.
        final averageCurrent = (previousCurrent! + s.current) / 2;
        final averagePower = (previousPower! + s.power) / 2;
        if (averageCurrent < 0) _ah += -averageCurrent * hours;
        if (averagePower < 0) _wh += -averagePower * hours;
        if (averageCurrent > 1.0) _chargedDuringRun = true;
      } else {
        // A drop, or the app having been closed. The interval used to be
        // thrown away with nothing counting it, so a test that lost the link
        // for twenty minutes came out short and looked as good as a clean
        // one. Now the BMS's own counter covers it, and the time is counted.
        final raw = s.timestamp.difference(previousAt);
        if (raw > Duration.zero) _gapSeconds += raw.inSeconds;
        _bridge(
          s,
          remainingBefore: previousRemaining,
          voltageBefore: previousVoltage,
          socBefore: previousSoc,
        );
      }
    }

    final reason = endpoints.emptyReason(
      minCell: s.cellVoltages.isEmpty ? 0 : s.minCellVoltage,
      warningsMask: s.warnings.raw,
      dischargeMosfetOn: s.dischargeMosfetOn,
    );
    if (reason == null) return false;
    _endReason = reason;
    return true;
  }

  /// Covers an unwatched stretch with the BMS's coulomb counter: the
  /// remaining amp-hours before and after. A rise means current went in.
  void _bridge(
    BmsSnapshot s, {
    required double? remainingBefore,
    required double? voltageBefore,
    required double? socBefore,
  }) {
    if (remainingBefore == null) return;
    final drawn = remainingBefore - s.remainingCapacityAh;
    final soc = socBefore ?? s.soc;
    final implied = soc > 0 ? remainingBefore / (soc / 100) : 0.0;
    final tolerance = implied > 0 ? implied * maxRiseFraction : 0.5;
    if (-drawn > tolerance) {
      _chargedDuringRun = true;
      return;
    }
    if (drawn <= 0) return;
    _ah += drawn;
    final volts = voltageBefore == null
        ? s.packVoltage
        : (voltageBefore + s.packVoltage) / 2;
    _wh += drawn * volts;
  }

  void _remember(BmsSnapshot s) {
    _lastAt = s.timestamp;
    _lastCurrent = s.current;
    _lastPower = s.power;
    _lastRemainingAh = s.remainingCapacityAh;
    _lastPackVoltage = s.packVoltage;
    _lastSoc = s.soc;
  }

  bool _chargedDuringRun = false;

  /// True when the pack was charged part way through, which makes the total
  /// meaningless. Worth saying out loud rather than quietly reporting a number.
  bool get chargedDuringRun => _chargedDuringRun;

  /// Ends the run as finished. [reason] is what closed it: the cutoff that
  /// [addSnapshot] reported, or [CapacityEndReason.stoppedEarly] when the
  /// rider ended it by hand.
  void finish({CapacityEndReason? reason}) {
    _endReason = reason ?? _endReason ?? CapacityEndReason.stoppedEarly;
    _state = CapacityTestState.idle;
  }

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
    _lastRemainingAh = null;
    _lastPackVoltage = null;
    _lastSoc = null;
    _ah = 0;
    _wh = 0;
    _startSoc = 0;
    _endSoc = 0;
    _startPackVoltage = 0;
    _endPackVoltage = 0;
    _catalogueAh = 0;
    _gapSeconds = 0;
    _endReason = null;
    _chargedDuringRun = false;
  }
}
