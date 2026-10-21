import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/simulator/jk_frame_builder.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/gps/location_source.dart';

import 'fixtures/captured_frames.dart';
import 'support/fakes.dart';

class _Gps implements LocationSource {
  _Gps(this.clock, {this.startGate, this.failStart = false});

  final DateTime Function() clock;
  final Completer<void>? startGate;
  final bool failStart;
  final controller = StreamController<GeoFix>.broadcast();
  bool running = false;

  @override
  Stream<GeoFix> get fixes => controller.stream;

  @override
  Future<LocationProblem?> start() async {
    running = true;
    await startGate?.future;
    if (failStart) throw StateError('provider refused to open');
    return null;
  }

  @override
  Future<void> stop() async => running = false;

  void offer(double speedKmh) {
    if (!running || controller.isClosed) return;
    controller.add(
      GeoFix(
        timestamp: clock(),
        latitude: 23,
        longitude: -82,
        speedMs: speedKmh / 3.6,
        altitudeM: 10,
        accuracyM: 8,
      ),
    );
  }
}

class _Ride {
  _Ride({
    this.firstStartGate,
    this.secondStartGate,
    this.firstStartError = false,
  }) {
    service = BmsService(
      transport: link,
      clock: () => now,
      locationFactory: () {
        final source = _Gps(
          () => now,
          startGate: sources.isEmpty
              ? firstStartGate
              : sources.length == 1
              ? secondStartGate
              : null,
          failStart: sources.isEmpty && firstStartError,
        );
        sources.add(source);
        openedAt.add(now);
        return source;
      },
    )..repository = repo;
  }

  final Completer<void>? firstStartGate;
  final Completer<void>? secondStartGate;
  final bool firstStartError;
  final base = DateTime.utc(2026, 10, 21, 10);
  late DateTime now = base;
  final link = FakeLink();
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  late final repo = BmsRepository(database: db);
  final sources = <_Gps>[];
  final openedAt = <DateTime>[];
  late final BmsService service;

  Future<void> open({String deviceId = 'AA:BB'}) async {
    await service.connect(deviceId, name: 'KevinJK');
    await link.deliver(deviceInfoFrames[1]);
    await link.deliver(cellInfo24s[0]);
    service.applySettings(haptics: false, rawFrames: false, autoTrip: true);
  }

