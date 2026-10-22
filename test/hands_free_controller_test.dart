import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/bms_link.dart';
import 'package:jk_bms/src/ble/hands_free_controller.dart';
import 'package:jk_bms/src/ble/proximity_connection.dart';
import 'package:jk_bms/src/ble/proximity_watcher.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/gps/location_source.dart';
import 'package:jk_bms/src/platform/hands_free_platform.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/real_kevinjk_frames.dart';
import 'support/fakes.dart';

const _bikeId = 'AA:00:00:00:88:01';
final _epoch = DateTime.utc(2026, 10, 22, 12);

HandsFreeStatus _status({
  bool enabled = false,
  bool associated = false,
  bool present = false,
  String reason = 'disabled',
}) => HandsFreeStatus(
  supported: true,
  enabled: enabled,
  associated: associated,
  present: present,
  deviceId: associated ? _bikeId : null,
  deviceName: associated ? 'KevinJK' : null,
  reason: reason,
);

class _Native extends HandsFreePlatform {
  _Native(this.value)
    : super(
        isAndroid: true,
        channel: const MethodChannel('test.jk_bms/hands_free_controller'),
      );
  HandsFreeStatus value;
  HandsFreeStatus? prerequisites;
  HandsFreeStatus? enableResult;
  Completer<HandsFreeStatus>? prerequisitesGate;
  final calls = <String>[];
  @override
  HandsFreeStatus get status => value;
  void publish(HandsFreeStatus next) {
    value = next;
    notifyListeners();
  }

  @override
  Future<HandsFreeStatus> refresh() async {
    calls.add('refresh');
    return value;
  }

  @override
  Future<HandsFreeStatus> requestPrerequisites({
    required bool usesLocation,
  }) async {
    expect(usesLocation, isTrue);
    calls.add('prerequisites');
    final result = await prerequisitesGate?.future ?? prerequisites ?? value;
    publish(result);
    return result;
  }

  @override
  Future<HandsFreeStatus> enable({
    required String deviceId,
    required String deviceName,
    required bool usesLocation,
  }) async {
    expect(deviceId, _bikeId);
    expect(deviceName, 'KevinJK');
    expect(usesLocation, isTrue);
    calls.add('enable');
    publish(enableResult ?? _status(enabled: true, associated: true));
    return value;
  }

  @override
  Future<HandsFreeStatus> disable() async {
    calls.add('disable');
    publish(_status(associated: value.associated));
    return value;
  }

  @override
  Future<HandsFreeStatus> forget() async {
    calls.add('forget');
    publish(_status());
    return value;
  }
}

class _Scan implements ProximityScanSource {
  int starts = 0;
  @override
  Future<ProximityScanSession> start({
    required Duration duration,
    required bool Function() stillWanted,
    required void Function(ProximityAdvertisement) onAdvertisement,
  }) async {
    starts++;
    return _ScanSession();
  }
}

class _ScanSession implements ProximityScanSession {
  @override
  bool get didStart => false;
  @override
  Future<void> cancel() async {}
}

class _Link extends FakeLink {
  final connects = <String>[];
  int disconnects = 0;
  @override
  Future<void> connect(String deviceId) async {
    connects.add(deviceId);
    announce(BleLinkState.connecting);
  }

  @override
  Future<void> disconnect() async {
    disconnects++;
    announce(BleLinkState.idle);
  }
}

class _Gps extends StubLocation {
  bool running = false;
  @override
  Future<LocationProblem?> start() async {
    running = true;
    return null;
  }

  @override
  Future<void> stop() async => running = false;
}

class _Fixture {
  _Fixture(this.time, {HandsFreeStatus? native, bool oldEnabled = false}) {
    SharedPreferences.setMockInitialValues({
      'proximity_enabled': oldEnabled,
      'proximity_device_id': _bikeId,
      'proximity_device_name': 'KevinJK',
    });
    platform = _Native(native ?? _status());
    service = BmsService(
      transport: link,
      clock: now,
      locationFactory: () => gps,
    );
    watcher = ProximityWatcher(
      clock: now,
      radioBusy: () => service.radioBusy,
      scanSource: scan,
    );
    connection = ProximityConnection(
      watcher: watcher,
      service: service,
      clock: now,
    );
    controller = HandsFreeController(
      platform: platform,
      watcher: watcher,
      connection: connection,
      service: service,
    );
    unawaited(controller.initialize());
    time.flushMicrotasks();
    expect(controller.ready, isTrue);
  }

