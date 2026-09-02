import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/metrics/range_estimator.dart';

void main() {
  late AppDatabase db;
  late BmsRepository repo;

  final t0 = DateTime.utc(2026, 9, 2, 8, 49, 58);
  const rideLength = Duration(minutes: 21, seconds: 55);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = BmsRepository(database: db);
    final now = DateTime.utc(2026, 9, 1);
    for (final id in ['AA:BB', 'CC:DD']) {
      await db.upsertDevice(
        DevicesCompanion.insert(id: id, firstSeenAt: now, lastSeenAt: now),
      );
    }
  });

  tearDown(() async => db.close());

  Future<void> reading(String device, DateTime at, double remainingAh) =>
      db.insertSnapshots([
        SnapshotsCompanion.insert(
          deviceId: Value(device),
          timestamp: at,
          packVoltage: 75,
          current: -20,
          soc: 62,
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

  /// A ride as a build before the fix stored it, plus the readings that can
  /// still measure it.
  Future<void> staleRide(String device) async {
    await db.insertTrip(
      TripsCompanion.insert(
        deviceId: Value(device),
        startedAt: t0,
        endedAt: t0.add(rideLength),
        distanceKm: 5.95,
        movingSeconds: 685,
        totalSeconds: rideLength.inSeconds,
        maxSpeedKmh: 55,
        energyOutWh: 4.29,
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
    await reading(device, t0, 25.61);
    await reading(device, t0.add(rideLength), 24.19);
  }

  /// What the saved-pack screen does: build an estimator from stored rides,
  /// with no radio involved.
  Future<RangeEstimator> estimatorFor(String device) async {
    final trips = await db.recentTrips(device, limit: 500);
    final e = RangeEstimator();
    for (final t in trips.where(
      (t) => t.distanceKm >= 0.2 && t.energyOutWh > t.energyInWh,
    )) {
      e.addSegment(wh: t.energyOutWh - t.energyInWh, km: t.distanceKm);
    }
    return e;
  }

  group('the repair has to reach a pack nobody connected to', () {
    test('an unmended ride teaches nothing, which is the symptom', () async {
      // The estimator refuses 0.72 Wh/km as impossible, correctly. So the
      // saved-pack screen said "nothing learned yet" against a ride the app
      // already knew how to measure.
      await staleRide('AA:BB');
      expect((await estimatorFor('AA:BB')).hasLearned, isFalse);
    });

    test('mending every pack does not need any of them connected', () async {
      // The mistake: the repair ran inside the connect path. Reading a pack's
      // history with no radio is the entire point of the saved-pack screen, so
      // a repair that only happens on connect never reaches it.
      await staleRide('AA:BB');
      await staleRide('CC:DD');

      final report = await repo.repairAllTripEnergy();
      expect(report.repaired, 2);

      for (final id in ['AA:BB', 'CC:DD']) {
        final e = await estimatorFor(id);
        expect(e.hasLearned, isTrue, reason: '$id should have learned');
        expect(e.whPerKm, closeTo(17.9, 0.3));
      }
    });

    test('running it again finds nothing to do', () async {
      await staleRide('AA:BB');
      expect((await repo.repairAllTripEnergy()).repaired, 1);
      expect((await repo.repairAllTripEnergy()).examined, 0);
    });

    test('a pack with no rides at all is not a problem', () async {
      final report = await repo.repairAllTripEnergy();
      expect(report.examined, 0);
      expect(report.didAnything, isFalse);
    });
  });
}
