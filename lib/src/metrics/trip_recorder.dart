import 'dart:math' as math;

import '../gps/location_source.dart';
import '../model/bms_snapshot.dart';
import 'altitude_tracker.dart';
import 'sampling.dart';
import 'range_estimator.dart';

enum TripState { idle, recording, paused }

/// How a ride's energy figure was arrived at.
enum EnergySource {
  /// The pack's own coulomb counter. Preferred: it is accumulated inside the
  /// BMS at a rate no phone sees, and it keeps counting through a dropped
  /// link.
  coulombCount,

  /// Power integrated between the readings the phone actually received. All
  /// there is when the counter has not moved, and blind to every second the
  /// link was down.
  integrated,
}

/// One point of the recorded track, with what the pack was doing there.
///
/// Position and pack state are captured together so that later a hill and a
/// voltage sag can be lined up against each other.
class TrackPoint {
  const TrackPoint({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.altitudeM,
    required this.packVoltage,
    required this.current,
    required this.soc,
  });

  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double speedKmh;

  /// Smoothed, not raw. See [AltitudeTracker].
  final double altitudeM;
  final double packVoltage;
  final double current;
  final double soc;
}

/// Everything a trip turned out to be.
///
/// The pack figures are here alongside the riding ones on purpose: distance and
/// speed on their own are what any speedometer app gives you. The point of
/// having both is being able to say what the battery did *over that ride*.
class TripSummary {
  const TripSummary({
    required this.startedAt,
    required this.movingDuration,
    required this.totalDuration,
    required this.distanceKm,
    required this.maxSpeedKmh,
    required this.energyOutWh,
    required this.energyInWh,
    required this.startSoc,
    required this.endSoc,
    required this.minPackVoltage,
    required this.maxPackVoltage,
    required this.maxDischargeCurrent,
    required this.maxTemperature,
    required this.maxDeltaVolts,
    required this.climbM,
    required this.descentM,
    this.ahOut,
    this.energySource = EnergySource.integrated,
  });

  final DateTime startedAt;

  /// Time actually moving. Waiting at a light is not riding.
  final Duration movingDuration;

  /// Wall-clock time from start to stop, pauses excluded.
  final Duration totalDuration;

  final double distanceKm;
  final double maxSpeedKmh;

  /// Watt-hours taken out of the pack.
  final double energyOutWh;

  /// Watt-hours put back in, by regeneration or by charging mid-trip.
  final double energyInWh;

  final double startSoc;
  final double endSoc;
  final double minPackVoltage;
  final double maxPackVoltage;
  final double maxDischargeCurrent;
  final double maxTemperature;
  final double maxDeltaVolts;
  final double climbM;
  final double descentM;

  /// Amp-hours the pack's own counter says left over the ride, when it said.
  final double? ahOut;

  /// Where [energyOutWh] came from. Worth recording: the two methods disagreed
  /// by a factor of twenty-five on a real ride, and knowing which one answered
  /// is the difference between a measurement and a guess.
  final EnergySource energySource;

  /// Net consumption per kilometre. Null on a trip too short to mean anything.
  double? get whPerKm {
    if (distanceKm < 0.2) return null;
    final net = energyOutWh - energyInWh;
    return net <= 0 ? null : net / distanceKm;
  }

  double get averageSpeedKmh {
    final hours = movingDuration.inMilliseconds / 3600000.0;
    return hours <= 0 ? 0 : distanceKm / hours;
  }

  /// Percentage points of charge used.
  double get socUsed => startSoc - endSoc;

  /// How much of the pack one kilometre costs, in percentage points. The figure
  /// people actually reason with when they are sizing a commute.
  double? get socPerKm =>
      distanceKm < 0.2 || socUsed <= 0 ? null : socUsed / distanceKm;

  /// Voltage the pack dropped under load over the trip.
  double get sagVolts => maxPackVoltage - minPackVoltage;
}

/// Records a ride: distance and speed from GPS, everything else from the BMS.
///
/// Pause and resume are first-class, because a trip that includes twenty
/// minutes parked outside a shop is not a trip you can learn consumption from.
class TripRecorder {
  TripRecorder();

  TripState _state = TripState.idle;
  TripState get state => _state;

