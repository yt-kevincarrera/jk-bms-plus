import '../model/bms_snapshot.dart';

/// Something worth interrupting a ride for.
enum RideAlert {
  /// The BMS raised a fault of its own.
  bmsFault,

  /// Cells have drifted far apart.
  cellSpread,

  /// Something is too hot.
  temperature,

  /// Charge is getting low.
  lowCharge,

  /// Charge is nearly gone.
  criticalCharge,

  /// A cell has fallen close to cutoff, which can happen well before the
  /// charge reading looks alarming.
  cellNearCutoff,

  /// The current is close to what the BMS is configured to allow, which is
  /// the moment before it cuts the power without warning.
  nearCurrentLimit,
}

extension RideAlertSeverity on RideAlert {
  /// Critical alerts are worth a stronger buzz and a red band.
  bool get isCritical =>
      this == RideAlert.criticalCharge ||
      this == RideAlert.cellNearCutoff ||
      this == RideAlert.bmsFault;
}

/// Decides when to interrupt.
///
/// Riding is exactly when nobody is looking at the screen, so the app has to
/// speak up. It also has to shut up: an alert that fires every second, or that
/// fires again the moment a value wobbles back over a threshold, is an alert
/// people learn to ignore, and then it is worse than nothing.
///
/// Two mechanisms keep it quiet. Each alert only fires once until it clears,
/// and clearing needs the value to come back past a lower bar than the one that
/// set it off — so a delta hovering at the threshold does not chatter.
class RideAlerts {
  RideAlerts({
    this.deltaWarn = 0.100,
    this.deltaClear = 0.080,
    this.tempWarn = 55,
    this.tempClear = 50,
    this.lowChargeWarn = 15,
    this.lowChargeClear = 20,
    this.criticalChargeWarn = 7,
    this.criticalChargeClear = 12,
    this.cellCutoffMargin = 0.10,
    this.nearLimitFraction = 0.95,
    this.nearLimitClearFraction = 0.85,
    this.minimumGap = const Duration(minutes: 2),
  });

  // Not final: the rider can move these from settings, and rebuilding the
  // detector to change one would throw away which alerts are standing and
  // start the whole quieting mechanism again.
  double deltaWarn;
  double deltaClear;
  double tempWarn;
  double tempClear;
  double lowChargeWarn;
  double lowChargeClear;
  final double criticalChargeWarn;
  final double criticalChargeClear;

  /// How close the lowest cell may get to the configured cutoff before this
  /// says something. Volts.
  final double cellCutoffMargin;

  /// How close the current may get to what the BMS is configured to allow
  /// before this says something, as a fraction of that limit.
  ///
  /// The interesting moment is just before the BMS acts: it cuts the power
  /// without warning and without explanation, and on a bike that is a very
  /// different experience from being told it is about to happen.
  final double nearLimitFraction;
  final double nearLimitClearFraction;

  /// Even a genuinely new alert will not fire twice inside this window.
  final Duration minimumGap;

  final Set<RideAlert> _active = {};
  final Map<RideAlert, DateTime> _lastFired = {};

  /// Alerts currently standing.
  Set<RideAlert> get active => Set.unmodifiable(_active);

  /// Feeds a reading and returns whatever should fire right now.
  ///
  /// [cutoffVoltagePerCell] comes from the BMS's own undervoltage setting, so
  /// the cell warning tracks how this pack is actually configured rather than
  /// a number picked here.
  List<RideAlert> evaluate(
    BmsSnapshot s, {
    required double cutoffVoltagePerCell,
    double? dischargeLimitAmps,
    double? chargeLimitAmps,
  }) {
    final firing = <RideAlert>[];

    void check(RideAlert alert, bool trips, bool clears) {
      if (_active.contains(alert)) {
        if (clears) _active.remove(alert);
        return;
      }
      if (!trips) return;

      final last = _lastFired[alert];
      if (last != null && s.timestamp.difference(last) < minimumGap) return;

      _active.add(alert);
      _lastFired[alert] = s.timestamp;
      firing.add(alert);
    }

    final temps = <double>[
      ...s.plausibleTemperatures,
      if (s.mosfetTemp != null) s.mosfetTemp!,
    ];
    final hottest = temps.isEmpty ? 0.0 : temps.reduce((a, b) => a > b ? a : b);

    check(RideAlert.bmsFault, s.warnings.hasFault, !s.warnings.hasFault);
    check(
      RideAlert.cellSpread,
      s.deltaCellVoltage > deltaWarn,
      s.deltaCellVoltage < deltaClear,
    );
    check(RideAlert.temperature, hottest > tempWarn, hottest < tempClear);
    check(
      RideAlert.criticalCharge,
      s.soc <= criticalChargeWarn,
      s.soc >= criticalChargeClear,
    );
    check(
      RideAlert.lowCharge,
      s.soc <= lowChargeWarn && s.soc > criticalChargeWarn,
      s.soc >= lowChargeClear,
    );
    // Whichever limit applies to what the pack is doing right now. A pack
    // being charged at 20 A is nowhere near a 100 A discharge limit, and
    // comparing it against one would never say anything.
    final limit = s.current < 0 ? dischargeLimitAmps : chargeLimitAmps;
    final magnitude = s.current.abs();
    check(
      RideAlert.nearCurrentLimit,
      limit != null && limit > 0 && magnitude >= limit * nearLimitFraction,
      limit == null || limit <= 0 || magnitude < limit * nearLimitClearFraction,
    );

    check(
      RideAlert.cellNearCutoff,
      s.minCellVoltage <= cutoffVoltagePerCell + cellCutoffMargin,
      s.minCellVoltage > cutoffVoltagePerCell + cellCutoffMargin * 2,
    );

    return firing;
  }

  void reset() {
    _active.clear();
    _lastFired.clear();
  }
}
