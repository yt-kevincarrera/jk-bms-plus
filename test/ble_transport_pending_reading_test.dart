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
    'a GATT drop after the hold time still fails without battery readings',
    () {
      fakeAsync((time) {
        const id = 'AA:00:00:00:75:01';
        final platform = FakeGattPlatform()
          ..characteristics = const [
            FakeGattCharacteristic(
              instanceId: 1,
              notify: true,
              writeWithoutResponse: true,
            ),
          ];
        FlutterBluePlusPlatform.instance = platform;
        final epoch = DateTime.utc(2026, 11, 5);
        DateTime now() => epoch.add(time.elapsed);
        final recovery = ConnectRecovery(
          radio: FakeRecoveryRadio(),
          adverts: AdvertBook(),
          now: now,
        );
        final records = <ConnectAttemptRecord>[];
        recovery.events.listen((event) {
          if (event is AttemptRecorded) records.add(event.record);
        });
        final transport = BleTransport(recovery: recovery, clock: now);
        unawaited(transport.connect(id));
        time.flushMicrotasks();
        time.elapse(const Duration(seconds: 3));
        expect(transport.currentState, BleLinkState.connected);
        expect(records, isEmpty);

        platform.radio.emit(id, BmConnectionStateEnum.disconnected, code: 8);
        time.flushMicrotasks();
        final record = records.single;
        final failures = recovery.streak;
        unawaited(transport.dispose());
        time.flushMicrotasks();

        expect(record.outcome, AttemptOutcome.droppedAfterConnect);
        expect(record.counted, isTrue);
        expect(failures, 1);
      });
    },
  );
}
