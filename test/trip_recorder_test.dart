import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/gps/location_source.dart';
import 'package:jk_bms/src/metrics/trip_recorder.dart';
import 'package:jk_bms/src/model/bms_snapshot.dart';
import 'package:jk_bms/src/model/bms_warning.dart';
import 'package:jk_bms/src/protocol/protocol_variant.dart';

/// Roughly 111 m of latitude per 0.001 degree, which makes the expected
/// distances easy to reason about.
GeoFix fix(
  DateTime at, {
  double lat = 0,
  double lon = 0,
  double speedKmh = 30,
  double altitude = 100,
}) =>
    GeoFix(
      timestamp: at,
      latitude: lat,
      longitude: lon,
      speedMs: speedKmh / 3.6,
      altitudeM: altitude,
      accuracyM: 4,
    );

BmsSnapshot snap(DateTime at, {double current = -10, double soc = 80}) {
  final cells = List.filled(20, 3.9);
  return BmsSnapshot(
    timestamp: at,
    variant: JkProtocolVariant.jk02_24s,
    frameCounter: 1,
    cellVoltages: cells,
    cellResistances: List.filled(20, 0.0025),
    enabledCellMask: 0xFFFFF,
    packVoltage: 78,
    current: current,
    temperatures: const [25, 24],
    temperatureSensorMask: 7,
    mosfetTemp: 30,
    soc: soc,
    soh: 97,
    remainingCapacityAh: 35,
    nominalCapacityAh: 45,
    cycleCount: 60,
    cycleCapacityAh: 2700,
    balancingAction: 0,
    balanceCurrent: 0,
    chargeMosfetOn: true,
    dischargeMosfetOn: true,
    balancerActive: false,
    heatingOn: false,
    warnings: BmsWarnings.none,
    wireResistanceWarningMask: 0,
    heatingCurrent: 0,
    totalRuntimeSeconds: 3600,
  );
}