  Future<void> tick(int second, {double current = -10, double? speed}) async {
    now = base.add(Duration(seconds: second));
    if (speed != null && sources.isNotEmpty) sources.last.offer(speed);
    await pumpEventQueue();
    await link.deliver(
      const JkFrameBuilder().cellInfo(
        counter: second & 0xff,
        cellVoltages: List.filled(16, 3.33),
        cellResistances: List.filled(16, 0.003),
        packVoltage: 53.28,
        current: current,
        temperatures: const [24, 25],
        mosfetTemp: 27,
        soc: 80,
        soh: 100,
        remainingCapacityAh: 32,
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
    for (final source in sources) {
      if (!source.controller.isClosed) await source.controller.close();
    }
  }
}

void main() {
  for (final failure in ['silence', 'error', 'done', 'start-error']) {
    test('auto-start recovers a pre-trip GPS stream after $failure', () async {
      final ride = _Ride(firstStartError: failure == 'start-error');
      addTearDown(ride.close);
      await ride.open();
      await ride.tick(0);
      expect(ride.service.autoTripWaitingForGps, isTrue);
      if (failure == 'error') {
        ride.sources.single.controller.addError(StateError('provider stopped'));
      } else if (failure == 'done') {
        await ride.sources.single.controller.close();
      }
      await pumpEventQueue();

      for (var i = 1; i < 160 && !ride.service.trip.isRecording; i++) {
        await ride.tick(i, speed: ride.sources.length > 1 ? 25 : null);
      }

      expect(ride.sources, hasLength(2));
      expect(ride.sources.first.running, isFalse);
      expect(ride.service.trip.isRecording, isTrue);
      expect(ride.service.autoTripWaitingForGps, isFalse);
    });
  }

  test(
    'a silent GPS is retried with a cooldown instead of every reading',
    () async {
      final ride = _Ride();
      addTearDown(ride.close);
      await ride.open();
      for (var i = 0; i <= 420; i++) {
        await ride.tick(i);
      }
      expect(ride.sources, hasLength(4));
      for (var i = 2; i < ride.openedAt.length; i++) {
        expect(
          ride.openedAt[i].difference(ride.openedAt[i - 1]),
          greaterThanOrEqualTo(const Duration(minutes: 2)),
        );
      }
      expect(ride.service.trip.isRecording, isFalse);
      expect(ride.service.autoTripGpsStalled, isTrue);
    },
  );

  test('an errored GPS is not rebuilt while the pack is idle', () async {
    final ride = _Ride();
    addTearDown(ride.close);
    await ride.open();
    await ride.tick(0);
    ride.sources.single.controller.addError(StateError('provider stopped'));
    await pumpEventQueue();
    for (var i = 1; i < 240; i++) {
      await ride.tick(i, current: 0);
    }
    expect(ride.sources, hasLength(1));
    expect(ride.sources.single.running, isFalse);
    expect(ride.service.trip.isRecording, isFalse);
  });

  test(
    'an error withdraws old moving speed before it can open a trip',
    () async {
      final ride = _Ride();
      addTearDown(ride.close);
      await ride.open();
      for (var i = 0; i <= 19; i++) {
        await ride.tick(i, speed: 25);
      }
      expect(ride.service.trip.isRecording, isFalse);
      ride.sources.single.controller.addError(StateError('provider stopped'));
      await pumpEventQueue();
      for (var i = 20; i < 60; i++) {
        await ride.tick(i);
      }
      expect(ride.sources, hasLength(2));
      expect(ride.service.trip.isRecording, isFalse);
    },
  );

  test('readings during a slow GPS start keep only one source', () async {
    final gate = Completer<void>();
    final ride = _Ride(firstStartGate: gate);
    addTearDown(ride.close);
    await ride.open();
    for (var i = 0; i < 5; i++) {
      await ride.tick(i);
    }
    expect(ride.sources, hasLength(1));
    gate.complete();
    await pumpEventQueue();
    for (var i = 5; i < 30; i++) {
      await ride.tick(i, speed: 25);
    }
    expect(ride.sources, hasLength(1));
    expect(ride.service.trip.isRecording, isTrue);
  });

  test(
    'disconnect cancels a pre-trip GPS request that is still opening',
    () async {
      final gate = Completer<void>();
      final ride = _Ride(firstStartGate: gate);
      addTearDown(ride.close);
      await ride.open();
      await ride.tick(0);
      expect(ride.sources, hasLength(1));
      await ride.service.disconnect();
      gate.complete();
      await pumpEventQueue();
      expect(ride.sources.single.running, isFalse);
      expect(ride.sources.single.controller.hasListener, isFalse);
      expect(ride.service.autoTripWaitingForGps, isFalse);
      expect(ride.service.trip.isRecording, isFalse);
    },
  );

  for (final oldStartThrows in [false, true]) {
    test('another pack opens GPS while a retired start is pending '
        '(old start throws=$oldStartThrows)', () async {
      final oldGate = Completer<void>();
      final newGate = Completer<void>();
      final ride = _Ride(
        firstStartGate: oldGate,
        secondStartGate: newGate,
        firstStartError: oldStartThrows,
      );
      addTearDown(ride.close);
      addTearDown(() async {
        if (!oldGate.isCompleted) oldGate.complete();
        if (!newGate.isCompleted) newGate.complete();
        await pumpEventQueue();
      });
      await ride.open();
      await ride.tick(0);
      expect(ride.sources, hasLength(1));
      await ride.service.disconnect();
      await ride.open(deviceId: 'CC:DD');
      await ride.tick(1);
      expect(
        ride.sources,
        hasLength(2),
        reason: 'the old pending future cannot own the new pack\'s GPS slot',
      );
      final current = ride.sources.last;
      oldGate.complete();
      await pumpEventQueue();
      expect(current.running, isTrue);
      expect(ride.sources.first.running, isFalse);
      expect(ride.service.lastLocationProblem, isNull);
      expect(ride.service.autoTripWaitingForGps, isTrue);
      for (var i = 2; i < 5; i++) {
        await ride.tick(i);
      }
      expect(ride.sources, hasLength(2));
      newGate.complete();
      await pumpEventQueue();
      expect(current.controller.hasListener, isTrue);
      for (var i = 5; i < 30; i++) {
        await ride.tick(i, speed: 25);
      }
      expect(ride.sources, hasLength(2));
      expect(current.running, isTrue);
      expect(ride.service.lastLocationProblem, isNull);
      expect(ride.service.trip.isRecording, isTrue);
    });
  }
}
