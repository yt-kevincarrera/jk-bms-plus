import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';

/// Builds a ride on one pack.
TripsCompanion ride(String? deviceId, DateTime at, {double km = 10}) =>
    TripsCompanion.insert(
      deviceId: Value(deviceId),
      startedAt: at,
      endedAt: at.add(const Duration(minutes: 20)),
      distanceKm: km,
      movingSeconds: 1200,
      totalSeconds: 1300,
      maxSpeedKmh: 55,
      energyOutWh: km * 25,
      energyInWh: 0,
      startSoc: 100,
      endSoc: 70,
      minPackVoltage: 70,
      maxPackVoltage: 82,
      maxDischargeCurrent: 30,
      maxTemperature: 30,
      maxDeltaVolts: 0.02,
      climbM: 10,
      descentM: 10,
    );

CapacityTestsCompanion measurement(String? deviceId, DateTime at, double ah) =>
    CapacityTestsCompanion.insert(
      deviceId: Value(deviceId),
      startedAt: at,
      startSoc: 100,
      endSoc: 3,
      startPackVoltage: 84,
      endPackVoltage: 60,
      measuredAh: ah,
      measuredWh: ah * 72,
      catalogueAh: const Value(45),
      completed: const Value(true),
    );

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  Future<void> addPack(String id, {String name = '', bool demo = false}) async {
    final now = DateTime.utc(2026, 1, 1);
    await db.upsertDevice(
      DevicesCompanion.insert(
        id: id,
        name: Value(name),
        firstSeenAt: now,
        lastSeenAt: now,
        demo: Value(demo),
      ),
    );
  }

  group('history is kept per pack', () {
    test("one pack's rides never appear under another", () async {
      await addPack('AA:BB', name: 'Moto');
      await addPack('CC:DD', name: 'Repuesto');

      await db.insertTrip(ride('AA:BB', DateTime.utc(2026, 3, 1)));
      await db.insertTrip(ride('AA:BB', DateTime.utc(2026, 3, 2)));
      await db.insertTrip(ride('CC:DD', DateTime.utc(2026, 3, 3)));

      expect(await db.recentTrips('AA:BB'), hasLength(2));
      expect(await db.recentTrips('CC:DD'), hasLength(1));
    });

    test('capacity measurements do not cross packs', () async {
      // The failure this prevents: a 45 Ah pack and a 30 Ah pack producing one
      // history whose average describes neither battery.
      await addPack('AA:BB');
      await addPack('CC:DD');
      await db.insertCapacityTest(
        measurement('AA:BB', DateTime.utc(2026, 3, 1), 41),
      );
      await db.insertCapacityTest(
        measurement('CC:DD', DateTime.utc(2026, 3, 2), 27),
      );

      final first = await db.allCapacityTests('AA:BB');
      final second = await db.allCapacityTests('CC:DD');
      expect(first.single.measuredAh, 41);
      expect(second.single.measuredAh, 27);
    });

    test('a new pack has no catalogue capacity at all', () async {
      // The bug this pins: every pack used to be born holding 45 Ah, so
      // connecting to a 35 Ah bike produced health measured against a figure
      // the app made up, indistinguishable on screen from one the rider had
      // entered. Unknown has to stay unknown until somebody says otherwise.
      await addPack('AA:BB');
      expect((await db.device('AA:BB'))!.catalogueCapacityAh, isNull);
    });

    test('each pack carries its own catalogue capacity', () async {
      await addPack('AA:BB');
      await addPack('CC:DD');
      await db.updateDevice(
        'AA:BB',
        const DevicesCompanion(catalogueCapacityAh: Value(45)),
      );
      await db.updateDevice(
        'CC:DD',
        const DevicesCompanion(catalogueCapacityAh: Value(35)),
      );

      expect((await db.device('AA:BB'))!.catalogueCapacityAh, 45);
      expect((await db.device('CC:DD'))!.catalogueCapacityAh, 35);
    });

    test('a measurement can be recorded with no claim to compare it to', () {
      // The amp-hours that came out are a fact; the percentage is an opinion
      // about a claim. Refusing to record the fact for want of the opinion
      // would throw away the only honest number in the app.
      expect(
        () => measurement('AA:BB', DateTime.utc(2026, 3), 41),
        returnsNormally,
      );
    });

    test('the demo pack is a pack like any other', () async {
      await addPack('demo', demo: true);
      await addPack('AA:BB');
      await db.insertTrip(ride('demo', DateTime.utc(2026, 3, 1)));

      expect(await db.recentTrips('demo'), hasLength(1));
      expect(await db.recentTrips('AA:BB'), isEmpty);
    });
  });

  group('deleting a pack', () {
    test('takes everything recorded on it, and nothing else', () async {
      await addPack('AA:BB');
      await addPack('CC:DD');
      final tripId = await db.insertTrip(ride('AA:BB', DateTime.utc(2026, 3)));
      await db.insertTripPoints([
        TripPointsCompanion.insert(
          tripId: tripId,
          timestamp: DateTime.utc(2026, 3),
          latitude: 23.1,
          longitude: -82.3,
          speedKmh: 30,
          altitudeM: 20,
          packVoltage: 78,
          current: -20,
          soc: 80,
        ),
      ]);
      await db.insertCapacityTest(
        measurement('AA:BB', DateTime.utc(2026, 3), 41),
      );
      await db.insertTrip(ride('CC:DD', DateTime.utc(2026, 3, 5)));

      await db.deleteDevice('AA:BB');

      expect(await db.recentTrips('AA:BB'), isEmpty);
      expect(await db.allCapacityTests('AA:BB'), isEmpty);
      expect(await db.device('AA:BB'), isNull);
      // The other pack is untouched.
      expect(await db.recentTrips('CC:DD'), hasLength(1));
      expect(await db.device('CC:DD'), isNotNull);
      // And the track went with its ride rather than being left dangling.
      expect(await db.pointsFor(tripId), isEmpty);
    });
  });

  group('rows written before packs were tracked', () {
    test('are counted rather than silently included anywhere', () async {
      await addPack('AA:BB');
      await db.insertTrip(ride(null, DateTime.utc(2026, 2, 1)));
      await db.insertTrip(ride('AA:BB', DateTime.utc(2026, 3, 1)));
      await db.insertCapacityTest(measurement(null, DateTime.utc(2026, 2), 40));

      // The point: an unattached row must not turn up in any pack's history,
      // because counting it would mean attributing it to a battery by accident.
      expect(await db.recentTrips('AA:BB'), hasLength(1));

      final counts = await db.orphanCounts();
      expect(counts['trips'], 1);
      expect(counts['capacityTests'], 1);
    });

    test('can be adopted, once, by a pack the rider names', () async {
      await addPack('AA:BB');
      await db.insertTrip(ride(null, DateTime.utc(2026, 2, 1)));
      await db.insertCapacityTest(measurement(null, DateTime.utc(2026, 2), 40));

      await db.adoptOrphans('AA:BB');

      expect(await db.recentTrips('AA:BB'), hasLength(1));
      expect(await db.allCapacityTests('AA:BB'), hasLength(1));
      final counts = await db.orphanCounts();
      expect(counts.values.every((c) => c == 0), isTrue);
    });

    test('adopting does not sweep up another pack\'s rows', () async {
      await addPack('AA:BB');
      await addPack('CC:DD');
      await db.insertTrip(ride('CC:DD', DateTime.utc(2026, 3, 1)));
      await db.insertTrip(ride(null, DateTime.utc(2026, 2, 1)));

      await db.adoptOrphans('AA:BB');

      expect(await db.recentTrips('AA:BB'), hasLength(1));
      expect(await db.recentTrips('CC:DD'), hasLength(1));
    });

    test('can be thrown away instead', () async {
      await addPack('AA:BB');
      await db.insertTrip(ride(null, DateTime.utc(2026, 2, 1)));
      await db.insertTrip(ride('AA:BB', DateTime.utc(2026, 3, 1)));

      await db.discardOrphans();

      expect(await db.totalTripCount(), 1);
      expect((await db.orphanCounts()).values.every((c) => c == 0), isTrue);
    });
  });
}
