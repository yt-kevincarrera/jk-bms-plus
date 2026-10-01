import 'dart:async';
import 'dart:io';

import 'package:geolocator/geolocator.dart';

/// One position reading.
class GeoFix {
  const GeoFix({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.speedMs,
    required this.altitudeM,
    required this.accuracyM,
  });

  /// Phone clock, UTC.
  final DateTime timestamp;
  final double latitude;
  final double longitude;

  /// Metres per second, as reported by the platform.
  final double speedMs;
  final double altitudeM;

  /// Horizontal accuracy in metres. Bigger is worse.
  final double accuracyM;

  double get speedKmh => speedMs * 3.6;
}

/// Why location is unavailable, in words worth showing.
///
/// [approximateOnly]: Android 12 lets the rider grant "approximate" location,
/// which comes in hundreds of metres wide. Every such fix fails the accuracy
/// floor below, so a ride started with it records no distance and no speed
/// at all, for as long as it runs.
enum LocationProblem {
  serviceDisabled,
  permissionDenied,
  permanentlyDenied,
  approximateOnly,
}

/// What a location source has seen, for writing down when a ride gets no
/// distance. Kept apart from [LocationSource] so test doubles need not care.
abstract interface class LocationDiagnostics {
  /// Positions the platform delivered.
  int get received;

  /// Of those, the ones dropped as too inaccurate.
  int get tooInaccurate;

  /// The best accuracy any delivered position had, in metres.
  double? get bestAccuracyM;
}

/// Where positions come from.
///
/// An interface so demo mode can drive the trip recorder from the simulated
/// pack, and so the recorder can be tested without a radio or a window.
abstract interface class LocationSource {
  Stream<GeoFix> get fixes;
  Future<LocationProblem?> start();
  Future<void> stop();
}

/// The real thing.
class GeolocatorSource implements LocationSource, LocationDiagnostics {
  GeolocatorSource({
    this.minimumAccuracyM = 30,
    this.ownForegroundService = false,
  });

  /// Fallback: let geolocator run its own foreground service instead of relying
  /// on the app's. Only useful if the app's service ever turns out not to keep
  /// location flowing on some device.
  final bool ownForegroundService;

  /// Fixes worse than this are dropped. A 100 m fix while stopped at a light
  /// would otherwise invent hundreds of metres of distance out of nothing.
  final double minimumAccuracyM;

  final _controller = StreamController<GeoFix>.broadcast();
  StreamSubscription<Position>? _sub;

  @override
  int received = 0;
  @override
  int tooInaccurate = 0;
  @override
  double? bestAccuracyM;

  @override
  Stream<GeoFix> get fixes => _controller.stream;

  @override
  Future<LocationProblem?> start() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationProblem.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationProblem.permanentlyDenied;
    }
    if (permission == LocationPermission.denied) {
      return LocationProblem.permissionDenied;
    }
    // Granted is not the same as usable: "approximate" passes every check
    // above and then delivers nothing a ride can be measured with.
    try {
      if (await Geolocator.getLocationAccuracy() ==
          LocationAccuracyStatus.reduced) {
        return LocationProblem.approximateOnly;
      }
    } on Object catch (_) {
      // Could not ask; the fix counts below will tell if it matters.
    }

    await _sub?.cancel();
    _sub = Geolocator.getPositionStream(
      locationSettings: _settings(),
    ).listen((p) {
      received++;
      final best = bestAccuracyM;
      if (best == null || p.accuracy < best) bestAccuracyM = p.accuracy;
      if (p.accuracy > minimumAccuracyM) {
        tooInaccurate++;
        return;
      }
      _controller.add(
        GeoFix(
          timestamp: DateTime.now().toUtc(),
          latitude: p.latitude,
          longitude: p.longitude,
          speedMs: p.speed.isFinite && p.speed > 0 ? p.speed : 0,
          altitudeM: p.altitude,
          accuracyM: p.accuracy,
        ),
      );
    }, onError: _controller.addError);
    return null;
  }

  /// On Android this asks for a foreground service, which is what keeps a trip
  /// recording once the screen goes off or the app is swiped away from view.
  ///
  /// Without it Android throttles a backgrounded app's location to a few fixes
  /// an hour, which would turn a ride into a straight line between two points.
  /// The persistent notification is not optional: it is the price Android
  /// charges for not being killed, and it doubles as the honest signal that
  /// something is still using the GPS.
  LocationSettings _settings() {
    // Metres of movement before a new fix is emitted. Small enough to follow a
    // bike, large enough not to accumulate jitter while parked.
    const distanceFilter = 5;

    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: distanceFilter,
        forceLocationManager: false,
        // Deliberately no foreground notification of its own. The app already
        // runs a location-typed foreground service that carries the live trip
        // readout, and that is what grants continued GPS access; asking
        // geolocator for a second one would put two notifications in the shade
        // saying the same thing.
        foregroundNotificationConfig: ownForegroundService
            ? const ForegroundNotificationConfig(
                notificationTitle: 'JK BMS +',
                notificationText: 'Recording a trip',
                notificationChannelName: 'Trip location',
                enableWakeLock: true,
                setOngoing: true,
              )
            : null,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: distanceFilter,
    );
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}