void main() {
  final t0 = DateTime.utc(2026, 1, 1, 10);

  group('TripRecorder', () {
    test('records nothing until started', () {
      final r = TripRecorder();
      r.addFix(fix(t0));
      r.addFix(fix(t0.add(const Duration(seconds: 1)), lat: 0.001));
      expect(r.state, TripState.idle);
      expect(r.distanceKm, 0);
      expect(r.stop(), isNull);
    });

    test('measures distance between fixes', () {
      final r = TripRecorder()..start();
      r.addFix(fix(t0));
      r.addFix(fix(t0.add(const Duration(seconds: 5)), lat: 0.001));

      // 0.001 degrees of latitude is about 111 m.
      expect(r.distanceKm, closeTo(0.111, 0.002));
      expect(r.movingDuration, const Duration(seconds: 5));
    });

    test('ignores GPS jitter while standing still', () {
      final r = TripRecorder()..start();
      r.addFix(fix(t0, speedKmh: 0));
      // Half a metre of wander at zero speed.
      r.addFix(
        fix(
          t0.add(const Duration(seconds: 5)),
          lat: 0.000005,
          speedKmh: 0,
        ),
      );

      expect(r.distanceKm, 0);
      expect(r.movingDuration, Duration.zero);
    });

    test('does not draw a line across a signal gap', () {
      final r = TripRecorder()..start();
      r.addFix(fix(t0));
      // Two minutes later and a kilometre away: the app was backgrounded.
      r.addFix(fix(t0.add(const Duration(minutes: 2)), lat: 0.01));

      expect(r.distanceKm, 0);
    });

    test('pausing stops the clock and the odometer', () {
      final r = TripRecorder()..start();
      r.addFix(fix(t0));
      r.addFix(fix(t0.add(const Duration(seconds: 5)), lat: 0.001));
      final before = r.distanceKm;

      r.pause();
      r.addFix(fix(t0.add(const Duration(seconds: 10)), lat: 0.002));
      r.addFix(fix(t0.add(const Duration(seconds: 15)), lat: 0.003));

      expect(r.state, TripState.paused);
      expect(r.distanceKm, before);

      r.resume();
      r.addFix(fix(t0.add(const Duration(seconds: 20)), lat: 0.004));
      r.addFix(fix(t0.add(const Duration(seconds: 25)), lat: 0.005));

      // Only the segment after resuming is added; the pause itself is not
      // bridged, which is the whole point of pausing.
      expect(r.distanceKm, closeTo(before + 0.111, 0.002));
    });

    test('integrates energy out of the pack', () {
      final r = TripRecorder()..start();
      // 78 V x 10 A = 780 W for 10 s = 2.166 Wh.
      r.addSnapshot(snap(t0));
      r.addSnapshot(snap(t0.add(const Duration(seconds: 10))));

      expect(r.energyOutWh, closeTo(780 * 10 / 3600, 0.01));
      expect(r.energyInWh, 0);
    });

    test('counts regeneration separately from consumption', () {
      final r = TripRecorder()..start();
      r.addSnapshot(snap(t0, current: -10));
      r.addSnapshot(snap(t0.add(const Duration(seconds: 10)), current: 5));
      r.addSnapshot(snap(t0.add(const Duration(seconds: 20)), current: 5));

      expect(r.energyOutWh, greaterThan(0));
      expect(r.energyInWh, greaterThan(0));
    });

    test('reports consumption once far enough to mean something', () {
      final r = TripRecorder()..start();
      expect(r.whPerKm, isNull);

      r.addFix(fix(t0));
      r.addFix(fix(t0.add(const Duration(seconds: 5)), lat: 0.005));
      r.addSnapshot(snap(t0));
      r.addSnapshot(snap(t0.add(const Duration(seconds: 10))));

      expect(r.whPerKm, isNotNull);
      expect(r.whPerKm, greaterThan(0));
    });

    test('summarises what the pack did', () {
      final r = TripRecorder()..start();
      r.addFix(fix(t0, speedKmh: 40));
      r.addFix(
        fix(t0.add(const Duration(seconds: 5)), lat: 0.005, speedKmh: 62),
      );
      r.addSnapshot(snap(t0, soc: 80));
      r.addSnapshot(snap(t0.add(const Duration(seconds: 10)), soc: 76));

      final summary = r.stop()!;
      expect(summary.maxSpeedKmh, 62);
      expect(summary.startSoc, 80);
      expect(summary.endSoc, 76);
      expect(summary.socUsed, 4);
      expect(summary.socPerKm, isNotNull);
      expect(summary.maxDischargeCurrent, 10);
      expect(summary.maxTemperature, 30);
      expect(summary.distanceKm, greaterThan(0.5));
      expect(r.state, TripState.idle);
    });

    test('counts a sustained climb, in full, over several fixes', () {
      final r = TripRecorder()..start();
      // Climbing steadily from 100 m to 200 m.
      for (var i = 0; i <= 60; i++) {
        r.addFix(
          fix(
            t0.add(Duration(seconds: i * 2)),
            lat: 0.0001 * i,
            altitude: 100 + i * 100 / 60,
          ),
        );
      }

      final summary = r.summarise()!;
      // The smoothing lags, so the total lands a little under the true 100 m
      // rather than over it. Under-reporting is the right direction to err:
      // the alternative is inventing elevation out of noise.
      expect(summary.climbM, greaterThan(85));
      expect(summary.climbM, lessThan(100));
      expect(summary.descentM, 0);
    });

    test('a flat ride with noisy altitude reports no elevation at all', () {
      final r = TripRecorder()..start();
      // Flat road, with GPS altitude wandering the +/- 8 m it really does.
      const wander = [0.0, 6.0, -5.0, 4.0, -7.0, 3.0, -4.0, 5.0, -6.0, 2.0];
      for (var i = 0; i < wander.length; i++) {
        r.addFix(
          fix(
            t0.add(Duration(seconds: i * 3)),
            lat: 0.0002 * i,
            altitude: 100 + wander[i],
          ),
        );
      }

      final summary = r.summarise()!;
      // This is the whole point of the hysteresis: summing consecutive steps
      // here would have claimed roughly 20 m of climbing on a flat road.
      expect(summary.climbM, lessThan(4));
      expect(summary.descentM, lessThan(4));
    });

    test('counts a descent after a climb', () {
      final r = TripRecorder()..start();
      for (var i = 0; i <= 40; i++) {
        r.addFix(
          fix(t0.add(Duration(seconds: i)), lat: 0.0001 * i, altitude: 100 + i.toDouble()),
        );
      }
      for (var i = 0; i <= 40; i++) {
        r.addFix(
          fix(
            t0.add(Duration(seconds: 40 + i)),
            lat: 0.004 + 0.0001 * i,
            altitude: 140 - i.toDouble(),
          ),
        );
      }

      final summary = r.summarise()!;
      expect(summary.climbM, greaterThan(30));
      expect(summary.descentM, greaterThan(30));
    });

    test('starting again clears the previous trip', () {
      final r = TripRecorder()..start();
      r.addFix(fix(t0));
      r.addFix(fix(t0.add(const Duration(seconds: 5)), lat: 0.005));
      r.stop();

      r.start();
      expect(r.distanceKm, 0);
      expect(r.energyOutWh, 0);
      expect(r.maxSpeedKmh, 0);
    });
  });
}
