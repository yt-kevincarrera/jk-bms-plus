import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/metrics/trip_recorder.dart';

/// The repair's side of the coverage rule.
///
/// [TripEnergyRepair.recompute] had the same hole the recorder did: given a
/// handful of readings from inside a ride it took the difference across them
/// and called it the ride, however little of the ride they covered. So the
/// repair could not have mended the two rides that prompted this even if it
/// had been allowed to look at them, and its own doc already knew why -- it
/// says of the bracketing path that "one of them plus a reading from inside
/// the ride would cover only part of it and quietly under-report the rest,
/// which is worse than admitting the ride cannot be measured". That principle
/// was only ever applied to rides where nothing arrived at all.
void main() {
  late AppDatabase db;
  late BmsRepository repo;

  const device = 'AA:BB';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = BmsRepository(database: db);
    final seen = DateTime.utc(2026, 9, 1);
    await db.upsertDevice(
      DevicesCompanion.insert(id: device, firstSeenAt: seen, lastSeenAt: seen),
    );
  });

  tearDown(() async => db.close());

  Future<void> reading(
    DateTime at, {
    required double remainingAh,
    double packVoltage = 76,
    double soc = 80,
  }) => db.insertSnapshots([
    SnapshotsCompanion.insert(
      deviceId: const Value(device),
      timestamp: at,
      packVoltage: packVoltage,
      current: -20,
      soc: soc,
      soh: 100,
      remainingAh: remainingAh,
      cycleCount: 2,
      deltaVolts: 0.003,
      minCellVoltage: 3.79,
      maxCellVoltage: 3.8,
      maxTemperature: 30,
      warningsMask: 0,
      balancerActive: false,
      cellVoltagesJson: '[3.8]',
    ),
  ]);

  /// A ride exactly as the two broken ones sit on disk: a real distance, an
  /// amp-hour figure that is not null, and [EnergySource.coulombCount], which
  /// is what made them invisible to every repair pass.
  Future<int> rideStoredAsMeasured({
    required DateTime start,
    required Duration length,
    required double km,
    required double ahOut,
    required double outWh,
    String source = 'coulombCount',
  }) => db.insertTrip(
    TripsCompanion.insert(
      deviceId: const Value(device),
      startedAt: start,
      endedAt: start.add(length),
      distanceKm: km,
      movingSeconds: length.inSeconds,
      totalSeconds: length.inSeconds,
      maxSpeedKmh: 55,
      energyOutWh: outWh,
      energyInWh: 0,
      startSoc: 86,
      endSoc: 85,
      minPackVoltage: 70,
      maxPackVoltage: 78,
      maxDischargeCurrent: 20.8,
      maxTemperature: 30,
      maxDeltaVolts: 0.02,
      climbM: 20,
      descentM: 20,
      ahOut: Value(ahOut),
      energySource: Value(source),
    ),
  );

  group('trip 20, the one that read 0.5 Wh/km', () {
    // 22.08 km over 53 minutes. The link was up for the first minute only:
    // the counter went 34.32 -> 34.20, a difference of 0.13 Ah, and that was
    // stored as the whole ride. The reading taken eight minutes after
    // arriving says 29.39, so the ride really cost 4.93 Ah.
    final start = DateTime.utc(2026, 9, 7, 16, 9, 50);
    const length = Duration(minutes: 53);

    Future<int> setUpRide() async {
      final id = await rideStoredAsMeasured(
        start: start,
        length: length,
        km: 22.081572586168008,
        ahOut: 0.125,
        outWh: 10.112202755905523,
      );
      // The bracket before setting off, a second before the ride's own start.
      await reading(
        start.subtract(const Duration(seconds: 1)),
        remainingAh: 34.32,
        soc: 86,
      );
      // The minute the link lasted.
      await reading(start.add(const Duration(seconds: 30)), remainingAh: 34.28);
      await reading(start.add(const Duration(minutes: 1)), remainingAh: 34.20);
      // The bracket on arrival, eight minutes after stopping.
      await reading(
        start.add(length + const Duration(minutes: 8)),
        remainingAh: 29.39,
        soc: 73,
      );
      return id;
    }

    test('a forced repair recovers what the ride really cost', () async {
      final id = await setUpRide();

      final report = await repo.repairTrip(id);
      expect(report.repaired, 1);

      final fixed = await db.tripById(id);
      expect(fixed!.ahOut, closeTo(4.93, 0.01));
      expect(fixed.energySource, EnergySource.bracketedCoulombCount.name);
      expect(
        fixed.energyOutWh / fixed.distanceKm,
        closeTo(17.0, 0.5),
        reason: 'the figure this bike really rides at',
      );
    });

    test('the automatic pass still will not touch it, and should not', () async {
      // Nothing about the row says it is wrong, so a pass that runs on every
      // connection has no business re-reading a week of history to find out.
      // That is what the button is for.
      await setUpRide();
      final report = await repo.repairTripEnergy(device);
      expect(report.examined, 0);
    });
  });

  group('trip 21, the one that quoted 225 km of range', () {
    // 22.05 km over 47 minutes, the link up for the first nine. Counter went
    // 39.10 -> 37.93 in that window, stored as 1.17 Ah and 4.3 Wh/km. The
    // reading on arrival says 34.23, so the ride cost 4.87 Ah.
    final start = DateTime.utc(2026, 9, 8, 8, 30, 43);
    const length = Duration(minutes: 47);

    test('a forced repair recovers what the ride really cost', () async {
      final id = await rideStoredAsMeasured(
        start: start,
        length: length,
        km: 22.05367867314009,
        ahOut: 1.1700000000000017,
        outWh: 95.47969315068505,
      );
      await reading(
        start.subtract(const Duration(seconds: 1)),
        remainingAh: 39.10,
        soc: 98,
      );
      await reading(start.add(const Duration(minutes: 9)), remainingAh: 37.93);
      await reading(start.add(length), remainingAh: 34.23, soc: 86);

      final report = await repo.repairTrip(id);
      expect(report.repaired, 1);

      final fixed = await db.tripById(id);
      expect(fixed!.ahOut, closeTo(4.87, 0.01));
      expect(fixed.energyOutWh / fixed.distanceKm, closeTo(16.8, 0.5));
    });
  });

  group('a ride the readings really did cover', () {
    test('is measured from them, not from the brackets', () async {
      // Trip 18's shape: watched end to end, so the readings from inside the
      // ride are the better measurement and the brackets are not needed.
      final start = DateTime.utc(2026, 9, 5, 11, 46);
      const length = Duration(minutes: 108);
      final id = await rideStoredAsMeasured(
        start: start,
        length: length,
        km: 25.1,
        ahOut: 6.64,
        outWh: 509.8,
        source: EnergySource.partialCoulombCount.name,
      );
      await reading(start, remainingAh: 33.86);
      await reading(start.add(length), remainingAh: 27.22);
      // A bracket far outside, which would give a worse answer if preferred.
      await reading(
        start.add(length + const Duration(minutes: 9)),
        remainingAh: 26.0,
      );

      await repo.repairTrip(id);
      final fixed = await db.tripById(id);
      expect(fixed!.energySource, EnergySource.coulombCount.name);
      expect(fixed.ahOut, closeTo(6.64, 0.01));
    });
  });

  group('a ride marked partial by the recorder', () {
    test('is picked up by the pass that runs on its own', () async {
      // The cheap marker is the whole point: no coverage arithmetic over a
      // week of readings, just a row that says outright it needs mending.
      final start = DateTime.utc(2026, 9, 7, 16, 9, 50);
      const length = Duration(minutes: 53);
      await db.insertTrip(
        TripsCompanion.insert(
          deviceId: const Value(device),
          startedAt: start,
          endedAt: start.add(length),
          distanceKm: 22.08,
          movingSeconds: length.inSeconds,
          totalSeconds: length.inSeconds,
          maxSpeedKmh: 55,
          energyOutWh: 0,
          energyInWh: 0,
          startSoc: 86,
          endSoc: 85,
          minPackVoltage: 70,
          maxPackVoltage: 78,
          maxDischargeCurrent: 20.8,
          maxTemperature: 30,
          maxDeltaVolts: 0.02,
          climbM: 20,
          descentM: 20,
          energySource: Value(EnergySource.partialCoulombCount.name),
        ),
      );
      await reading(
        start.subtract(const Duration(seconds: 1)),
        remainingAh: 34.32,
      );
      await reading(start.add(const Duration(minutes: 1)), remainingAh: 34.20);
      await reading(
        start.add(length + const Duration(minutes: 8)),
        remainingAh: 29.39,
      );

      final report = await repo.repairTripEnergy(device);
      expect(report.examined, 1);
      expect(report.repaired, 1);
    });
  });

  group('what the estimator is allowed to learn from', () {
    test('a ride with no honest energy figure teaches nothing', () async {
      // Belt and braces for the 225 km. Even before any repair runs, a ride
      // whose own row admits it was never measured must not reach the
      // estimator -- and the marker says so without anyone having to guess a
      // plausible Wh/km.
      final start = DateTime.utc(2026, 9, 7, 16, 9, 50);
      for (final source in [
        EnergySource.partialCoulombCount,
        EnergySource.unmeasurable,
        EnergySource.unmeasurableBracketed,
      ]) {
        await rideStoredAsMeasured(
          start: start,
          length: const Duration(minutes: 53),
          km: 22.08,
          ahOut: 0.125,
          outWh: 10.1,
          source: source.name,
        );
      }
      // And one good ride, so the test can tell exclusion from an empty table.
      await rideStoredAsMeasured(
        start: start.add(const Duration(days: 1)),
        length: const Duration(minutes: 108),
        km: 25.1,
        ahOut: 6.64,
        outWh: 509.8,
      );

      final learning = await repo.tripsForLearning(device);
      expect(learning.length, 1);
      expect(learning.single.energySource, EnergySource.coulombCount.name);
    });
  });
}
