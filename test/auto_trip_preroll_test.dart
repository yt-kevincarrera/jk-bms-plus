import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:jk_bms/src/ble/simulator/jk_frame_builder.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/gps/location_source.dart';
import 'package:jk_bms/src/metrics/trip_preroll.dart';

import 'fixtures/captured_frames.dart';
import 'fixtures/snapshot_builder.dart';
import 'support/fakes.dart';

class _Gps implements LocationSource {
  final fixesController = StreamController<GeoFix>.broadcast();
  bool running = false;
  @override
  Stream<GeoFix> get fixes => fixesController.stream;
  @override
  Future<LocationProblem?> start() async {
    running = true;
    return null;
  }

  @override
  Future<void> stop() async => running = false;
  void offer(GeoFix fix) {
    if (running) fixesController.add(fix);
  }
}

class _Ride {
  final base = DateTime.utc(2026, 10, 22, 9);
  late DateTime now = base;
  final link = FakeLink();
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  late final repo = BmsRepository(database: db);
  final sources = <_Gps>[];
  late final service = BmsService(
    transport: link,
    clock: () => now,
    locationFactory: () {
      final g = _Gps();
      sources.add(g);
      return g;
    },
  )..repository = repo;

  Future<void> open({double current = -10}) async {
    now = base.subtract(const Duration(seconds: 1));
    await service.connect('AA:BB', name: 'KevinJK');
    await link.deliver(deviceInfoFrames[1]);
    await tick(-1, current: current);
  }

  Future<void> tick(
    int second, {
    double current = -10,
    double? speed,
    Duration fixAge = Duration.zero,
  }) async {
    now = base.add(Duration(seconds: second));
    if (speed != null && sources.isNotEmpty) {
      sources.last.offer(
        GeoFix(
          timestamp: now.subtract(fixAge),
          latitude: 0,
          longitude: second * (30 / 3.6) / 111195,
          speedMs: speed / 3.6,
          altitudeM: 10,
          accuracyM: 8,
        ),
      );
    }
    await pumpEventQueue();
    await link.deliver(
      const JkFrameBuilder().cellInfo(
        counter: (second + 10) & 255,
        cellVoltages: List.filled(16, 3.33),
        cellResistances: List.filled(16, 0.003),
        packVoltage: 53.28,
        current: current,
        temperatures: const [24, 25],
        mosfetTemp: 27,
        soc: 80,
        soh: 100,
        remainingCapacityAh: 40 - (second > 0 ? second * 10 / 3600 : 0),
        nominalCapacityAh: 40,
        cycleCount: 60,
        cycleCapacityAh: 2400,
        balancingAction: 0,
        balanceCurrent: 0,
        chargeMosfetOn: true,
        dischargeMosfetOn: true,
        errorBitmask: 0,
        totalRuntimeSeconds: 3600,
      ),
    );
  }

  Future<void> close() async {
    await service.dispose();
    await repo.dispose();
    await db.close();
    for (final g in sources) {
      await g.fixesController.close();
    }
  }
}

