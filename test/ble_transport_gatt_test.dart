import 'dart:async';

import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/connect_recovery.dart';
import 'package:jk_bms/src/ble/link_script.dart';
import 'package:jk_bms/src/protocol/ant_constants.dart';
import 'package:jk_bms/src/protocol/jk_commands.dart';

import 'fixtures/real_kevinjk_frames.dart';
import 'support/fake_gatt_radio.dart';
import 'support/fake_radio.dart';

void main() {
  final platform = FakeGattPlatform();
  late BleTransport transport;
  final states = <BleLinkState>[];
  final errors = <String>[];
  var sequence = 0;

  setUpAll(() => FlutterBluePlusPlatform.instance = platform);

  setUp(() {
    states.clear();
    errors.clear();
    platform
      ..characteristics = const [
        FakeGattCharacteristic(
          instanceId: 1,
          notify: true,
          writeWithoutResponse: true,
        ),
      ]
      ..failedWritesRemaining = 0
      ..beforeWrite = null
      ..afterWrite = null;
    platform.radio.connects.clear();
    platform.radio.disconnects.clear();
    platform.writes.clear();
    platform.subscriptions.clear();
    transport = BleTransport(
      recovery: ConnectRecovery(
        radio: FakeRecoveryRadio(),
        adverts: AdvertBook(),
      ),
      reconnectDelay: const Duration(milliseconds: 100),
    );
    transport.state.listen(states.add);
    transport.errors.listen((error) => errors.add(error.message));
  });

  tearDown(() => transport.dispose());

  String nextId() =>
      'AA:00:00:00:72:${(++sequence).toString().padLeft(2, '0')}';

  Future<void> until(bool Function() done) async {
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (!done()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('GATT operation did not finish');
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  for (final split in [false, true]) {
    test('JK reads real bytes through ${split ? 'separate' : 'combined'} '
        'notify and write characteristics', () async {
      final notifyInstance = split ? 2 : 1;
      if (split) {
        platform.characteristics = const [
          FakeGattCharacteristic(instanceId: 1, writeWithoutResponse: true),
          FakeGattCharacteristic(instanceId: 2, notify: true),
        ];
      }
      final received = <List<int>>[];
      transport.bytes.listen(received.add);
      platform.afterWrite = (request) {
        if (request.value[4] == 0x96) {
          platform.notify(
            request.remoteId,
            notifyInstance,
            kevinJkCellInfo.first,
          );
        }
      };

      await transport.connect(nextId());
      await pumpEventQueue();

      expect(transport.currentState, BleLinkState.connected);
      expect(platform.subscriptions.single.instanceId, notifyInstance);
      expect(platform.writes.map((w) => w.instanceId), [1, 1]);
      expect(platform.writes.map((w) => w.value), [
        jkReadCommand(0x97),
        jkReadCommand(0x96),
      ]);
      expect(received, [kevinJkCellInfo.first]);
    });
  }

  test('supports indications plus writes with response', () async {
    platform.characteristics = const [
      FakeGattCharacteristic(instanceId: 7, indicate: true, write: true),
    ];
    await transport.connect(nextId());

    expect(transport.currentState, BleLinkState.connected);
    expect(platform.subscriptions.single.instanceId, 7);
    expect(
      platform.writes.every((w) => w.writeType == BmWriteType.withResponse),
      isTrue,
    );
  });

  test('stays negotiating until both opening requests are sent', () async {
    final release = Completer<void>();
    platform.beforeWrite = (request) async {
      if (request.value[4] == 0x96) await release.future;
    };
    final connecting = transport.connect(nextId());
    await until(() => platform.writes.length == 2);
    final whileWriting = transport.currentState;
    release.complete();
    await connecting;

    expect(whileWriting, BleLinkState.negotiating);
    expect(transport.currentState, BleLinkState.connected);
  });

  test('a rejected opening request releases and retries without announcing '
      'a working connection', () async {
    platform.failedWritesRemaining = 1;
    await transport.connect(nextId());
    await pumpEventQueue();

    expect(states, isNot(contains(BleLinkState.connected)));
    expect(platform.radio.disconnects, hasLength(1));
    expect(
      errors.any((e) => e.contains('initial GATT write rejected')),
      isTrue,
    );
    await until(() => transport.currentState == BleLinkState.connected);
    expect(platform.radio.connects, hasLength(2));
    expect(platform.writes.map((w) => w.value), [
      jkReadCommand(0x97),
      jkReadCommand(0x97),
      jkReadCommand(0x96),
    ]);
    expect(transport.retry.failures, greaterThan(0));
    transport.frameAccepted(deviceInfo: true);
    expect(
      transport.retry.failures,
      greaterThan(0),
      reason: 'device info does not prove that battery readings resumed',
    );
    transport.readingAccepted();
    expect(transport.retry.failures, 0);
  });

  test('rejects a notify-only endpoint before sending any requests', () async {
    platform.characteristics = const [
      FakeGattCharacteristic(instanceId: 2, notify: true),
    ];
    await transport.connect(nextId());
    await pumpEventQueue();

    expect(transport.currentState, BleLinkState.failed);
    expect(states, isNot(contains(BleLinkState.connected)));
    expect(platform.writes, isEmpty);
    expect(platform.radio.disconnects, hasLength(1));
  });

  test(
    'ANT keeps its own read-only handshake and polling on split GATT',
    () async {
      platform.characteristics = const [
        FakeGattCharacteristic(instanceId: 1, writeWithoutResponse: true),
        FakeGattCharacteristic(instanceId: 2, notify: true),
      ];
      transport.script = LinkScript.ant;
      await transport.connect(nextId());
      await transport.askAgain();

      expect(transport.currentState, BleLinkState.connected);
      expect(platform.subscriptions.single.instanceId, 2);
      expect(platform.writes.map((w) => w.instanceId), [1, 1, 1]);
      expect(platform.writes.map((w) => w.value), [
        antDeviceInfoRequest,
        antStatusRequest,
        antStatusRequest,
      ]);
    },
  );

  test('device-info traffic without battery readings still releases a stuck '
      'link and retains the failure streak', () async {
    await transport.dispose();
    transport = BleTransport(
      recovery: ConnectRecovery(
        radio: FakeRecoveryRadio(),
        adverts: AdvertBook(),
      ),
      pollInterval: const Duration(milliseconds: 10),
      muteBefore: const Duration(milliseconds: 80),
      muteRetryDelay: const Duration(seconds: 1),
    );
    transport.errors.listen((error) => errors.add(error.message));
    await transport.connect(nextId());
    final heartbeat = Timer.periodic(
      const Duration(milliseconds: 10),
      (_) => transport.frameAccepted(deviceInfo: true),
    );
    try {
      await until(() => transport.drops == 1);
      expect(transport.retry.failures, greaterThan(0));
      expect(
        errors.any((e) => e.contains('without a decoded battery reading')),
        isTrue,
      );
      expect(platform.radio.disconnects, isNotEmpty);
    } finally {
      heartbeat.cancel();
    }
  });

  test(
    'fresh battery readings keep a working connection without polling it',
    () async {
      await transport.dispose();
      transport = BleTransport(
        recovery: ConnectRecovery(
          radio: FakeRecoveryRadio(),
          adverts: AdvertBook(),
        ),
        pollInterval: const Duration(milliseconds: 10),
        muteBefore: const Duration(milliseconds: 80),
      );
      await transport.connect(nextId());
      transport.frameAccepted();
      transport.readingAccepted();
      final heartbeat = Timer.periodic(const Duration(milliseconds: 10), (_) {
        transport.frameAccepted();
        transport.readingAccepted();
      });
      try {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(transport.currentState, BleLinkState.connected);
        expect(transport.drops, 0);
        expect(
          platform.writes,
          hasLength(2),
          reason: 'a healthy stream needs no poll',
        );
      } finally {
        heartbeat.cancel();
      }
    },
  );
}
