import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/metrics/trip_recorder.dart';

void main() {
  late AppDatabase db;
  late BmsRepository repo;

  final t0 = DateTime.utc(2026, 9, 2, 8, 49, 58);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = BmsRepository(database: db);
    final now = DateTime.utc(2026, 9, 1);
    await db.upsertDevice(
      DevicesCompanion.insert(id: 'AA:BB', firstSeenAt: now, lastSeenAt: now),
    );
  });

  tearDown(() async => db.close());

  /// A reading, with the pack's coulomb counter at [remainingAh].
  Future<void> reading(
    DateTime at, {
    required double remainingAh,
    double packVoltage = 75,
    double current = -20,
    double soc = 62,
  }) =>
      db.insertSnapshots([
        SnapshotsCompanion.insert(
          deviceId: const Value('AA:BB'),
          timestamp: at,
          packVoltage: packVoltage,
          current: current,
          soc: soc,
          soh: 100,
          remainingAh: remainingAh,
          cycleCount: 2,
          deltaVolts: 0.003,
          minCellVoltage: 3.671,
          maxCellVoltage: 3.674,
          maxTemperature: 30,
          warningsMask: 0,
          balancerActive: false,
          cellVoltagesJson: '[3.671]',
        ),
      ]);

  /// A ride as a build before the fix would have stored it: real distance,
  /// energy far too low, and no amp-hour figure because it could not produce
  /// one.
  Future<int> staleTrip({
    required double km,
    required double outWh,
    Duration length = const Duration(minutes: 21, seconds: 55),
  }) =>
      db.insertTrip(
        TripsCompanion.insert(
          deviceId: const Value('AA:BB'),
          startedAt: t0,
          endedAt: t0.add(length),
          distanceKm: km,
          movingSeconds: 685,
          totalSeconds: length.inSeconds,
          maxSpeedKmh: 55,
          energyOutWh: outWh,
          energyInWh: 0,
          startSoc: 64,
          endSoc: 60,
          minPackVoltage: 70,
          maxPackVoltage: 78,
          maxDischargeCurrent: 21.9,
          maxTemperature: 30,
          maxDeltaVolts: 0.02,
          climbM: 20,
          descentM: 20,
        ),
      );

  group('mending a ride recorded before the fix', () {
    test('measures it again from the pack own counter', () async {
      // The real ride, with its real numbers: 5.95 km stored as 4.3 Wh, where
      // the counter went from 25.61 to 24.19 Ah at about 75 V. That is 106 Wh
      // and 17.9 Wh/km, which is what a motorcycle costs.
      await staleTrip(km: 5.95, outWh: 4.292658347989722);
      await reading(t0, remainingAh: 25.61);
      await reading(
        t0.add(const Duration(minutes: 21, seconds: 55)),
        remainingAh: 24.19,
      );

      final report = await repo.repairTripEnergy('AA:BB');
      expect(report.repaired, 1);
      expect(report.unrepairable, 0);

      final fixed = (await repo.tripsForLearning('AA:BB')).single;
      expect(fixed.ahOut, closeTo(1.42, 0.001));
      expect(fixed.energySource, EnergySource.coulombCount.name);
      expect(fixed.energyOutWh, closeTo(106.5, 1));
      expect(fixed.energyOutWh / fixed.distanceKm, closeTo(17.9, 0.3));
    });

    test('the mended ride is one the estimator will accept', () async {
      // The whole point. Before mending, 0.72 Wh/km is below the estimator's
      // floor of 2 and the ride teaches nothing.
      await staleTrip(km: 5.95, outWh: 4.29);
      await reading(t0, remainingAh: 25.61);
      await reading(
        t0.add(const Duration(minutes: 21, seconds: 55)),
        remainingAh: 24.19,
      );

      await repo.repairTripEnergy('AA:BB');
      final fixed = (await repo.tripsForLearning('AA:BB')).single;
      final whPerKm = fixed.energyOutWh / fixed.distanceKm;
      expect(whPerKm, greaterThan(2));
      expect(whPerKm, lessThan(400));
    });

    test('runs once and then finds nothing', () async {
      await staleTrip(km: 5.95, outWh: 4.29);
      await reading(t0, remainingAh: 25.61);
      await reading(
        t0.add(const Duration(minutes: 21, seconds: 55)),
        remainingAh: 24.19,
      );

      expect((await repo.repairTripEnergy('AA:BB')).repaired, 1);
      expect((await repo.repairTripEnergy('AA:BB')).examined, 0);
    });

    test('leaves a ride recorded after the fix alone', () async {
      final id = await staleTrip(km: 5.95, outWh: 106);
      await db.updateTrip(
        id,
        const TripsCompanion(
          ahOut: Value(1.42),
          energySource: Value('coulombCount'),
        ),
      );
      await reading(t0, remainingAh: 25.61);
      await reading(
        t0.add(const Duration(minutes: 21, seconds: 55)),
        remainingAh: 24.19,
      );

      expect((await repo.repairTripEnergy('AA:BB')).examined, 0);
      final untouched = (await repo.tripsForLearning('AA:BB')).single;
      expect(untouched.energyOutWh, 106);
    });
  });

  group('what cannot be mended', () {
    test('a ride whose readings are gone stays as it was', () async {
      // Readings are thinned after thirty days and dropped eventually. An old
      // ride with nothing left to measure keeps its wrong figure rather than
      // getting a made-up one.
      await staleTrip(km: 5.95, outWh: 4.29);

      final report = await repo.repairTripEnergy('AA:BB');
      expect(report.repaired, 0);
      expect(report.unrepairable, 1);

      final untouched = (await repo.tripsForLearning('AA:BB')).single;
      expect(untouched.energyOutWh, closeTo(4.29, 0.001));
    });

    test('falls back to integrating when the counter did not move', () async {
      // A short ride can finish inside one step of the counter and still have
      // drawn a measurable amount. Integration answers, done properly this
      // time.
      await staleTrip(km: 1.5, outWh: 0.3, length: const Duration(minutes: 5));
      for (var ms = 0; ms <= 300000; ms += 400) {
        await reading(
          t0.add(Duration(milliseconds: ms)),
          remainingAh: 25.0,
        );
      }

      final report = await repo.repairTripEnergy('AA:BB');
      expect(report.repaired, 1);

      final fixed = (await repo.tripsForLearning('AA:BB')).single;
      expect(fixed.ahOut, isNull);
      expect(fixed.energySource, EnergySource.integrated.name);
      // Five minutes at 1500 W is 125 Wh.
      expect(fixed.energyOutWh, closeTo(125, 3));
    });

    test('a counter that went up is not consumption', () async {
      // Charging during the ride. The counter difference is net and cannot
      // separate the directions, so integration has to answer.
      await staleTrip(km: 1.5, outWh: 0.3, length: const Duration(minutes: 5));
      await reading(t0, remainingAh: 20, current: 10);
      await reading(
        t0.add(const Duration(minutes: 5)),
        remainingAh: 23,
        current: 10,
      );

      final report = await repo.repairTripEnergy('AA:BB');
      // Nothing left the pack over that window, so there is nothing to mend.
      expect(report.repaired, 0);
      expect(report.unrepairable, 1);
    });
  });
}
