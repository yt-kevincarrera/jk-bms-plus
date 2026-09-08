import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/metrics/trip_recorder.dart';

import 'fixtures/snapshot_builder.dart';

/// The recorder's side of the coverage rule.
///
/// Every ride here is one of the real ones from the backup of 2026-09-08. The
/// two that were wrong, 20 and 21, are wrong in the same way: the Bluetooth
/// link died early, the counter difference measured only the watched minutes,
/// and the recorder stored that as the whole ride under
/// [EnergySource.coulombCount] with nothing downstream any the wiser.
void main() {
  final t0 = DateTime.utc(2026, 9, 7, 16, 9, 49);

  /// A recorder whose clock the test drives, so a ride can last 53 minutes
  /// without the test taking 53 minutes.
  ({TripRecorder trip, void Function(Duration) advance}) recorder() {
    var now = t0;
    final trip = TripRecorder(clock: () => now);
    return (trip: trip, advance: (d) => now = now.add(d));
  }

  group('a ride the link covered', () {
    test('is measured by the counter, as it always was', () {
      // Trip 18, the one that came out right: 6.64 Ah over 108 minutes.
      final r = recorder();
      r.trip.start();
      r.trip.addSnapshot(buildSnapshot(timestamp: t0, remainingAh: 33.86));
      r.advance(const Duration(minutes: 108));
      r.trip.addSnapshot(
        buildSnapshot(
          timestamp: t0.add(const Duration(minutes: 108)),
          remainingAh: 27.22,
        ),
      );

      expect(r.trip.ahOut, closeTo(6.64, 0.001));
      expect(r.trip.energySource, EnergySource.coulombCount);
      expect(r.trip.energyOutWh, greaterThan(0));
    });

    test('a blackout in the middle changes nothing', () {
      // Trip 18 again. It lost 63 of its 108 minutes to one gap. The counter
      // was accumulating throughout, so both ends is all it ever needed.
      final r = recorder();
      r.trip.start();
      r.trip.addSnapshot(buildSnapshot(timestamp: t0, remainingAh: 33.86));
      r.advance(const Duration(minutes: 63));
      r.advance(const Duration(minutes: 45));
      r.trip.addSnapshot(
        buildSnapshot(
          timestamp: t0.add(const Duration(minutes: 108)),
          remainingAh: 27.22,
        ),
      );

      expect(r.trip.energySource, EnergySource.coulombCount);
      expect(r.trip.ahOut, closeTo(6.64, 0.001));
    });
  });

  group('a ride the link abandoned', () {
    test('does not pass a minute of counting off as 53 minutes of riding', () {
      // Trip 20 exactly: readings for 1 minute of 53, a 0.13 Ah difference,
      // and 22 km ridden. It was stored as 10 Wh, or 0.5 Wh/km. Bracketing it
      // afterwards recovers 4.93 Ah, which is 17.0 Wh/km.
      final r = recorder();
      r.trip.start();
      r.trip.addSnapshot(buildSnapshot(timestamp: t0, remainingAh: 34.32));
      r.advance(const Duration(minutes: 1));
      r.trip.addSnapshot(
        buildSnapshot(
          timestamp: t0.add(const Duration(minutes: 1)),
          remainingAh: 34.20,
        ),
      );
      r.advance(const Duration(minutes: 52));

      expect(
        r.trip.energySource,
        EnergySource.partialCoulombCount,
        reason: 'the counter measured a minute, not the ride',
      );
      expect(
        r.trip.ahOut,
        isNull,
        reason: 'no amp-hour figure for the ride is honest; 0.13 is not',
      );
      expect(
        r.trip.energyOutWh,
        0,
        reason: 'integrating the watched minute tells the same lie',
      );
    });

    test('nor nine minutes of counting off as 47 of riding', () {
      // Trip 21, the one that quoted 225 km of range.
      final r = recorder();
      r.trip.start();
      r.trip.addSnapshot(buildSnapshot(timestamp: t0, remainingAh: 39.10));
      r.advance(const Duration(minutes: 9));
      r.trip.addSnapshot(
        buildSnapshot(
          timestamp: t0.add(const Duration(minutes: 9)),
          remainingAh: 37.93,
        ),
      );
      r.advance(const Duration(minutes: 38));

      expect(r.trip.energySource, EnergySource.partialCoulombCount);
      expect(r.trip.ahOut, isNull);
    });

    test('is left repairable rather than marked unmeasurable', () {
      // The distinction earns its keep: unmeasurable means nothing arrived at
      // all, and the bracketing repair is the only thing that can help. A
      // partial ride has readings on disk and two ends to reach for, and the
      // repair should know it is worth looking.
      final r = recorder();
      r.trip.start();
      r.trip.addSnapshot(buildSnapshot(timestamp: t0, remainingAh: 34.32));
      r.advance(const Duration(minutes: 1));
      r.trip.addSnapshot(
        buildSnapshot(
          timestamp: t0.add(const Duration(minutes: 1)),
          remainingAh: 34.20,
        ),
      );
      r.advance(const Duration(minutes: 52));

      expect(r.trip.energySource, isNot(EnergySource.unmeasurable));
      expect(r.trip.energySource, isNot(EnergySource.coulombCount));
      expect(r.trip.energySource, isNot(EnergySource.integrated));
    });

    test('a ride nothing arrived during is still unmeasurable', () {
      // Not a regression: no readings at all is a different state from a few,
      // and it keeps its own marker.
      final r = recorder();
      r.trip.start();
      r.advance(const Duration(minutes: 30));

      expect(r.trip.energySource, EnergySource.unmeasurable);
      expect(r.trip.ahOut, isNull);
    });
  });

  group('the stored summary', () {
    test('carries the partial marker through to the row', () {
      // What the repair reads later, and what stops the estimator learning
      // 0.5 Wh/km in the meantime.
      final r = recorder();
      r.trip.start();
      r.trip.addSnapshot(buildSnapshot(timestamp: t0, remainingAh: 34.32));
      r.advance(const Duration(minutes: 1));
      r.trip.addSnapshot(
        buildSnapshot(
          timestamp: t0.add(const Duration(minutes: 1)),
          remainingAh: 34.20,
        ),
      );
      r.advance(const Duration(minutes: 52));

      final summary = r.trip.stop()!;
      expect(summary.energySource, EnergySource.partialCoulombCount);
      expect(summary.ahOut, isNull);
      expect(summary.energyOutWh, 0);
      expect(
        summary.whPerKm,
        isNull,
        reason: 'a ride with no honest energy figure has no honest Wh/km',
      );
    });
  });
}
