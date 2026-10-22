import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/platform/hands_free_platform.dart';
import 'package:jk_bms/src/platform/live_notification.dart';

import 'support/fakes.dart';

const _plugin = MethodChannel('flutter_foreground_task/methods');

class _Native extends HandsFreePlatform {
  _Native(this.events)
    : super(
        isAndroid: true,
        channel: const MethodChannel('test.jk_bms/notification_owner'),
      );
  final List<String> events;
  bool enabled = true;
  bool running = false;
  bool failStart = false;
  final power = <bool>[];
  @override
  HandsFreeStatus get status => HandsFreeStatus(
    supported: true,
    enabled: enabled,
    associated: true,
    deviceId: 'AA:BB',
    reason: enabled ? 'ready' : 'disabled',
  );
  @override
  Future<bool> notificationStart({
    required String title,
    required String text,
    required bool usesLocation,
  }) async {
    events.add('native.start');
    if (failStart) {
      lastFailure = 'native_start_failed';
      return false;
    }
    running = true;
    return true;
  }

  @override
  Future<void> notificationStop() async {
    events.add('native.stop');
    running = false;
  }

  @override
  Future<void> notificationUpdate({
    required String title,
    required String text,
  }) async => events.add('native.update');
  @override
  Future<bool> notificationRunning() async => running;
  @override
  Future<void> notificationPower({required bool active}) async {
    power.add(active);
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final events = <String>[];
  late _Native native;
  late LiveNotification notifications;
  var legacyRunning = false;
  var failLegacyStart = false;
  Completer<void>? legacyStartGate;

  setUp(() {
    events.clear();
    legacyRunning = false;
    failLegacyStart = false;
    legacyStartGate = null;
    FlutterForegroundTask.resetStatic();
    FlutterForegroundTask.skipServiceResponseCheck = true;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_plugin, (
      call,
    ) async {
      switch (call.method) {
        case 'isRunningService':
          return legacyRunning;
        case 'checkNotificationPermission':
          return NotificationPermission.granted.index;
        case 'startService':
          events.add('legacy.start');
          await legacyStartGate?.future;
          if (failLegacyStart) {
            throw PlatformException(code: 'start_not_allowed');
          }
          legacyRunning = true;
          return null;
        case 'stopService':
          events.add('legacy.stop');
          legacyRunning = false;
          return null;
        case 'updateService':
          events.add('legacy.update');
          return null;
        default:
          throw MissingPluginException(call.method);
      }
    });
    native = _Native(events);
    notifications = LiveNotification(handsFree: native, isAndroid: true);
    notifications.ensureInitialised(
      channelName: 'Ride',
      channelDescription: 'Recording a ride',
    );
  });

  tearDown(() {
    native.dispose();
    FlutterForegroundTask.resetStatic();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_plugin, null);
  });

  Future<bool> start() => notifications.start(title: 'Ride', text: 'Recording');

  test(
    'native owner stays alive until the legacy successor has started',
    () async {
      expect(await start(), isTrue);
      native.enabled = false;
      legacyStartGate = Completer<void>();
      final handingOff = start();
      await pumpEventQueue();
      expect(events, ['native.start', 'legacy.start']);
      expect(native.running, isTrue);
      expect(legacyRunning, isFalse);
      legacyStartGate!.complete();
      expect(await handingOff, isTrue);
      expect(events, ['native.start', 'legacy.start', 'native.stop']);
      expect(native.running, isFalse);
      expect(legacyRunning, isTrue);
    },
  );

  test(
    'a rejected legacy start retains the native ride notification',
    () async {
      expect(await start(), isTrue);
      native.enabled = false;
      failLegacyStart = true;
      expect(await start(), isFalse);
      expect(native.running, isTrue);
      expect(notifications.isRunning, isTrue);
      expect(notifications.lastFailure, contains('start_not_allowed'));
      expect(events, ['native.start', 'legacy.start']);
      await notifications.update(title: 'Ride', text: 'Still recording');
      expect(events.last, 'native.update');
    },
  );

  test(
    'legacy owner releases its service after native accepts the slot',
    () async {
      native.enabled = false;
      expect(await start(), isTrue);
      expect(legacyRunning, isTrue);
      native.enabled = true;
      expect(await start(), isTrue);
      expect(events, ['legacy.start', 'native.start', 'legacy.stop']);
      expect(legacyRunning, isFalse);
      expect(native.running, isTrue);
    },
  );

  test('a rejected native handoff restores the legacy ride service', () async {
    native.enabled = false;
    expect(await start(), isTrue);
    native.enabled = true;
    native.failStart = true;
    expect(await start(), isFalse);
    expect(native.running, isFalse);
    expect(legacyRunning, isTrue);
    expect(notifications.isRunning, isTrue);
  });

  test(
    'native wake ownership follows actual GPS work rather than its type',
    () async {
      expect(await start(), isTrue);
      expect(native.power.last, isFalse);
      notifications.locationActive = true;
      await pumpEventQueue();
      expect(native.power.last, isTrue);
      notifications.locationActive = false;
      await pumpEventQueue();
      expect(native.power.last, isFalse);
    },
  );

  test(
    'backend mismatch bypasses the cached running check in either direction',
    () async {
      expect(await start(), isTrue);
      expect(await notifications.stillRunning(), isTrue);
      native.enabled = false;
      expect(await notifications.stillRunning(), isFalse);
      expect(native.running, isTrue);
      expect(await start(), isTrue);
      expect(await notifications.stillRunning(), isTrue);
      native.enabled = true;
      expect(await notifications.stillRunning(), isFalse);
    },
  );

  test(
    'native service loss is observed from Android rather than a local flag',
    () async {
      expect(await start(), isTrue);
      native.running = false;
      expect(await notifications.stillRunning(), isFalse);
      expect(notifications.isRunning, isFalse);
    },
  );

  test(
    'runtime refresh hands the existing connection to the current backend',
    () async {
      final link = FakeLink();
      final service = BmsService(
        transport: link,
        notificationService: notifications,
      );
      addTearDown(service.dispose);
      await service.connect('AA:BB', name: 'KevinJK');
      final now = DateTime.now().toUtc();
      service.activeDevice = Device(
        id: 'AA:BB',
        name: 'KevinJK',
        serialNumber: '',
        model: '',
        catalogueFromBms: false,
        chemistry: 'unknown',
        firstSeenAt: now,
        lastSeenAt: now,
        demo: false,
      );
      link.announce(BleLinkState.connected);
      await pumpEventQueue();
      expect(service.isWatchingLink, isTrue);
      expect(native.running, isTrue);
      native.enabled = false;
      await service.refreshForegroundRuntime();
      expect(service.isWatchingLink, isTrue);
      expect(legacyRunning, isTrue);
      expect(native.running, isFalse);
      expect(
        events.indexOf('legacy.start'),
        lessThan(events.indexOf('native.stop')),
      );
      expect(service.lastLinkState, BleLinkState.connected);
    },
  );
}
