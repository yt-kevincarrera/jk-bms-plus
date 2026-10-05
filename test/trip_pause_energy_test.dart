import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/metrics/trip_recorder.dart';

import 'fixtures/snapshot_builder.dart';

/// What a pause does to a ride's energy, and what the live screen says while
/// the link is down.
void main() {
  final t0 = DateTime.utc(2026, 9, 7, 16);

  ({TripRecorder trip, void Function(Duration) advance}) recorder() {
    var now = t0;
    final trip = TripRecorder(clock: () => now);
    return (trip: trip, advance: (d) => now = now.add(d));
  }

  group('a pause', () {
    test('is not billed to the ride', () {
      // Twenty minutes outside a shop with the lights on took 0.4 Ah. The
      // counter kept running, the readings stopped, and the difference from
      // start to end used to charge the ride for it.
      final r = recorder();
      r.trip.start();
      r.trip.addSnapshot(buildSnapshot(timestamp: t0, remainingAh: 30.0));
      r.advance(const Duration(minutes: 20));
      r.trip.addSnapshot(
        buildSnapshot(
          timestamp: t0.add(const Duration(minutes: 20)),
          remainingAh: 28.0,
        ),
      );
      r.trip.pause();
      r.advance(const Duration(minutes: 20));
      r.trip.resume();
      r.trip.addSnapshot(
        buildSnapshot(
          timestamp: t0.add(const Duration(minutes: 40)),
          remainingAh: 27.6,
        ),
      );
      r.advance(const Duration(minutes: 20));
      r.trip.addSnapshot(
        buildSnapshot(
          timestamp: t0.add(const Duration(minutes: 60)),
          remainingAh: 25.6,
        ),
      );
      // 2.0 Ah before the pause and 2.0 after; the 0.4 in between is not
      // the ride's.
      expect(r.trip.ahOut, closeTo(4.0, 0.001));
    });

    test('charging while parked is not taken off the ride either', () {
      final r = recorder();
      r.trip.start();
      r.trip.addSnapshot(buildSnapshot(timestamp: t0, remainingAh: 30.0));
      r.advance(const Duration(minutes: 10));
      r.trip.addSnapshot(
        buildSnapshot(
          timestamp: t0.add(const Duration(minutes: 10)),
          remainingAh: 29.0,
        ),
      );
      r.trip.pause();
      r.advance(const Duration(minutes: 30));
      r.trip.resume();
      r.trip.addSnapshot(
        buildSnapshot(
          timestamp: t0.add(const Duration(minutes: 40)),
          remainingAh: 33.0,
        ),
      );
      r.advance(const Duration(minutes: 10));
      r.trip.addSnapshot(
        buildSnapshot(
          timestamp: t0.add(const Duration(minutes: 50)),
          remainingAh: 32.0,
        ),
      );
      expect(r.trip.ahOut, closeTo(2.0, 0.001));
    });
  });

  group('the live screen with the link down', () {
    test('shows what was measured until the link went, not zero', () {
      // Readings for the first five minutes of a forty-minute ride: the
      // ride's own figure is zero on purpose until it is measured again, and
      // "0.0 Wh" read as a ride that cost nothing.
      final r = recorder();
      r.trip.start();
      r.trip.addSnapshot(buildSnapshot(timestamp: t0, remainingAh: 30.0));
      r.advance(const Duration(minutes: 5));
      r.trip.addSnapshot(
        buildSnapshot(
          timestamp: t0.add(const Duration(minutes: 5)),
          remainingAh: 29.5,
        ),
      );
      r.advance(const Duration(minutes: 35));
      expect(r.trip.energyOutWh, 0);
      expect(r.trip.energyCoversRide, isFalse);
      expect(r.trip.energyOutWhSoFar, greaterThan(0));
    });
  });
}
