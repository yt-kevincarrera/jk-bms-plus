import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/link_script.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/link_event.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/model/bms_snapshot.dart';
import 'package:jk_bms/src/protocol/ant_constants.dart';
import 'package:jk_bms/src/protocol/ant_legacy.dart';
import 'package:jk_bms/src/protocol/bms_brand.dart';

import 'fixtures/ant_frames.dart';
import 'fixtures/real_kevinjk_frames.dart';
import 'support/fakes.dart';

/// Feeds [frame] to [a] 20 bytes at a time, as BLE does.
List<AntLegacyFrame> chunked(AntLegacyAssembler a, List<int> frame) => [
  for (var i = 0; i < frame.length; i += 20)
    ...a.addChunk(frame.sublist(i, (i + 20).clamp(0, frame.length))),
];

void main() {
  const parser = AntLegacyParser();

  group('the frame', () {
    test('the reference captures pass the checksum, whole and in chunks', () {
      for (final f in [
        antLegacyStatus14s,
        antLegacyStatus14sLater,
        antLegacyStatus16sFrom2021Board,
      ]) {
        expect(f, hasLength(antLegacyFrameLength));
        expect(antLegacyChecksum(f), (f[138] << 8) | f[139]);
        expect(chunked(AntLegacyAssembler(), f), hasLength(1));
      }
    });

    test('a damaged one is refused, and handed over whole', () {
      final bad = Uint8List.fromList(antLegacyStatus14s)..[20] ^= 0x01;
      Uint8List? reported;
      final a = AntLegacyAssembler()..onBadChecksum = (b) => reported = b;
      expect(chunked(a, bad), isEmpty);
      expect(a.stats.badChecksum, 1);
      expect(reported, bad);
    });

    test('a new header starts over, as the reference does', () {
      final a = AntLegacyAssembler();
      a.addChunk(antLegacyStatus14s.sublist(0, 60));
      expect(chunked(a, antLegacyStatus14sLater), hasLength(1));
    });
  });

  group('the parser, against the reference test values', () {
    // tests/components/ant_bms_old_ble/ant_bms_old_ble_test.cpp
    final st = parser.parseStatus(
      AntLegacyFrame(
        bytes: antLegacyStatus14s,
        receivedAt: DateTime.utc(2026, 10, 5),
      ),
    );
    final s = st.snapshot;

    test('pack, cells, charge', () {
      expect(s.brand, BmsBrand.ant);
      expect(s.packVoltage, closeTo(48.8, 1e-9));
      expect(s.cellCount, 14);
      expect(s.cellVoltages[0], closeTo(3.498, 1e-9));
      expect(s.cellVoltages[8], closeTo(3.509, 1e-9));
      expect(s.cellVoltages[13], closeTo(3.468, 1e-9));
      expect(s.soc, 41);
      expect(s.nominalCapacityAh, closeTo(170.0, 1e-6));
      expect(s.remainingCapacityAh, closeTo(68.769939, 1e-6));
      expect(s.cycleCapacityAh, closeTo(11109.391, 1e-6));
      expect(s.totalRuntimeSeconds, 16386097);
    });

    test('six temperatures as probes, no MOSFET guessed among them', () {
      expect(s.temperatures, [22.0, 21.0, 21.0, 21.0, 21.0, 21.0]);
      expect(s.mosfetTemp, isNull);
    });

    test('MOSFETs on, balancer off, nothing raised', () {
      expect(s.chargeMosfetOn, isTrue);
      expect(s.dischargeMosfetOn, isTrue);
      expect(s.balancerActive, isFalse);
      expect(s.warnings.active, isEmpty);
      expect(st.chargeMosfetCode, 1);
      expect(st.balancerCode, 0);
      expect(st.legacy, isTrue);
    });

    test('what this frame does not carry is null, never filled in', () {
      expect(s.soh, isNull);
      expect(s.cycleCount, isNull);
      expect(st.batteryState, isNull);
      expect(st.balancerTemp, isNull);
      expect(st.batteryTypeCode, isNull);
      expect(st.totalChargedAh, isNull);
    });

    test('positive on the wire is discharge, as the capture shows', () {
      // +8.0 A on the wire and +390 W, while the remaining capacity falls
      // from the first frame to the ninth: the pack was being discharged.
      // In this app's convention that is negative.
      expect(s.current, closeTo(-8.0, 1e-9));
      final later = parser.parseStatus(
        AntLegacyFrame(
          bytes: antLegacyStatus14sLater,
          receivedAt: DateTime.utc(2026, 10, 5, 0, 0, 38),
        ),
      ).snapshot;
      expect(later.current, closeTo(-12.0, 1e-9));
      expect(later.remainingCapacityAh, lessThan(s.remainingCapacityAh));
      expect(later.totalRuntimeSeconds - s.totalRuntimeSeconds, 38);
      expect(s.isCharging, isFalse);
    });

    test('a 2021 board answering the old read: empty inputs are hidden', () {
      final b = parser.parseStatus(
        AntLegacyFrame(
          bytes: antLegacyStatus16sFrom2021Board,
          receivedAt: DateTime.utc(2026, 10, 5),
        ),
      ).snapshot;
      expect(b.cellCount, 16);
      expect(b.packVoltage, closeTo(63.7, 1e-9));
      expect(b.current, 0);
      expect(b.nominalCapacityAh, closeTo(234.0, 1e-6));
      expect(b.temperatures, [
        23.0,
        25.0,
        21.0,
        22.0,
        BmsSnapshot.absentProbeCelsius,
        BmsSnapshot.absentProbeCelsius,
      ]);
    });

    test('codes the legacy table leaves unnamed are not given 2021 names', () {
      expect(antLegacyCodeKnown(0x01, charge: true), isTrue);
      expect(antLegacyCodeKnown(0x0B, charge: true), isFalse);
      expect(antLegacyCodeKnown(0x04, charge: false), isFalse);
      expect(antLegacyCodeKnown(0x10, charge: false), isFalse);
      final unnamed = Uint8List.fromList(antLegacyStatus14s)..[104] = 0x04;
      final sum = antLegacyChecksum(unnamed);
      unnamed[138] = sum >> 8;
      unnamed[139] = sum & 0xFF;
      final st = parser.parseStatus(
        AntLegacyFrame(bytes: unnamed, receivedAt: DateTime.utc(2026)),
      );
      // In 2021, 0x04 is "two current exceeded" and raises a warning; here
      // it has no name and raises nothing.
      expect(st.snapshot.warnings.active, isEmpty);
    });
  });

  group('the scripts', () {
    final t0 = DateTime.utc(2026, 10, 5, 12);
    const quiet = Duration(seconds: 6);
    const mute = Duration(seconds: 60);

    test('the legacy one asks with the one read, every tick', () {
      expect(LinkScript.antLegacy.brand, BmsBrand.ant);
      expect(LinkScript.antLegacy.onConnect, [antLegacyStatusRequest]);
      expect(LinkScript.antLegacy.everyFrameHex, {'dbdb00000000'});
      for (var n = 1; n <= 10; n++) {
        final a = LinkScript.antLegacy.tick(
          now: t0.add(Duration(seconds: 2 * n)),
          lastFrameAt: t0.add(Duration(seconds: 2 * n - 1)),
          connectedAt: t0,
          tickNumber: n,
          deviceInfoSeen: false,
          quietBefore: quiet,
          muteBefore: mute,
        );
        expect((a as WriteFrame).bytes, antLegacyStatusRequest);
      }
    });

    test('the 2021 one tries the old read only on a pack that said nothing',
        () {
      WriteFrame at(int n, {DateTime? heard}) => LinkScript.ant.tick(
        now: t0.add(Duration(seconds: 2 * n)),
        lastFrameAt: heard,
        connectedAt: t0,
        tickNumber: n,
        deviceInfoSeen: false,
        quietBefore: quiet,
        muteBefore: mute,
      ) as WriteFrame;
      expect(at(3).bytes, antLegacyStatusRequest);
      expect(at(8).bytes, antLegacyStatusRequest);
      expect(at(4).bytes, antStatusRequest);
      expect(at(5).bytes, antDeviceInfoRequest);
      // Heard anything at all: never.
      expect(at(3, heard: t0.add(const Duration(seconds: 5))).bytes,
          antStatusRequest);
    });
  });

  group('the service', () {
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

    test('an ANT that answers the old read is read with the old protocol',
        () async {
      await service.connect('OLD1', name: 'ANT-BLE14S');
      link.announce(BleLinkState.connected);
      expect(service.antLegacy, isFalse);
      final next = service.snapshots.first;
      await link.deliver(antLegacyStatus14s);
      final s = await next;
      expect(service.antLegacy, isTrue);
      expect(service.brand, BmsBrand.ant);
      expect(link.scriptSet, same(LinkScript.antLegacy));
      expect(s.cellCount, 14);
      expect(s.current, closeTo(-8.0, 1e-9));
      expect(s.soh, isNull);
      expect(service.lastAntStatus?.legacy, isTrue);
      expect(service.stats.accepted, 1);
      // Said once, and written down.
      expect(service.recentProblems.join(' '), contains('before 2021'));
      final events = await repo.recentLinkEvents();
      expect(
        events.map((e) => e.kind),
        contains(LinkEventKind.oldAntProtocolSeen.name),
      );
      // And stored, so the history and the energy work as for any pack.
      await pumpEventQueue();
      expect(service.activeDeviceId, 'OLD1');
    });

    test('a JK-named connection that gets old ANT frames switches to them',
        () async {
      await service.connect('OLD2', name: 'JK-somewhere');
      expect(service.brand, BmsBrand.jk);
      link.announce(BleLinkState.connected);
      final next = service.snapshots.first;
      await link.deliver(antLegacyStatus16sFrom2021Board);
      final s = await next;
      expect(service.brand, BmsBrand.ant);
      expect(service.antLegacy, isTrue);
      expect(s.cellCount, 16);
    });

    test('once the 2021 protocol decodes, an old frame changes nothing',
        () async {
      await service.connect('NEW1', name: 'ANT-BLE16ZMUB');
      link.announce(BleLinkState.connected);
      await link.deliver(antStatus16s);
      await link.deliver(antLegacyStatus14s);
      await pumpEventQueue();
      expect(service.antLegacy, isFalse);
      expect(service.lastSnapshot?.cellCount, 16);
    });

    test('a JK that has proved itself is never taken for an old ANT',
        () async {
      await service.connect('JK1', name: 'JK-B2A24S20P');
      link.announce(BleLinkState.connected);
      await link.deliver(kevinJkDeviceInfo[0]);
      await link.deliver(kevinJkCellInfo[0]);
      await link.deliver(antLegacyStatus14s);
      await pumpEventQueue();
      expect(service.brand, BmsBrand.jk);
      expect(service.antLegacy, isFalse);
    });
  });
}
