import '../model/bms_snapshot.dart';

/// Something worth interrupting a ride for.
enum RideAlert {
  /// The BMS raised a fault of its own.
  bmsFault,

  /// Cells have drifted far apart.
  cellSpread,

  /// A battery probe is too hot.
  temperature,

  /// The BMS's own MOSFET is too hot. Not the battery: a different part, a
  /// different threshold and a different thing to do about it, and calling
  /// it "the pack" had the rider stopping for a switch that runs hot by
  /// design.
  bmsHot,

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
    this.criticalChargeWarn = defaultCriticalChargeWarn,
    this.criticalChargeClear = 12,
    this.cellCutoffMargin = 0.10,
    this.mosfetWarn = BmsSnapshot.mosfetHotCelsius,
    this.mosfetOtpMargin = 10,
    this.mosfetClearDrop = 5,
    this.nearLimitFraction = 0.95,
    this.nearLimitClearFraction = 0.85,
    this.minimumGap = const Duration(minutes: 2),
  });

  /// Where "nearly gone" starts. The low-charge threshold has to sit above
  /// it: low charge only trips above this, so a low threshold at or under it
  /// never fired at all, and the settings slider went down to 5.
  static const double defaultCriticalChargeWarn = 7;

  /// The lowest the low-charge threshold can usefully be.
  static const double minLowChargeWarn = defaultCriticalChargeWarn + 1;

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

  /// Where the MOSFET alert trips when the BMS has not stated its own MOSFET
  /// protection, and how far under that protection it trips when it has.
  /// Clearing needs the MOSFET [mosfetClearDrop] degrees under the trip
  /// point, so a reading hovering there does not chatter.
  final double mosfetWarn;
  final double mosfetOtpMargin;
  final double mosfetClearDrop;

  /// The MOSFET temperature this alert trips at, given the BMS's own MOSFET
  /// protection when it reported one. A protection outside what a board
  /// could plausibly be set to is ignored rather than trusted.
  double mosfetTripFor(double? mosfetOtpCelsius) {
    final otp = mosfetOtpCelsius;
    if (otp != null && otp >= 50 && otp <= 150) return otp - mosfetOtpMargin;
    return mosfetWarn;
  }

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
  /// a number picked here. Where the BMS has not stated one (an ANT never
  /// does) the caller passes the usual cutoff for the chemistry, and the
  /// wording of the alert says it is assumed.
  ///
  /// [riding] and [charging] say what the pack is doing ([RidingGate]).
  /// These alerts used to fire whenever a reading arrived, so "stop and let
  /// it cool" and "find somewhere to stop" came up on the charger and on the
  /// sofa, under a heading that says "riding". Now the cells spreading and
  /// the pack running hot only trip while riding (charging has its own
  /// alerts for both), and running out of charge never trips while charging.
  /// Low charge still trips at rest, which is worth knowing before setting
  /// off; its words then leave the stopping out.
  List<RideAlert> evaluate(
    BmsSnapshot s, {
    required double cutoffVoltagePerCell,
    double? dischargeLimitAmps,
    double? chargeLimitAmps,
    double? mosfetOtpCelsius,
    bool riding = true,
    bool charging = false,
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

    // Battery probes only. The MOSFET used to be folded in here, so a warm
    // switch next to cool cells told the rider the pack was too hot to ride.
    final hottest = s.hottestBatteryTemp;
    final mosfet = s.mosfetTemp;
    final mosfetTrip = mosfetTripFor(mosfetOtpCelsius);

    check(RideAlert.bmsFault, s.warnings.hasFault, !s.warnings.hasFault);
    check(
      RideAlert.cellSpread,
      riding && s.deltaCellVoltage > deltaWarn,
      s.deltaCellVoltage < deltaClear,
    );
    check(
      RideAlert.temperature,
      riding && hottest != null && hottest > tempWarn,
      hottest == null || hottest < tempClear,
    );
    check(
      RideAlert.bmsHot,
      mosfet != null && mosfet >= mosfetTrip,
      mosfet == null || mosfet < mosfetTrip - mosfetClearDrop,
    );
    check(
      RideAlert.criticalCharge,
      !charging && s.soc <= criticalChargeWarn,
      s.soc >= criticalChargeClear,
    );
    check(
      RideAlert.lowCharge,
      !charging && s.soc <= lowChargeWarn && s.soc > criticalChargeWarn,
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
      !charging && s.minCellVoltage <= cutoffVoltagePerCell + cellCutoffMargin,
      s.minCellVoltage > cutoffVoltagePerCell + cellCutoffMargin * 2,
    );

    return firing;
  }

  void reset() {
    _active.clear();
    _lastFired.clear();
  }
}

/// Whether the bike is being ridden, for the alerts that only mean something
/// then.
///
/// A trip recording is the plain case. Without one, sustained discharge: the
/// same bar the automatic trip start uses for "the bike doing work", 3 A for
/// ten seconds, well clear of a wheel spun on a stand (about 1.5 A) and of
/// the lights (0.44 A). It lets go only after three minutes with nothing over
/// 1.5 A, because a traffic light is not the end of a ride.
class RidingGate {
  RidingGate({
    this.loadAmps = 3.0,
    this.holdFor = const Duration(seconds: 10),
    this.idleAmps = 1.5,
    this.releaseAfter = const Duration(minutes: 3),
  });

  final double loadAmps;
  final Duration holdFor;
  final double idleAmps;
  final Duration releaseAfter;

  DateTime? _loadSince;
  DateTime? _lastWork;
  bool _riding = false;

  bool get isRiding => _riding;

  /// Feeds a reading and returns whether the bike counts as ridden now.
  bool update(BmsSnapshot s, {bool tripRecording = false}) {
    final draw = -s.current;
    if (draw >= loadAmps) {
      _loadSince ??= s.timestamp;
    } else {
      _loadSince = null;
    }
    if (draw > idleAmps) _lastWork = s.timestamp;

    final since = _loadSince;
    if (since != null && s.timestamp.difference(since) >= holdFor) {
      _riding = true;
    }
    final work = _lastWork;
    if (_riding &&
        (work == null || s.timestamp.difference(work) >= releaseAfter)) {
      _riding = false;
    }
    return tripRecording || _riding;
  }

  void reset() {
    _loadSince = null;
    _lastWork = null;
    _riding = false;
  }
}
