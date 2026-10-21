import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/bms_service.dart';

import 'fixtures/real_kevinjk_frames.dart';
import 'support/fakes.dart';

void main() {
  test(
    'a reconnect asks for new JK readings despite an earlier working link',
    () {
      fakeAsync((time) {
        final link = FakeLink();
        final service = BmsService(transport: link);
        unawaited(service.connect('AA:00:00:00:71:02'));
        time.flushMicrotasks();
        link.announce(BleLinkState.connected);
        time.flushMicrotasks();
        unawaited(link.deliver(kevinJkCellInfo.first));
        time.elapse(const Duration(milliseconds: 1));
        expect(service.snapshotsEmitted, 1);
        expect(service.hasCurrentReadings, isTrue);
        time.elapse(const Duration(seconds: 3));
        final asksBefore = link.asks;

        link.announce(BleLinkState.reconnecting);
        time.flushMicrotasks();
        link.announce(BleLinkState.connected);
        time.flushMicrotasks();
        expect(service.hasCurrentReadings, isFalse);
        for (var i = 0; i < 4; i++) {
          unawaited(link.deliver(kevinJkDeviceInfo.first));
          time.elapse(const Duration(seconds: 2));
        }
        expect(service.snapshotsEmitted, 1);
        expect(link.asks, greaterThan(asksBefore));

        unawaited(link.deliver(kevinJkCellInfo.first));
        time.elapse(const Duration(milliseconds: 1));
        expect(service.snapshotsEmitted, 2);
        final asksWhenRecovered = link.asks;
        time.elapse(const Duration(seconds: 9));
        expect(
          link.asks,
          asksWhenRecovered,
          reason: 'the service leaves a recovered streaming pack alone',
        );
        unawaited(service.dispose());
        time.flushMicrotasks();
      });
    },
  );

  test('checksum-valid cells that cannot decode do not end JK recovery', () {
    fakeAsync((time) {
      final link = FakeLink();
      final service = BmsService(transport: link);
      unawaited(service.connect('AA:00:00:00:71:03'));
      time.flushMicrotasks();
      link.announce(BleLinkState.connected);
      time.flushMicrotasks();
      final undecodable = Uint8List.fromList(kevinJkCellInfo.first);
      for (var i = 6; i < 260; i++) {
        undecodable[i] = 0xFF;
      }
      undecodable[299] = undecodable
          .take(299)
          .fold(0, (sum, b) => (sum + b) & 0xFF);
      for (var i = 0; i < 4; i++) {
        unawaited(link.deliver(undecodable));
        time.elapse(const Duration(seconds: 2));
      }
      expect(service.cellInfoFrames, 4);
      expect(service.snapshotsEmitted, 0);
      expect(link.asks, greaterThan(0));
      unawaited(service.dispose());
      time.flushMicrotasks();
    });
  });

  test(
    'a failed bootstrap reading cannot satisfy the next connection attempt',
    () {
      fakeAsync((time) {
        final link = FakeLink();
        final service = BmsService(transport: link);
        unawaited(service.connect('AA:00:00:00:71:05'));
        time.flushMicrotasks();
        link.announce(BleLinkState.negotiating);
        time.flushMicrotasks();
        unawaited(link.deliver(kevinJkCellInfo.first));
        time.elapse(const Duration(milliseconds: 1));
        expect(service.snapshotsEmitted, 1);
        link.announce(BleLinkState.failed);
        link.announce(BleLinkState.connecting);
        link.announce(BleLinkState.negotiating);
        link.announce(BleLinkState.connected);
        time.flushMicrotasks();
        time.elapse(const Duration(seconds: 9));
        expect(service.hasCurrentReadings, isFalse);
        expect(link.asks, greaterThan(0));
        unawaited(service.dispose());
        time.flushMicrotasks();
      });
    },
  );

  test(
    'a valid reading received during bootstrap survives connected state',
    () {
      fakeAsync((time) {
        final link = FakeLink();
        final service = BmsService(transport: link);
        unawaited(service.connect('AA:00:00:00:71:04'));
        time.flushMicrotasks();
        unawaited(link.deliver(kevinJkCellInfo.first));
        time.elapse(const Duration(milliseconds: 1));
        expect(service.snapshotsEmitted, 1);
        link.announce(BleLinkState.connected);
        time.flushMicrotasks();
        time.elapse(const Duration(seconds: 9));
        expect(link.asks, 0);
        unawaited(service.dispose());
        time.flushMicrotasks();
      });
    },
  );
}
