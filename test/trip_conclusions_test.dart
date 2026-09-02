import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/metrics/range_estimator.dart';
import 'package:jk_bms/src/metrics/trip_recorder.dart';

TripSummary summary({double distanceKm = 20, double outWh = 800}) =>
    TripSummary(
      startedAt: DateTime.utc(2026, 9, 1, 8),
      movingDuration: const Duration(minutes: 40),
      totalDuration: const Duration(minutes: 45),
      distanceKm: distanceKm,
      maxSpeedKmh: 62,
      energyOutWh: outWh,
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
    );

void main() {
  group('what the app concluded, kept', () {
    test('a ride with no learned figure before says so', () {
      // Null, not zero. The estimator always has something to quote, including
      // its own starting default, so its value cannot tell "nothing learned
      // yet" apart from "learned it is zero".
      const c = TripConclusions(
        whPerKmBefore: null,
        whPerKmAfter: 40,
        learnedKm: 20,
        rangeKmAtEnd: 45,
        confidence: RangeConfidence.low,
      );
      expect(c.hadLearnedBefore, isFalse);
      expect(c.moved, isFalse);
      expect(c.thirstPercentFor(60), isNull);
    });

    test('a ride that moved the estimate', () {
      const c = TripConclusions(
        whPerKmBefore: 41,
        whPerKmAfter: 39,
        learnedKm: 220,
        rangeKmAtEnd: 60,
        confidence: RangeConfidence.medium,
      );
      expect(c.hadLearnedBefore, isTrue);
      expect(c.moved, isTrue);
    });

    test('a change smaller than rounding is not a change', () {
      const c = TripConclusions(
        whPerKmBefore: 40.0,
        whPerKmAfter: 40.3,
        learnedKm: 220,
        rangeKmAtEnd: 60,
        confidence: RangeConfidence.medium,
      );
      expect(c.moved, isFalse);
    });

    test('a thirsty ride is reported against what was learned then', () {
      const c = TripConclusions(
        whPerKmBefore: 40,
        whPerKmAfter: 42,
        learnedKm: 220,
        rangeKmAtEnd: 55,
        confidence: RangeConfidence.medium,
      );
      // 50 against a learned 40 is 25% thirstier.
      expect(c.thirstPercentFor(50), closeTo(25, 0.001));
      // Within noise, so not worth saying.
      expect(c.thirstPercentFor(43), isNull);
    });
  });

  group('restoring from a stored row', () {
    test('comes back whole', () {
      final c = TripConclusions.restore(
        whPerKmBefore: 41,
        whPerKmAfter: 39,
        learnedKm: 220,
        rangeKmAtEnd: 61,
        confidence: 'high',
      );
      expect(c!.whPerKmBefore, 41);
      expect(c.confidence, RangeConfidence.high);
      expect(c.rangeKmAtEnd, 61);
    });

    test('a ride from before this was kept has no conclusions', () {
      // Null rather than a filled-in default. "0 Wh/km, low confidence" is a
      // measurement nobody took, sitting where a real one goes.
      expect(TripConclusions.restore(), isNull);
      expect(
        TripConclusions.restore(whPerKmAfter: 40),
        isNull,
        reason: 'confidence is part of the record, not optional',
      );
    });

    test('a first ride restores as a first ride', () {
      final c = TripConclusions.restore(
        whPerKmAfter: 40,
        learnedKm: 12,
        rangeKmAtEnd: 30,
        confidence: 'low',
      );
      expect(c!.hadLearnedBefore, isFalse);
    });

    test('an unrecognised confidence does not lose the row', () {
      // A backup written by a newer build. Losing the label is survivable.
      final c = TripConclusions.restore(
        whPerKmAfter: 40,
        confidence: 'somethingNewer',
      );
      expect(c, isNotNull);
    });
  });

  group('stored with the ride', () {
    late AppDatabase db;
    late BmsRepository repo;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = BmsRepository(database: db);
      final now = DateTime.utc(2026, 9, 1);
      await db.upsertDevice(
        DevicesCompanion.insert(id: 'AA:BB', firstSeenAt: now, lastSeenAt: now),
      );
      repo.activeDeviceId = 'AA:BB';
    });

    tearDown(() async => db.close());

    test('a finished ride carries them', () async {
      final id = await repo.beginTrip(DateTime.utc(2026, 9, 1, 8));
      await repo.finishTrip(
        id,
        summary(),
        const [],
        conclusions: const TripConclusions(
          whPerKmBefore: 41,
          whPerKmAfter: 39.4,
          learnedKm: 220,
          rangeKmAtEnd: 61,
          confidence: RangeConfidence.high,
        ),
      );

      final stored = (await repo.tripsForLearning('AA:BB')).single;
      expect(stored.whPerKmBefore, 41);
      expect(stored.whPerKmAfter, closeTo(39.4, 0.001));
      expect(stored.confidence, 'high');

      final back = TripConclusions.restore(
        whPerKmBefore: stored.whPerKmBefore,
        whPerKmAfter: stored.whPerKmAfter,
        learnedKm: stored.learnedKm,
        rangeKmAtEnd: stored.rangeKmAtEnd,
        confidence: stored.confidence,
      );
      expect(back!.moved, isTrue);
    });

    test('a ride finished without them stores nulls, not zeroes', () async {
      final id = await repo.beginTrip(DateTime.utc(2026, 9, 1, 8));
      await repo.finishTrip(id, summary(), const []);

      final stored = (await repo.tripsForLearning('AA:BB')).single;
      expect(stored.whPerKmAfter, isNull);
      expect(stored.confidence, isNull);
    });

    test('they can be corrected once the range at the end is known', () async {
      // Which is why they are written twice: the range needs an estimator that
      // has already learned from this ride, and that does not exist when the
      // row is first completed.
      final id = await repo.beginTrip(DateTime.utc(2026, 9, 1, 8));
      await repo.finishTrip(
        id,
        summary(),
        const [],
        conclusions: const TripConclusions(
          whPerKmBefore: 41,
          whPerKmAfter: 39,
          learnedKm: 220,
          rangeKmAtEnd: 0,
          confidence: RangeConfidence.high,
        ),
      );
      await repo.recordTripConclusions(
        id,
        const TripConclusions(
          whPerKmBefore: 41,
          whPerKmAfter: 39,
          learnedKm: 220,
          rangeKmAtEnd: 61,
          confidence: RangeConfidence.high,
        ),
      );

      final stored = (await repo.tripsForLearning('AA:BB')).single;
      expect(stored.rangeKmAtEnd, 61);
      // And nothing else was disturbed by the second write.
      expect(stored.distanceKm, 20);
    });
  });
}
