import 'dart:math' as math;

import '../gps/location_source.dart';
import '../model/bms_snapshot.dart';
import 'altitude_tracker.dart';
import 'range_estimator.dart';

enum TripState { idle, recording, paused }

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

  double _energyOutWh = 0;
  double _energyInWh = 0;

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
  double get energyOutWh => _energyOutWh;
  double get energyInWh => _energyInWh;
  double? get startSoc => _startSoc;

  /// Consumption so far. Null until far enough to be meaningful.
  double? get whPerKm {
    if (_distanceKm < 0.2) return null;
    final net = _energyOutWh - _energyInWh;
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
      startedAt: started,
      movingDuration: _movingDuration,
      totalDuration: totalDuration,
      distanceKm: _distanceKm,
      maxSpeedKmh: _maxSpeedKmh,
      energyOutWh: _energyOutWh,
      energyInWh: _energyInWh,
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

    final dt = fix.timestamp.difference(previousAt);
    // A long gap means the app was backgrounded or the signal died. Do not draw
    // a straight line across it and call it distance.
    if (dt.inSeconds <= 0 || dt.inSeconds > 30) return;

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

    if (s.packVoltage > 0) {
      _minPackVoltage = math.min(_minPackVoltage, s.packVoltage);
      _maxPackVoltage = math.max(_maxPackVoltage, s.packVoltage);
    }
    if (s.current < 0) {
      _maxDischargeCurrent = math.max(_maxDischargeCurrent, -s.current);
    }
    final temps = <double>[
      ...s.temperatures,
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

    final dt = s.timestamp.difference(previousAt);
    if (dt.inSeconds <= 0 || dt.inSeconds > 10) return;

    // Trapezoid rather than sampling one endpoint: at 1 Hz against a throttle
    // that swings hard, taking only the later reading biases the total.
    final wh = (previousPower + s.power) / 2 * dt.inMilliseconds / 3600000.0;
    if (wh < 0) {
      _energyOutWh += -wh;
    } else {
      _energyInWh += wh;
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
    _energyOutWh = 0;
    _energyInWh = 0;
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

/// What a finished ride turned out to be, and what it taught.
///
/// The summary alone says what happened. This adds what changed because of it,
/// which is the part that makes recording a ride feel worth doing.
class TripOutcome {
  const TripOutcome({
    required this.summary,
    required this.whPerKmBefore,
    required this.whPerKmAfter,
    required this.hadLearnedBefore,
    required this.learnedKm,
    required this.confidence,
    required this.rangeKmNow,
    required this.averageWhPerKm,
  });

  final TripSummary summary;

  /// The learned figure before this ride was folded in.
  final double whPerKmBefore;
  final double whPerKmAfter;

  /// False when this was the first ride with usable data.
  final bool hadLearnedBefore;

  final double learnedKm;
  final RangeConfidence confidence;

  /// Range at the charge level the ride ended on.
  final double rangeKmNow;

  /// What this ride cost, for comparison against the learned average.
  final double? averageWhPerKm;

  /// True when the ride moved the estimate by more than rounding.
  bool get moved => (whPerKmAfter - whPerKmBefore).abs() > 0.5;

  /// How much thirstier this ride was than the learned average, as a
  /// percentage. Null when there is nothing to compare against.
  double? get thirstPercent {
    final ride = summary.whPerKm;
    if (ride == null || !hadLearnedBefore || whPerKmBefore <= 0) return null;
    final delta = (ride - whPerKmBefore) / whPerKmBefore * 100;
    return delta > 15 ? delta : null;
  }
}