void main() {
  test(
    'confirmation keeps the observed first twenty seconds of track and energy',
    () async {
      final r = _Ride();
      addTearDown(r.close);
      await r.open();
      for (var s = 0; s <= 20; s++) {
        await r.tick(s, speed: 30);
      }
      expect(r.service.trip.isRecording, isTrue);
      expect(r.service.trip.startedAt, r.base);
      expect(r.service.trip.points.first.timestamp, r.base);
      expect(r.service.trip.points.first.packVoltage, closeTo(53.28, 0.01));
      expect(r.service.trip.points.first.current, -10);
      expect(r.service.trip.distanceKm, closeTo(1 / 6, 0.002));
      expect(r.service.trip.energyOutWh, closeTo(53.28 * 10 * 20 / 3600, 0.08));
      final row = await r.db.tripById(r.service.currentTripId!);
      expect(row!.startedAt.toUtc(), r.base);
      await r.service.stopTrip();
      expect((await r.repo.pointsFor(row.id)).first.timestamp.toUtc(), r.base);
    },
  );

  test(
    'a first useful fix at 52 seconds keeps its confirmation but invents no prefix',
    () async {
      final r = _Ride();
      addTearDown(r.close);
      await r.open();
      for (var s = 0; s <= 72; s++) {
        await r.tick(s, speed: s >= 52 ? 30 : null);
      }
      expect(r.service.trip.isRecording, isTrue);
      expect(r.service.trip.startedAt, r.base.add(const Duration(seconds: 52)));
      expect(
        r.service.trip.points.first.timestamp,
        r.base.add(const Duration(seconds: 52)),
      );
      expect(r.service.trip.distanceKm, closeTo(1 / 6, 0.002));
      expect(r.service.trip.distanceKm, lessThan(0.6));
    },
  );

  test(
    'the first useful idle reading primes GPS once and stands it down',
    () async {
      final r = _Ride();
      addTearDown(r.close);
      await r.open(current: 0);
      expect(r.sources, hasLength(1));
      for (var s = 0; s < 70; s++) {
        await r.tick(s, current: 0, speed: 0);
      }
      expect(r.sources, hasLength(1));
      expect(r.sources.single.running, isFalse);
      expect(r.service.trip.isActive, isFalse);
    },
  );

  test('cached fixes cannot confirm movement or become pre-roll', () async {
    final r = _Ride();
    addTearDown(r.close);
    await r.open();
    for (var s = 0; s < 40; s++) {
      await r.tick(s, speed: 30, fixAge: const Duration(minutes: 1));
    }
    expect(r.service.trip.isActive, isFalse);
  });

  test('manual start includes no candidate prehistory', () async {
    final r = _Ride();
    addTearDown(r.close);
    await r.open();
    for (var s = 0; s <= 10; s++) {
      await r.tick(s, speed: 30);
    }
    r.service.autoTripEnabled = false;
    expect(await r.service.startTrip(), isNull);
    expect(r.service.trip.startedAt, r.now);
    expect(r.service.trip.points, isEmpty);
    expect(r.service.trip.distanceKm, 0);
  });

  test(
    'an abandoned candidate is not included when a later ride confirms',
    () async {
      final r = _Ride();
      addTearDown(r.close);
      await r.open();
      for (var s = 0; s <= 10; s++) {
        await r.tick(s, speed: 30);
      }
      for (var s = 11; s <= 30; s++) {
        await r.tick(s, current: 0, speed: 0);
      }
      expect(r.service.trip.isActive, isFalse);
      for (var s = 31; s <= 51; s++) {
        await r.tick(s, speed: 30);
      }
      expect(r.service.trip.startedAt, r.base.add(const Duration(seconds: 31)));
      expect(
        r.service.trip.points.first.timestamp,
        r.base.add(const Duration(seconds: 31)),
      );
      expect(r.service.trip.distanceKm, closeTo(1 / 6, 0.002));
    },
  );

  for (final condition in [(0.0, 30.0), (-10.0, 0.0)]) {
    test(
      'pre-roll still requires both current and movement: $condition',
      () async {
        final r = _Ride();
        addTearDown(r.close);
        await r.open();
        for (var s = 0; s <= 30; s++) {
          await r.tick(s, current: condition.$1, speed: condition.$2);
        }
        expect(r.service.trip.isActive, isFalse);
      },
    );
  }

  test('changing packs discards the earlier candidate', () async {
    final r = _Ride();
    addTearDown(r.close);
    await r.open();
    for (var s = 0; s <= 10; s++) {
      await r.tick(s, speed: 30);
    }
    await r.service.disconnect();
    await r.service.connect('CC:DD', name: 'Other JK');
    await r.link.deliver(deviceInfoFrames[1]);
    await r.tick(11);
    for (var s = 12; s <= 32; s++) {
      await r.tick(s, speed: 30);
    }
    expect(r.service.trip.startedAt, r.base.add(const Duration(seconds: 12)));
    expect(
      r.service.trip.points.first.timestamp,
      r.base.add(const Duration(seconds: 12)),
    );
  });

  test('pre-roll bounds both memory and observed age', () {
    final base = DateTime.utc(2026, 10, 22);
    final buffer = TripPreRoll(
      maxEvents: 3,
      maxAge: const Duration(seconds: 5),
    );
    for (var i = 0; i < 10; i++) {
      buffer.add(
        TripPreRollReading(
          buildSnapshot(timestamp: base.add(Duration(seconds: i))),
        ),
      );
    }
    expect(buffer.length, 3);
    buffer.add(
      TripPreRollReading(
        buildSnapshot(timestamp: base.add(const Duration(seconds: 20))),
      ),
    );
    expect(buffer.length, 1);
    expect(buffer.capture(base, base.add(const Duration(seconds: 20))), isNull);
  });

  test('idle GPS prime expires even if no more BMS frames arrive', () {
    fakeAsync((time) {
      final base = DateTime.utc(2026, 10, 22);
      final link = FakeLink();
      final sources = <_Gps>[];
      final service = BmsService(
        transport: link,
        clock: time.getClock(base).now,
        locationFactory: () {
          final g = _Gps();
          sources.add(g);
          return g;
        },
      );
      unawaited(service.connect('AA:BB', name: 'KevinJK'));
      time.flushMicrotasks();
      // The timer seam needs a remembered pack, but no real SQLite executor
      // inside FakeAsync. The bytes still use the actual assembler/parser.
      service.activeDevice = Device(
        id: 'AA:BB',
        name: 'KevinJK',
        serialNumber: '',
        model: '',
        catalogueFromBms: false,
        chemistry: 'unknown',
        firstSeenAt: base,
        lastSeenAt: base,
        demo: false,
      );
      unawaited(link.deliver(deviceInfoFrames[1]));
      time.elapse(const Duration(milliseconds: 1));
      final idle = Uint8List.fromList(cellInfo24s[0]);
      for (var i = 126; i < 130; i++) {
        idle[i] = 0;
      }
      idle[299] = idle.take(299).fold(0, (sum, value) => (sum + value) & 255);
      unawaited(link.deliver(idle));
      time.elapse(const Duration(milliseconds: 1));
      expect(service.lastSnapshot!.current, 0);
      expect(sources, hasLength(1));
      expect(sources.single.running, isTrue);
      time.elapse(const Duration(seconds: 45));
      expect(sources.single.running, isFalse);
      expect(sources, hasLength(1));
      unawaited(service.dispose());
      time.flushMicrotasks();
    });
  });
}
