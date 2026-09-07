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
    double startSoc = 64,
    double endSoc = 60,
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
          startSoc: startSoc,
          endSoc: endSoc,
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

  // The ride that prompted this: 22.09 km of GPS track and not one reading
  // from the pack, because the link dropped on departure and only came back on
  // arrival. Every pack figure on the screen was zero.
  group('a ride nothing was received during', () {
    /// The blackout ride, as the recorder stored it: distance and no pack.
    Future<int> blackoutTrip() => staleTrip(
      km: 22.09,
      outWh: 0,
      length: const Duration(minutes: 50),
      startSoc: 0,
      endSoc: 0,
    );

    test('is measured from the readings either side of it', () async {
      // Connected a minute before setting off, reconnected two minutes after
      // arriving. The BMS counted the whole ride regardless of the phone.
      await blackoutTrip();
      await reading(
        t0.subtract(const Duration(minutes: 1)),
        remainingAh: 39.6,
        packVoltage: 81,
        soc: 99,
      );
      await reading(
        t0.add(const Duration(minutes: 52)),
        remainingAh: 33.8,
        packVoltage: 77,
        soc: 84,
      );

      final report = await repo.repairTripEnergy('AA:BB');
      expect(report.repaired, 1);

      final fixed = (await repo.tripsForLearning('AA:BB')).single;
      expect(fixed.ahOut, closeTo(5.8, 0.001));
      expect(fixed.energySource, EnergySource.bracketedCoulombCount.name);
      // 5.8 Ah priced at the mean of 81 and 77 V.
      expect(fixed.energyOutWh, closeTo(458.2, 0.5));
      expect(fixed.energyOutWh / fixed.distanceKm, closeTo(20.7, 0.3));
    });

    test('gets its charge figures back too', () async {
      // They were zero for the same reason the energy was, and they come from
      // the same two readings.
      await blackoutTrip();
      await reading(
        t0.subtract(const Duration(minutes: 1)),
        remainingAh: 39.6,
        soc: 99,
      );
      await reading(
        t0.add(const Duration(minutes: 52)),
        remainingAh: 33.8,
        soc: 84,
      );

      await repo.repairTripEnergy('AA:BB');
      final fixed = (await repo.tripsForLearning('AA:BB')).single;
      expect(fixed.startSoc, 99);
      expect(fixed.endSoc, 84);
    });

    test('a ride the link was up for keeps its own charge figures', () async {
      // The bracketing path is the only one that touches these, because it is
      // the only one whose ride has none of its own.
      await staleTrip(km: 5.95, outWh: 4.29);
      await reading(t0, remainingAh: 25.61);
      await reading(
        t0.add(const Duration(minutes: 21, seconds: 55)),
        remainingAh: 24.19,
      );

      await repo.repairTripEnergy('AA:BB');
      final fixed = (await repo.tripsForLearning('AA:BB')).single;
      expect(fixed.energySource, EnergySource.coulombCount.name);
      expect(fixed.startSoc, 64);
      expect(fixed.endSoc, 60);
    });

    test('will not reach far for a bracket', () async {
      // Forty minutes before setting off is long enough for another ride or a
      // charge to hide in, and the counter difference cannot tell.
      await blackoutTrip();
      await reading(
        t0.subtract(const Duration(minutes: 40)),
        remainingAh: 39.6,
      );
      await reading(
        t0.add(const Duration(minutes: 52)),
        remainingAh: 33.8,
      );

      final report = await repo.repairTripEnergy('AA:BB');
      expect(report.repaired, 0);
      expect(report.unrepairable, 1);
    });

    test('will not measure across a charge', () async {
      await blackoutTrip();
      await reading(
        t0.subtract(const Duration(minutes: 1)),
        remainingAh: 33.8,
      );
      await reading(
        t0.add(const Duration(minutes: 52)),
        remainingAh: 39.6,
      );

      expect((await repo.repairTripEnergy('AA:BB')).repaired, 0);
    });

    test('one side is not enough', () async {
      // Half a ride measured reads as a whole ride that was cheap.
      await blackoutTrip();
      await reading(
        t0.subtract(const Duration(minutes: 1)),
        remainingAh: 39.6,
      );

      expect((await repo.repairTripEnergy('AA:BB')).repaired, 0);
    });

    test('a ride the old repair gave up on is retried, once', () async {
      // What EnergySource.unmeasurable was written down for. It must be
      // findable by a repair that knows a new trick, and must stop being
      // examined again once that trick has also been tried.
      final id = await blackoutTrip();
      await db.updateTrip(
        id,
        TripsCompanion(
          energySource: Value(EnergySource.unmeasurable.name),
        ),
      );

      // Nothing on disk to bracket with, so the new trick fails too.
      expect((await repo.repairTripEnergy('AA:BB')).examined, 1);
      expect((await repo.repairTripEnergy('AA:BB')).examined, 0);
    });

    test('and the retry mends it when the readings are there', () async {
      final id = await blackoutTrip();
      await db.updateTrip(
        id,
        TripsCompanion(
          energySource: Value(EnergySource.unmeasurable.name),
        ),
      );
      await reading(
        t0.subtract(const Duration(minutes: 1)),
        remainingAh: 39.6,
      );
      await reading(
        t0.add(const Duration(minutes: 52)),
        remainingAh: 33.8,
      );

      expect((await repo.repairTripEnergy('AA:BB')).repaired, 1);
      final fixed = (await repo.tripsForLearning('AA:BB')).single;
      expect(fixed.ahOut, closeTo(5.8, 0.001));
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
