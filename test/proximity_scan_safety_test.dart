import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/proximity_connection.dart';
import 'package:jk_bms/src/ble/proximity_watcher.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

const _bike = DiscoveredBms(
  id: 'AA:00:00:00:89:01',
  name: 'KevinJK',
  rssi: -42,
);
final _epoch = DateTime.utc(2026, 10, 22, 12);

class _Session implements ProximityScanSession {
  int cancellations = 0;
  @override
  bool didStart = true;
  @override
  Future<void> cancel() async {
    cancellations++;
  }
}

/// Supplies radio observations, including callbacks arriving after cancellation.
/// It does not implement the watcher's generation, freshness or connect policy.
class _ScanSource implements ProximityScanSource {
  final sessions = <_Session>[];
  final listeners = <void Function(ProximityAdvertisement)>[];
  final wanted = <bool Function()>[];
  Completer<void>? startGate;

  @override
  Future<ProximityScanSession> start({
    required Duration duration,
    required bool Function() stillWanted,
    required void Function(ProximityAdvertisement) onAdvertisement,
  }) async {
    final session = _Session();
    sessions.add(session);
    listeners.add(onAdvertisement);
    wanted.add(stillWanted);
    await startGate?.future;
    return session;
  }

  void hear(int session, DateTime at, {DiscoveredBms device = _bike}) =>
      listeners[session](ProximityAdvertisement(device, at));
}