  final FakeAsync time;
  final link = _Link();
  final scan = _Scan();
  final gps = _Gps();
  late final _Native platform;
  late final BmsService service;
  late final ProximityWatcher watcher;
  late final ProximityConnection connection;
  late final HandsFreeController controller;
  DateTime now() => _epoch.add(time.elapsed);

  void publish(HandsFreeStatus value) {
    platform.publish(value);
    time.flushMicrotasks();
  }

  void readManually() {
    unawaited(service.connect(_bikeId, name: 'KevinJK'));
    time.flushMicrotasks();
    service.activeDevice = Device(
      id: _bikeId,
      name: 'KevinJK',
      serialNumber: '',
      model: '',
      catalogueFromBms: false,
      chemistry: 'unknown',
      firstSeenAt: now(),
      lastSeenAt: now(),
      demo: false,
    );
    link.announce(BleLinkState.connected);
    time.flushMicrotasks();
    unawaited(link.deliver(kevinJkCellInfo.first));
    time.elapse(const Duration(milliseconds: 1));
    expect(service.hasCurrentReadings, isTrue);
  }

  void dispose() {
    controller.dispose();
    unawaited(connection.dispose());
    unawaited(watcher.dispose());
    unawaited(service.dispose());
    platform.dispose();
    time.flushMicrotasks();
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const homeWidget = MethodChannel('home_widget');
  setUp(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      homeWidget,
      (call) async => true,
    );
  });
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(homeWidget, null);
  });

  test(
    'headless initialization does not turn an old preference into consent',
    () {
      fakeAsync((time) {
        final f = _Fixture(time, oldEnabled: true);
        time.elapse(const Duration(minutes: 3));
        expect(f.controller.enabled, isFalse);
        expect(f.watcher.isEnabled, isFalse);
        expect(f.scan.starts, 0);
        expect(f.link.connects, isEmpty);
        expect(f.platform.calls, ['refresh']);
        f.dispose();
      });
    },
  );

  test('native presence reaches the sole service without any screen', () {
    fakeAsync((time) {
      final f = _Fixture(
        time,
        native: _status(enabled: true, associated: true),
      );
      expect(f.link.connects, isEmpty);
      f.publish(_status(enabled: true, associated: true, present: true));
      expect(f.link.connects, [_bikeId]);
      for (var i = 1; i <= 5; i++) {
        f.link.retry = LinkRetryState(failures: i);
        f.link.announce(BleLinkState.reconnecting);
        time.flushMicrotasks();
        f.publish(_status(enabled: true, associated: true, present: true));
      }
      expect(f.link.connects, [_bikeId]);
      expect(f.link.retry.failures, 5);
      expect(f.scan.starts, 0);
      expect(f.platform.calls, ['refresh']);
      f.dispose();
    });
  });

  test('disabling hands-free preserves a healthy manual connection', () {
    fakeAsync((time) {
      final f = _Fixture(
        time,
        native: _status(enabled: true, associated: true),
      );
      f.readManually();
      unawaited(f.controller.setEnabled(false));
      time.flushMicrotasks();
      expect(f.controller.enabled, isFalse);
      expect(f.link.disconnects, 0);
      expect(f.service.hasCurrentReadings, isTrue);
      expect(f.controller.busy, isFalse);
      f.dispose();
    });
  });

  test('disabling hands-free preserves an active trip and its GPS', () {
    fakeAsync((time) {
      final f = _Fixture(
        time,
        native: _status(enabled: true, associated: true),
      );
      f.readManually();
      unawaited(f.service.startTrip());
      time.flushMicrotasks();
      expect(f.service.trip.isRecording, isTrue);
      unawaited(f.controller.setEnabled(false));
      time.flushMicrotasks();
      expect(f.service.trip.isRecording, isTrue);
      expect(f.link.disconnects, 0);
      expect(f.gps.running, isTrue);
      f.dispose();
    });
  });

  test(
    'cancelled association restores a connection released for the chooser',
    () async {
      SharedPreferences.setMockInitialValues({
        'proximity_device_id': _bikeId,
        'proximity_device_name': 'KevinJK',
      });
      final platform = _Native(_status())
        ..enableResult = _status(reason: 'association_cancelled');
      final link = _Link();
      final gps = _Gps();
      final service = BmsService(
        transport: link,
        clock: () => _epoch,
        locationFactory: () => gps,
      );
      final watcher = ProximityWatcher(scanSource: _Scan());
      final connection = ProximityConnection(
        watcher: watcher,
        service: service,
      );
      final controller = HandsFreeController(
        platform: platform,
        watcher: watcher,
        connection: connection,
        service: service,
      );
      addTearDown(() async {
        controller.dispose();
        await connection.dispose();
        await watcher.dispose();
        await service.dispose();
        platform.dispose();
      });
      await controller.initialize();
      await service.connect(_bikeId, name: 'KevinJK');
      service.activeDevice = Device(
        id: _bikeId,
        name: 'KevinJK',
        serialNumber: '',
        model: '',
        catalogueFromBms: false,
        chemistry: 'unknown',
        firstSeenAt: _epoch,
        lastSeenAt: _epoch,
        demo: false,
      );
      link.announce(BleLinkState.connected);
      await link.deliver(kevinJkCellInfo.first);
      expect(service.hasCurrentReadings, isTrue);
      expect(gps.running, isTrue);
      await controller.setEnabled(true);
      expect(platform.calls, ['refresh', 'prerequisites', 'enable']);
      expect(link.disconnects, 1);
      expect(link.connects, [_bikeId, _bikeId]);
      expect(gps.running, isFalse);
      expect(controller.enabled, isFalse);
      expect(controller.reason, 'association_cancelled');
      expect(controller.busy, isFalse);
    },
  );

  test('missing background permission does not release current readings', () {
    fakeAsync((time) {
      final f = _Fixture(time);
      f.readManually();
      f.platform.prerequisites = _status(
        reason: 'background_location_permission',
      );
      unawaited(f.controller.setEnabled(true));
      time.flushMicrotasks();
      expect(f.platform.calls, ['refresh', 'prerequisites']);
      expect(f.link.disconnects, 0);
      expect(f.service.hasCurrentReadings, isTrue);
      expect(f.controller.enabled, isFalse);
      expect(f.controller.reason, 'background_location_permission');
      f.dispose();
    });
  });

  test('first association waits until the current trip is finished', () {
    fakeAsync((time) {
      final f = _Fixture(time);
      f.readManually();
      unawaited(f.service.startTrip());
      time.flushMicrotasks();
      unawaited(f.controller.setEnabled(true));
      time.flushMicrotasks();
      expect(f.controller.reason, 'finish_trip_before_setup');
      expect(f.platform.calls, ['refresh']);
      expect(f.link.disconnects, 0);
      expect(f.service.trip.isRecording, isTrue);
      f.dispose();
    });
  });

  test(
    'a setup in progress rejects duplicate toggles until permissions return',
    () {
      fakeAsync((time) {
        final f = _Fixture(time);
        f.platform.prerequisitesGate = Completer<HandsFreeStatus>();
        unawaited(f.controller.setEnabled(true));
        time.flushMicrotasks();
        expect(f.controller.busy, isTrue);
        unawaited(f.controller.setEnabled(true));
        time.flushMicrotasks();
        expect(f.platform.calls, ['refresh', 'prerequisites']);
        f.platform.prerequisitesGate!.complete(_status());
        time.flushMicrotasks();
        expect(f.platform.calls, ['refresh', 'prerequisites', 'enable']);
        expect(f.controller.enabled, isTrue);
        expect(f.controller.busy, isFalse);
        f.dispose();
      });
    },
  );
}
