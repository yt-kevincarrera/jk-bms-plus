import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/backup.dart';
import 'package:jk_bms/src/data/database.dart';

void main() {
  late AppDatabase source;
  late Directory tmp;

  setUp(() async {
    source = AppDatabase.forTesting(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('jkbms-backup');
  });

  tearDown(() async {
    await source.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<void> seed(AppDatabase db) async {
    final now = DateTime.utc(2026, 8, 1);
    await db.upsertDevice(
      DevicesCompanion.insert(
        id: 'AA:BB',
        name: const Value('Moto'),
        catalogueCapacityAh: const Value(45),
        chemistry: const Value('lfp'),
        acquiredAt: Value(DateTime.utc(2024, 3, 2)),
        firstSeenAt: now,
        lastSeenAt: now,
      ),
    );
    await db.saveBaseline(
      BaselinesCompanion.insert(
        deviceId: 'AA:BB',
        capturedAt: DateTime.utc(2026, 8, 1),
        json:
            '{"at":"2026-08-01T00:00:00.000Z","cells":[3.31,3.32],'
            '"packV":6.63,"current":0.1}',
        note: const Value('comprada a un vecino'),
      ),
    );
    final tripId = await db.insertTrip(
      TripsCompanion.insert(
        deviceId: const Value('AA:BB'),
        startedAt: now,
        endedAt: now.add(const Duration(minutes: 30)),
        distanceKm: 14.2,
        movingSeconds: 1500,
        totalSeconds: 1800,
        maxSpeedKmh: 61,
        energyOutWh: 355,
        energyInWh: 8,
        startSoc: 100,
        endSoc: 66,
        minPackVoltage: 70.4,
        maxPackVoltage: 83.1,
        maxDischargeCurrent: 38,
        maxTemperature: 33,
        maxDeltaVolts: 0.019,
        climbM: 60,
        descentM: 55,
        note: const Value('primera vuelta'),
      ),
    );
    await db.insertTripPoints([
      TripPointsCompanion.insert(
        tripId: tripId,
        timestamp: now,
        latitude: 23.11,
        longitude: -82.36,
        speedKmh: 32,
        altitudeM: 24,
        packVoltage: 78.4,
        current: -19.2,
        soc: 88,
      ),
    ]);
    await db.insertSnapshots([
      SnapshotsCompanion.insert(
        deviceId: const Value('AA:BB'),
        timestamp: now,
        tripId: Value(tripId),
        packVoltage: 78.4,
        current: -19.2,
        soc: 88,
        soh: 97,
        remainingAh: 39.6,
        cycleCount: 61,
        cycleCapacityAh: const Value(2843.5),
        deltaVolts: 0.012,
        minCellVoltage: 3.905,
        maxCellVoltage: 3.917,
        maxTemperature: 29,
        warningsMask: 0,
        balancerActive: false,
        cellVoltagesJson: '[3.91,3.90]',
      ),
    ]);
    await db.insertCapacityTest(
      CapacityTestsCompanion.insert(
        deviceId: const Value('AA:BB'),
        startedAt: now,
        endedAt: Value(now.add(const Duration(hours: 2))),
        startSoc: 100,
        endSoc: 3,
        startPackVoltage: 84,
        endPackVoltage: 60.1,
        measuredAh: 39.8,
        measuredWh: 2860,
        catalogueAh: const Value(45),
        completed: const Value(true),
      ),
    );
    await db.insertMaintenance(
      MaintenanceEventsCompanion.insert(
        deviceId: 'AA:BB',
        at: now,
        kind: 'cellReplaced',
        note: const Value('celda 7'),
      ),
    );
    await db.insertRawFrames([
      RawFramesCompanion.insert(
        deviceId: const Value('AA:BB'),
        timestamp: now,
        recordType: 2,
        bytes: Uint8List.fromList([0x55, 0xAA, 0xEB, 0x90, 0x02, 0xFF]),
      ),
    ]);
  }

  Future<AppDatabase> restoreInto(File file, {bool replace = false}) async {
    final target = AppDatabase.forTesting(NativeDatabase.memory());
    await BackupCodec(target).import(file, replace: replace);
    return target;
  }

  group('a backup that can actually come back', () {
    test('every table survives a round trip', () async {
      await seed(source);
      final file = await BackupCodec(source).export(into: tmp);

      final target = await restoreInto(file);
      addTearDown(target.close);

      expect(await target.allDevices(), hasLength(1));
      expect(await target.recentTrips('AA:BB'), hasLength(1));
      expect(await target.allCapacityTestsForBackup(), hasLength(1));
      expect(await target.allSnapshotsForBackup(), hasLength(1));
      expect(await target.allRawFramesForBackup(), hasLength(1));
    });

    test('the values come back intact, not just the row counts', () async {
      await seed(source);
      final target = await restoreInto(
        await BackupCodec(source).export(into: tmp),
      );
      addTearDown(target.close);

      final trip = (await target.recentTrips('AA:BB')).single;
      expect(trip.distanceKm, 14.2);
      expect(trip.energyOutWh, 355);
      expect(trip.note, 'primera vuelta');

      final device = (await target.device('AA:BB'))!;
      expect(device.name, 'Moto');
      expect(device.catalogueCapacityAh, 45);
    });

    test('the profile and the day one come back with the pack', () async {
      await seed(source);
      final file = await BackupCodec(source).export(into: tmp);
      final restored = await restoreInto(file);
      addTearDown(restored.close);

      final device = (await restored.allDevices()).single;
      // Neither of these can be read off the wire, so losing them in a
      // backup would lose them for good.
      expect(device.chemistry, 'lfp');
      expect(device.acquiredAt?.toUtc(), DateTime.utc(2024, 3, 2));

      final baseline = await restored.baselineRow('AA:BB');
      expect(baseline, isNotNull);
      expect(baseline!.note, 'comprada a un vecino');
      expect(baseline.json, contains('3.31'));
    });

    test('a track still points at its own ride after renumbering', () async {
      // Row ids are local to a database, so they are reassigned on import.
      // Getting this wrong would leave every track attached to nothing, or
      // worse, to somebody elses ride.
      await seed(source);
      final target = await restoreInto(
        await BackupCodec(source).export(into: tmp),
      );
      addTearDown(target.close);

      final trip = (await target.recentTrips('AA:BB')).single;
      final points = await target.pointsFor(trip.id);
      expect(points, hasLength(1));
      expect(points.single.latitude, 23.11);
    });

    test('raw frames survive byte for byte', () async {
      // These exist so a wrongly-decoded offset can be reparsed later. A
      // backup that mangled them would quietly destroy the one thing that
      // makes a decoding mistake survivable.
      await seed(source);
      final target = await restoreInto(
        await BackupCodec(source).export(into: tmp),
      );
      addTearDown(target.close);

      final frame = (await target.allRawFramesForBackup()).single;
      expect(frame.bytes, [0x55, 0xAA, 0xEB, 0x90, 0x02, 0xFF]);
    });

    test('they can be left out for a smaller file', () async {
      await seed(source);
      final file = await BackupCodec(
        source,
      ).export(includeRawFrames: false, into: tmp);

      final target = await restoreInto(file);
      addTearDown(target.close);
      expect(await target.allRawFramesForBackup(), isEmpty);
      // And everything else is still there.
      expect(await target.recentTrips('AA:BB'), hasLength(1));
    });
  });

  group('importing onto a phone that has kept riding', () {
    test('merges by default rather than replacing', () async {
      await seed(source);
      final file = await BackupCodec(source).export(into: tmp);

      final target = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(target.close);
      await seed(target);

      await BackupCodec(target).import(file);
      // Two rides now: the one already there and the one restored. Restoring
      // an old backup must not throw away newer riding.
      expect(await target.recentTrips('AA:BB'), hasLength(2));
    });

    test('replace wipes first, for a new phone', () async {
      await seed(source);
      final file = await BackupCodec(source).export(into: tmp);

      final target = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(target.close);
      await seed(target);

      await BackupCodec(target).import(file, replace: true);
      expect(await target.recentTrips('AA:BB'), hasLength(1));
    });
  });

  group('refusing what it cannot read', () {
    test('a file that is not JSON', () async {
      final f = File('${tmp.path}/junk.json')..writeAsStringSync('nope');
      expect(
        () => BackupCodec(source).import(f),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('JSON with no format version', () async {
      final f = File('${tmp.path}/x.json')..writeAsStringSync('{"trips":[]}');
      expect(
        () => BackupCodec(source).import(f),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('a file from a newer app, rather than half-importing it', () async {
      // Half of a backup looks like a complete database and is not.
      final f = File('${tmp.path}/future.json')
        ..writeAsStringSync(jsonEncode({'format': 99, 'trips': <Object>[]}));
      expect(
        () => BackupCodec(source).import(f),
        throwsA(isA<BackupFormatException>()),
      );
    });
  });

  group('the maintenance log', () {
    test('comes back with everything else', () async {
      // It is the one part of the history the app cannot reconstruct from
      // anything: nothing in the BMS records what the rider did to the pack.
      await seed(source);
      final target = await restoreInto(
        await BackupCodec(source).export(into: tmp),
      );
      addTearDown(target.close);

      final events = await target.maintenanceFor('AA:BB');
      expect(events, hasLength(1));
      expect(events.single.kind, 'cellReplaced');
      expect(events.single.note, 'celda 7');
    });
  });

  group("the rider's answer about a ride", () {
    // representative is nullable on purpose: null means nobody was asked,
    // false means the rider called the ride an exception and it must stay
    // out of the learned range. A backup that lost this would silently let
    // an excluded ride back into the training set after a restore, which is
    // exactly the wrongness the whole feature exists to prevent.
    Future<int> insertTrip({
      required String note,
      required Value<bool?> representative,
      required Value<bool> summarySeen,
    }) {
      final now = DateTime.utc(2026, 8, 1);
      return source.insertTrip(
        TripsCompanion.insert(
          startedAt: now,
          endedAt: now.add(const Duration(minutes: 10)),
          distanceKm: 3,
          movingSeconds: 200,
          totalSeconds: 250,
          maxSpeedKmh: 30,
          energyOutWh: 50,
          energyInWh: 0,
          startSoc: 90,
          endSoc: 80,
          minPackVoltage: 70,
          maxPackVoltage: 80,
          maxDischargeCurrent: 10,
          maxTemperature: 25,
          maxDeltaVolts: 0.01,
          climbM: 5,
          descentM: 5,
          note: Value(note),
          representative: representative,
          summarySeen: summarySeen,
        ),
      );
    }

    test('marked as an exception, true, or left unanswered all survive a round trip', () async {
      await insertTrip(
        note: 'exception',
        representative: const Value(false),
        summarySeen: const Value(true),
      );
      await insertTrip(
        note: 'normal',
        representative: const Value(true),
        summarySeen: const Value(false),
      );
      await insertTrip(
        note: 'unanswered',
        representative: const Value(null),
        summarySeen: const Value(true),
      );

      final target = await restoreInto(await BackupCodec(source).export(into: tmp));
      addTearDown(target.close);

      final trips = await target.allTripsForBackup();
      final exception = trips.firstWhere((t) => t.note == 'exception');
      final normal = trips.firstWhere((t) => t.note == 'normal');
      final unanswered = trips.firstWhere((t) => t.note == 'unanswered');

      expect(exception.representative, isFalse);
      expect(exception.summarySeen, isTrue);
      expect(normal.representative, isTrue);
      expect(normal.summarySeen, isFalse);
      expect(unanswered.representative, isNull);
      expect(unanswered.summarySeen, isTrue);
    });

    test('a backup written before this existed leaves a restored ride unanswered and unseen', () async {
      // Older backups have neither key at all. A missing key must not become
      // false for representative, false there means "the rider called this
      // an exception", which nobody said about a ride from before the
      // question existed.
      final now = DateTime.utc(2026, 8, 1);
      final file = File('${tmp.path}/old.json')
        ..writeAsStringSync(
          jsonEncode({
            'format': 1,
            'trips': [
              {
                'startedAt': now.toIso8601String(),
                'endedAt': now
                    .add(const Duration(minutes: 10))
                    .toIso8601String(),
              },
            ],
          }),
        );

      final target = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(target.close);
      await BackupCodec(target).import(file);

      final trip = (await target.allTripsForBackup()).single;
      expect(trip.representative, isNull);
      expect(trip.summarySeen, isFalse);
    });
  });
}
