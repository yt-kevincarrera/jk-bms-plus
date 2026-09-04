import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/bms_link.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/gps/location_source.dart';
import 'package:jk_bms/src/metrics/trip_autostart.dart';

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
}

/// A location source that refuses, so the blocked path can be exercised.
class RefusingLocation implements LocationSource {
  @override
  Stream<GeoFix> get fixes => const Stream<GeoFix>.empty();
  @override
  Future<LocationProblem?> start() async => LocationProblem.permissionDenied;
  @override
  Future<void> stop() async {}
}

void main() {
  final t0 = DateTime.utc(2026, 8, 31, 9);

  /// Feeds [seconds] of identical conditions, a second apart, and returns the
  /// actions raised.
  List<AutoTripAction> feed(
    TripAutoStart d, {
    required int seconds,
    required double current,
    double? speedKmh,
    required bool recording,
    DateTime? from,
  }) {
    final start = from ?? t0;
    final out = <AutoTripAction>[];
    var open = recording;
    for (var i = 0; i < seconds; i++) {
      final action = d.evaluate(
        at: start.add(Duration(seconds: i)),
        current: current,
        speedKmh: speedKmh,
        recording: open,
      );
      if (action == AutoTripAction.start) open = true;
      if (action == AutoTripAction.stop) open = false;
      out.add(action);
    }
    return out;
  }

  group('starting a ride', () {
    test('starts once current and movement have both held', () {
      final d = TripAutoStart();
      final actions =
          feed(d, seconds: 40, current: -22, speedKmh: 28, recording: false);
      expect(actions, contains(AutoTripAction.start));
      // Exactly once. A second start would open a trip on top of a trip.
      expect(actions.where((a) => a == AutoTripAction.start), hasLength(1));
    });

    test('does not start on current alone', () {
      // The bike switched on at the kerb, lights on, going nowhere.
      final d = TripAutoStart();
      final actions =
          feed(d, seconds: 300, current: -18, speedKmh: 0, recording: false);
      expect(actions, everyElement(AutoTripAction.none));
    });

    test('does not start on movement alone', () {
      // The phone in a car with the bike parked in range, or the bike on a
      // trailer. Nothing is being ridden.
      final d = TripAutoStart();
      final actions =
          feed(d, seconds: 300, current: -0.2, speedKmh: 60, recording: false);
      expect(actions, everyElement(AutoTripAction.none));
    });

    test('does not start with no GPS fix yet', () {
      // A null fix is treated as not moving. Starting on current alone is
      // precisely the mistake this exists to avoid.
      final d = TripAutoStart();
      final actions = feed(d, seconds: 300, current: -22, recording: false);
      expect(actions, everyElement(AutoTripAction.none));
    });

    test('does not start from a brief push out of a doorway', () {
      final d = TripAutoStart();
      final actions =
          feed(d, seconds: 8, current: -14, speedKmh: 9, recording: false);
      expect(actions, everyElement(AutoTripAction.none));
    });
  });

  group('ending a ride', () {
    test('ends once everything has been still long enough', () {
      final d = TripAutoStart();
      final actions =
          feed(d, seconds: 240, current: 0.0, speedKmh: 0, recording: true);
      expect(actions, contains(AutoTripAction.stop));
      expect(actions.where((a) => a == AutoTripAction.stop), hasLength(1));
    });

    test('a traffic light does not end it', () {
      // The failure this prevents: one commute becoming eight trips, none of
      // them long enough for the estimator to trust.
      final d = TripAutoStart();
      final actions =
          feed(d, seconds: 90, current: 0.0, speedKmh: 0, recording: true);
      expect(actions, everyElement(AutoTripAction.none));
    });

    test('rolling downhill does not end it', () {
      // No current drawn, but plainly still riding.
      final d = TripAutoStart();
      final actions =
          feed(d, seconds: 300, current: -0.1, speedKmh: 34, recording: true);
      expect(actions, everyElement(AutoTripAction.none));
    });

    test('charging does not end it either, until it stands still', () {
      // Regeneration on a descent reads as current going in.
      final d = TripAutoStart();
      final actions =
          feed(d, seconds: 300, current: 6, speedKmh: 30, recording: true);
      expect(actions, everyElement(AutoTripAction.none));
    });

    test('a stop that is interrupted by riding does not accumulate', () {
      final d = TripAutoStart();
      // Two minutes still, then moving again, then two minutes still. Neither
      // stretch is long enough, and they must not add up to one.
      feed(d, seconds: 120, current: 0, speedKmh: 0, recording: true);
      feed(d,
          seconds: 30,
          current: -20,
          speedKmh: 30,
          recording: true,
          from: t0.add(const Duration(seconds: 120)));
      final actions = feed(d,
          seconds: 120,
          current: 0,
          speedKmh: 0,
          recording: true,
          from: t0.add(const Duration(seconds: 150)));
      expect(actions, everyElement(AutoTripAction.none));
    });

    test('does not try to end a ride that is not open', () {
      final d = TripAutoStart();
      final actions =
          feed(d, seconds: 600, current: 0, speedKmh: 0, recording: false);
      expect(actions, everyElement(AutoTripAction.none));
    });
  });

  group('a whole outing', () {
    test('starts, survives a light, and ends when parked', () {
      final d = TripAutoStart();
      var at = t0;
      var open = false;

      List<AutoTripAction> run(int seconds, double current, double speed) {
        final out = <AutoTripAction>[];
        for (var i = 0; i < seconds; i++) {
          final a = d.evaluate(
            at: at,
            current: current,
            speedKmh: speed,
            recording: open,
          );
          if (a == AutoTripAction.start) open = true;
          if (a == AutoTripAction.stop) open = false;
          out.add(a);
          at = at.add(const Duration(seconds: 1));
        }
        return out;
      }

      expect(run(60, -20, 30), contains(AutoTripAction.start));
      expect(open, isTrue);
      expect(run(80, 0, 0), everyElement(AutoTripAction.none)); // red light
      expect(open, isTrue);
      expect(run(300, -20, 35), everyElement(AutoTripAction.none));
      expect(run(240, 0, 0), contains(AutoTripAction.stop)); // parked
      expect(open, isFalse);
    });
  });

  group('a missing fix is not a parked bike', () {
    test('does not end a ride when the GPS has nothing to say', () {
      // The bug that cost a real ride. Coasting, or waiting at a barrier, puts
      // the current under the idle threshold; with no fix to contradict it,
      // three of those minutes used to read as a bike in a garage and the ride
      // was closed on the spot, mid-route.
      final d = TripAutoStart();
      final actions =
          feed(d, seconds: 600, current: 0, speedKmh: null, recording: true);
      expect(actions, everyElement(AutoTripAction.none));
    });

    test('still ends it once a fix confirms the bike is standing still', () {
      final d = TripAutoStart();
      final actions =
          feed(d, seconds: 240, current: 0, speedKmh: 0, recording: true);
      expect(actions, contains(AutoTripAction.stop));
    });

    test('a ride whose GPS died does not stay open forever', () {
      // The other side of the asymmetry. Leaving it open would append the next
      // ride to this one, which is its own kind of data loss, so a pack that
      // has drawn nothing for twenty minutes closes the trip even unwitnessed.
      final d = TripAutoStart();
      final actions =
          feed(d, seconds: 1400, current: 0, speedKmh: null, recording: true);
      expect(actions, contains(AutoTripAction.stop));
    });

    test('the long fuse does not fire on a bike that is still working', () {
      // Twenty-three minutes of riding with no fix at all: no stillness, so
      // nothing to end.
      final d = TripAutoStart();
      final actions =
          feed(d, seconds: 1400, current: -20, speedKmh: null, recording: true);
      expect(actions, everyElement(AutoTripAction.none));
    });

    test('current returning resets the long fuse', () {
      // Nineteen minutes quiet, a minute of riding, nineteen more quiet. The
      // fuse must start again rather than carry over.
      final d = TripAutoStart();
      var at = t0;
      List<AutoTripAction> run(int seconds, double current, double? speed) {
        final out = <AutoTripAction>[];
        for (var i = 0; i < seconds; i++) {
          out.add(d.evaluate(
            at: at,
            current: current,
            speedKmh: speed,
            recording: true,
          ));
          at = at.add(const Duration(seconds: 1));
        }
        return out;
      }

      expect(run(19 * 60, 0, null), everyElement(AutoTripAction.none));
      expect(run(60, -20, null), everyElement(AutoTripAction.none));
      expect(run(19 * 60, 0, null), everyElement(AutoTripAction.none));
    });
  });

  group('reset', () {
    test('forgets a run in progress', () {
      final d = TripAutoStart();
      feed(d, seconds: 15, current: -20, speedKmh: 30, recording: false);
      d.reset();
      expect(d.looksLikeRiding, isFalse);
      // And the part-finished run does not count towards the next one.
      final actions =
          feed(d, seconds: 10, current: -20, speedKmh: 30, recording: false);
      expect(actions, everyElement(AutoTripAction.none));
    });
  });

  group('the blocked event', () {
    test('a ride that could not open says so instead of going quiet',
        () async {
      // The silent version of this is the worst bug in the feature: the rider
      // believes the app is learning, the app records nothing, and the range
      // figure never appears. The problem used to be stored in
      // lastLocationProblem and read by nobody.
      //
      // The refusal comes from the injected location source rather than from
      // a test-only setter on the service: locationFactory is the seam that
      // already exists, and one seam is enough.
      final link = FakeLink();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final service = BmsService(
        transport: link,
        locationFactory: RefusingLocation.new,
      )..repository = BmsRepository(database: db);
      addTearDown(service.dispose);
      await service.connect('AA:BB', name: 'KevinJK');
      service.applySettings(haptics: false, rawFrames: false, autoTrip: true);

      final events = <AutoTripAction>[];
      service.autoTripEvents.listen(events.add);

      await service.forceAutoTripStartForTest();
      await pumpEventQueue();

      expect(events, [AutoTripAction.blocked]);
    });
  });
}
