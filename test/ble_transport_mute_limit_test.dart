import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/connect_recovery.dart';

import 'support/fake_gatt_radio.dart';
import 'support/fake_radio.dart';

void main() {
  test(
    'a pack that never provides a reading exhausts its retries into failed',
    () {
      // Keep the plugin and its internal stream listeners inside one fake-time
      // zone. Advancing through the whole backoff then costs milliseconds.
      fakeAsync((time) {
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
          // DateTime.now is real; zero makes the lack of readings immediately
          // eligible, while fake time advances retries and plugin operations.
          muteBefore: Duration.zero,
          muteRetryDelay: Duration.zero,
        );
        unawaited(transport.connect('AA:00:00:00:73:01'));
        time.flushMicrotasks();
        time.elapse(const Duration(minutes: 10));

        final state = transport.currentState;
        final retry = transport.retry;
        final attempts = platform.radio.connects.length;
        unawaited(transport.dispose());
        time.flushMicrotasks();

        expect(retry.gaveUp, isTrue);
        expect(retry.failures, 12);
        expect(attempts, 12);
        expect(
          state,
          BleLinkState.failed,
          reason:
              'the final mute reset must not leave a disconnected pack '
              'announced as connected with no retry scheduled',
        );
      });
    },
  );
}
