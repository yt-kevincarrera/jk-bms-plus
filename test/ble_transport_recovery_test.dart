import 'dart:async';

import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/connect_recovery.dart';

import 'support/fake_radio.dart';

void main() {
  // The real transport, with a fake Android under the plugin. Until this, the
  // attach, the retry and the letting-go had no test, because the plugin has
  // no platform in a test; the MTU fix for the 147 report went in untested
  // for that reason.

  final log = <String>[];
  final platform = FakeFbpPlatform(log: log);
  late FakeRecoveryRadio radio;
  late ConnectRecovery recovery;
  late BleTransport transport;
  late List<ConnectAttemptRecord> records;

  setUpAll(() => FlutterBluePlusPlatform.instance = platform);

  setUp(() {
    log.clear();
    platform
      ..connects.clear()
      ..disconnects.clear()
      ..onConnect = null;
    radio = FakeRecoveryRadio(log: log);
    recovery = ConnectRecovery(
      radio: radio,
      adverts: AdvertBook(),
      releasePause: const Duration(milliseconds: 1),
      normalTimeout: const Duration(seconds: 2),
      longTimeout: const Duration(seconds: 3),
    );
    records = [];
    recovery.events.listen((e) {
      if (e is AttemptRecorded) records.add(e.record);
    });
    transport = BleTransport(
      reconnectDelay: const Duration(milliseconds: 10),
      connectTimeout: const Duration(seconds: 2),
      recovery: recovery,
    );
  });

  tearDown(() => transport.dispose());

  /// Waits for [done], in real time, because the plugin's own timers are
  /// real.
  Future<void> until(bool Function() done, {int seconds = 10}) async {
    final end = DateTime.now().add(Duration(seconds: seconds));
    while (!done()) {
      if (DateTime.now().isAfter(end)) fail('timed out waiting');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('an MTU refusal on a link that already dropped is a failed attempt, '
      'and is retried', () async {
    const id = 'AA:00:00:00:00:01';
    // Up, then straight back down, as in the 147 report.
    platform.onConnect = (d) {
      platform
        ..emit(d, BmConnectionStateEnum.connected)
        ..emit(d, BmConnectionStateEnum.disconnected, code: 19);
    };
    final said = <String>[];
    transport.errors.listen((e) => said.add(e.message));
    unawaited(transport.connect(id));
    await until(() => platform.connects.length >= 2);

    // Not reported as a small packet size, which is what hid the drop.
    expect(said, isNot(contains(startsWith('MTU stayed'))));
    expect(said.first, contains('requestMtu'));
    final first = records.first;
    expect(first.outcome, AttemptOutcome.droppedAfterConnect);
    expect(first.counted, isTrue);
    expect(transport.retry.failures, greaterThanOrEqualTo(1));
  });

  test('the third attempt in a failing streak releases and waits for an '
      'advert before it connects, with the longer timeout', () async {
    const id = 'AA:00:00:00:00:02';
    platform.onConnect = (d) => platform.emit(
      d,
      BmConnectionStateEnum.disconnected,
      code: 147,
      reason: 'GATT_CONNECTION_TIMEOUT',
    );
    unawaited(transport.connect(id));
    await until(() => platform.connects.length >= 3);

    final third = log.indexOf('connect $id', log.indexOf('freshAdvert $id 8s'));
    expect(log.where((l) => !l.startsWith('disconnect')).toList().sublist(0, 5), [
      'connect $id',
      'connect $id',
      'release $id',
      'freshAdvert $id 8s',
      'connect $id',
    ]);
    expect(third, greaterThan(0));
    expect(records.take(2).every((r) => r.counted), isTrue);
    expect(records.first.detail, contains('GATT_CONNECTION_TIMEOUT'));
    await until(() => records.length >= 3);
    expect(records[2].detail, contains('timeout 3 s'));
  });

  test('switching to another pack lets go of the one whose attempt was in '
      'flight', () async {
    const a = 'AA:00:00:00:00:03';
    const b = 'AA:00:00:00:00:04';
    // Neither ever answers.
    unawaited(transport.connect(a));
    await until(() => platform.connects.contains(a));
    unawaited(transport.connect(b));
    await until(() => platform.connects.contains(b));
    // Well inside the plugin's own two-second timeout, which would cancel it
    // too: this is the transport giving it back, not the plugin.
    expect(platform.disconnects, contains(a));
    expect(records.single.outcome, AttemptOutcome.cancelled);
    expect(records.single.counted, isFalse);
  });

  test('disconnecting mid-attempt cancels it, gives the pack back, and does '
      'not count', () async {
    const id = 'AA:00:00:00:00:05';
    unawaited(transport.connect(id));
    await until(() => platform.connects.contains(id));
    await transport.disconnect();
    expect(platform.disconnects, contains(id));
    expect(records.single.outcome, AttemptOutcome.cancelled);
    expect(recovery.failuresFor(id), 0);
    // And nothing retries it.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(platform.connects.where((c) => c == id), hasLength(1));
  });

  test('the reset lets go of the link and runs the radio reset', () async {
    const id = 'AA:00:00:00:00:06';
    unawaited(transport.connect(id));
    await until(() => platform.connects.contains(id));
    await transport.resetRadio();
    expect(platform.disconnects, contains(id));
    expect(log.last, 'resetAll');
    expect(transport.busy, isFalse);
  });
}
