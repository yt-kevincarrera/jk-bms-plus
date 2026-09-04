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

import 'fixtures/captured_frames.dart';

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

  void announce(BleLinkState s) => _state.add(s);

  Future<void> deliver(Uint8List frame, {int chunk = 20}) async {
    for (var i = 0; i < frame.length; i += chunk) {
      _bytes.add(frame.sublist(i, (i + chunk).clamp(0, frame.length)));
    }
    await pumpEventQueue();
  }
}

class StubLocation implements LocationSource {
  final _controller = StreamController<GeoFix>.broadcast();
  @override
  Stream<GeoFix> get fixes => _controller.stream;
  @override
  Future<LocationProblem?> start() async => null;
  @override
  Future<void> stop() async {}
}

void main() {
  late FakeLink link;
  late AppDatabase db;
  late BmsService service;

  Future<void> feedReading() async {
    await link.deliver(cellInfo24s[0]);
    await pumpEventQueue();
  }

  setUp(() async {
    link = FakeLink();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = BmsService(
      transport: link,
      locationFactory: StubLocation.new,
    )..repository = BmsRepository(database: db);
    await service.connect('AA:BB', name: 'KevinJK');
    await link.deliver(deviceInfoFrames[1]);
    await feedReading();
  });

  tearDown(() async {
    await service.dispose();
    await db.close();
  });

  // The service itself cannot start off a device, so these check the *claim*:
  // which of the three things gets the one slot, and when it is released.
  // Getting that wrong is how a charge finishing used to be able to stop the
  // service a ride was relying on.

  group('who gets the one foreground service', () {
    test('nothing, when nothing is connected or happening', () async {
      // Never connected in the eyes of the link: no reading has proved a live
      // radio, so there is nothing to keep alive.
      expect(service.isWatchingLink, isFalse);
      expect(service.isWatchingCharge, isFalse);
    });

    test('a bare connection claims it, which is the point', () async {
      // Without this the app stops receiving shortly after the screen goes
      // dark. It does not fail: readings thin out and stop, which is the worst
      // way for a logger to break.
      link.announce(BleLinkState.connected);
      await pumpEventQueue();
      expect(service.lastLinkState, BleLinkState.connected);
      expect(service.claimForTest, ServiceClaim.link);
    });

    test('and lets go the moment the link drops', () async {
      link.announce(BleLinkState.connected);
      await pumpEventQueue();
      expect(service.claimForTest, ServiceClaim.link);

      // Readings are what normally drive this, and a dropped link stops
      // producing them, so the state change has to be able to stand it down
      // itself or the notification outlives the connection it describes.
      link.announce(BleLinkState.reconnecting);
      await pumpEventQueue();
      expect(service.claimForTest, isNull);
    });

    test('turning it off releases it', () async {
      link.announce(BleLinkState.connected);
      await pumpEventQueue();
      service.linkWatchEnabled = false;
      expect(service.claimForTest, isNull);
    });

    test('a ride outranks a bare connection', () async {
      link.announce(BleLinkState.connected);
      await pumpEventQueue();
      expect(await service.startTrip(), isNull);
      expect(service.claimForTest, ServiceClaim.trip);
    });

    test('a paused ride still outranks it', () async {
      // The fault that cost a real ride: a pause used to hand the slot away.
      link.announce(BleLinkState.connected);
      await pumpEventQueue();
      expect(await service.startTrip(), isNull);
      service.pauseTrip();
      await feedReading();
      expect(service.claimForTest, ServiceClaim.trip);
    });

    test('a download outranks a connection and a charge', () async {
      link.announce(BleLinkState.connected);
      await pumpEventQueue();
      service.chargeWatchEnabled = true;

      service.reportDownloadProgress(12);
      expect(service.claimForTest, ServiceClaim.update);

      // Released on finishing, failing or being cancelled alike.
      service.reportDownloadProgress(null);
      expect(service.claimForTest, isNot(ServiceClaim.update));
    });

    test('but not over a ride', () async {
      expect(await service.startTrip(), isNull);
      service.reportDownloadProgress(50);
      expect(service.claimForTest, ServiceClaim.trip);
    });

    test('ending a ride hands back to the connection, not to nothing', () async {
      // Ending a ride is not a reason to stop reading. It used to stop the
      // service outright.
      link.announce(BleLinkState.connected);
      await pumpEventQueue();
      expect(await service.startTrip(), isNull);
      await service.stopTrip();
      expect(service.claimForTest, ServiceClaim.link);
    });

    test('the service is location-typed while auto-start needs a fix', () async {
      // The pre-trip GPS arming used to run under a dataSync-typed service, and
      // Android only sustains background location for a location-typed one. With
      // the screen off the fixes stopped, the detector saw no speed, and a ride
      // that needs speed to start never started.
      service.applySettings(haptics: false, rawFrames: false, autoTrip: true);
      link.announce(BleLinkState.connected);
      await pumpEventQueue();

      expect(service.claimForTest, ServiceClaim.link);
      expect(service.serviceUsesLocationForTest, isTrue);
    });

    test('and not location-typed when auto-start is off', () async {
      // Nothing is watching for a ride, so nothing needs the GPS. Claiming the
      // location type without using it is what Android 14 refuses.
      service.applySettings(haptics: false, rawFrames: false, autoTrip: false);
      link.announce(BleLinkState.connected);
      await pumpEventQueue();

      expect(service.claimForTest, ServiceClaim.link);
      expect(service.serviceUsesLocationForTest, isFalse);
    });

    test('toggling auto-start on while connected restarts with location type',
        () async {
      // The settings screen lets the rider switch auto-start on after connecting.
      // Without restarting the service, it keeps the dataSync type it was born
      // with, which is the exact bug this type exists to prevent.
      service.applySettings(haptics: false, rawFrames: false, autoTrip: false);
      link.announce(BleLinkState.connected);
      await pumpEventQueue();

      expect(service.claimForTest, ServiceClaim.link);
      expect(service.serviceUsesLocationForTest, isFalse);

      // Now toggle auto-start on.
      service.autoTripEnabled = true;
      await pumpEventQueue();

      expect(service.serviceUsesLocationForTest, isTrue);
    });

    test('the notification says a ride was saved, then goes back to normal',
        () async {
      // Arriving home with the phone in a pocket used to give nothing at all:
      // the summary was discarded and the notification went straight back to
      // the connected readout. The one notification slot is free at that
      // moment, so it carries the news instead of a second notification being
      // invented.
      link.announce(BleLinkState.connected);
      await pumpEventQueue();
      expect(service.claimForTest, ServiceClaim.link);

      service.rideSavedText = (km, whPerKm) =>
          'Guardado ${km.toStringAsFixed(1)} km';
      service.linkWatchText = (_) => 'conectado';

      service.noteRideSavedForTest(km: 23.4, whPerKm: 18);
      expect(service.serviceTextForTest, 'Guardado 23.4 km');

      service.expireRideSavedForTest();
      expect(service.serviceTextForTest, 'conectado');
    });

    test('switching packs clears the ride saved on the one before it',
        () async {
      // Real stopTrip(), not the test-only setter: this is the path that
      // used to leave the fields standing, so pack B's first notification
      // showed pack A's distance as if it had just happened on pack B.
      link.announce(BleLinkState.connected);
      await pumpEventQueue();
      service.rideSavedText = (km, whPerKm) =>
          'Guardado ${km.toStringAsFixed(1)} km';
      service.linkWatchText = (_) => 'conectado';

      expect(await service.startTrip(), isNull);
      await service.stopTrip();
      expect(service.claimForTest, ServiceClaim.link);
      expect(service.serviceTextForTest, startsWith('Guardado'));

      // A different pack, still within the few minutes the news would stand.
      await service.connect('CC:DD', name: 'OtherPack');
      await link.deliver(deviceInfoFrames[1]);
      await feedReading();

      expect(service.claimForTest, ServiceClaim.link);
      expect(service.serviceTextForTest, 'conectado');
    });
  });
}
