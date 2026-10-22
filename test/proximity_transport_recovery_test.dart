import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/connect_recovery.dart';
import 'package:jk_bms/src/ble/proximity_connection.dart';
import 'package:jk_bms/src/ble/proximity_watcher.dart';
import 'package:jk_bms/src/ble/switchable_link.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/real_kevinjk_frames.dart';
import 'support/fake_gatt_radio.dart';
import 'support/fake_radio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'automatic mute retries exhaust once and manual same-MAC recovery reads real JK',
    () async {
      late FakeAsync timeControl;
      late void Function() verifyManual;
      late void Function() cleanup;
      var manualDone = false;
      Object? manualError;
      fakeAsync((time) {
        timeControl = time;
        SharedPreferences.setMockInitialValues({});
        final platform = FakeGattPlatform()
          ..characteristics = const [
            FakeGattCharacteristic(
              instanceId: 1,
              notify: true,
              writeWithoutResponse: true,
            ),
          ];
        FlutterBluePlusPlatform.instance = platform;
        final transport = BleTransport(
          recovery: ConnectRecovery(
            radio: FakeRecoveryRadio(),
            adverts: AdvertBook(),
            releasePause: Duration.zero,
          ),
          pollInterval: const Duration(milliseconds: 1),
          muteBefore: Duration.zero,
          muteRetryDelay: Duration.zero,
        );
        final errors = <String>[];
        transport.errors.listen((error) => errors.add(error.message));
        final service = BmsService(transport: SwitchableLink(real: transport));
        final epoch = DateTime.utc(2026, 10, 22, 12);
        DateTime now() => epoch.add(time.elapsed);
        final watcher = ProximityWatcher(
          clock: now,
          radioBusy: () => service.radioBusy,
        );
        final coordinator = ProximityConnection(
          watcher: watcher,
          service: service,
          clock: now,
        );
        const bike = DiscoveredBms(
          id: 'AA:00:00:00:91:01',
          name: 'KevinJK',
          rssi: -40,
        );
        unawaited(watcher.setNativeDiscovery(true));
        unawaited(watcher.remember(bike.id, bike.name));
        time.flushMicrotasks();
        unawaited(watcher.setEnabled(true));
        time.flushMicrotasks();
        watcher.offerPresence(bike);
        time.flushMicrotasks();
        for (var i = 0; i < 20; i++) {
          time.elapse(const Duration(seconds: 45));
          watcher.offerPresence(bike);
          time.flushMicrotasks();
        }
        expect(transport.retry.gaveUp, isTrue);
        expect(transport.retry.failures, 12);
        expect(
          platform.radio.connects,
          hasLength(12),
          reason:
              'proximity must never restart the exhausted budget every sweep',
        );
        expect(service.lastLinkState, BleLinkState.failed);

        unawaited(coordinator.suspendForManual());
        time.flushMicrotasks();
        platform.afterWrite = (request) {
          if (request.value[4] == 0x96) {
            platform.notify(request.remoteId, 1, kevinJkCellInfo.first);
          }
        };
        unawaited(
          service
              .connect(bike.id, name: bike.name)
              .then(
                (_) {
                  manualDone = true;
                },
                onError: (Object error) {
                  manualError = error;
                },
              ),
        );
        time.flushMicrotasks();
        // Recovery's zero-length release pause is a timer event, rather than
        // a microtask. Let the actual preparation finish before judging it.
        time.elapse(const Duration(milliseconds: 1));
        verifyManual = Zone.current.bindCallback(() {
          expect(
            platform.radio.connects,
            hasLength(13),
            reason:
                'state=${service.lastLinkState} busy=${service.radioBusy} '
                'manualDone=$manualDone manualError=$manualError errors=$errors',
          );
          expect(manualDone, isTrue);
          expect(manualError, isNull);
          expect(service.snapshotsEmitted, greaterThan(0));
          expect(service.hasCurrentReadings, isTrue);
          expect(service.lastLinkState, BleLinkState.connected);
          coordinator.resumeAfterManual();
          time.flushMicrotasks();
          expect(platform.radio.connects, hasLength(13));
        });
        cleanup = Zone.current.bindCallback(() {
          unawaited(coordinator.dispose());
          unawaited(watcher.dispose());
          unawaited(service.dispose());
          time.flushMicrotasks();
        });
      });
      // FBP's connectionState is async*. Cancelling that old subscription
      // completes on the native event loop, outside FakeAsync's microtask
      // queue. Drain that boundary while retaining fake time for the whole
      // multi-minute retry budget; do not mistake it for a stuck manual link.
      for (var i = 0; i < 20 && !manualDone && manualError == null; i++) {
        await pumpEventQueue();
        timeControl.flushMicrotasks();
        timeControl.elapse(Duration.zero);
      }
      try {
        verifyManual();
      } finally {
        cleanup();
        await pumpEventQueue();
        timeControl.flushMicrotasks();
      }
    },
  );
}
