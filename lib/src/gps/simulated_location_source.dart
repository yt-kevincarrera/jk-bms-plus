import 'dart:async';
import 'dart:math' as math;

import '../ble/simulator/simulated_pack.dart';
import 'location_source.dart';

/// Drives the trip recorder from the simulated pack, so demo mode can show the
/// riding screens working without a window or a satellite.
///
/// The track is a synthetic loop: heading drifts slowly, so the path curves the
/// way a road does instead of running dead straight forever. Position is
/// integrated from the simulated speed, which means distance in demo mode is
/// exactly as consistent as the pack model driving it.
class SimulatedLocationSource implements LocationSource {
  SimulatedLocationSource({
    required this.pack,
    this.interval = const Duration(seconds: 1),
    // Somewhere with hills, so the climb figures move.
    this.startLatitude = -34.6037,
    this.startLongitude = -58.3816,
  });

  final SimulatedPack pack;
  final Duration interval;
  final double startLatitude;
  final double startLongitude;

  final _controller = StreamController<GeoFix>.broadcast();
  final math.Random _random = math.Random(4242);

  Timer? _timer;
  late double _lat = startLatitude;
  late double _lon = startLongitude;
  double _headingRad = 0.4;
  double _altitude = 25;

  @override
  Stream<GeoFix> get fixes => _controller.stream;

  @override
  Future<LocationProblem?> start() async {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _step());
    return null;
  }

  void _step() {
    if (_controller.isClosed) return;

    final seconds = interval.inMilliseconds / 1000.0;
    final speedMs = pack.speedKmh / 3.6;
    final metres = speedMs * seconds;

    // Drift the heading, and add a gentle rise and fall so altitude is not flat.
    _headingRad += (_random.nextDouble() - 0.5) * 0.12;
    _altitude += math.sin(_headingRad * 2) * 0.35;

    // A degree of latitude is about 111.32 km anywhere; longitude shrinks with
    // the cosine of latitude.
    const metresPerDegreeLat = 111320.0;
    final metresPerDegreeLon =
        metresPerDegreeLat * math.cos(_lat * math.pi / 180.0);

    _lat += metres * math.cos(_headingRad) / metresPerDegreeLat;
    _lon += metres * math.sin(_headingRad) / metresPerDegreeLon;

    _controller.add(
      GeoFix(
        timestamp: DateTime.now().toUtc(),
        latitude: _lat,
        longitude: _lon,
        speedMs: speedMs,
        altitudeM: _altitude,
        accuracyM: 4,
      ),
    );
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}
