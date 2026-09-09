import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/metrics/trip_recorder.dart';
import 'package:jk_bms/src/ui/widgets/representative_question.dart';

import 'fixtures/captured_frames.dart';
import 'support/fakes.dart';

/// Answering the representative question, and unanswering it.
///
/// The trap this file exists for. A rider marked a ride an exception, so it
/// stopped counting. Then they pressed the change button in the ride's detail,
/// which wrote *null* -- "never asked" -- and null counts:
/// `tripsForLearning` only takes a ride out on an explicit no. So the ride
/// silently rejoined the estimate and the app went back to quoting 225 km.
///
/// Worse, there was often no way back. The question only reappears when the
/// ride moved the learned figure by more than five percent, and most rides move
/// it by nothing at all: three of the rider's own stored rides have a
/// before and after of 17.1/17.1, 17.5/17.5 and 19.6/19.6. For those, pressing
/// change threw the answer away and closed the door behind it.
void main() {
  group('the choice on offer', () {
    test('is offered for any ride there is a consumption to judge', () {
      // The fix for the dead end. Whether to *ask* is a question about how
      // much this ride moved the estimate; whether the rider may *set* the
      // flag is not, and tying the two together is what made the state
      // unreachable.
      expect(shouldOfferChoice(rideWhPerKm: 17.5), isTrue);
      expect(shouldOfferChoice(rideWhPerKm: 4.3), isTrue);
    });

    test('is not offered for a ride with no consumption to judge', () {
      // A ride too short to divide, or one whose energy could never be
      // measured. There is nothing to include or exclude.
      expect(shouldOfferChoice(rideWhPerKm: null), isFalse);
    });

    test('is offered where the question itself would stay quiet', () {
      // The exact shape of the rides that could not be recovered: a real
      // consumption, and a shift of zero.
      final shift = shiftFraction(before: 19.6, after: 19.6);
      expect(shouldAskAbout(shiftFraction: shift, answered: null), isFalse);
      expect(shouldOfferChoice(rideWhPerKm: 18.7), isTrue);
    });
  });

  group('changing the answer', () {
    late AppDatabase db;
    late BmsRepository repo;
    late BmsService service;
    late String device;
    late int rideId;

    setUp(() async {
      final link = FakeLink();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = BmsRepository(database: db);
      service = BmsService(transport: link, locationFactory: StubLocation.new)
        ..repository = repo;
      await service.connect('AA:BB', name: 'KevinJK');
      await link.deliver(deviceInfoFrames[1]);
      await link.deliver(cellInfo24s[0]);
      device = service.activeDeviceId!;

      await _ride(repo, device, km: 22, whPerKm: 17.5);
      // The odd one out, the one a rider would want excluded.
      rideId = await _ride(repo, device, km: 22, whPerKm: 4.3);
      await service.relearnRangeFromTrips();
    });

    tearDown(() async {
      service.dispose();
      // The repository owns a five second flush timer. Left running it fires
      // after the database below is closed, and the write lands as an
      // unhandled async error blamed on whichever test happens to be running
      // by then, in a file that has nothing to do with it.
      await repo.dispose();
      await db.close();
    });

    test('never leaves the ride unanswered', () async {
      // The bug, straight out. Changing an answer must land on the other
      // answer, because the third state counts towards the estimate and
      // cannot always be got out of.
      await service.setTripRepresentative(rideId, false);
      expect((await db.tripById(rideId))!.representative, isFalse);

      await service.setTripRepresentative(rideId, otherChoice(false));
      expect((await db.tripById(rideId))!.representative, isTrue);

      await service.setTripRepresentative(rideId, otherChoice(true));
      expect((await db.tripById(rideId))!.representative, isFalse);
    });

    test('moves the estimate back and forth, as many times as asked',
        () async {
      // Reversibility is the promise. It was not kept.
      await service.setTripRepresentative(rideId, false);
      final withoutIt = service.rangeEstimator.whPerKm;
      expect(withoutIt, closeTo(17.5, 0.1));

      await service.setTripRepresentative(rideId, true);
      final withIt = service.rangeEstimator.whPerKm;
      expect(withIt, lessThan(13.0));

      await service.setTripRepresentative(rideId, false);
      expect(service.rangeEstimator.whPerKm, closeTo(withoutIt, 0.01));

      await service.setTripRepresentative(rideId, true);
      expect(service.rangeEstimator.whPerKm, closeTo(withIt, 0.01));
    });

    test('a ride nobody answered still counts, as it always did', () async {
      // Not a regression: null has to keep meaning "counts", because every
      // ride recorded before the question existed is null. What changed is
      // that the interface can no longer put a ride back into that state.
      expect((await db.tripById(rideId))!.representative, isNull);
      expect((await repo.tripsForLearning(device)).length, 2);
    });
  });
}

Future<int> _ride(
  BmsRepository repo,
  String device, {
  required double km,
  required double whPerKm,
}) async {
  repo.activeDeviceId = device;
  final at = DateTime.utc(2026, 9, 8, 8, 30);
  final id = await repo.beginTrip(at);
  await repo.finishTrip(
    id,
    TripSummary(
      startedAt: at,
      movingDuration: const Duration(minutes: 40),
      totalDuration: const Duration(minutes: 47),
      distanceKm: km,
      maxSpeedKmh: 55,
      energyOutWh: km * whPerKm,
      energyInWh: 0,
      startSoc: 98,
      endSoc: 70,
      minPackVoltage: 70,
      maxPackVoltage: 80,
      maxDischargeCurrent: 20,
      maxTemperature: 30,
      maxDeltaVolts: 0.02,
      climbM: 40,
      descentM: 40,
      ahOut: km * whPerKm / 76,
      energySource: EnergySource.coulombCount,
    ),
    const [],
  );
  return id;
}
