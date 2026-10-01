import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/simulator/jk_frame_builder.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/link_event.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/gps/location_source.dart';
import 'package:jk_bms/src/metrics/trip_autostart.dart';

import 'fixtures/captured_frames.dart';
import 'fixtures/real_ride_starts_kevinjk.dart';
import 'support/fakes.dart';

/// A GPS that behaves like the phone's in a pocket: nothing for the first
/// [firstFixAfter] after it is switched on, then the ride's real speeds, and
/// nothing at all once it is switched off again.
class PocketGps implements LocationSource {
  PocketGps(this._clock, this.firstFixAfter);

  final DateTime Function() _clock;
  final Duration firstFixAfter;
  final _controller = StreamController<GeoFix>.broadcast();

  DateTime? startedAt;
  bool running = false;

  @override
  Stream<GeoFix> get fixes => _controller.stream;

  @override
  Future<LocationProblem?> start() async {
    startedAt = _clock();
    running = true;
    return null;
  }

  @override
  Future<void> stop() async => running = false;

  /// Delivers [speedKmh] if this GPS is on and has had time to find itself.
  bool offer(double speedKmh) {
    final since = startedAt;
    if (!running || since == null) return false;
    if (_clock().difference(since) < firstFixAfter) return false;
    _controller.add(
      GeoFix(
        timestamp: _clock(),
        latitude: 40,
        longitude: -3,
        speedMs: speedKmh / 3.6,
        altitudeM: 100,
        accuracyM: 8,
      ),
    );
    return true;
  }
}

/// What one replayed ride came to.
class ReplayOutcome {
  ReplayOutcome(this.startedAfter, this.gpsSwitchOns, this.events);

  /// When the ride opened itself, from the first reading. Null if it never
  /// did within the replay.
  final Duration? startedAfter;

  /// Times the GPS was switched on, up to and including the ride opening.
  /// One means it went on once and the ride kept the stream it found.
  final int gpsSwitchOns;

  final List<String> events;

  @override
  String toString() => 'started after ${startedAfter?.inSeconds ?? 'never'} '
      's, GPS switched on $gpsSwitchOns times';
}