  bool get isRecording => _state == TripState.recording;
  bool get isPaused => _state == TripState.paused;

  /// Whether a trip exists at all, paused or running.
  ///
  /// The distinction matters more than it looks: anything the ride *owns* (the
  /// location stream, the foreground service) has to be held for [isActive],
  /// while anything the ride *learns from* must only run for [isRecording].
  /// Confusing the two is what let a pause dismantle a ride in progress.
  bool get isActive => _state != TripState.idle;

  DateTime? _startedAt;
  DateTime? _lastFixAt;
  DateTime? _lastSnapshotAt;
  double? _lastPower;
  GeoFix? _lastFix;

  double _distanceKm = 0;
  double _maxSpeedKmh = 0;
  double _speedKmh = 0;
  Duration _movingDuration = Duration.zero;
  /// Time spent paused, so it can be taken back out of the elapsed clock.
  Duration _pausedTotal = Duration.zero;
  DateTime? _pausedAt;

  /// Frozen at stop, so the summary does not keep ticking.
  Duration? _finalTotal;

  /// Energy from integrating power between readings. A cross-check now rather
  /// than the answer: it can only account for the moments the phone was
  /// listening.
  double _integratedOutWh = 0;
  double _integratedInWh = 0;

  /// The coulomb counter at the start and end of the ride.
  double? _startRemainingAh;
  double _endRemainingAh = 0;

  /// Mean pack voltage over the ride, for turning amp-hours into watt-hours.
  double _voltageSum = 0;
  int _voltageSamples = 0;

  /// Climb and descent are not simple sums of the steps between fixes. See
  /// [AltitudeTracker] for why, and for what the numbers actually mean.
  final AltitudeTracker _altitude = AltitudeTracker();

  double? _startSoc;
  double _endSoc = 0;
  double _minPackVoltage = double.infinity;
  double _maxPackVoltage = 0;
  double _maxDischargeCurrent = 0;
  double _maxTemperature = -100;
  double _maxDeltaVolts = 0;

  BmsSnapshot? _lastSnapshot;
  final List<TrackPoint> _points = [];

  /// The recorded track, oldest first.
  List<TrackPoint> get points => List.unmodifiable(_points);

  /// Live figures, for the screen.
  double get distanceKm => _distanceKm;
  double get speedKmh => _speedKmh;

