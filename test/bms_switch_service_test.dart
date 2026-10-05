import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/bms_write_gate.dart';
import 'package:jk_bms/src/ble/link_traffic.dart';
import 'package:jk_bms/src/ble/simulator/simulated_link.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/real_kevinjk_frames.dart';
import 'support/fakes.dart';

/// The app is read-only again (owner, 2026-10-05): the service keeps its
/// switch-write path, dormant, and nothing it does may reach the transport.
/// These used to test the confirmation loop of a granted write; with
/// [bmsWritesShipped] false no write can be granted, so what is left to
/// check is that none ever goes out, the 2.29 permission on or not.
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

  test('nothing is written, permission on or off, and each tap is recorded '
      'as refused for the build', () async {
    for (final permitted in [false, true]) {
      service.bmsWritesAllowed = permitted;
      for (final s in BmsSwitch.values) {
        for (final on in [false, true]) {
          final outcome = await service.setBmsSwitch(s, on);
          expect(outcome.status, SwitchWriteStatus.refused);
          expect(outcome.refusal, WriteRefusal.notShipped);
          expect(
            service.checkSwitchWrite(s, on),
            isA<WriteRefused>(),
          );
        }
      }
    }
    expect(link.registerWrites, isEmpty);
    expect(link.settingsAsks, 0);
    expect(
      service.traffic.entries.where((e) => e.direction == TrafficDirection.tx),
      isEmpty,
    );
    expect(await kinds(), List.filled(12, 'bmsWriteRefused'));
    final row = (await repo.recentLinkEvents())
        .firstWhere((e) => e.kind == 'bmsWriteRefused');
    expect(row.detail, endsWith('notShipped'));
  });

  test('an ANT is refused the same way', () async {
    final antLink = FakeLink();
    final ant = BmsService(
      transport: antLink,
      locationFactory: StubLocation.new,
    )..bmsWritesAllowed = true;
    await ant.connect('ANT1', name: 'ANT-BLE16ZMUB');
    antLink.announce(BleLinkState.connected);
    final outcome = await ant.setBmsSwitch(BmsSwitch.charge, false);
    expect(outcome.refusal, WriteRefusal.notShipped);
    expect(antLink.registerWrites, isEmpty);
    await ant.dispose();
  });

  test('the demo pack is never switched either', () async {
    final sim = SimulatedLink(tickInterval: const Duration(hours: 1));
    final demo = BmsService(transport: sim, locationFactory: StubLocation.new)
      ..bmsWritesAllowed = true
      ..switchConfirmWindow = const Duration(milliseconds: 300);
    await demo.connect('demo', name: 'JK-B2A24S20P (demo)');
    await pumpEventQueue();
    expect(demo.lastSettings?.chargeSwitchOn, isTrue);

    final outcome = await demo.setBmsSwitch(BmsSwitch.charge, false);
    expect(outcome.refusal, WriteRefusal.notShipped);
    expect(sim.pack.chargeSwitchOn, isTrue);
    // Only read requests on the console.
    for (final e in demo.traffic.entries.where(
      (e) => e.direction == TrafficDirection.tx,
    )) {
      expect(e.hex.replaceAll(' ', '').substring(10, 12), '00',
          reason: 'value length byte of ${e.hex}');
    }
    await demo.dispose();
  });
}
