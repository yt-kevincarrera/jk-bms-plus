import 'dart:async';
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
import 'package:jk_bms/src/pack/chemistry.dart';
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
    // Borrowed, so nothing may compare against it as what was sold, and the
    // full-pack range says it rests on the BMS's setting.
    expect(service.catalogueFromBms, isTrue);
    expect(service.advertisedCapacityAh, isNull);
    expect(service.catalogueCapacityAh, closeTo(280, 1e-6));
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

  test('bytes from an ANT after a JK session still count as bytes', () async {
    // The connect screen takes the byte total before connecting and judges
    // "the pack is talking" by growth from there. A per-brand counter put an
    // ANT after a JK below that baseline, so its failing frames read as
    // silence.
    await service.connect('JK1', name: 'KevinJK');
    link.announce(BleLinkState.connected);
    await link.deliver(deviceInfoFrames[1]);
    await link.deliver(cellInfo24s[0]);
    await pumpEventQueue();
    // The baseline is the lifetime total, which the connect screen takes for
    // exactly this reason. The per-connection figure restarts on connect,
    // so it cannot be measured against a number taken before it.
    final before = service.bytesReceivedTotal;
    await service.connect('ANT1', name: 'ANT-BLE16ZMUB');
    link.announce(BleLinkState.connected);
    final bad = Uint8List.fromList(antStatus16s)..[40] ^= 0xFF;
    await link.deliver(bad);
    await pumpEventQueue();
    expect(service.bytesReceivedTotal, before + bad.length);
    expect(service.stats.bytesReceived, bad.length);
    expect(service.stats.badChecksum, greaterThan(0));
  });

  test('the chunk that switches the brand is counted', () async {
    await service.connect('X', name: 'Moto', brand: BmsBrand.jk);
    link.announce(BleLinkState.connected);
    final before = service.stats.bytesReceived;
    await link.deliver(antStatus16s);
    await pumpEventQueue();
    expect(service.brand, BmsBrand.ant);
    expect(service.stats.bytesReceived, before + antStatus16s.length);
  });

  test("an ANT that has not answered for its cutoff gets the chemistry's "
      'usual one, marked assumed', () async {
    // It used to be a flat 3.0 V for any pack without a settings frame,
    // quoted in the alert as "the BMS cutoff". This ANT has not answered
    // the read of its undervoltage register (ant_settings_test covers one
    // that has).
    await service.connect('ANT1', name: 'ANT-BLE16ZMUB');
    link.announce(BleLinkState.connected);
    await link.deliver(antStatus16s);
    await pumpEventQueue();
    expect(service.activeDeviceId, 'ANT1');
    expect(service.cutoffIsAssumed, isTrue);
    // Cells at 3.3 V say nothing about the chemistry, and nobody has.
    expect(service.cutoffChemistry, CellChemistry.unknown);
    expect(service.cutoffVoltagePerCell, ChemistryLimits.unknownCutoffVolts);

    await repo.setPackProfile('ANT1', chemistry: 'lfp');
    service.activeDevice = await repo.db.device('ANT1');
    expect(service.cutoffChemistry, CellChemistry.lfp);
    expect(service.cutoffVoltagePerCell, ChemistryLimits.lfp.typicalCutoffVolts);
    expect(service.cutoffIsAssumed, isTrue);
  });

  test('energy left is priced by the same chemistry, from the charge level',
      () async {
    // The one function every Wh and range figure goes through. With the
    // chemistry declared, it is the LFP curve's mean below this charge, not
    // the pack voltage of the moment and not a fixed 3.7 V a cell.
    await service.connect('ANT1', name: 'ANT-BLE16ZMUB');
    link.announce(BleLinkState.connected);
    await link.deliver(antStatus16s);
    await pumpEventQueue();
    await repo.setPackProfile('ANT1', chemistry: 'lfp');
    service.activeDevice = await repo.db.device('ANT1');

    final s = service.lastSnapshot!;
    final energy = service.energyOf(s);
    expect(energy.meanCellVolts, OcvCurve.lfp.meanVoltsBelow(s.soc));
    expect(
      energy.grossWh,
      closeTo(s.remainingCapacityAh * s.cellCount * energy.meanCellVolts, 1e-6),
    );
  });

  group('an ANT whose current runs against its own state', () {
    // The parser reverses the field, measured on one real pack. The state
    // byte is the witness for any other: charging at a clearly negative
    // current, three frames running, means the pack reports the other way.
    Future<List<double>> feed(List<Uint8List> frames) async {
      await service.connect('ANT1', name: 'ANT-BLE16ZMUB');
      link.announce(BleLinkState.connected);
      final seen = <double>[];
      final sub = service.snapshots.listen((s) => seen.add(s.current));
      for (final f in frames) {
        await link.deliver(f);
        await pumpEventQueue();
      }
      await sub.cancel();
      return seen;
    }

    test('is reversed from the frame that settles it, and said once',
        () async {
      final charging = antFrameWithState(0x02, -6.0);
      final seen = await feed([charging, charging, charging, charging]);
      // The first two are taken as they come; the third settles it.
      expect(seen, [-6.0, -6.0, 6.0, 6.0]);
      expect(service.lastAntStatus!.snapshot.current, 6.0);
      expect(service.lastSnapshot!.isCharging, isTrue);
      expect(
        service.recentProblems.where((p) => p.contains('opposite sign')),
        hasLength(1),
      );
      final events = await service.repository!.recentLinkEvents();
      final rows = events.where(
        (e) => e.kind == LinkEventKind.antCurrentSignInverted.name,
      );
      expect(rows, hasLength(1));
      expect(rows.single.detail, contains('Charge'));
    });

    test("the rider's 20S pack: a longer frame reads, charging positive",
        () async {
      // Every status frame this pack sent was refused as the wrong size,
      // and the connect ended in "no readings have arrived".
      final seen = await feed([
        antStatus20s4tCharging,
        antStatus20s4tCharging,
        antStatus20s4tCharging,
        antStatus20s4tCharging,
      ]);
      expect(seen, everyElement(closeTo(5.1, 1e-9)));
      expect(service.decodeFailures, 0);
      expect(service.lastSnapshot!.cellCount, 20);
      final events = await service.repository!.recentLinkEvents();
      expect(
        events.where(
          (e) => e.kind == LinkEventKind.antCurrentSignInverted.name,
        ),
        isEmpty,
      );
    });

    test('and a pack whose state agrees is left alone', () async {
      final charging = antFrameWithState(0x02, 6.0);
      final seen = await feed([charging, charging, charging, charging]);
      expect(seen, everyElement(6.0));
      final events = await service.repository!.recentLinkEvents();
      expect(
        events.where(
          (e) => e.kind == LinkEventKind.antCurrentSignInverted.name,
        ),
        isEmpty,
      );
    });
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

  // A pack whose every reading fails plausibility never becomes active, and
  // the repository keeps no raw frame without an active pack. The LinkEvents
  // row is then the only copy of the bytes the decoder has to be fixed from.
  test('an implausible ANT reading leaves its bytes in LinkEvents before the '
      'pack is active', () async {
    await service.connect('X', name: 'ANT-BLE16ZMUB');
    link.announce(BleLinkState.connected);
    final frame = antFrameWithCells(antStatus16s, 9999);
    await link.deliver(frame);
    await pumpEventQueue();
    expect(service.activeDeviceId, isNull);
    expect(service.heldBackFrames, 1);
    final events = await service.repository!.recentLinkEvents();
    final row = events.singleWhere(
      (e) => e.kind == LinkEventKind.antDecodeFailed.name,
    );
    expect(row.detail, startsWith('implausible '));
    expect(row.detail.split(' ').last, _hexOf(frame));
  });

  test('a valid ANT frame that is neither status nor device info is written '
      'down with its function and bytes', () async {
    await service.connect('X', name: 'ANT-BLE16ZMUB');
    link.announce(BleLinkState.connected);
    // A read reply for some other address, standing in for a refusal of the
    // device-info request: CRC-valid, and nothing this app decodes.
    final other = antFrame(0x12, 0x0000, const []);
    await link.deliver(other);
    await pumpEventQueue();
    expect(link.framesHeard, 1);
    final events = await service.repository!.recentLinkEvents();
    final row = events.singleWhere(
      (e) => e.kind == LinkEventKind.antDecodeFailed.name,
    );
    expect(row.detail, 'unrecognised fn=0x12 ${_hexOf(other)}');
  });

  test(
    'rejected buffers before activation do not spend the raw-frame budget',
    () async {
      await service.connect('X', name: 'ANT-BLE16ZMUB');
      link.announce(BleLinkState.connected);
      final bad = Uint8List.fromList(antStatus16s)..[40] ^= 0xFF;
      // More than the raw budget of 200, none of which could be stored.
      for (var i = 0; i < 205; i++) {
        await link.deliver(bad);
      }
      await link.deliver(antStatus16s);
      await pumpEventQueue();
      expect(service.activeDeviceId, 'X');
      await repo.flush();
      final before = await db.countRawFrames();
      await link.deliver(bad);
      await repo.flush();
      expect(await db.countRawFrames(), before + 1);
    },
  );

  test('a stored brand that cannot be read falls back to the name', () async {
    final broken = _UnreadableRepo(database: db);
    final own = FakeLink();
    final s = BmsService(transport: own, locationFactory: StubLocation.new)
      ..repository = broken;
    addTearDown(s.dispose);
    await s.connect('X', name: 'ANT-BLE16ZMUB');
    expect(s.brand, BmsBrand.ant);
    expect(own.scriptSet?.brand, BmsBrand.ant);
    expect(s.recentProblems.first, contains('stored brand'));
  });

  test(
    'a disconnect while the stored brand is read keeps the link closed',
    () async {
      final counting = _CountingLink();
      final gated = _GatedRepo(database: db);
      final s = BmsService(
        transport: counting,
        locationFactory: StubLocation.new,
      )..repository = gated;
      addTearDown(s.dispose);
      final connecting = s.connect('X', name: 'ANT-BLE16ZMUB');
      await pumpEventQueue();
      await s.disconnect();
      gated.gate.complete();
      await connecting;
      expect(counting.connects, 0);
    },
  );

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
    expect(lonely.recentProblems.first, contains('if it is a JK'));
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

/// A repository whose device lookup fails, as a locked or damaged database
/// would.
class _UnreadableRepo extends BmsRepository {
  _UnreadableRepo({required super.database});

  @override
  Future<Device?> device(String id) =>
      Future.error(StateError('database is locked'));
}

/// A repository whose device lookup waits for the test to let it finish, so
/// something can happen while connect() is waiting on it.
class _GatedRepo extends BmsRepository {
  _GatedRepo({required super.database});

  final Completer<void> gate = Completer<void>();

  @override
  Future<Device?> device(String id) async {
    await gate.future;
    return super.device(id);
  }
}

/// A fake link that counts connection attempts.
class _CountingLink extends FakeLink {
  int connects = 0;

  @override
  Future<void> connect(String deviceId) async => connects++;
}

/// A copy of the 16S fixture with its battery state byte and current set, and
/// the CRC recomputed. Current is at 40+o, o = 2 * (16 cells + 2 probes).
/// [amps] is what the parser reads out, so the field gets its negation: an
/// ANT reports charge as negative and the parser reverses it.
Uint8List antFrameWithState(int state, double amps) {
  final b = Uint8List.fromList(antStatus16s);
  b[7] = state;
  final raw = (-amps * 10).round() & 0xFFFF;
  b[40 + 36] = raw & 0xFF;
  b[41 + 36] = raw >> 8;
  final crc = antCrc16(b, 1, b.length - 4);
  b[b.length - 4] = crc & 0xFF;
  b[b.length - 3] = crc >> 8;
  return b;
}

String _hexOf(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

/// A well-formed ANT frame for [function] and [address], CRC included.
Uint8List antFrame(int function, int address, List<int> data) {
  final b = Uint8List.fromList([
    0x7E, 0xA1, function, address & 0xFF, address >> 8, data.length, //
    ...data, 0, 0, 0xAA, 0x55,
  ]);
  final crcAt = 6 + data.length;
  final crc = antCrc16(b, 1, crcAt);
  b[crcAt] = crc & 0xFF;
  b[crcAt + 1] = crc >> 8;
  return b;
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
