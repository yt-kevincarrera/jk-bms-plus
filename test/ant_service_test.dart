import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/switchable_link.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/link_event.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/protocol/ant_crc.dart';
import 'package:jk_bms/src/protocol/bms_brand.dart';

import 'fixtures/ant_frames.dart';
import 'fixtures/captured_frames.dart';
import 'support/fakes.dart';

void main() {
  // Why this exists. The ANT path reuses everything below the snapshot, so
  // what needs proving here is the seam: which brand a connection starts
  // with, which assembler the bytes reach, what happens when the bytes say
  // the brand was wrong, and what is written down when nothing decodes. A
  // rider with an ANT has no other way to tell the app something is off.

  late FakeLink link;
  late AppDatabase db;
  late BmsRepository repo;
  late BmsService service;

  setUp(() {
    link = FakeLink();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = BmsRepository(database: db);
    service = BmsService(transport: link, locationFactory: StubLocation.new)
      ..repository = repo;
  });

  tearDown(() async {
    await service.dispose();
    await repo.dispose();
    await db.close();
  });

  test('a named ANT connects with the ANT script and produces readings',
      () async {
    await service.connect('ANT1', name: 'ANT-BLE16ZMUB');
    expect(link.scriptSet?.brand, BmsBrand.ant);
    link.announce(BleLinkState.connected);
    final next = service.snapshots.first;
    await link.deliver(antStatus16s);
    final s = await next;
    expect(s.brand, BmsBrand.ant);
    expect(s.packVoltage, closeTo(52.84, 1e-9));
    expect(link.framesHeard, 1);
  });

  test('device info arrives neutral and tells the link it was heard',
      () async {
    await service.connect('ANT1', name: 'ANT-BLE16ZMUB');
    link.announce(BleLinkState.connected);
    final info = service.deviceInfo.first;
    await link.deliver(antInfo16zm);
    expect((await info).model, '16ZM');
    expect(link.deviceInfoHeard, 1);
  });

  test('status without device info still activates the pack', () async {
    await service.connect('ANT1', name: 'ANT-BLE16ZMUB');
    link.announce(BleLinkState.connected);
    await link.deliver(antStatus16s);
    await pumpEventQueue();
    expect(service.activeDeviceId, 'ANT1');
    expect(service.lastDeviceInfo, isNull);
  });

  test('the pack adopts the ANT nominal capacity when none is set', () async {
    await service.connect('ANT1', name: 'ANT-BLE16ZMUB');
    link.announce(BleLinkState.connected);
    await link.deliver(antStatus16s);
    await pumpEventQueue();
    expect(service.activeDevice?.catalogueCapacityAh, closeTo(280, 1e-6));
    expect(service.activeDevice?.catalogueFromBms, isTrue);
  });

  test('the brand is stored on the pack', () async {
    await service.connect('ANT1', name: 'ANT-BLE16ZMUB');
    link.announce(BleLinkState.connected);
    await link.deliver(antStatus16s);
    await pumpEventQueue();
    expect(service.activeDevice?.brand, 'ant');
  });

  test('reconnecting by id alone uses the stored brand', () async {
    await service.repository!.rememberDevice(
      id: 'ANT1',
      name: 'Mi moto',
      demo: false,
      brand: BmsBrand.ant,
    );
    await service.connect('ANT1');
    expect(link.scriptSet?.brand, BmsBrand.ant);
  });

  test('an explicit brand beats the name', () async {
    await service.connect('X', name: 'KevinJK', brand: BmsBrand.ant);
    expect(service.brand, BmsBrand.ant);
  });

  test('ANT is polled by its script, never asked for JK cell info', () async {
    await service.connect('ANT1', name: 'ANT-BLE16ZMUB');
    link.announce(BleLinkState.connected);
    await Future<void>.delayed(const Duration(milliseconds: 3200));
    expect(link.asks, 0);
  });

  test('passive detection: ANT bytes on a JK connection switch the brand',
      () async {
    await service.connect('X', name: 'Moto', brand: BmsBrand.jk);
    link.announce(BleLinkState.connected);
    await link.deliver(antStatus16s);
    await pumpEventQueue();
    expect(service.brand, BmsBrand.ant);
    expect(link.scriptSet?.brand, BmsBrand.ant);
  });

  test('a switch to ANT stops the JK cell info requests', () async {
    await service.connect('X', name: 'Moto', brand: BmsBrand.jk);
    link.announce(BleLinkState.connected);
    await link.deliver(antStatus16s);
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 3200));
    expect(link.asks, 0);
  });

  test('passive detection works the other way too', () async {
    await service.connect('X', name: 'Moto', brand: BmsBrand.ant);
    link.announce(BleLinkState.connected);
    await link.deliver(cellInfo24s[0]);
    await pumpEventQueue();
    expect(service.brand, BmsBrand.jk);
  });

  test('once a JK frame decodes, ANT-looking bytes never switch the brand',
      () async {
    await service.connect('X', name: 'KevinJK');
    link.announce(BleLinkState.connected);
    await link.deliver(cellInfo24s[0]);
    await link.deliver(antStatus16s);
    await pumpEventQueue();
    expect(service.brand, BmsBrand.jk);
  });

  test('old ANT bytes are named, and nothing switches', () async {
    await service.connect('X', name: 'ANT-BLE16ZMUB');
    link.announce(BleLinkState.connected);
    await link.deliver(
      Uint8List.fromList([0xAA, 0x55, 0xAA, 0xFF, ...List.filled(136, 0)]),
    );
    expect(service.recentProblems.first, contains('2021'));
    expect(service.brand, BmsBrand.ant);
  });

  test('a bad CRC is counted and written down with its bytes', () async {
    await service.connect('X', name: 'ANT-BLE16ZMUB');
    link.announce(BleLinkState.connected);
    final bad = Uint8List.fromList(antStatus16s)..[40] ^= 0xFF;
    await link.deliver(bad);
    await pumpEventQueue();
    expect(service.antRejectedFrames, 1);
    final events = await service.repository!.recentLinkEvents();
    expect(
      events.any(
        (e) =>
            e.kind == LinkEventKind.antFrameRejected.name &&
            e.detail.contains('7ea1'),
      ),
      isTrue,
    );
  });

  test('rejections written down are capped at 20 per connection', () async {
    await service.connect('X', name: 'ANT-BLE16ZMUB');
    link.announce(BleLinkState.connected);
    final bad = Uint8List.fromList(antStatus16s)..[40] ^= 0xFF;
    for (var i = 0; i < 30; i++) {
      await link.deliver(bad);
    }
    await pumpEventQueue();
    final events = await service.repository!.recentLinkEvents();
    expect(
      events.where((e) => e.kind == LinkEventKind.antFrameRejected.name),
      hasLength(20),
    );
    expect(service.antRejectedFrames, 30);
  });

  test('an implausible ANT reading feeds nothing', () async {
    await service.connect('X', name: 'ANT-BLE16ZMUB');
    link.announce(BleLinkState.connected);
    // Every cell at 9.999 V: CRC-valid, physically impossible.
    await link.deliver(antFrameWithCells(antStatus16s, 9999));
    await pumpEventQueue();
    expect(service.history.isEmpty, isTrue);
    expect(service.recentProblems.first, contains('battery'));
  });

  test('a link drop resets the ANT assembler', () async {
    await service.connect('X', name: 'ANT-BLE16ZMUB');
    link.announce(BleLinkState.connected);
    await link.deliver(antStatus16s.sublist(0, 60), chunk: 60);
    link.announce(BleLinkState.reconnecting);
    link.announce(BleLinkState.connected);
    final next = service.snapshots.first;
    // Tail of a frame without its 7E A1 head, then a whole frame.
    await link.deliver(antStatus16s.sublist(60), chunk: 200);
    await link.deliver(antStatus14s4t);
    expect((await next).cellCount, 14);
  });

  test('demo mode after an ANT session goes back to JK', () async {
    // Built on a SwitchableLink as demo_mode_test.dart does, because only a
    // service over one has a demo mode at all. The radio underneath cannot
    // actually connect in a test, so connecting is the one thing it skips.
    final demo = BmsService(transport: SwitchableLink(real: _NoRadio()));
    addTearDown(demo.dispose);
    await demo.connect('X', name: 'Moto', brand: BmsBrand.ant);
    expect(demo.brand, BmsBrand.ant);
    await demo.enterDemoMode();
    expect(demo.brand, BmsBrand.jk);
    // And the simulator's JK frames are read as JK, not fed to ANT.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(demo.lastSnapshot, isNotNull);
  });

  // No fake_async dependency in this repo, so the clock is flutter_test's
  // own: testWidgets runs the body in a fake zone whose timers only fire when
  // the tester pumps time forward.
  testWidgets('silence on an inferred brand gives the general explanation',
      (tester) async {
    final quiet = FakeLink();
    final lonely = BmsService(
      transport: quiet,
      locationFactory: StubLocation.new,
    );
    await lonely.connect('X', name: 'ANT-BLE16ZMUB');
    quiet.announce(BleLinkState.connected);
    await tester.pump(const Duration(seconds: 13));
    expect(lonely.recentProblems.first, contains('not an authentication'));
    expect(lonely.recentProblems.first, isNot(contains('You said')));
    await tester.runAsync(lonely.dispose);
  });

  testWidgets('silence on a rider-chosen brand suggests the other one',
      (tester) async {
    final quiet = FakeLink();
    final lonely = BmsService(
      transport: quiet,
      locationFactory: StubLocation.new,
    );
    await lonely.connect('X', name: 'Moto', brand: BmsBrand.ant);
    quiet.announce(BleLinkState.connected);
    await tester.pump(const Duration(seconds: 13));
    expect(lonely.recentProblems.first, contains('JK'));
    // Disposing awaits stream teardown that a fake clock never delivers.
    await tester.runAsync(lonely.dispose);
  });
}

/// The real transport with connecting taken out: flutter_blue_plus has no
/// platform in a test, and everything the demo test needs happens above it.
class _NoRadio extends BleTransport {
  @override
  Future<void> connect(String deviceId) async {}
}

/// A copy of [f] with every cell set to [mv] and the CRC recomputed.
Uint8List antFrameWithCells(Uint8List f, int mv) {
  final b = Uint8List.fromList(f);
  final n = b[9];
  for (var i = 0; i < n; i++) {
    b[34 + 2 * i] = mv & 0xFF;
    b[35 + 2 * i] = mv >> 8;
  }
  final crc = antCrc16(b, 1, b.length - 4);
  b[b.length - 4] = crc & 0xFF;
  b[b.length - 3] = crc >> 8;
  return b;
}
