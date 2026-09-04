import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/metrics/trip_recorder.dart';

/// Opens a trip, closes it with a plausible summary, and returns its id.
///
/// Distance and energy are the fields `tripsForLearning` filters on, so
/// callers pick them; everything else just needs to be a legal ride.
Future<int> _storeRide(
  BmsRepository repo,
  String device, {
  required double km,
  required double whPerKm,
}) async {
  repo.activeDeviceId = device;
  final id = await repo.beginTrip(DateTime.utc(2026, 9, 1, 8));
  await repo.finishTrip(
    id,
    TripSummary(
      startedAt: DateTime.utc(2026, 9, 1, 8),
      movingDuration: const Duration(minutes: 40),
      totalDuration: const Duration(minutes: 45),
      distanceKm: km,
      maxSpeedKmh: 60,
      energyOutWh: km * whPerKm,
      energyInWh: 0,
      startSoc: 95,
      endSoc: 55,
      minPackVoltage: 70,
      maxPackVoltage: 82,
      maxDischargeCurrent: 48,
      maxTemperature: 32,
      maxDeltaVolts: 0.02,
      climbM: 120,
      descentM: 110,
    ),
    const [],
  );
  return id;
}

void main() {
  group('a ride the rider called an exception', () {
    test('is not one of the rides the estimate is built from', () async {
      // Deleting the ride was the only way to say this before, and deleting
      // throws away the track and the pack readings with it. A ride can be
      // unrepresentative and still be worth keeping.
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = BmsRepository(database: db);
      const device = 'pack-1';

      await _storeRide(repo, device, km: 20, whPerKm: 17.5);
      final exceptionId =
          await _storeRide(repo, device, km: 40, whPerKm: 10.0);

      expect((await repo.tripsForLearning(device)).length, 2);

      await repo.setTripRepresentative(exceptionId, false);
      final kept = await repo.tripsForLearning(device);

      expect(kept.length, 1);
      expect(kept.single.distanceKm, 20);
    });

    test('comes back the moment the rider changes their mind', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = BmsRepository(database: db);
      const device = 'pack-1';
      final id = await _storeRide(repo, device, km: 40, whPerKm: 10.0);

      await repo.setTripRepresentative(id, false);
      expect(await repo.tripsForLearning(device), isEmpty);

      await repo.setTripRepresentative(id, true);
      expect((await repo.tripsForLearning(device)).length, 1);
    });
  });
}
