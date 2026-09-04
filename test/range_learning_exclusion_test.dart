import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/metrics/trip_recorder.dart';

import 'fixtures/captured_frames.dart';
import 'support/fakes.dart';

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

  group('marking a ride through the service', () {
    test('answering moves the learned figure, and unanswering puts it back',
        () async {
      // The whole promise of the question: an answer has a visible
      // consequence immediately, and it is reversible. Both fall out of the
      // rebuild the service already does on a delete, which is why the
      // marking goes through the service rather than the repository.
      final link = FakeLink();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = BmsRepository(database: db);
      final service = BmsService(
        transport: link,
        locationFactory: StubLocation.new,
      )..repository = repo;
      addTearDown(service.dispose);
      // connect() only opens the link; the pack is promoted to an active
      // device on its first decoded frame (mirroring
      // foreground_service_test.dart's setUp), so there is no shortcut
      // around delivering one before activeDeviceId is usable.
      await service.connect('AA:BB', name: 'KevinJK');
      await link.deliver(deviceInfoFrames[1]);
      await link.deliver(cellInfo24s[0]);
      final device = service.activeDeviceId!;

      await _storeRide(repo, device, km: 40, whPerKm: 17.5);
      final gentleId = await _storeRide(repo, device, km: 40, whPerKm: 10.0);
      await service.relearnRangeFromTrips();

      final withGentle = service.rangeEstimator.whPerKm;
      expect(withGentle, lessThan(17.0));

      await service.setTripRepresentative(gentleId, false);
      expect(service.rangeEstimator.whPerKm, closeTo(17.5, 0.01));

      await service.setTripRepresentative(gentleId, true);
      expect(service.rangeEstimator.whPerKm, closeTo(withGentle, 0.01));
    });
  });
}
