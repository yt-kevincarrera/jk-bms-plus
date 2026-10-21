import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/platform/live_notification.dart';

import 'fixtures/captured_frames.dart';
import 'support/fakes.dart';

class _DelayedNotification extends LiveNotification {
  bool running = false;
  int starts = 0;
  int stops = 0;
  int operations = 0;
  int maxOperations = 0;
  int updates = 0;
  final types = <bool>[];
  Completer<void>? startGate;
  Completer<void>? stopGate;
  Completer<void>? updateGate;

  void _enter() {
    operations++;
    if (operations > maxOperations) maxOperations = operations;
  }

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> stillRunning() async => running;

  @override
  Future<void> update({required String title, required String text}) async {
    _enter();
    updates++;
    try {
      await updateGate?.future;
    } finally {
      operations--;
    }
  }

  @override
  Future<bool> start({
    required String title,
    required String text,
    bool usesRealLocation = true,
  }) async {
    _enter();
    starts++;
    types.add(usesRealLocation);
    try {
      await startGate?.future;
      running = true;
      return true;
    } finally {
      operations--;
    }
  }

  @override
  Future<void> stop() async {
    _enter();
    stops++;
    try {
      await stopGate?.future;
      running = false;
    } finally {
      operations--;
    }
  }

  void release() {
    final starting = startGate;
    if (starting != null && !starting.isCompleted) starting.complete();
    final stopping = stopGate;
    if (stopping != null && !stopping.isCompleted) stopping.complete();
    final updating = updateGate;
    if (updating != null && !updating.isCompleted) updating.complete();
  }
}

void main() {
  late FakeLink link;
  late AppDatabase db;
  late BmsRepository repo;
  late _DelayedNotification notification;
  late BmsService service;
  late bool disposed;

  setUp(() async {
    link = FakeLink();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = BmsRepository(database: db);
    notification = _DelayedNotification();
    disposed = false;
    service = BmsService(
      transport: link,
      notificationService: notification,
      locationFactory: StubLocation.new,
    )..repository = repo;
    service.applySettings(haptics: false, rawFrames: false, autoTrip: false);
    await service.connect('AA:BB', name: 'KevinJK');
    await link.deliver(deviceInfoFrames[1]);
    await link.deliver(cellInfo24s[0]);
    link.announce(BleLinkState.connected);
    await pumpEventQueue();
    expect(notification.types, [false]);
  });

  tearDown(() async {
    notification.release();
    await pumpEventQueue();
    if (!disposed) await service.dispose();
    await repo.dispose();
    await db.close();
  });

  test(
    'snapshots and toggles share one stop and one start in flight',
    () async {
      notification.stopGate = Completer<void>();
      service.autoTripEnabled = true;
      await pumpEventQueue();
      expect(notification.stops, 1);
      for (var i = 0; i < 3; i++) {
        service.autoTripEnabled = false;
        service.autoTripEnabled = true;
        await link.deliver(cellInfo24s[0]);
      }
      expect(notification.starts, 1);
      expect(notification.maxOperations, 1);
      notification.stopGate!.complete();
      await pumpEventQueue();
      expect(notification.types, [false, true]);
      expect(notification.stops, 1);
      expect(service.serviceUsesLocationForTest, isTrue);

      notification.startGate = Completer<void>();
      service.autoTripEnabled = false;
      await pumpEventQueue();
      expect(notification.starts, 3);
      for (var i = 0; i < 3; i++) {
        service.autoTripEnabled = true;
        service.autoTripEnabled = false;
        await link.deliver(cellInfo24s[0]);
      }
      expect(notification.starts, 3);
      expect(notification.maxOperations, 1);
      notification.startGate!.complete();
      await pumpEventQueue();
      expect(notification.types, [false, true, false]);
      expect(notification.stops, 2);
      expect(notification.running, isTrue);
      expect(service.isWatchingLink, isTrue);
      expect(service.serviceUsesLocationForTest, isFalse);
    },
  );

  test('a stopped service restarts with the latest setting', () async {
    notification.stopGate = Completer<void>();
    service.autoTripEnabled = true;
    await pumpEventQueue();
    service.autoTripEnabled = false;
    await link.deliver(cellInfo24s[0]);
    notification.stopGate!.complete();
    await pumpEventQueue();
    expect(notification.starts, 2);
    expect(notification.stops, 1);
    expect(notification.types, [false, false]);
    expect(notification.maxOperations, 1);
    expect(service.serviceUsesLocationForTest, isFalse);
    expect(service.isWatchingLink, isTrue);
  });

  test(
    'pending text refreshes coalesce once the service configuration is right',
    () async {
      notification.updateGate = Completer<void>();
      final before = notification.updates;
      await link.deliver(cellInfo24s[0]);
      expect(notification.updates, before + 1);
      for (var i = 0; i < 10; i++) {
        await link.deliver(cellInfo24s[0]);
      }
      notification.updateGate!.complete();
      await pumpEventQueue();
      expect(
        notification.updates,
        before + 1,
        reason: 'queued text updates must not keep the drain future open',
      );
      await link.deliver(cellInfo24s[0]);
      expect(notification.updates, before + 2);
      expect(notification.maxOperations, 1);
    },
  );

  test(
    'disposing during start waits for it and stops the resulting service',
    () async {
      notification.startGate = Completer<void>();
      service.autoTripEnabled = true;
      await pumpEventQueue();
      expect(notification.starts, 2);
      final closing = service.dispose();
      await pumpEventQueue();
      expect(
        notification.stops,
        1,
        reason: 'stop must not race the pending platform start',
      );
      notification.startGate!.complete();
      await closing;
      disposed = true;
      expect(notification.running, isFalse);
      expect(notification.stops, 2);
      expect(notification.maxOperations, 1);
      expect(service.isWatchingLink, isFalse);
      expect(service.serviceUsesLocationForTest, isFalse);
    },
  );
}
