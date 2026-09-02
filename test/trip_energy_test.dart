import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/metrics/trip_recorder.dart';
import 'package:jk_bms/src/model/bms_snapshot.dart';
import 'package:jk_bms/src/model/bms_warning.dart';
import 'package:jk_bms/src/protocol/protocol_variant.dart';

/// One reading. [remainingAh] is the pack's own coulomb counter.
BmsSnapshot at(
  DateTime when, {
  double current = -20,
  double packVoltage = 75,
  double remainingAh = 25,
  double soc = 62,
}) =>
    BmsSnapshot(
      timestamp: when,
      variant: JkProtocolVariant.jk02_24s,
      frameCounter: 1,
      cellVoltages: List.filled(20, packVoltage / 20),
      cellResistances: List.filled(20, 0.0025),
      enabledCellMask: 0xFFFFF,
      packVoltage: packVoltage,
      current: current,
      temperatures: const [25, 24],
      temperatureSensorMask: 7,
      mosfetTemp: 30,
      soc: soc,
      soh: 97,
      remainingCapacityAh: remainingAh,
      nominalCapacityAh: 40,
      cycleCount: 60,
      cycleCapacityAh: 2000,
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

void main() {
  final t0 = DateTime.utc(2026, 9, 2, 8, 49);

  group('energy over a ride, at the cadence a real BMS pushes', () {
    // The bug this file exists for. A JK BMS sends two or three cell-info
    // frames a second, so the gap between readings is 300 to 500 ms. Every
    // integration in the app guarded on `dt.inSeconds <= 0`, which is true for
    // all of them, and returned early having already moved its anchor. A real
    // 22 km ride recorded 4.3 Wh against a coulomb count of 102.

    test('sub-second readings are integrated, not discarded', () {
      final trip = TripRecorder()..start();

      // Ten minutes at 350 ms, 75 V and 20 A out: 1500 W, so 250 Wh.
      // remainingAh held still so the coulomb path cannot answer instead.
      for (var i = 0; i <= 600 * 1000 ~/ 350; i++) {
        trip.addSnapshot(at(t0.add(Duration(milliseconds: i * 350))));
      }

      expect(trip.energyOutWh, closeTo(250, 3));
      expect(trip.energySource, EnergySource.integrated);
    });

    test('the same ride at one second reads the same', () {
      // Sampling rate must not change the answer. It used to change it by a
      // factor of twenty-five.
      final fast = TripRecorder()..start();
      final slow = TripRecorder()..start();

      for (var ms = 0; ms <= 600000; ms += 350) {
        fast.addSnapshot(at(t0.add(Duration(milliseconds: ms))));
      }
      for (var ms = 0; ms <= 600000; ms += 1000) {
        slow.addSnapshot(at(t0.add(Duration(milliseconds: ms))));
      }

      expect(fast.energyOutWh, closeTo(slow.energyOutWh, 2));
    });

    test('two readings sharing an instant do not double count', () {
      final trip = TripRecorder()..start();
      trip.addSnapshot(at(t0));
      trip.addSnapshot(at(t0));
      expect(trip.energyOutWh, 0);
    });

    test('a long gap is not integrated across', () {
      // What happened while the link was down is unknown, and drawing a
      // straight line over it invents whatever the bike was doing at each end.
      final trip = TripRecorder()..start();
      trip.addSnapshot(at(t0));
      trip.addSnapshot(at(t0.add(const Duration(minutes: 3))));
      expect(trip.energyOutWh, 0);
    });
  });

  group('the coulomb counter, preferred where there is one', () {
    test('answers with amp-hours times the mean voltage', () {
      // 1.42 Ah at about 75 V is roughly 107 Wh: the figures from the ride
      // that exposed all of this.
      final trip = TripRecorder()..start();
      trip.addSnapshot(at(t0, remainingAh: 25.61));
      trip.addSnapshot(
        at(t0.add(const Duration(minutes: 21)), remainingAh: 24.19),
      );

      expect(trip.ahOut, closeTo(1.42, 0.001));
      expect(trip.energySource, EnergySource.coulombCount);
      expect(trip.energyOutWh, closeTo(1.42 * 75, 1));
    });

    test('survives a link that was down for most of the ride', () {
      // The real failure: 998 of 1286 seconds with no readings. Integration
      // can only ever account for the moments the phone was listening; the
      // BMS was counting the whole time.
      final trip = TripRecorder()..start();
      trip.addSnapshot(at(t0, remainingAh: 25.61));
      // A three-minute hole, which no integration may cross.
      trip.addSnapshot(
        at(t0.add(const Duration(minutes: 3)), remainingAh: 24.19),
      );

      expect(trip.energyOutWh, closeTo(1.42 * 75, 1));
      expect(
        trip.energySource,
        EnergySource.coulombCount,
        reason: 'the gap is exactly why the counter is preferred',
      );
    });

    test('a counter that has not moved is not a measurement of nothing', () {
      // Quantised to a hundredth of an amp-hour. A difference below its own
      // step says nothing, so integration answers instead.
      final trip = TripRecorder()..start();
      for (var ms = 0; ms <= 60000; ms += 350) {
        trip.addSnapshot(at(t0.add(Duration(milliseconds: ms))));
      }
      expect(trip.ahOut, isNull);
      expect(trip.energySource, EnergySource.integrated);
      expect(trip.energyOutWh, greaterThan(0));
    });

    test('a counter going up is not consumption', () {
      // Charging mid-ride. The counter difference is net and cannot separate
      // the directions, so it must not be read as a negative consumption.
      final trip = TripRecorder()..start();
      trip.addSnapshot(at(t0, remainingAh: 20, current: 10));
      trip.addSnapshot(
        at(t0.add(const Duration(minutes: 5)), remainingAh: 23, current: 10),
      );
      expect(trip.ahOut, isNull);
    });
  });

  group('what it all adds up to', () {
    test('consumption lands where a motorcycle actually lives', () {
      // The end-to-end check. 5.95 km on 1.42 Ah at 75 V is about 18 Wh/km.
      // The old code reported 0.72, which the range estimator then rejected
      // for being under 2 Wh/km -- which is why eight recorded rides taught
      // it nothing and the rider asked why.
      final trip = TripRecorder()..start();
      trip.addSnapshot(at(t0, remainingAh: 25.61));
      trip.addSnapshot(
        at(t0.add(const Duration(minutes: 21)), remainingAh: 24.19),
      );

      final summary = trip.summarise()!;
      expect(summary.ahOut, closeTo(1.42, 0.001));
      expect(summary.energySource, EnergySource.coulombCount);

      final whPerKm = summary.energyOutWh / 5.95;
      expect(whPerKm, greaterThan(2), reason: 'above the estimator floor');
      expect(whPerKm, lessThan(60));
    });
  });
}
