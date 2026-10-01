import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/bms_write_gate.dart';
import 'package:jk_bms/src/ble/link_traffic.dart';
import 'package:jk_bms/src/ble/simulator/simulated_link.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/protocol/jk_checksum.dart';
import 'package:jk_bms/src/protocol/jk_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/real_kevinjk_frames.dart';
import 'support/fakes.dart';

/// The real pack's settings frame with the three switches set as given, and
/// the checksum made good again, the way the pack would send it after a
/// write.
Uint8List kevinSettings({
  bool charge = true,
  bool discharge = true,
  bool balancer = true,
}) {
  final f = Uint8List.fromList(kevinJkSettings[0]);
  f[118] = charge ? 1 : 0;
  f[122] = discharge ? 1 : 0;
  f[126] = balancer ? 1 : 0;
  f[responseFrameSize - 1] = jkChecksum(f, responseFrameSize - 1);
  return f;
}

void main() {
  late FakeLink link;
  late AppDatabase db;
  late BmsRepository repo;
  late BmsService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    link = FakeLink();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = BmsRepository(database: db);
    service = BmsService(transport: link, locationFactory: StubLocation.new)
      ..repository = repo
      ..switchConfirmWindow = const Duration(milliseconds: 300);
    await service.connect('C8:47:80:00:00:01', name: 'KevinJK');
    link.announce(BleLinkState.connected);
    await link.deliver(kevinJkDeviceInfo[0]);
    await link.deliver(kevinJkSettings[0]);
    await link.deliver(kevinJkCellInfo[0]);
  });

  tearDown(() async {
    await service.dispose();
    await repo.dispose();
    await db.close();
  });

  Future<List<String>> kinds() async => [
    for (final e in (await repo.recentLinkEvents()).reversed)
      if (e.kind.startsWith('bmsWrite')) e.kind,
  ];

  test('with the setting off nothing is written, and the tap is recorded',
      () async {
    expect(service.bmsWritesAllowed, isFalse);
    for (final s in BmsSwitch.values) {
      final outcome = await service.setBmsSwitch(s, false);
      expect(outcome.status, SwitchWriteStatus.refused);
      expect(outcome.refusal, WriteRefusal.notPermitted);
    }
    expect(link.registerWrites, isEmpty);
    expect(link.settingsAsks, 0);
    expect(
      service.traffic.entries.where((e) => e.direction == TrafficDirection.tx),
      isEmpty,
    );
    expect(await kinds(), List.filled(3, 'bmsWriteRefused'));
  });

  test('a write confirmed by a settings frame showing the new state',
      () async {
    service.bmsWritesAllowed = true;
    // The pack answers the settings request with the switch now off.
    link.onAskSettings = () =>
        link.deliver(kevinSettings(balancer: false));

    final outcome = await service.setBmsSwitch(BmsSwitch.balancer, false);

    expect(outcome.status, SwitchWriteStatus.confirmed);
    expect(link.registerWrites, hasLength(1));
    expect(link.registerWrites.single.hex,
        'AA5590EB1F0400000000000000000000000000' '9D');
    expect(service.lastSettings!.balancerSwitchOn, isFalse);
    expect(await kinds(), ['bmsWriteSent', 'bmsWriteConfirmed']);
    final sent = (await repo.recentLinkEvents())
        .firstWhere((e) => e.kind == 'bmsWriteSent');
    expect(sent.detail, contains('balancer off'));
    expect(sent.detail, contains('0x1F'));
    expect(sent.deviceId, 'C8:47:80:00:00:01');
  });

  test('a settings frame still showing the old state is not a confirmation',
      () async {
    service.bmsWritesAllowed = true;
    link.onAskSettings = () => link.deliver(kevinSettings());

    final outcome = await service.setBmsSwitch(BmsSwitch.charge, false);

    expect(outcome.status, SwitchWriteStatus.unconfirmed);
    // Asked straight away and once more halfway through the window.
    expect(link.settingsAsks, 2);
    expect(service.lastSettings!.chargeSwitchOn, isTrue);
    expect(await kinds(), ['bmsWriteSent', 'bmsWriteUnconfirmed']);
  });

  test('a write the radio would not take is said as not sent', () async {
    service.bmsWritesAllowed = true;
    link.acceptWrites = false;
    final outcome = await service.setBmsSwitch(BmsSwitch.charge, false);
    expect(outcome.status, SwitchWriteStatus.notSent);
    expect(link.settingsAsks, 0);
    expect(await kinds(), ['bmsWriteNotSent']);
  });

  test('discharge off is refused during a ride, and nothing goes out',
      () async {
    service.bmsWritesAllowed = true;
    await service.startTrip();
    expect(service.trip.isRecording, isTrue);
    final outcome = await service.setBmsSwitch(BmsSwitch.discharge, false);
    expect(outcome.refusal, WriteRefusal.riding);
    expect(link.registerWrites, isEmpty);
    expect(await kinds(), ['bmsWriteRefused']);
    final row = (await repo.recentLinkEvents())
        .firstWhere((e) => e.kind == 'bmsWriteRefused');
    expect(row.detail, 'discharge off: riding');
  });

  test('an ANT is never offered a write', () async {
    final antLink = FakeLink();
    final ant = BmsService(
      transport: antLink,
      locationFactory: StubLocation.new,
    )..bmsWritesAllowed = true;
    await ant.connect('ANT1', name: 'ANT-BLE16ZMUB');
    antLink.announce(BleLinkState.connected);
    final outcome = await ant.setBmsSwitch(BmsSwitch.charge, false);
    expect(outcome.refusal, WriteRefusal.notJk);
    expect(antLink.registerWrites, isEmpty);
    await ant.dispose();
  });

  test('the simulator honours a write, so demo mode shows it working',
      () async {
    final sim = SimulatedLink(tickInterval: const Duration(hours: 1));
    final demo = BmsService(transport: sim, locationFactory: StubLocation.new)
      ..bmsWritesAllowed = true
      ..switchConfirmWindow = const Duration(seconds: 2);
    await demo.connect('demo', name: 'JK-B2A24S20P (demo)');
    await pumpEventQueue();
    expect(demo.lastSettings?.chargeSwitchOn, isTrue);
    expect(demo.lastSnapshot, isNotNull);

    final outcome = await demo.setBmsSwitch(BmsSwitch.charge, false);
    expect(outcome.status, SwitchWriteStatus.confirmed);
    expect(sim.pack.chargeSwitchOn, isFalse);
    expect(demo.lastSettings!.chargeSwitchOn, isFalse);
    // The write is on the console, as a tx entry with the frame's bytes.
    expect(
      demo.traffic.entries
          .where((e) => e.direction == TrafficDirection.tx)
          .map((e) => e.hex),
      ['AA 55 90 EB 1D 04 00 00 00 00 00 00 00 00 00 00 00 00 00 9B'],
    );
    await demo.dispose();
  });
}
