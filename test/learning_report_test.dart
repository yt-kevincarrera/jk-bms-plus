import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/metrics/learning_report.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final now = DateTime.utc(2026, 9, 1);
    await db.upsertDevice(
      DevicesCompanion.insert(id: 'AA:BB', firstSeenAt: now, lastSeenAt: now),
    );
  });

  tearDown(() async => db.close());

  /// One stored ride. [outWh] is energy that left the pack.
  Future<void> ride({
    required double km,
    double outWh = 400,
    double inWh = 0,
    bool unfinished = false,
    int dayOffset = 0,
  }) async {
    final start = DateTime.utc(2026, 9, 1).add(Duration(days: dayOffset));
    final id = await db.insertTrip(
      TripsCompanion.insert(
        deviceId: const Value('AA:BB'),
        startedAt: start,
        endedAt: unfinished ? start : start.add(const Duration(minutes: 20)),
        distanceKm: km,
        movingSeconds: 900,
        totalSeconds: 1200,
        maxSpeedKmh: 55,
        energyOutWh: outWh,
        energyInWh: inWh,
        startSoc: 90,
        endSoc: 70,
        minPackVoltage: 70,
        maxPackVoltage: 82,
        maxDischargeCurrent: 40,
        maxTemperature: 30,
        maxDeltaVolts: 0.02,
        climbM: 20,
        descentM: 20,
      ),
    );
    expect(id, greaterThan(0));
  }

  Future<LearningReport> report({double learnedKm = 0}) async =>
      LearningReport.from(
        await db.recentTrips('AA:BB', limit: 500),
        learnedKm: learnedKm,
      );

  group('rides that teach nothing', () {
    test('an implausible consumption is named as a fault, not a habit', () async {
      // What actually happened. Eight rides with real distance and real
      // energy, every sample at 0.7 Wh/km because almost every reading was
      // dropped before it could be integrated. The estimator's own floor of
      // 2 Wh/km refused all of them, correctly and silently, which left
      // "learned: 0 km" as the only visible symptom of a bug three layers
      // down.
      for (var i = 0; i < 8; i++) {
        await ride(km: 5.95, outWh: 4.3, dayOffset: i);
      }
      final r = await report();
      expect(r.implausible, 8);
      expect(r.noEnergyOut, 0);
      expect(r.blocker, LearningBlocker.implausible);
    });

    test('a plausible ride is not called implausible', () async {
      // The same ride once the readings are actually being integrated: 5.95 km
      // on 107 Wh is about 18 Wh/km.
      await ride(km: 5.95, outWh: 107);
      final r = await report(learnedKm: 5.95);
      expect(r.used, 1);
      expect(r.implausible, 0);
    });

    test('an absurdly high figure is refused the same way', () async {
      // The other end of the same guard: a GPS glitch that records 50 m as a
      // full ride produces hundreds of Wh/km.
      await ride(km: 0.3, outWh: 400);
      final r = await report();
      expect(r.implausible, 1);
    });

    test('a pack with no rides is not blocked, it is new', () async {
      final r = await report();
      expect(r.considered, 0);
      expect(r.allRejected, isFalse);
      expect(r.blocker, isNull);
    });

    test('rides that drew no energy point at the current sign', () async {
      // The case worth catching. Eight recorded rides, real distance, and the
      // estimate learned nothing: if the pack reports discharge as positive,
      // no energy is ever counted as leaving, and range learning, consumption,
      // trip energy and the capacity scan all fail together while every live
      // reading still looks right.
      for (var i = 0; i < 8; i++) {
        await ride(km: 1.2, outWh: 0, inWh: 60, dayOffset: i);
      }

      final r = await report();
      expect(r.considered, 8);
      expect(r.used, 0);
      expect(r.noEnergyOut, 8);
      expect(r.blocker, LearningBlocker.noEnergyOut);
    });

    test('rides too short to divide by say so instead', () async {
      for (var i = 0; i < 5; i++) {
        await ride(km: 0.05, dayOffset: i);
      }
      final r = await report();
      expect(r.noDistance, 5);
      expect(r.blocker, LearningBlocker.ridesTooShort);
    });

    test('one usable ride is enough to stop explaining', () async {
      await ride(km: 0.05, dayOffset: 0);
      await ride(km: 8, dayOffset: 1);

      final r = await report(learnedKm: 8);
      expect(r.used, 1);
      expect(r.hasLearned, isTrue);
      expect(r.allRejected, isFalse);
      expect(r.blocker, isNull, reason: 'nothing is being blocked any more');
    });

    test('a ride in progress is not a ride that was rejected', () async {
      // A row exists from the moment recording starts. Counting it as a
      // failure would have the card appear during the first ride, blaming the
      // ride for not having finished.
      await ride(km: 0, unfinished: true);
      final r = await report();
      expect(r.considered, 0);
      expect(r.allRejected, isFalse);
    });

    test('regeneration heavier than draw counts as no energy out', () async {
      // Net, not gross. A descent that put back more than it took is not a
      // consumption sample, whichever way the sign went.
      await ride(km: 5, outWh: 100, inWh: 140);
      final r = await report();
      expect(r.noEnergyOut, 1);
      expect(r.used, 0);
    });

    test('the counts add up to what was considered', () async {
      await ride(km: 0.1, dayOffset: 0);
      await ride(km: 5, outWh: 0, dayOffset: 1);
      await ride(km: 5, dayOffset: 2);

      final r = await report();
      expect(
        r.noDistance + r.noEnergyOut + r.implausible + r.used,
        r.considered,
      );
    });
  });
}