class _CountingLink extends FakeLink {
  final connects = <String>[];
  @override
  Future<void> connect(String id) async {
    connects.add(id);
    announce(BleLinkState.connecting);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProximityWatcher watcher(
    FakeAsync time,
    _ScanSource radio, {
    bool Function()? busy,
  }) => ProximityWatcher(
    scanSource: radio,
    clock: () => _epoch.add(time.elapsed),
    radioBusy: busy,
    scanDuration: const Duration(seconds: 1),
    scanInterval: const Duration(seconds: 45),
  );

  void enable(FakeAsync time, ProximityWatcher watcher) {
    unawaited(watcher.remember(_bike.id, _bike.name));
    time.flushMicrotasks();
    unawaited(watcher.setEnabled(true));
    time.flushMicrotasks();
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('native discovery has no periodic Dart scans', () {
    fakeAsync((time) {
      final radio = _ScanSource();
      final watch = watcher(time, radio);
      unawaited(watch.setNativeDiscovery(true));
      time.flushMicrotasks();
      enable(time, watch);
      time.elapse(const Duration(hours: 4));
      expect(radio.sessions, isEmpty);
      unawaited(watch.dispose());
      time.flushMicrotasks();
    });
  });

  test('remembering a target after enabling starts the legacy watcher', () {
    fakeAsync((time) {
      final radio = _ScanSource();
      final watch = watcher(time, radio);
      unawaited(watch.setEnabled(true));
      time.flushMicrotasks();
      expect(radio.sessions, isEmpty);
      unawaited(watch.remember(_bike.id, _bike.name));
      time.flushMicrotasks();
      expect(radio.sessions, hasLength(1));
      unawaited(watch.dispose());
      time.flushMicrotasks();
    });
  });

  test('old scan callbacks and deadline cannot reach a new manual owner', () {
    fakeAsync((time) {
      final radio = _ScanSource();
      final watch = watcher(time, radio);
      final found = <DiscoveredBms>[];
      watch.found.listen(found.add);
      enable(time, watch);
      expect(radio.sessions, hasLength(1));
      unawaited(watch.suspend());
      time.flushMicrotasks();
      expect(radio.wanted.single(), isFalse);
      final cancelsAtHandoff = radio.sessions.single.cancellations;
      radio.hear(0, _epoch.add(time.elapsed));
      time.elapse(const Duration(minutes: 2));
      expect(found, isEmpty);
      expect(radio.sessions, hasLength(1));
      expect(radio.sessions.single.cancellations, cancelsAtHandoff);
      unawaited(watch.dispose());
      time.flushMicrotasks();
    });
  });

  test(
    'manual handoff waits for a starting legacy request then discards it',
    () {
      fakeAsync((time) {
        final radio = _ScanSource()..startGate = Completer<void>();
        final watch = watcher(time, radio);
        final found = <DiscoveredBms>[];
        watch.found.listen(found.add);
        enable(time, watch);
        var released = false;
        unawaited(watch.suspend().then((_) => released = true));
        time.flushMicrotasks();
        expect(released, isFalse);
        expect(radio.wanted.single(), isFalse);
        radio.hear(0, _epoch);
        radio.startGate!.complete();
        time.flushMicrotasks();
        expect(released, isTrue);
        expect(found, isEmpty);
        expect(watch.isScanning, isFalse);
        expect(radio.sessions.single.cancellations, greaterThan(0));
        unawaited(watch.dispose());
        time.flushMicrotasks();
      });
    },
  );

  test(
    'concurrent manual owners both wait for the starting proximity scan',
    () {
      fakeAsync((time) {
        final radio = _ScanSource()..startGate = Completer<void>();
        final watch = watcher(time, radio);
        final service = BmsService(transport: _CountingLink());
        final coordinator = ProximityConnection(
          watcher: watch,
          service: service,
        );
        enable(time, watch);
        expect(radio.sessions, hasLength(1));
        var firstReady = false;
        var secondReady = false;
        unawaited(
          coordinator.suspendForManual().then((_) => firstReady = true),
        );
        unawaited(
          coordinator.suspendForManual().then((_) => secondReady = true),
        );
        time.flushMicrotasks();
        time.elapse(const Duration(seconds: 2));
        expect(firstReady, isFalse);
        expect(
          secondReady,
          isFalse,
          reason:
              'a second handoff cannot bypass the first pending radio request',
        );
        expect(radio.wanted.single(), isFalse);
        radio.startGate!.complete();
        time.flushMicrotasks();
        expect(firstReady, isTrue);
        expect(secondReady, isTrue);
        expect(watch.isScanning, isFalse);
        unawaited(coordinator.dispose());
        unawaited(watch.dispose());
        unawaited(service.dispose());
        time.flushMicrotasks();
      });
    },
  );

  test(
    'changing targets ignores observations still arriving from the old scan',
    () {
      fakeAsync((time) {
        final radio = _ScanSource();
        final watch = watcher(time, radio);
        final found = <DiscoveredBms>[];
        watch.found.listen(found.add);
        enable(time, watch);
        unawaited(watch.remember('AA:00:00:00:89:02', 'AnotherJK'));
        time.flushMicrotasks();
        expect(radio.sessions, hasLength(2));
        radio.hear(0, _epoch);
        time.flushMicrotasks();
        expect(found, isEmpty);
        expect(watch.deviceId, 'AA:00:00:00:89:02');
        unawaited(watch.dispose());
        time.flushMicrotasks();
      });
    },
  );

  test('legacy cache timestamps from before this sweep cannot connect', () {
    fakeAsync((time) {
      final radio = _ScanSource();
      final watch = watcher(time, radio);
      final found = <DiscoveredBms>[];
      watch.found.listen(found.add);
      enable(time, watch);
      radio.hear(0, _epoch.subtract(const Duration(milliseconds: 1)));
      time.flushMicrotasks();
      expect(found, isEmpty);
      radio.hear(0, _epoch);
      time.flushMicrotasks();
      expect(found.map((d) => d.id), [_bike.id]);
      unawaited(watch.dispose());
      time.flushMicrotasks();
    });
  });

  test(
    'radio becoming busy during scan startup blocks the late observation',
    () {
      fakeAsync((time) {
        var busy = false;
        final radio = _ScanSource()..startGate = Completer<void>();
        final watch = watcher(time, radio, busy: () => busy);
        final found = <DiscoveredBms>[];
        watch.found.listen(found.add);
        enable(time, watch);
        busy = true;
        radio.hear(0, _epoch);
        radio.startGate!.complete();
        time.flushMicrotasks();
        expect(found, isEmpty);
        expect(watch.isScanning, isFalse);
        expect(radio.sessions.single.cancellations, greaterThan(0));
        unawaited(watch.dispose());
        time.flushMicrotasks();
      });
    },
  );

  test(
    'legacy sighting expires during a manual scan instead of reconnecting',
    () {
      fakeAsync((time) {
        final radio = _ScanSource();
        final watch = watcher(time, radio);
        final link = _CountingLink();
        final service = BmsService(transport: link);
        final coordinator = ProximityConnection(
          watcher: watch,
          service: service,
        );
        enable(time, watch);
        unawaited(coordinator.suspendForManual());
        time.flushMicrotasks();
        watch.offerPresence(_bike, seenAt: _epoch);
        time.elapse(const Duration(seconds: 20));
        coordinator.resumeAfterManual();
        time.flushMicrotasks();
        expect(link.connects, isEmpty);
        expect(watch.presentAdvertisement, isNull);
        unawaited(coordinator.dispose());
        unawaited(watch.dispose());
        unawaited(service.dispose());
        time.flushMicrotasks();
      });
    },
  );

  test(
    'native rejects stale initial and out-of-order presence, clear persists',
    () {
      fakeAsync((time) {
        final radio = _ScanSource();
        final watch = watcher(time, radio);
        unawaited(watch.setNativeDiscovery(true));
        time.flushMicrotasks();
        enable(time, watch);
        final found = <DiscoveredBms>[];
        watch.found.listen(found.add);
        watch.offerPresence(
          _bike,
          seenAt: _epoch.subtract(const Duration(minutes: 1)),
        );
        expect(found, isEmpty);
        watch.offerPresence(_bike);
        time.elapse(const Duration(seconds: 2));
        watch.offerAbsence(_bike.id);
        watch.offerPresence(_bike, seenAt: _epoch);
        expect(found, hasLength(1));
        expect(watch.presentDevice, isNull);
        unawaited(watch.clear());
        time.flushMicrotasks();
        expect(watch.isEnabled, isFalse);
        expect(watch.hasDevice, isFalse);
        watch.offerPresence(_bike);
        expect(found, hasLength(1));
        SharedPreferences.getInstance().then((prefs) {
          expect(prefs.getBool('proximity_enabled'), isFalse);
          expect(prefs.getString('proximity_device_id'), isNull);
        });
        time.flushMicrotasks();
        unawaited(watch.dispose());
        time.flushMicrotasks();
      });
    },
  );
}