  /// The speed, but only while it is still worth believing.
  ///
  /// [speedKmh] is the last figure a fix carried, and it keeps that figure
  /// forever once the fixes stop. Fine for a dial the rider can see is frozen;
  /// dangerous for a decision. Null here means nobody knows, which is what the
  /// auto-stop needs to hear rather than a confident zero.
  double? get freshSpeedKmh {
    if (_state != TripState.recording) return null;
    final last = _lastFixAt;
    if (last == null) return null;
    final age = DateTime.now().toUtc().difference(last);
    return age > const Duration(seconds: 20) ? null : _speedKmh;
  }
  double get maxSpeedKmh => _maxSpeedKmh;
  Duration get movingDuration => _movingDuration;
  /// Wall-clock time since the trip started, minus whatever was spent paused.
  ///
  /// Deliberately different from [movingDuration]: the gap between the two is
  /// how long you spent stopped at lights and waiting, which is worth seeing.
  /// It keeps running while the bike is still, and stops while paused.
  Duration get totalDuration {
    final frozen = _finalTotal;
    if (frozen != null) return frozen;

    final started = _startedAt;
    if (started == null) return Duration.zero;

    final pausedSoFar = _pausedTotal +
        (_pausedAt == null
            ? Duration.zero
            : DateTime.now().toUtc().difference(_pausedAt!));
    final elapsed = DateTime.now().toUtc().difference(started) - pausedSoFar;
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  /// How long the bike spent stopped without the trip being paused.
  Duration get stoppedDuration {
    final idle = totalDuration - _movingDuration;
    return idle.isNegative ? Duration.zero : idle;
  }
  /// Amp-hours the pack's own counter says have left, or null when it has not
  /// moved enough to mean anything.
  ///
  /// Null rather than zero below a hundredth of an amp-hour: the counter is
  /// quantised, and a difference smaller than its own step is not a
  /// measurement of nothing, it is nothing measured.
  double? get ahOut {
    final start = _startRemainingAh;
    if (start == null) return null;
    final used = start - _endRemainingAh;
    return used < 0.01 ? null : used;
  }

  double get meanPackVoltage =>
      _voltageSamples == 0 ? 0 : _voltageSum / _voltageSamples;

  /// Energy out of the pack: the coulomb count where there is one, otherwise
  /// what could be integrated.
  double get energyOutWh {
    final ah = ahOut;
    final volts = meanPackVoltage;
    if (ah != null && volts > 0) return ah * volts;
    return _integratedOutWh;
  }

  /// Energy back in. Only ever integrated: the coulomb difference is a net
  /// figure and cannot separate the two directions.
  double get energyInWh => _integratedInWh;

  /// Which of the two produced [energyOutWh], so a stored ride can say.
  EnergySource get energySource =>
      ahOut != null && meanPackVoltage > 0
          ? EnergySource.coulombCount
          : EnergySource.integrated;

  double? get startSoc => _startSoc;

  /// Consumption so far. Null until far enough to be meaningful.
  double? get whPerKm {
    if (_distanceKm < 0.2) return null;
    final net = energyOutWh - energyInWh;
    return net <= 0 ? null : net / _distanceKm;
  }

  double get averageSpeedKmh {
    final hours = _movingDuration.inMilliseconds / 3600000.0;
    return hours <= 0 ? 0 : _distanceKm / hours;
  }

  void start() {
    _reset();
    _state = TripState.recording;
    _startedAt = DateTime.now().toUtc();
  }

  void pause() {
    if (_state != TripState.recording) return;
    _state = TripState.paused;
    _pausedAt = DateTime.now().toUtc();
    // Drop the timing anchors so the pause does not get integrated as riding.
    _lastFixAt = null;
    _lastSnapshotAt = null;
    _lastPower = null;
    _lastFix = null;
    _speedKmh = 0;
  }

  void resume() {
    if (_state != TripState.paused) return;
    final since = _pausedAt;
    if (since != null) {
      _pausedTotal += DateTime.now().toUtc().difference(since);
      _pausedAt = null;
    }
    _state = TripState.recording;
  }

  /// Ends the trip and returns what it was.
  TripSummary? stop() {
    if (_state == TripState.idle) return null;
    _finalTotal = totalDuration;
    final summary = summarise();
    _state = TripState.idle;
    return summary;
  }

  TripSummary? summarise() {
    final started = _startedAt;
    if (started == null) return null;
    return TripSummary(
      ahOut: ahOut,
      energySource: energySource,
      startedAt: started,
      movingDuration: _movingDuration,
      totalDuration: totalDuration,
      distanceKm: _distanceKm,
      maxSpeedKmh: _maxSpeedKmh,
      energyOutWh: energyOutWh,
      energyInWh: energyInWh,
      startSoc: _startSoc ?? 0,
      endSoc: _endSoc,
      minPackVoltage: _minPackVoltage.isFinite ? _minPackVoltage : 0,
      maxPackVoltage: _maxPackVoltage,
      maxDischargeCurrent: _maxDischargeCurrent,
      maxTemperature: _maxTemperature > -100 ? _maxTemperature : 0,
      maxDeltaVolts: _maxDeltaVolts,
      climbM: _altitude.climbM,
      descentM: _altitude.descentM,
    );
  }

  /// Feeds one position. Distance comes from great-circle steps between fixes
  /// rather than from integrating reported speed, which drifts badly.
  void addFix(GeoFix fix) {
    if (_state != TripState.recording) return;

    _speedKmh = fix.speedKmh;
    if (fix.speedKmh > _maxSpeedKmh) _maxSpeedKmh = fix.speedKmh;

    // Altitude is tracked on every fix, moving or not: a chairlift, a ferry or
    // a slow crawl uphill is still elevation gained.
    final smoothedAltitude = _altitude.add(fix.altitudeM);

    final pack = _lastSnapshot;
    _points.add(
      TrackPoint(
        timestamp: fix.timestamp,
        latitude: fix.latitude,
        longitude: fix.longitude,
        speedKmh: fix.speedKmh,
        altitudeM: smoothedAltitude,
        packVoltage: pack?.packVoltage ?? 0,
        current: pack?.current ?? 0,
        soc: pack?.soc ?? 0,
      ),
    );

    final previous = _lastFix;
    final previousAt = _lastFixAt;
    _lastFix = fix;
    _lastFixAt = fix.timestamp;

    if (previous == null || previousAt == null) return;

    // A long gap means the app was backgrounded or the signal died. Do not draw
    // a straight line across it and call it distance.
    //
    // This one was never wrong in practice, because the location source asks
    // for a fix every five metres and they arrive seconds apart. It is written
    // in milliseconds anyway: it was wrong for the same reason as the others,
    // and lowering that filter would have silently started dropping distance.
    final dt = usableInterval(
      previousAt,
      fix.timestamp,
      maxGap: const Duration(seconds: 30),
    );
    if (dt == null) return;

    final metres = _haversineMetres(
      previous.latitude,
      previous.longitude,
      fix.latitude,
      fix.longitude,
    );


    // Below walking pace this is GPS jitter, not movement.
    if (metres < 1.5 || fix.speedKmh < 1.5) return;

    _distanceKm += metres / 1000.0;
    _movingDuration += dt;
  }

  /// Feeds one pack reading.
  void addSnapshot(BmsSnapshot s) {
    if (_state != TripState.recording) return;

    _lastSnapshot = s;
    _startSoc ??= s.soc;
    _endSoc = s.soc;

    // The pack's own count of what has left it, which is the figure to prefer.
    // It is accumulated by the BMS at a rate no phone sees, and it keeps
    // counting through a dropped link: the ride that exposed all of this had
    // 998 of its 1286 seconds with no readings at all, and the coulomb counter
    // did not care.
    if (s.remainingCapacityAh > 0) {
      _startRemainingAh ??= s.remainingCapacityAh;
      _endRemainingAh = s.remainingCapacityAh;
    }
    if (s.packVoltage > 0) {
      _voltageSum += s.packVoltage;
      _voltageSamples++;
    }

    if (s.packVoltage > 0) {
      _minPackVoltage = math.min(_minPackVoltage, s.packVoltage);
      _maxPackVoltage = math.max(_maxPackVoltage, s.packVoltage);
    }
    if (s.current < 0) {
      _maxDischargeCurrent = math.max(_maxDischargeCurrent, -s.current);
    }
    final temps = <double>[
      ...s.plausibleTemperatures,
      if (s.mosfetTemp != null) s.mosfetTemp!,
    ];
    if (temps.isNotEmpty) {
      _maxTemperature = math.max(_maxTemperature, temps.reduce(math.max));
    }
    _maxDeltaVolts = math.max(_maxDeltaVolts, s.deltaCellVoltage);

    final previousAt = _lastSnapshotAt;
    final previousPower = _lastPower;
    _lastSnapshotAt = s.timestamp;
    _lastPower = s.power;
    if (previousAt == null || previousPower == null) return;

    final dt = usableInterval(previousAt, s.timestamp);
    if (dt == null) return;

    // Trapezoid rather than sampling one endpoint: against a throttle that
    // swings hard, taking only the later reading biases the total.
    final wh = (previousPower + s.power) / 2 * hoursIn(dt);
    if (wh < 0) {
      _integratedOutWh += -wh;
    } else {
      _integratedInWh += wh;
    }
  }

  void _reset() {
    _startedAt = null;
    _lastFixAt = null;
    _lastSnapshotAt = null;
    _lastPower = null;
    _lastFix = null;
    _distanceKm = 0;
    _maxSpeedKmh = 0;
    _speedKmh = 0;
    _movingDuration = Duration.zero;
    _pausedTotal = Duration.zero;
    _pausedAt = null;
    _finalTotal = null;
    _integratedOutWh = 0;
    _integratedInWh = 0;
    _startRemainingAh = null;
    _endRemainingAh = 0;
    _voltageSum = 0;
    _voltageSamples = 0;
    _altitude.reset();
    _points.clear();
    _lastSnapshot = null;
    _startSoc = null;
    _endSoc = 0;
    _minPackVoltage = double.infinity;
    _maxPackVoltage = 0;
    _maxDischargeCurrent = 0;
    _maxTemperature = -100;
    _maxDeltaVolts = 0;
  }

  /// Great-circle distance in metres.
  static double _haversineMetres(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusM = 6371000.0;
    final dLat = _radians(lat2 - lat1);
    final dLon = _radians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(lat1)) *
            math.cos(_radians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadiusM * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _radians(double degrees) => degrees * math.pi / 180.0;
}

/// What the app concluded when a ride ended, kept so it can be read again.
///
/// These are stored with the ride rather than worked out on demand, because
/// they cannot be worked out on demand. "The estimate moved from 41 to 39
/// Wh/km" is a statement about a moment; by the time anybody looks again the
/// estimator has learned from every ride since, so asking it now answers a
/// different question. The conclusions used to be shown once, in a sheet at
/// the end of a ride, and be gone the instant it was dismissed.
class TripConclusions {
  const TripConclusions({
    required this.whPerKmBefore,
    required this.whPerKmAfter,
    required this.learnedKm,
    required this.rangeKmAtEnd,
    required this.confidence,
  });

  /// The learned figure before this ride was folded in.
  ///
  /// Null when there was nothing learned yet, which is different from zero.
  /// The estimator always has a figure to quote, including its own starting
  /// default, so its value alone cannot tell the two apart.
  final double? whPerKmBefore;

  /// And after, which is what the next range was quoted from.
  final double whPerKmAfter;

  final double learnedKm;

  /// Range at the charge the ride ended on.
  final double rangeKmAtEnd;

  final RangeConfidence confidence;

  /// False when this was the first ride with usable data.
  bool get hadLearnedBefore => whPerKmBefore != null;

  /// True when the ride moved the estimate by more than rounding.
  bool get moved => (whPerKmAfter - (whPerKmBefore ?? whPerKmAfter)).abs() > 0.5;

  /// How much thirstier a ride costing [rideWhPerKm] was than the learned
  /// average, as a percentage. Null when there is nothing to compare against,
  /// or when the difference is not worth remarking on.
  double? thirstPercentFor(double? rideWhPerKm) {
    final before = whPerKmBefore;
    if (rideWhPerKm == null || before == null || before <= 0) return null;
    final delta = (rideWhPerKm - before) / before * 100;
    return delta > 15 ? delta : null;
  }

  /// Rebuilds from stored columns, or null when the ride predates them.
  ///
  /// Null rather than defaults: a ride from before this was kept has no
  /// conclusions, and inventing "0 Wh/km, low confidence" for it would put a
  /// made-up measurement in front of the rider.
  static TripConclusions? restore({
    double? whPerKmBefore,
    double? whPerKmAfter,
    double? learnedKm,
    double? rangeKmAtEnd,
    String? confidence,
  }) {
    if (whPerKmAfter == null || confidence == null) return null;
    return TripConclusions(
      whPerKmBefore: whPerKmBefore,
      whPerKmAfter: whPerKmAfter,
      learnedKm: learnedKm ?? 0,
      rangeKmAtEnd: rangeKmAtEnd ?? 0,
      confidence: RangeConfidence.values.firstWhere(
        (c) => c.name == confidence,
        // An unrecognised name comes from a newer build's backup. Losing the
        // label beats losing the row.
        orElse: () => RangeConfidence.values.first,
      ),
    );
  }
}

/// What a finished ride turned out to be, and what it taught.
///
/// The summary alone says what happened. This pairs it with what changed
/// because of it, which is the part that makes recording a ride feel worth
/// doing.
class TripOutcome {
  const TripOutcome({required this.summary, required this.conclusions});

  final TripSummary summary;
  final TripConclusions conclusions;

  double? get whPerKmBefore => conclusions.whPerKmBefore;
  double get whPerKmAfter => conclusions.whPerKmAfter;
  bool get hadLearnedBefore => conclusions.hadLearnedBefore;
  double get learnedKm => conclusions.learnedKm;
  RangeConfidence get confidence => conclusions.confidence;
  double get rangeKmNow => conclusions.rangeKmAtEnd;
  double? get averageWhPerKm => summary.whPerKm;
  bool get moved => conclusions.moved;
  double? get thirstPercent => conclusions.thirstPercentFor(summary.whPerKm);
}
