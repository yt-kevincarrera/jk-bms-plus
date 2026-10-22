import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/bms_link.dart';
import 'package:jk_bms/src/ble/proximity_connection.dart';
import 'package:jk_bms/src/ble/proximity_watcher.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/real_kevinjk_frames.dart';
import 'support/fakes.dart';

const _bike = DiscoveredBms(
  id: 'AA:00:00:00:88:01',
  name: 'KevinJK',
  rssi: -45,
);
final _epoch = DateTime.utc(2026, 10, 22, 12);

class _CountingLink extends FakeLink {
  final connects = <String>[];
  int disconnects = 0;
  Future<void> Function(int attempt)? onConnect;

  @override
  Future<void> connect(String deviceId) async {
    connects.add(deviceId);
    announce(BleLinkState.connecting);
    await onConnect?.call(connects.length);
  }

  @override
  Future<void> disconnect() async {
    disconnects++;
    announce(BleLinkState.idle);
  }
}

class _Fixture {
  _Fixture(this.time, {Duration cooldown = const Duration(minutes: 5)}) {
    SharedPreferences.setMockInitialValues({});
    service = BmsService(transport: link, clock: now);
    watcher = ProximityWatcher(clock: now, radioBusy: () => service.radioBusy);
    connection = ProximityConnection(
      watcher: watcher,
      service: service,
      clock: now,
      failedCooldown: cooldown,
    );
    unawaited(watcher.setNativeDiscovery(true));
    unawaited(watcher.remember(_bike.id, _bike.name));
    time.flushMicrotasks();
    unawaited(watcher.setEnabled(true));
    time.flushMicrotasks();
  }

  final FakeAsync time;
  final link = _CountingLink();
  late final BmsService service;
  late final ProximityWatcher watcher;
  late final ProximityConnection connection;
  DateTime now() => _epoch.add(time.elapsed);
  void presence() {
    watcher.offerPresence(_bike);
    time.flushMicrotasks();
  }

  void absence() {
    watcher.offerAbsence(_bike.id);
    time.flushMicrotasks();
  }

  void gaveUp() {
    link.retry = const LinkRetryState(failures: 12, gaveUp: true);
    link.announce(BleLinkState.failed);
    time.flushMicrotasks();
  }

