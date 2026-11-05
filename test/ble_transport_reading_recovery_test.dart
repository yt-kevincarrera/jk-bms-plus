import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/connect_recovery.dart';

import 'support/fake_gatt_radio.dart';
import 'support/fake_radio.dart';

void main() {
  test('mute GATT links escalate recovery instead of recording success', () {
    fakeAsync((time) {
      const id = 'AA:00:00:00:74:01';
      final platform = FakeGattPlatform()
        ..characteristics = const [
          FakeGattCharacteristic(
            instanceId: 1,
            notify: true,
            writeWithoutResponse: true,
          ),
        ];
      FlutterBluePlusPlatform.instance = platform;
      final radio = FakeRecoveryRadio();
      final epoch = DateTime.utc(2026, 11, 5);
      DateTime now() => epoch.add(time.elapsed);
      final recovery = ConnectRecovery(
        radio: radio,
        adverts: AdvertBook(),
        now: now,
        releasePause: Duration.zero,
      );
      final records = <ConnectAttemptRecord>[];
      recovery.events.listen((event) {
        if (event is AttemptRecorded) records.add(event.record);
      });
      final transport = BleTransport(recovery: recovery, clock: now);
      unawaited(transport.connect(id));
      time.flushMicrotasks();
      time.elapse(const Duration(seconds: 57));
      final attempts = platform.radio.connects.length;
      final steps = List<String>.of(radio.log);
      final successesBeforeReading = records
          .where((record) => record.outcome == AttemptOutcome.connected)
          .length;
      transport.frameAccepted(deviceInfo: true);
      time.elapse(Duration.zero);
      final failuresAfterInfo = recovery.streak;
      transport.readingAccepted();
      time.elapse(const Duration(seconds: 2));
      final failuresAfterReading = recovery.streak;
      final successesAfterReading = records
          .where((record) => record.outcome == AttemptOutcome.connected)
          .length;
      unawaited(transport.dispose());
      time.flushMicrotasks();

      expect(attempts, greaterThanOrEqualTo(3));
      expect(
        steps,
        contains('freshAdvert $id 8s'),
        reason:
            'two connected links without readings must activate the '
            'release and fresh-advert recovery before the third attempt',
      );
      expect(
        successesBeforeReading,
        0,
        reason: 'GATT staying up is not proof that battery readings resumed',
      );
      expect(failuresAfterInfo, 2);
      expect(failuresAfterReading, 0);
      expect(successesAfterReading, 1);
    });
  });
}
