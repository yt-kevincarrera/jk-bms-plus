import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/metrics/trip_recorder.dart';

import 'fixtures/captured_frames.dart';
import 'support/fakes.dart';

/// The rider mending a ride themselves, which is what the button does.
///
/// The failure this is for: a 22 km ride whose Bluetooth link died nine
/// minutes in was stored at 4.3 Wh/km, taught the range estimator, and had the
/// app quote 225 km. Nothing in the row hinted at a problem, so no automatic
/// pass would ever look at it again, and there was no way for the rider to say
/// "this one is wrong, measure it again".
void main() {
  late AppDatabase db;
  late BmsRepository repo;
  late BmsService service;
  late String device;

  final start = DateTime.utc(2026, 9, 8, 8, 30, 43);
  const length = Duration(minutes: 47);

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

  Future<void> reading(
    DateTime at, {
    required double remainingAh,
    double soc = 90,
  }) => db.insertSnapshots([
    SnapshotsCompanion.insert(
      deviceId: Value(device),
      timestamp: at,
      packVoltage: 76,
      current: -20,
      soc: soc,
      soh: 100,
      remainingAh: remainingAh,
      cycleCount: 2,
      deltaVolts: 0.003,
      minCellVoltage: 3.79,
      maxCellVoltage: 3.8,
      maxTemperature: 30,
      warningsMask: 0,
      balancerActive: false,
      cellVoltagesJson: '[3.8]',
    ),
  ]);

  /// A believable ride, so the estimator has something honest to stand on.
  Future<int> goodRide(DateTime at) => db.insertTrip(
    TripsCompanion.insert(
      deviceId: Value(device),
      startedAt: at,
      endedAt: at.add(const Duration(minutes: 60)),
      distanceKm: 22,
      movingSeconds: 3000,
      totalSeconds: 3600,
      maxSpeedKmh: 55,
      energyOutWh: 22 * 17.5,
      energyInWh: 0,
      startSoc: 95,
      endSoc: 70,
      minPackVoltage: 70,
      maxPackVoltage: 80,
      maxDischargeCurrent: 30,
      maxTemperature: 30,
      maxDeltaVolts: 0.02,
      climbM: 40,
      descentM: 40,
      ahOut: const Value(6.3),
      energySource: Value(EnergySource.coulombCount.name),
    ),
  );

  /// Trip 21 as it sits on disk: 4.3 Wh/km, and nothing in the row to say so.
  Future<int> theBrokenRide() async {
    final id = await db.insertTrip(
      TripsCompanion.insert(
        deviceId: Value(device),
        startedAt: start,
        endedAt: start.add(length),
        distanceKm: 22.05367867314009,
        movingSeconds: 2600,
        totalSeconds: length.inSeconds,
        maxSpeedKmh: 55,
        energyOutWh: 95.47969315068505,
        energyInWh: 0,
        startSoc: 98,
        endSoc: 95,
        minPackVoltage: 70,
        maxPackVoltage: 80,
        maxDischargeCurrent: 18.4,
        maxTemperature: 30,
        maxDeltaVolts: 0.02,
        climbM: 40,
        descentM: 40,
        ahOut: const Value(1.1700000000000017),
        energySource: Value(EnergySource.coulombCount.name),
      ),
    );
    // The bracket before setting off, the nine minutes the link lasted, and
    // the reading taken on arrival.
    await reading(
      start.subtract(const Duration(seconds: 1)),
      remainingAh: 39.10,
      soc: 98,
    );
    await reading(start.add(const Duration(minutes: 9)), remainingAh: 37.93);
    // Just under a minute after stopping, which is where the real one sits.
    // Far enough out to fall outside the ride's own window, so the brackets
    // are what measures this ride rather than the nine watched minutes.
    await reading(
      start.add(length + const Duration(seconds: 58)),
      remainingAh: 34.23,
      soc: 86,
    );
    return id;
  }

  test('mending the ride puts the range estimate back', () async {
    await goodRide(start.subtract(const Duration(days: 2)));
    final brokenId = await theBrokenRide();
    await service.relearnRangeFromTrips();

    // The state the rider was actually in: a ride at a quarter of the real
    // cost, believed, dragging the learned figure right down.
    final poisoned = service.rangeEstimator.whPerKm;
    expect(poisoned, lessThan(13.0));

    final report = await service.repairTrip(brokenId);
    expect(report.repaired, 1);

    // Measured again from the readings either side, and believed this time
    // because they span the ride.
    final mended = (await db.tripById(brokenId))!;
    expect(mended.ahOut, closeTo(4.87, 0.01));
    expect(mended.energyOutWh / mended.distanceKm, closeTo(16.8, 0.5));
    expect(mended.energySource, EnergySource.bracketedCoulombCount.name);

    // And the estimate is rebuilt, which is why this goes through the service.
    expect(service.rangeEstimator.whPerKm, greaterThan(16.0));
    expect(service.rangeEstimator.whPerKm, lessThan(18.5));
  });

  test('a ride with nothing left to measure is left exactly as it was',
      () async {
    // Readings are thinned to one a minute after thirty days and eventually
    // go. A ride old enough cannot be re-measured, and its row says
    // coulombCount with an amp-hour figure -- which is precisely what the two
    // broken rides said too.
    //
    // So nothing here can tell a ride that was measured correctly from one
    // that was not, and the app must not pretend otherwise in either
    // direction. Demoting it would drop a good ride out of the range estimate
    // on no evidence; inventing a figure would be worse. It stays as it is,
    // and the button says as much.
    final id = await db.insertTrip(
      TripsCompanion.insert(
        deviceId: Value(device),
        startedAt: start,
        endedAt: start.add(length),
        distanceKm: 22.05,
        movingSeconds: 2600,
        totalSeconds: length.inSeconds,
        maxSpeedKmh: 55,
        energyOutWh: 95.48,
        energyInWh: 0,
        startSoc: 98,
        endSoc: 95,
        minPackVoltage: 70,
        maxPackVoltage: 80,
        maxDischargeCurrent: 18.4,
        maxTemperature: 30,
        maxDeltaVolts: 0.02,
        climbM: 40,
        descentM: 40,
        ahOut: const Value(1.17),
        energySource: Value(EnergySource.coulombCount.name),
      ),
    );

    final report = await service.repairTrip(id);
    expect(report.repaired, 0);
    expect(report.unrepairable, 1);

    // Untouched, all of it. Pressing the button on a ride nothing can be said
    // about must not change the ride.
    final tried = (await db.tripById(id))!;
    expect(tried.energySource, EnergySource.coulombCount.name);
    expect(tried.ahOut, closeTo(1.17, 0.001));
    expect(tried.energyOutWh, closeTo(95.48, 0.01));
    expect(await repo.tripsForLearning(device), isNotEmpty);
  });

  test('a healthy old ride with no readings left keeps its measurement',
      () async {
    // The trap in offering the button on every ride. Readings are thinned to
    // one a minute after thirty days, and a ride old enough to have lost even
    // those cannot be re-measured -- but it was measured correctly at the
    // time, and pressing the button must not throw that away.
    //
    // Marking it unmeasurable would, now that learning skips rides whose
    // marker says they were never measured: a perfectly good 17.5 Wh/km ride
    // would silently drop out of the range estimate because the rider was
    // curious.
    final at = start.subtract(const Duration(days: 90));
    final id = await goodRide(at);
    await service.relearnRangeFromTrips();
    final before = service.rangeEstimator.whPerKm;

    final report = await service.repairTrip(id);
    expect(report.repaired, 0);

    final after = (await db.tripById(id))!;
    expect(after.energySource, EnergySource.coulombCount.name);
    expect(after.ahOut, closeTo(6.3, 0.01));
    expect(after.energyOutWh / after.distanceKm, closeTo(17.5, 0.01));

    // And it still teaches the estimator, exactly as before the button was
    // pressed.
    expect(await repo.tripsForLearning(device), isNotEmpty);
    expect(service.rangeEstimator.whPerKm, closeTo(before, 0.01));
  });

  test('a ride that never had an honest figure is still demoted', () async {
    // The other side of it, and why the demotion exists at all: a ride the
    // recorder itself flagged as measured across only part of its length has
    // nothing worth keeping, so when the readings cannot mend it the marker
    // has to settle terminally and the ride has to stop counting.
    final id = await db.insertTrip(
      TripsCompanion.insert(
        deviceId: Value(device),
        startedAt: start,
        endedAt: start.add(length),
        distanceKm: 22.05,
        movingSeconds: 2600,
        totalSeconds: length.inSeconds,
        maxSpeedKmh: 55,
        energyOutWh: 95.48,
        energyInWh: 0,
        startSoc: 98,
        endSoc: 95,
        minPackVoltage: 70,
        maxPackVoltage: 80,
        maxDischargeCurrent: 18.4,
        maxTemperature: 30,
        maxDeltaVolts: 0.02,
        climbM: 40,
        descentM: 40,
        energySource: Value(EnergySource.partialCoulombCount.name),
      ),
    );

    final report = await service.repairTrip(id);
    expect(report.repaired, 0);

    final after = (await db.tripById(id))!;
    expect(after.energySource, EnergySource.unmeasurableBracketed.name);
    expect(await repo.tripsForLearning(device), isEmpty);
  });

  test('a ride already measured properly is left alone', () async {
    // Pressing the button on a healthy ride must not make it worse. The
    // readings from inside a watched ride are the better measurement.
    final at = start.subtract(const Duration(days: 2));
    final id = await goodRide(at);
    // 5.07 Ah at 76 V over 22 km is 17.5 Wh/km, the same figure the row
    // already carries, so a correct re-measurement changes nothing.
    await reading(at, remainingAh: 33.86);
    await reading(at.add(const Duration(minutes: 60)), remainingAh: 28.79);

    await service.repairTrip(id);

    final after = (await db.tripById(id))!;
    expect(after.energySource, EnergySource.coulombCount.name);
    expect(after.energyOutWh / after.distanceKm, closeTo(17.5, 0.3));
  });
}
