import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/bms_link.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/gps/location_source.dart';
import 'package:jk_bms/src/metrics/trip_recorder.dart';

import 'fixtures/captured_frames.dart';

/// A transport that replays captured bytes instead of talking to a radio.
class FakeLink implements BmsLink {
  final _bytes = StreamController<List<int>>.broadcast();
  final _state = StreamController<BleLinkState>.broadcast();
  final _errors = StreamController<BleLinkError>.broadcast();

  @override
  Stream<List<int>> get bytes => _bytes.stream;
  @override
  Stream<BleLinkState> get state => _state.stream;
  @override
  Stream<BleLinkError> get errors => _errors.stream;
  @override
  int? negotiatedMtu = 244;

  @override
  LinkHealth get health => LinkHealth.unknown;

  @override
  Stream<List<DiscoveredBms>> scan() => const Stream.empty();
  @override
  Future<void> connect(String deviceId) async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> dispose() async {
    await _bytes.close();
    await _state.close();
    await _errors.close();
  }

  Future<void> deliver(Uint8List frame, {int chunk = 20}) async {
    for (var i = 0; i < frame.length; i += chunk) {
      _bytes.add(frame.sublist(i, (i + chunk).clamp(0, frame.length)));
    }
    await pumpEventQueue();
  }
}

/// A location source that counts how many times it was started and stopped.
///
/// The whole bug was invisible from the outside: the ride carried on looking
/// like a ride. What gives it away is the stream being torn down, so that is
/// what this watches.
class CountingLocation implements LocationSource {
  final _controller = StreamController<GeoFix>.broadcast();

  int starts = 0;
  int stops = 0;
  bool get running => starts > stops;

  /// Set to refuse to start, the way a revoked permission would.
  LocationProblem? refuseWith;

  @override
  Stream<GeoFix> get fixes => _controller.stream;

  @override
  Future<LocationProblem?> start() async {
    if (refuseWith != null) return refuseWith;
    starts++;
    return null;
  }

  @override
  Future<void> stop() async {
    if (running) stops++;
  }

  void emit({
    double speedKmh = 30,
    double lat = 40,
    double lon = -3,
    int secondsAgo = 0,
  }) {
    _controller.add(
      GeoFix(
        timestamp: DateTime.now().toUtc().subtract(Duration(seconds: secondsAgo)),
        latitude: lat,
        longitude: lon,
        speedMs: speedKmh / 3.6,
        altitudeM: 100,
        accuracyM: 5,
      ),
    );
  }
}

void main() {
  late FakeLink link;
  late CountingLocation gps;
  late AppDatabase db;
  late BmsService service;

  /// One decoded reading. This fixture carries a current of zero, which is a
  /// bike standing still: exactly the condition that used to stand the GPS
  /// down underneath a paused ride.
  Future<void> feedReading() async {
    await link.deliver(cellInfo24s[0]);
    await pumpEventQueue();
  }

  setUp(() async {
    link = FakeLink();
    gps = CountingLocation();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = BmsService(transport: link, locationFactory: () => gps)
      ..repository = BmsRepository(database: db);
    // A pack on record is a precondition for any of the watchers to run: with
    // nothing connected the app deliberately records nothing at all.
    await service.connect('AA:BB', name: 'KevinJK');
    await link.deliver(deviceInfoFrames[1]);
    await feedReading();
    expect(service.activeDevice, isNotNull);
  });

  tearDown(() async {
    await service.dispose();
    await db.close();
  });

  group('pausing a ride', () {
    test('keeps the location stream the ride depends on', () async {
      // The bug, in one assertion. Pausing at a petrol station left the pack
      // drawing nothing, the auto-trip watcher read that as "nothing is
      // happening, stand the GPS down", and it tore down the stream the paused
      // ride was still holding. Nothing ever put it back, so the remaining
      // sixteen kilometres of a twenty-two kilometre ride recorded no distance.
      expect(await service.startTrip(), isNull);
      expect(gps.running, isTrue);

      service.pauseTrip();
      // Readings keep arriving while parked, which is exactly when it happened.
      for (var i = 0; i < 5; i++) {
        await feedReading();
      }
      await pumpEventQueue();

      expect(gps.running, isTrue, reason: 'a paused ride still owns the GPS');
      expect(gps.stops, 0);
    });

    test('resuming records distance again', () async {
      expect(await service.startTrip(), isNull);
      service.pauseTrip();
      await feedReading();
      await pumpEventQueue();

      expect(await service.resumeTrip(), isNull);
      expect(service.trip.state, TripState.recording);

      // Two fixes a few hundred metres and a few seconds apart, the way a
      // moving bike arrives.
      gps.emit(lat: 40, lon: -3, secondsAgo: 5);
      await pumpEventQueue();
      gps.emit(lat: 40.002, lon: -3);
      await pumpEventQueue();

      expect(service.trip.distanceKm, greaterThan(0));
    });

    test('a paused ride keeps its foreground service', () async {
      // Losing the service mid-pause is how a ride dies the moment the phone
      // goes back in a pocket.
      expect(await service.startTrip(), isNull);
      service.chargeWatchEnabled = false;
      service.pauseTrip();
      for (var i = 0; i < 3; i++) {
        await feedReading();
      }
      await pumpEventQueue();
      expect(service.trip.isActive, isTrue);
    });

    test('resuming re-arms location when it died on its own', () async {
      expect(await service.startTrip(), isNull);
      service.pauseTrip();
      // Something outside the app took it away: the OS revoking the
      // permission, or the provider being stood down.
      await gps.stop();
      expect(gps.running, isFalse);

      expect(await service.resumeTrip(), isNull);
      expect(gps.running, isTrue, reason: 'resume puts the stream back');
    });

    test('says so out loud when it cannot re-arm', () async {
      final problems = <String>[];
      service.problems.listen(problems.add);

      expect(await service.startTrip(), isNull);
      service.pauseTrip();
      await gps.stop();
      gps.refuseWith = LocationProblem.permissionDenied;

      final problem = await service.resumeTrip();
      await pumpEventQueue();

      expect(problem, LocationProblem.permissionDenied);
      expect(problems, isNotEmpty);
      // Still resumed: a ride with no distance is worth less than one with,
      // but it is worth more than a ride that silently stopped.
      expect(service.trip.state, TripState.recording);
    });

    test('resuming something that is not paused does nothing', () async {
      expect(await service.resumeTrip(), isNull);
      expect(service.trip.state, TripState.idle);
    });
  });

  group('the speed a decision is made on', () {
    test('is withdrawn once the fixes stop', () async {
      expect(await service.startTrip(), isNull);
      gps.emit(speedKmh: 40);
      await pumpEventQueue();
      expect(service.trip.freshSpeedKmh, closeTo(40, 0.001));

      // Pause writes a zero over it, and that zero used to be handed to the
      // auto-stop detector for the rest of the ride.
      service.pauseTrip();
      expect(service.trip.freshSpeedKmh, isNull);
    });

    test('is null before any fix at all', () async {
      expect(await service.startTrip(), isNull);
      expect(service.trip.freshSpeedKmh, isNull);
    });
  });
}
