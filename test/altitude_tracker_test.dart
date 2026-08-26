import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/metrics/altitude_tracker.dart';

void main() {
  group('AltitudeTracker', () {
    test('the first reading sets the baseline and counts nothing', () {
      final a = AltitudeTracker();
      expect(a.add(100), 100);
      expect(a.climbM, 0);
      expect(a.descentM, 0);
    });

    test('wander below the threshold never accumulates', () {
      final a = AltitudeTracker();
      // Two hundred readings of pure noise around a flat 100 m. Summing
      // consecutive steps would claim hundreds of metres here.
      const noise = [0.0, 2.5, -2.0, 1.5, -2.5, 2.0, -1.5, 2.5, -2.0, 1.0];
      a.add(100);
      for (var i = 0; i < 200; i++) {
        a.add(100 + noise[i % noise.length]);
      }

      expect(a.climbM, lessThan(3));
      expect(a.descentM, lessThan(3));
    });

    test('a real climb is counted, in chunks, as it is made', () {
      final a = AltitudeTracker()..add(100);
      // 100 m of climbing, one metre at a time.
      for (var i = 1; i <= 100; i++) {
        a.add(100 + i.toDouble());
      }

      // The moving average lags, so the total lands just under the truth.
      expect(a.climbM, greaterThan(90));
      expect(a.climbM, lessThan(100));
      expect(a.descentM, 0);
    });

    test('climbing then descending counts both', () {
      final a = AltitudeTracker()..add(100);
      for (var i = 1; i <= 50; i++) {
        a.add(100 + i.toDouble());
      }
      for (var i = 49; i >= 0; i--) {
        a.add(100 + i.toDouble());
      }

      expect(a.climbM, greaterThan(40));
      expect(a.descentM, greaterThan(40));
      // Back where it started, so the two should roughly match.
      expect((a.climbM - a.descentM).abs(), lessThan(6));
    });

    test('a single spike does not survive the smoothing', () {
      final a = AltitudeTracker()..add(100);
      for (var i = 0; i < 10; i++) {
        a.add(100);
      }
      // One bad fix twenty metres off, then back to normal.
      a.add(120);
      for (var i = 0; i < 10; i++) {
        a.add(100);
      }

      // The spike moves the average by 25% of 20 m, which does cross the
      // threshold once. What matters is that it does not count the full 20 m
      // and does not leave the tracker convinced it climbed.
      expect(a.climbM, lessThan(6));
      expect(a.netM.abs(), lessThan(1));
    });

    test('net change tracks the smoothed altitude, not the total', () {
      final a = AltitudeTracker()..add(100);
      for (var i = 1; i <= 60; i++) {
        a.add(100 + i.toDouble());
      }
      for (var i = 59; i >= 30; i--) {
        a.add(100 + i.toDouble());
      }

      // Ended 30 m above where it started, having climbed 60 and dropped 30.
      expect(a.netM, closeTo(30, 3));
      expect(a.climbM, greaterThan(a.netM));
    });

    test('reset clears everything', () {
      final a = AltitudeTracker()..add(100);
      for (var i = 1; i <= 50; i++) {
        a.add(100 + i.toDouble());
      }
      expect(a.climbM, greaterThan(0));

      a.reset();
      expect(a.climbM, 0);
      expect(a.descentM, 0);
      expect(a.altitudeM, isNull);
    });

    test('a coarser threshold ignores more', () {
      List<double> profile() => [
            for (var i = 0; i < 40; i++) 100 + (i % 4) * 2.0,
          ];

      final tight = AltitudeTracker(thresholdM: 1);
      final loose = AltitudeTracker(thresholdM: 10);
      for (final v in profile()) {
        tight.add(v);
        loose.add(v);
      }

      expect(tight.climbM, greaterThan(loose.climbM));
      expect(loose.climbM, 0);
    });
  });
}
