import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/metrics/trip_energy_repair.dart';
import 'package:jk_bms/src/metrics/trip_recorder.dart';

/// A span, standing in for a ride, so the grouping can be judged without
/// building database rows.
class Span {
  Span(this.from, this.to);
  final DateTime from;
  final DateTime to;
}

void main() {
  final t0 = DateTime.utc(2026, 9, 2, 8, 0);

  // Why this exists. The rider's own pack sat on "waiting for the first
  // reading" while a battery that arrived that morning connected and showed
  // its data at once. The difference between them was stored history: the
  // first decoded frame of every connection paid for a trip repair over every
  // reading between the oldest unmended ride and now, unbounded, before any
  // reading was allowed to reach a screen. And a ride that could not be
  // measured was never marked, so it stayed unmended forever and every
  // connection read the whole span it forced, again.

  group('grouping rides into one reading query each', () {
    List<List<Span>> group(List<Span> spans, Duration maxSpan) => groupBySpan(
      spans,
      startOf: (s) => s.from,
      endOf: (s) => s.to,
      maxSpan: maxSpan,
    );

    test('an evening of riding stays in one query', () {
      // The case the original single-window design was right for.
      final spans = [
        Span(t0, t0.add(const Duration(minutes: 20))),
        Span(t0.add(const Duration(hours: 1)), t0.add(const Duration(hours: 1, minutes: 15))),
        Span(t0.add(const Duration(hours: 3)), t0.add(const Duration(hours: 3, minutes: 40))),
      ];
      expect(group(spans, const Duration(hours: 8)), hasLength(1));
    });

    test('rides weeks apart do not', () {
      // The case it was ruinous for: one query over every reading in between.
      final spans = [
        Span(t0, t0.add(const Duration(minutes: 20))),
        Span(t0.add(const Duration(days: 21)), t0.add(const Duration(days: 21, minutes: 20))),
      ];
      final groups = group(spans, const Duration(hours: 8));
      expect(groups, hasLength(2));
      expect(groups.first.single.from, t0);
    });

    test('a run splits exactly where the span runs out', () {
      final spans = [
        Span(t0, t0.add(const Duration(minutes: 10))),
        Span(t0.add(const Duration(hours: 7)), t0.add(const Duration(hours: 7, minutes: 30))),
        Span(t0.add(const Duration(hours: 9)), t0.add(const Duration(hours: 9, minutes: 10))),
      ];
      final groups = group(spans, const Duration(hours: 8));
      expect(groups.map((g) => g.length), [2, 1]);
    });

    test('order of arrival does not matter', () {
      final late = Span(t0.add(const Duration(days: 5)), t0.add(const Duration(days: 5, minutes: 5)));
      final early = Span(t0, t0.add(const Duration(minutes: 5)));
      final groups = group([late, early], const Duration(hours: 8));
      expect(groups, hasLength(2));
      expect(groups.first.single.from, t0, reason: 'sorted before grouping');
    });

    test('one ride, and none at all', () {
      expect(group([Span(t0, t0)], const Duration(hours: 8)), hasLength(1));
      expect(group(const [], const Duration(hours: 8)), isEmpty);
    });
  });

  group('a ride that cannot be measured', () {
    late AppDatabase db;
    late BmsRepository repo;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = BmsRepository(database: db);
      final now = DateTime.utc(2026, 9, 1);
      await db.upsertDevice(
        DevicesCompanion.insert(id: 'AA:BB', firstSeenAt: now, lastSeenAt: now),
      );
    });

    tearDown(() async => db.close());

    Future<int> staleTrip({DateTime? at}) => db.insertTrip(
      TripsCompanion.insert(
        deviceId: const Value('AA:BB'),
        startedAt: at ?? t0,
        endedAt: (at ?? t0).add(const Duration(minutes: 20)),
        distanceKm: 5.95,
        movingSeconds: 685,
        totalSeconds: 1200,
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

    test('is examined once, not on every connection', () async {
      // The leak. Nothing was written for a ride the repair gave up on, so it
      // looked stale forever: every connection examined it again and re-read
      // every reading in the window it forced.
      await staleTrip();

      expect((await repo.repairTripEnergy('AA:BB')).unrepairable, 1);
      expect((await repo.repairTripEnergy('AA:BB')).examined, 0);
      expect((await repo.repairTripEnergy('AA:BB')).examined, 0);
    });

    test('keeps its wrong figure rather than getting a made-up one', () async {
      await staleTrip();
      await repo.repairTripEnergy('AA:BB');

      final trip = (await repo.tripsForLearning('AA:BB')).single;
      expect(trip.energyOutWh, closeTo(4.29, 0.001));
      expect(trip.ahOut, isNull);
      // Marked, and marked distinguishably, so a future repair that knows a
      // new trick can come looking for exactly these.
      expect(trip.energySource, EnergySource.unmeasurable.name);
    });

    test('an old one no longer drags every later reading into the query',
        () async {
      // Two rides three weeks apart, both unmeasurable. They used to be read
      // as one window covering the three weeks between them.
      await staleTrip();
      await staleTrip(at: t0.add(const Duration(days: 21)));

      final report = await repo.repairTripEnergy('AA:BB');
      expect(report.examined, 2);
      expect(report.unrepairable, 2);
      expect((await repo.repairTripEnergy('AA:BB')).examined, 0);
    });
  });
}
