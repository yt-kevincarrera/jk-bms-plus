import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/metrics/trip_recorder.dart';

/// Opens a trip, closes it with a plausible summary, and returns its id.
///
/// Mirrors the helper in test/range_learning_exclusion_test.dart: distance
/// and Wh/km are picked by the caller, everything else just needs to be a
/// legal finished ride so `pendingSummaryTrip` has something real to find.
Future<int> _storeRide(
  BmsRepository repo,
  String device, {
  required double km,
  required double whPerKm,
  bool demo = false,
  DateTime? startedAt,
}) async {
  final started = startedAt ?? DateTime.utc(2026, 9, 1, 8);
  repo.activeDeviceId = device;
  final id = await repo.beginTrip(started, demo: demo);
  await repo.finishTrip(
    id,
    TripSummary(
      startedAt: started,
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
  group('a ride whose summary nobody saw', () {
    test('is offered the next time the app opens', () async {
      // The pocket case, which is the normal case. The summary used to be
      // built by the stop button and by nothing else, so a ride that closed
      // itself was stored complete and shown to nobody.
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = BmsRepository(database: db);
      final id = await _storeRide(repo, 'pack-1', km: 20, whPerKm: 17.5);

      final pending = await repo.pendingSummaryTrip('pack-1');
      expect(pending?.id, id);
    });

    test('is not offered twice', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = BmsRepository(database: db);
      final id = await _storeRide(repo, 'pack-1', km: 20, whPerKm: 17.5);

      await repo.markTripSummarySeen(id);
      expect(await repo.pendingSummaryTrip('pack-1'), isNull);
    });

    test('a demo ride is never offered', () async {
      // A made-up ride announcing itself would be the app talking about
      // nothing, which is the one thing it is built not to do.
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = BmsRepository(database: db);
      await _storeRide(repo, 'pack-1', km: 20, whPerKm: 17.5, demo: true);
      expect(await repo.pendingSummaryTrip('pack-1'), isNull);
    });

    test('only the latest unseen ride is offered', () async {
      // A week of unseen rides queuing up on opening the app would be a
      // punishment for having gone riding.
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = BmsRepository(database: db);
      await _storeRide(
        repo,
        'pack-1',
        km: 10,
        whPerKm: 17.5,
        startedAt: DateTime.utc(2026, 9, 1, 8),
      );
      final latest = await _storeRide(
        repo,
        'pack-1',
        km: 30,
        whPerKm: 17.5,
        startedAt: DateTime.utc(2026, 9, 2, 8),
      );

      expect((await repo.pendingSummaryTrip('pack-1'))?.id, latest);
    });
  });
}