Future<ReplayOutcome> replay(
  RealRideStart ride, {
  Duration firstFixAfter = const Duration(seconds: 10),
}) async {
  final base = DateTime.utc(2026, 9, 1, 8);
  var now = base.subtract(const Duration(seconds: 5));
  DateTime clock() => now;

  final sources = <PocketGps>[];
  final link = FakeLink();
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final repo = BmsRepository(database: db);
  final service = BmsService(
    transport: link,
    clock: clock,
    locationFactory: () {
      final g = PocketGps(clock, firstFixAfter);
      sources.add(g);
      return g;
    },
  )..repository = repo;

  try {
    await service.connect('AA:BB', name: 'KevinJK');
    await link.deliver(deviceInfoFrames[1]);
    await link.deliver(cellInfo24s[0]);
    service.applySettings(haptics: false, rawFrames: false, autoTrip: true);

    DateTime? startedAt;
    var switchOnsBeforeStart = 0;
    final sub = service.autoTripEvents.listen((a) {
      if (a == AutoTripAction.start && startedAt == null) {
        startedAt = now;
        switchOnsBeforeStart = sources.length;
      }
    });

    // Readings stored in the same whole second are spread across it, in
    // order, the way they arrived.
    final timeline = <(int, double?, double?)>[];
    final perSecond = <int, int>{};
    for (final (t, _) in ride.readings) {
      perSecond[t] = (perSecond[t] ?? 0) + 1;
    }
    final seen = <int, int>{};
    for (final (t, current) in ride.readings) {
      final k = seen[t] = (seen[t] ?? 0) + 1;
      final ms = t + (1000 * (k - 1)) ~/ perSecond[t]!;
      timeline.add((ms, current, null));
    }
    for (final (t, speed) in ride.fixes) {
      // A fix a hair after the reading of the same second.
      timeline.add((t + 1, null, speed));
    }
    timeline.sort((a, b) => a.$1.compareTo(b.$1));

    const builder = JkFrameBuilder();
    var counter = 10;
    for (final (ms, current, speed) in timeline) {
      if (startedAt != null) break;
      now = base.add(Duration(milliseconds: ms));
      if (speed != null) {
        if (sources.isNotEmpty) sources.last.offer(speed);
        await pumpEventQueue();
        continue;
      }
      await link.deliver(
        builder.cellInfo(
          counter: counter++ & 0xFF,
          cellVoltages: List.filled(16, 3.33),
          cellResistances: List.filled(16, 0.003),
          packVoltage: 53.28,
          current: current!,
          temperatures: const [24, 25],
          mosfetTemp: 27,
          soc: 80,
          soh: 100,
          remainingCapacityAh: 32,
          nominalCapacityAh: 40,
          cycleCount: 60,
          cycleCapacityAh: 2400,
          balancingAction: 0,
          balanceCurrent: 0,
          chargeMosfetOn: true,
          dischargeMosfetOn: true,
          errorBitmask: 0,
          totalRuntimeSeconds: 3600,
        ),
      );
      await pumpEventQueue();
    }
    await sub.cancel();

    final events = (await repo.recentLinkEvents()).reversed
        .map((e) => e.kind)
        .where((k) => const {
              'ridingCurrentSeen',
              'locationArmed',
              'locationRefused',
              'idleSpeedSeen',
              'autoTripStarted',
              'autoTripBlocked',
            }.contains(k))
        .toList();
    return ReplayOutcome(
      startedAt?.difference(base),
      startedAt == null ? sources.length : switchOnsBeforeStart,
      events,
    );
  } finally {
    await service.dispose();
    await repo.dispose();
    await db.close();
  }
}

void main() {
  // The owner, 2026-10-01: "lo de empezar solo ni siquiera funciona". These
  // replay the first six minutes of his own rides, readings and GPS speeds as
  // they were stored, through the real service, with the phone's GPS taking
  // ten seconds to find itself each time it is switched on.
  //
  // What they found, on the code before this test existed: the GPS was
  // switched on by the first reading that drew 3 A and switched off by the
  // first one that did not, which on a real ride is a second or two later.
  // It was switched on and off up to a dozen times in a ride's first minutes,
  // almost never long enough for a fix, and the one reading in three that
  // draws under 3 A on a real ride reset the detector's twenty seconds every
  // time. Most of these rides opened minutes late or not at all.
  //
  // The bounds are what each ride allows. Ride 18 went at walking pace for its
  // first two and a half minutes, which is not riding; ride 11's link was down
  // for most of its first two minutes, and nothing is judged without readings.
  // On the old code, in the same replay: ride 8 opened after 133 s with the
  // GPS switched on 9 times, ride 12 after 67 s (3), ride 11 after 124 s (2),
  // ride 18 never in six minutes (45).
  const opensWithin = {8: 60, 11: 130, 12: 60, 18: 180};
  for (final ride in realRideStarts) {
    final mostlyDown = ride.tripId == 21;
    test('ride ${ride.tripId} (${ride.description}) opens itself', () async {
      final out = await replay(ride);
      // The GPS goes on once and stays on: every restart costs another wait
      // for a fix, and from a pocket another chance to be refused.
      expect(out.gpsSwitchOns, 1, reason: '$out');

      if (mostlyDown) {
        // Twenty-eight readings in six minutes: there is next to nothing to
        // judge. Not opening on that is right, and it must not churn.
        return;
      }
      expect(out.startedAfter, isNotNull, reason: '$out');
      expect(
        out.startedAfter!,
        lessThan(Duration(seconds: opensWithin[ride.tripId]!)),
        reason: '$out',
      );
      expect(out.events, contains(LinkEventKind.autoTripStarted.name));
    });
  }
}