  void dispose() {
    unawaited(connection.dispose());
    unawaited(watcher.dispose());
    unawaited(service.dispose());
    time.flushMicrotasks();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('native presence connects without a ConnectScreen or navigation', () {
    fakeAsync((time) {
      final f = _Fixture(time);
      f.presence();
      expect(f.link.connects, [_bike.id]);
      expect(f.service.lastLinkState, BleLinkState.connecting);
      f.dispose();
    });
  });

  test('replayed presence never resets the transport retry budget', () {
    fakeAsync((time) {
      final f = _Fixture(time);
      f.presence();
      for (var i = 0; i < 8; i++) {
        time.elapse(const Duration(seconds: 45));
        f.link.retry = LinkRetryState(failures: i + 1);
        f.link.announce(BleLinkState.failed);
        time.flushMicrotasks();
        f.presence();
      }
      expect(f.link.connects, [_bike.id]);
      expect(f.link.retry.failures, 8);
      expect(f.link.disconnects, 0);
      f.dispose();
    });
  });

  test(
    'connected without readings stays with the transport past 25 seconds',
    () {
      fakeAsync((time) {
        final f = _Fixture(time);
        f.presence();
        f.link.announce(BleLinkState.connected);
        time.flushMicrotasks();
        time.elapse(const Duration(seconds: 90));
        expect(f.service.hasCurrentReadings, isFalse);
        expect(f.link.connects, [_bike.id]);
        expect(f.link.disconnects, 0);
        expect(f.link.asks, greaterThan(0));
        f.dispose();
      });
    },
  );

  test('after gaveUp the same present pack stays stopped beyond cooldown', () {
    fakeAsync((time) {
      final f = _Fixture(time);
      f.presence();
      f.gaveUp();
      for (var i = 0; i < 20; i++) {
        time.elapse(const Duration(seconds: 45));
        f.presence();
      }
      expect(f.link.connects, [_bike.id]);
      f.absence();
      time.elapse(const Duration(seconds: 16));
      f.presence();
      expect(f.link.connects, [_bike.id, _bike.id]);
      f.dispose();
    });
  });

  test('a fresh departure-return still respects the failure cooldown', () {
    fakeAsync((time) {
      final f = _Fixture(time, cooldown: const Duration(seconds: 30));
      f.presence();
      f.gaveUp();
      f.absence();
      time.elapse(const Duration(seconds: 16));
      f.presence();
      expect(f.link.connects, hasLength(1));
      time.elapse(const Duration(seconds: 14));
      expect(f.link.connects, hasLength(2));
      f.dispose();
    });
  });

  test('native return remains present through the failure cooldown', () {
    fakeAsync((time) {
      final f = _Fixture(time);
      f.presence();
      f.gaveUp();
      f.absence();
      time.elapse(const Duration(seconds: 16));
      f.presence();
      time.elapse(const Duration(minutes: 6));
      expect(f.link.connects, hasLength(2));
      f.dispose();
    });
  });

  test('GATT presence flapping cannot reopen an exhausted retry budget', () {
    fakeAsync((time) {
      final f = _Fixture(time);
      f.presence();
      f.gaveUp();
      f.absence();
      time.elapse(const Duration(seconds: 2));
      f.presence();
      time.elapse(const Duration(minutes: 6));
      f.presence();
      expect(f.link.connects, hasLength(1));
      f.absence();
      time.elapse(const Duration(seconds: 15));
      f.presence();
      expect(f.link.connects, hasLength(2));
      f.dispose();
    });
  });

  test(
    'failed automatic connection yields to manual connect of the same MAC',
    () {
      fakeAsync((time) {
        final f = _Fixture(time);
        final oldConnect = Completer<void>();
        f.link.onConnect = (attempt) =>
            attempt == 1 ? oldConnect.future : Future<void>.value();
        f.presence();
        var suspended = false;
        unawaited(
          f.connection.suspendForManual().then((_) => suspended = true),
        );
        time.flushMicrotasks();
        expect(
          suspended,
          isTrue,
          reason: 'manual intent must not await GATT retries',
        );
        expect(f.link.disconnects, 1);
        unawaited(f.service.connect(_bike.id, name: _bike.name));
        time.flushMicrotasks();
        f.link.announce(BleLinkState.connected);
        time.flushMicrotasks();
        f.connection.resumeAfterManual();
        oldConnect.completeError(StateError('the cancelled automatic attempt'));
        time.flushMicrotasks();
        for (var i = 0; i < 4; i++) {
          time.elapse(const Duration(seconds: 45));
          f.presence();
        }
        expect(f.link.connects, [_bike.id, _bike.id]);
        expect(f.link.disconnects, 1);
        expect(f.service.lastLinkState, BleLinkState.connected);
        f.dispose();
      });
    },
  );

  test(
    'fresh native presence received during a manual scan is used on resume',
    () {
      fakeAsync((time) {
        final f = _Fixture(time);
        unawaited(f.connection.suspendForManual());
        time.flushMicrotasks();
        f.presence();
        expect(f.link.connects, isEmpty);
        time.elapse(const Duration(seconds: 2));
        f.connection.resumeAfterManual();
        time.flushMicrotasks();
        expect(f.link.connects, [_bike.id]);
        f.dispose();
      });
    },
  );

  test(
    'native presence survives a manual scan longer than advert freshness',
    () {
      fakeAsync((time) {
        final f = _Fixture(time);
        unawaited(f.connection.suspendForManual());
        time.flushMicrotasks();
        f.presence();
        time.elapse(const Duration(seconds: 20));
        f.connection.resumeAfterManual();
        time.flushMicrotasks();
        expect(f.link.connects, [_bike.id]);
        expect(f.watcher.presentAdvertisement!.at, _epoch);
        f.dispose();
      });
    },
  );

  test('manual inspection cannot be replaced by a proximity connection', () {
    fakeAsync((time) {
      final f = _Fixture(time);
      unawaited(f.service.connect('AA:00:00:00:88:02', inspecting: true));
      time.flushMicrotasks();
      f.presence();
      expect(f.link.connects, ['AA:00:00:00:88:02']);
      expect(f.link.disconnects, 0);
      f.dispose();
    });
  });

  test('manual scanning leaves a healthy automatic connection intact', () {
    fakeAsync((time) {
      final f = _Fixture(time);
      f.presence();
      f.link.announce(BleLinkState.connected);
      time.flushMicrotasks();
      unawaited(f.link.deliver(kevinJkCellInfo.first));
      time.elapse(const Duration(milliseconds: 1));
      expect(f.service.hasCurrentReadings, isTrue);
      unawaited(f.connection.suspendForManual());
      time.flushMicrotasks();
      expect(f.link.disconnects, 0);
      f.dispose();
    });
  });

  test('explicit disconnect requires a later departure and fresh return', () {
    fakeAsync((time) {
      final f = _Fixture(time);
      f.presence();
      f.link.announce(BleLinkState.connected);
      time.flushMicrotasks();
      f.absence(); // Advertising stopped because GATT connected.
      f.connection.suppressUntilReturn();
      unawaited(f.service.disconnect());
      time.flushMicrotasks();
      time.elapse(const Duration(seconds: 1));
      f.presence();
      expect(f.link.connects, hasLength(1));
      f.absence();
      time.elapse(const Duration(seconds: 16));
      f.presence();
      expect(f.link.connects, hasLength(2));
      f.dispose();
    });
  });

  test(
    'GATT disconnect presence flapping cannot undo explicit suppression',
    () {
      fakeAsync((time) {
        final f = _Fixture(time);
        f.presence();
        f.link.announce(BleLinkState.connected);
        time.flushMicrotasks();
        f.connection.suppressUntilReturn();
        unawaited(f.service.disconnect());
        time.flushMicrotasks();
        f.absence();
        time.elapse(const Duration(seconds: 2));
        f.presence();
        time.elapse(const Duration(seconds: 30));
        f.presence();
        expect(
          f.link.connects,
          hasLength(1),
          reason: 'the bike never left; BLE merely returned after GATT closed',
        );
        f.absence();
        time.elapse(const Duration(seconds: 15));
        f.presence();
        expect(f.link.connects, hasLength(2));
        f.dispose();
      });
    },
  );

  test('every early return cancels the pending departure dwell', () {
    fakeAsync((time) {
      final f = _Fixture(time);
      f.connection.suppressUntilReturn();
      f.absence();
      time.elapse(const Duration(seconds: 14));
      f.presence();
      f.absence();
      time.elapse(const Duration(seconds: 2));
      f.presence();
      expect(f.link.connects, isEmpty);
      f.absence();
      time.elapse(const Duration(seconds: 15));
      f.presence();
      expect(f.link.connects, [_bike.id]);
      f.dispose();
    });
  });

  test('explicit reenable can rearm after an exhausted attempt', () {
    fakeAsync((time) {
      final f = _Fixture(time);
      f.presence();
      f.gaveUp();
      f.connection.rearm();
      time.flushMicrotasks();
      expect(f.link.connects, hasLength(2));
      f.dispose();
    });
  });
}
