import '../model/bms_snapshot.dart';
import '../pack/chemistry.dart';
import 'capacity_endpoints.dart';

/// Something worth saying while a pack is charging.
enum ChargeAlert {
  /// Charge has reached the level the rider asked to be told about.
  targetReached,

  /// The pack is full and the current has fallen away.
  chargeComplete,

  /// It is getting hot while charging, which is a different thing from getting
  /// hot under load and usually means the charger, not the ride.
  hotWhileCharging,

  /// Cells are drifting apart in the region where that actually means
  /// something. Above 4.0 V per cell the curve is steep, so a small capacity
  /// mismatch shows as a large voltage gap.
  spreadAtTop,
}

extension ChargeAlertSeverity on ChargeAlert {
  bool get isProblem =>
      this == ChargeAlert.hotWhileCharging || this == ChargeAlert.spreadAtTop;
}

/// Watches a charge and speaks up at the moments worth knowing about.
///
/// Charging happens overnight, which is exactly why nobody sees any of it. The
/// two things people actually want are "it has reached the level I wanted" and
/// "it is done", and the two things they should want are "it is getting hot"
/// and "the cells are spreading at the top".
///
/// Stopping short of full is not a superstition: the top of the range is where
/// a lithium cell spends most of its calendar ageing, so a rider who does not
/// need the whole pack tomorrow is better off at 80. The app does not enforce
/// that, it just makes it possible to notice.
///
/// Quiet by the same rules as [RideAlerts]: each alert fires once per charge,
/// and a new charge is what re-arms them.
class ChargeAlerts {
  ChargeAlerts({
    this.targetSoc = 80,
    this.chargingCurrent = 1.0,
    this.trickleCurrent = 0.05,
    this.completeSoc = 97,
    this.completeDwell = const Duration(seconds: 60),
    this.hotWarn = ChemistryLimits.hotChargeLimitCelsius,
    this.spreadWarn = maxSpreadWarn,
    this.highCellVolts = 4.0,
  });

  /// The top-of-charge spread that is always worth hearing about. The rider's
  /// spread threshold can bring the alert earlier, never later: see
  /// [BmsService.applySettings].
  static const double maxSpreadWarn = 0.060;

  /// The level to announce. Null disables that one alert without disabling
  /// the rest, because "tell me when it is done" and "tell me at 80" are
  /// separate wants.
  ///
  /// A target at or above [completeSoc] is announced by the completion alert
  /// instead: the BMS counter reaches 97 % well before the cells are full,
  /// and a "reached 99 %" while an hour of charge is still going in is the
  /// same wrong promise as a "finished" would be.
  double? targetSoc;

  /// Amps in above which a charge is under way.
  final double chargingCurrent;

  /// Amps in above which something is still going in. The tail of a charge
  /// runs well under [chargingCurrent], and it is still a charge.
  final double trickleCurrent;

  /// The charge from which a target is left to the completion alert, and the
  /// full mark for a pack whose cells say nothing about where full is.
  final double completeSoc;

  /// How long the tapered tail has to hold, reading after reading, before
  /// the charge counts as finished. A single reading used to be enough, so
  /// pulling the plug at 97 % read as the charge finishing.
  final Duration completeDwell;

  /// Where charging hot starts. Not final: the rider's temperature threshold
  /// can lower it, never raise it above [ChemistryLimits.hotChargeLimitCelsius].
  double hotWarn;

  /// Top-of-charge spread that trips the alert. Not final, for the same
  /// reason, capped at [maxSpreadWarn].
  double spreadWarn;

  final double highCellVolts;

  bool _charging = false;
  DateTime? _taperSince;
  final Set<ChargeAlert> _fired = {};

  bool get isCharging => _charging;

  /// Which alerts have already been raised during this charge.
  Set<ChargeAlert> get fired => Set.unmodifiable(_fired);

  /// Feeds one reading and returns anything newly worth saying.
  ///
  /// [fullCellVolts] is where the top cell sits when this pack is full: the
  /// chemistry's mark or the BMS's request voltage (see
  /// [ChemistryLimits.fullCellVoltsFor]). Null when neither is known, and
  /// then the percentage stands in for it. [capacityAh] sets what a tapered
  /// charge is: C/20 ([CapacityEndpoints.taperAmpsFor]).
  List<ChargeAlert> evaluate(
    BmsSnapshot s, {
    double? fullCellVolts,
    double? capacityAh,
  }) {
    final chargingNow = s.current > chargingCurrent;

    // A charge starting is what re-arms everything. Without this the app would
    // announce 80% once and never again, which is useless on the second night.
    if (chargingNow && !_charging) {
      _fired.clear();
      _taperSince = null;
    }

    // Still a charge while anything at all is going in: the last stretch of
    // a charge runs at a fraction of an amp. Nothing going in ends it, and
    // that is the plug coming out as often as it is the charger finishing,
    // which is why ending is not completion.
    final wasCharging = _charging;
    _charging = chargingNow || (wasCharging && s.current > trickleCurrent);

    if (!wasCharging && !chargingNow) return const [];

    final out = <ChargeAlert>[];

    final target = targetSoc;
    if (target != null &&
        target < completeSoc &&
        s.soc >= target &&
        _raise(ChargeAlert.targetReached)) {
      out.add(ChargeAlert.targetReached);
    }

    // Full is the top cell at the full mark with the current tapered and
    // still flowing, for a minute of consecutive readings. It used to be 97 %
    // and 0.3 A on one reading: the percentage is the counter, not the cells,
    // and a plug pulled at 97 % reads 0 A just the same as a finished charge.
    // Pulled, the current drops straight from the bulk rate to nothing and
    // never spends a minute in the taper.
    final taper = CapacityEndpoints.taperAmpsFor(capacityAh);
    final mark = fullCellVolts;
    final atTop = mark == null || s.cellVoltages.isEmpty
        ? s.soc >= completeSoc
        : s.maxCellVoltage >= mark;
    final tapering = s.current > trickleCurrent && s.current <= taper;
    if (_charging && atTop && tapering) {
      _taperSince ??= s.timestamp;
    } else {
      _taperSince = null;
    }
    final since = _taperSince;
    if (since != null &&
        s.timestamp.difference(since) >= completeDwell &&
        _raise(ChargeAlert.chargeComplete)) {
      out.add(ChargeAlert.chargeComplete);
      // Any target has been passed by now, or is this alert (one at or above
      // [completeSoc]). A counter that lags the cells must not announce its
      // target after the pack has been called full.
      _fired.add(ChargeAlert.targetReached);
      _charging = false;
      _taperSince = null;
    }

    // The battery, not the MOSFET: this is about the cells charging hot, and
    // a warm switch next to cool cells is no reason to unplug.
    final hottest = s.hottestBatteryTemp;
    if (hottest != null &&
        hottest >= hotWarn &&
        _raise(ChargeAlert.hotWhileCharging)) {
      out.add(ChargeAlert.hotWhileCharging);
    }

    // Only in the steep region, where a spread means capacity mismatch rather
    // than the normal wander of cells at rest.
    if (s.maxCellVoltage >= highCellVolts &&
        s.deltaCellVoltage >= spreadWarn &&
        _raise(ChargeAlert.spreadAtTop)) {
      out.add(ChargeAlert.spreadAtTop);
    }

    return out;
  }

  bool _raise(ChargeAlert a) => _fired.add(a);

  /// Forgets this charge, for a disconnection or a switch of pack.
  void reset() {
    _charging = false;
    _taperSince = null;
    _fired.clear();
  }
}
