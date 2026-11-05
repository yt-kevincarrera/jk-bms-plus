import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/connect_recovery.dart';
import 'package:jk_bms/src/ble/first_contact.dart';
import 'package:jk_bms/src/bms_service.dart';

import 'fixtures/real_kevinjk_frames.dart';
import 'support/fake_gatt_radio.dart';
import 'support/fake_radio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'initial contact lets a silent GATT link recover before giving up',
    () async {
      await _silentThenReading(
        id: 'AA:00:00:00:94:01',
        contact: (now) => FirstContact(startedAt: now, bytesBefore: 0),
      );
    },
  );
}

Future<void> _silentThenReading({
  required String id,
  required FirstContact Function(DateTime now) contact,
}) async {
  late FakeAsync timeControl;
  late BmsService service;
  late BleTransport transport;
  late FakeGattPlatform platform;
  late void Function(Duration duration) advance;
  late void Function() cleanup;
  FirstContactOutcome? outcome;
  Duration? judgedAt;
  Object? connectError;
  var connected = false;
  final states = <BleLinkState>[];

  fakeAsync((time) {
    timeControl = time;
    final epoch = DateTime.utc(2026, 11, 5, 12);
    DateTime now() => epoch.add(time.elapsed);
    platform = FakeGattPlatform()
      ..characteristics = const [
        FakeGattCharacteristic(
          instanceId: 1,
          notify: true,
          writeWithoutResponse: true,
        ),
      ];
    FlutterBluePlusPlatform.instance = platform;
    transport = BleTransport(
      recovery: ConnectRecovery(
        radio: FakeRecoveryRadio(),
        adverts: AdvertBook(),
        releasePause: Duration.zero,
        now: now,
      ),
      clock: now,
    );
    service = BmsService(transport: transport, clock: now);
    final judge = contact(now());
    final subscriptions = <StreamSubscription<Object?>>[
      service.linkState.listen((state) {
        states.add(state);
        judge.onLinkState(state, now());
      }),
      service.frameStats.listen(
        (_) => judge.onBytesTotal(service.bytesReceivedTotal),
      ),
      service.deviceInfo.listen((_) => judge.onDecoded()),
      service.snapshots.listen((_) => judge.onDecoded()),
    ];
    platform.afterWrite = (request) {
      if (platform.radio.connects.length < 2) return;
      if (request.value[4] == 0x97) {
        platform.notify(request.remoteId, 1, kevinJkDeviceInfo.first);
      } else if (request.value[4] == 0x96) {
        platform.notify(request.remoteId, 1, kevinJkCellInfo.first);
      }
    };

    // This is ConnectScreen's _awaitVerdict cadence and failure action, fed
    // by the actual service streams rather than announcing states by hand.
    final verdictTimer = Timer.periodic(const Duration(milliseconds: 250), (
      timer,
    ) {
      final result = judge.judge(now());
      if (result == null) return;
      outcome = result;
      judgedAt = time.elapsed;
      timer.cancel();
      if (result != FirstContactOutcome.proven) {
        unawaited(service.disconnect());
      }
    });
    unawaited(
      service
          .connect(id, name: 'KevinJK')
          .then(
            (_) {
              connected = true;
            },
            onError: (Object error) {
              connectError = error;
            },
          ),
    );
    time.flushMicrotasks();
    advance = Zone.current.bindUnaryCallback((Duration duration) {
      time.elapse(duration);
    });
    cleanup = Zone.current.bindCallback(() {
      verdictTimer.cancel();
      for (final subscription in subscriptions) {
        unawaited(subscription.cancel());
      }
      unawaited(service.dispose());
      time.flushMicrotasks();
    });
  });

  // The plugin's async* connection-state cancellation crosses the native
  // event loop. Drain it without turning the recovery into a wall-clock wait.
  Future<void> drain() async {
    for (var i = 0; i < 8; i++) {
      await pumpEventQueue(times: 2);
      timeControl.flushMicrotasks();
      advance(Duration.zero);
    }
  }

  try {
    await drain();
    expect(connectError, isNull);
    expect(connected, isTrue);
    expect(service.lastLinkState, BleLinkState.connected);
    expect(platform.radio.connects, hasLength(1));
    expect(service.snapshotsEmitted, 0);

    advance(const Duration(milliseconds: 12250));
    await drain();
    expect(
      outcome,
      isNull,
      reason:
          'the screen judged $outcome at $judgedAt and left '
          '${service.lastLinkState}; its first-contact deadline must allow '
          'the transport to release the silent link after its mute timeout',
    );
    expect(platform.radio.disconnects, isEmpty);

    // The production poll runs every five seconds and releases the link once
    // the twenty-second mute threshold has been exceeded: at twenty-five.
    advance(const Duration(seconds: 13));
    await drain();
    expect(transport.drops, 1);
    expect(states, contains(BleLinkState.reconnecting));
    expect(platform.radio.disconnects, hasLength(1));
    expect(outcome, isNull);

    advance(const Duration(seconds: 3));
    await drain();
    advance(const Duration(milliseconds: 250));
    await drain();
    expect(platform.radio.connects, hasLength(2));
    expect(service.deviceInfoFrames, greaterThan(0));
    expect(service.snapshotsEmitted, greaterThan(0));
    expect(service.hasCurrentReadings, isTrue);
    expect(service.lastLinkState, BleLinkState.connected);
    expect(outcome, FirstContactOutcome.proven);
  } finally {
    cleanup();
    await drain();
  }
}
