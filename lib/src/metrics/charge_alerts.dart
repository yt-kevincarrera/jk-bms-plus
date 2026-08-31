import '../model/bms_snapshot.dart';

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
    this.completeCurrent = 0.3,
    this.completeSoc = 97,
    this.hotWarn = 45,
    this.spreadWarn = 0.060,
    this.highCellVolts = 4.0,
  });

  /// The level to announce. Null disables that one alert without disabling
  /// the rest, because "tell me when it is done" and "tell me at 80" are
  /// separate wants.
  double? targetSoc;

  final double chargingCurrent;
  final double completeCurrent;
  final double completeSoc;
  final double hotWarn;
  final double spreadWarn;
  final double highCellVolts;

  bool _charging = false;
  final Set<ChargeAlert> _fired = {};

  bool get isCharging => _charging;

  /// Which alerts have already been raised during this charge.
  Set<ChargeAlert> get fired => Set.unmodifiable(_fired);

  /// Feeds one reading and returns anything newly worth saying.
  List<ChargeAlert> evaluate(BmsSnapshot s) {
    final chargingNow = s.current > chargingCurrent;

    // A charge starting is what re-arms everything. Without this the app would
    // announce 80% once and never again, which is useless on the second night.
    if (chargingNow && !_charging) {
      _fired.clear();
    }

    // Falling below the trickle threshold ends the charge, but only from a
    // state where it had genuinely been charging: a pack sitting idle must not
    // announce completion every time it is looked at.
    final wasCharging = _charging;
    _charging = chargingNow ||
        (wasCharging && s.current > -chargingCurrent && s.soc >= completeSoc);

    if (!wasCharging && !chargingNow) return const [];

    final out = <ChargeAlert>[];

    final target = targetSoc;
    if (target != null &&
        s.soc >= target &&
        target < completeSoc &&
        _raise(ChargeAlert.targetReached)) {
      out.add(ChargeAlert.targetReached);
    }

    // Full means the charge has tapered as well as the percentage being high.
    // Percentage alone announces completion while there are still amps going
    // in, which is early enough to be wrong.
    if (s.soc >= completeSoc &&
        s.current.abs() <= completeCurrent &&
        _raise(ChargeAlert.chargeComplete)) {
      out.add(ChargeAlert.chargeComplete);
      _charging = false;
    }

    final temps = s.plausibleTemperatures;
    if (temps.isNotEmpty &&
        temps.reduce((a, b) => a > b ? a : b) >= hotWarn &&
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
    _fired.clear();
  }
}
