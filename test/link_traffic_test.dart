import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/link_traffic.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/link_event.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/protocol/jk_commands.dart';
import 'package:jk_bms/src/protocol/jk_constants.dart';

import 'fixtures/captured_frames.dart';
import 'support/fakes.dart';

void main() {
  // Why this exists. The console was meant to show what went wrong when a
  // pack does not connect, and all it could show was decoded frames, which a
  // failing pack has none of. What proves the fix is that the bytes are
  // there to read afterwards: the ones the pack sent, the ones the app
  // wrote, and for a JK the ones the assembler threw away, in a backup.

  group('LinkTrafficLog', () {
    test('is bounded by entries, oldest out first', () {
      final log = LinkTrafficLog(maxEntries: 3);
      for (var i = 0; i < 5; i++) {
        log.add(TrafficDirection.rx, [i]);
      }
      expect(log.entries.map((e) => e.bytes.single), [2, 3, 4]);
    });

    test('is bounded by bytes, however few entries that leaves', () {
      final log = LinkTrafficLog(maxBytes: 500);
      for (var i = 0; i < 10; i++) {
        log.add(TrafficDirection.rx, List.filled(200, i));
      }
      expect(log.heldBytes, lessThanOrEqualTo(500));
      expect(log.entries.map((e) => e.bytes.first), [8, 9]);
    });

    test('prints hex in pairs, the way a sniffer does', () {
      final log = LinkTrafficLog()..add(TrafficDirection.tx, [0xAA, 0x5, 0xFF]);
      expect(log.entries.single.hex, 'AA 05 FF');
    });

    test('keeps a copy, not the caller\'s buffer', () {
      final chunk = Uint8List.fromList([1, 2, 3]);
      final log = LinkTrafficLog()..add(TrafficDirection.rx, chunk);
      chunk[0] = 9;
      expect(log.entries.single.bytes.first, 1);
    });
  });

  group('BmsService', () {
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

    Future<List<LinkEvent>> eventsOf(LinkEventKind kind) async =>
        (await repo.recentLinkEvents())
            .where((e) => e.kind == kind.name)
            .toList();

    test('records what arrived and what was written, and keeps it across a '
        'disconnect', () async {
      await service.connect('JK1', name: 'KevinJK');
      link.announce(BleLinkState.connected);
      link.wrote(jkReadCommand(commandDeviceInfo));
      await link.deliver(cellInfo24s[0], chunk: 244);
      await service.disconnect();
      await pumpEventQueue();

      final entries = service.traffic.entries;
      expect(entries.first.direction, TrafficDirection.tx);
      expect(entries.first.bytes, jkReadCommand(commandDeviceInfo));
      expect(
        entries.where((e) => e.direction == TrafficDirection.rx),
        hasLength(2),
      );
      expect(entries[1].bytes, cellInfo24s[0].sublist(0, 244));

      // And a second attempt adds to it rather than starting it over.
      await service.connect('JK1', name: 'KevinJK');
      await link.deliver(Uint8List.fromList([1, 2, 3]));
      expect(service.traffic.entries, hasLength(4));
    });

    test('a JK frame that fails its checksum is written down with its bytes',
        () async {
      await service.connect('JK1', name: 'KevinJK');
      link.announce(BleLinkState.connected);
      final corrupt = Uint8List.fromList(cellInfo24s[0])..[50] ^= 0xFF;
      await link.deliver(corrupt);
      await pumpEventQueue();

      final rows = await eventsOf(LinkEventKind.jkFrameRejected);
      expect(rows, hasLength(1));
      expect(rows.single.detail, startsWith('badChecksum '));
      // The last token is the whole frame, so a backup can be replayed.
      final hex = rows.single.detail.split(' ').last;
      expect(hex, hasLength(600));
      expect(hex, startsWith('55aaeb90'));
      expect(rows.single.deviceId, 'JK1');
    });

    test('JK rejections written down are capped at 20 per connection',
        () async {
      await service.connect('JK1', name: 'KevinJK');
      link.announce(BleLinkState.connected);
      final corrupt = Uint8List.fromList(cellInfo24s[0])..[50] ^= 0xFF;
      for (var i = 0; i < 30; i++) {
        await link.deliver(corrupt);
      }
      await pumpEventQueue();
      expect(await eventsOf(LinkEventKind.jkFrameRejected), hasLength(20));
      expect(service.stats.badChecksum, 30);

      // A new connection gets its budget back.
      await service.connect('JK1', name: 'KevinJK');
      await link.deliver(corrupt);
      await pumpEventQueue();
      expect(await eventsOf(LinkEventKind.jkFrameRejected), hasLength(21));
    });

    test('bytes that never frame are written down until something frames',
        () async {
      await service.connect('JK1', name: 'KevinJK');
      link.announce(BleLinkState.connected);
      await link.deliver(Uint8List.fromList(List.generate(20, (i) => i + 1)));
      await pumpEventQueue();
      final before = await eventsOf(LinkEventKind.jkFrameRejected);
      expect(before, hasLength(1));
      // The last three bytes were held back in case a preamble straddled
      // the next chunk. None did, so they go when the frame's head arrives,
      // still before anything had framed.
      expect(before.single.detail, 'noPreamble 0102030405060708090a0b0c0d0e0f1011');
      await link.deliver(deviceInfoFrames[1]);
      await pumpEventQueue();
      final heldBack = await eventsOf(LinkEventKind.jkFrameRejected);
      expect(heldBack.map((e) => e.detail), contains('beforePreamble 121314'));

      // Once the pack has proved it speaks JK, junk around frames is padding
      // and cut-off tails, and writing it down would spend the budget on
      // every healthy connection.
      await link.deliver(Uint8List.fromList(List.generate(20, (i) => i + 1)));
      await link.deliver(cellInfo24s[0]);
      await pumpEventQueue();
      expect(await eventsOf(LinkEventKind.jkFrameRejected), hasLength(2));
    });

    test('a frame of a record type with no decoder is written down with its '
        'bytes', () async {
      await service.connect('JK1', name: 'KevinJK');
      link.announce(BleLinkState.connected);
      final odd = Uint8List.fromList(cellInfo24s[0]);
      odd[4] = 0x07;
      var sum = 0;
      for (var i = 0; i < odd.length - 1; i++) {
        sum = (sum + odd[i]) & 0xFF;
      }
      odd[odd.length - 1] = sum;
      await link.deliver(odd);
      await pumpEventQueue();

      final rows = await eventsOf(LinkEventKind.jkFrameUndecoded);
      expect(rows, hasLength(1));
      expect(rows.single.detail, contains('type=0x07'));
      expect(rows.single.detail.split(' ').last, hasLength(600));
    });

    test('frame counters are this connection\'s, and the total is kept '
        'separately', () async {
      // The connect screen's evidence line printed the assembler's lifetime
      // tally beside counters that restart on connect, so it could say
      // "3000 frames ok · 0 cell info" about a pack that had sent nothing.
      await service.connect('JK1', name: 'KevinJK');
      link.announce(BleLinkState.connected);
      await link.deliver(deviceInfoFrames[1]);
      await link.deliver(cellInfo24s[0]);
      final corrupt = Uint8List.fromList(cellInfo24s[1])..[50] ^= 0xFF;
      await link.deliver(corrupt);
      await pumpEventQueue();
      expect(service.stats.accepted, 2);
      expect(service.stats.badChecksum, 1);
      expect(service.stats.bytesReceived, 900);
      expect(service.bytesReceivedTotal, 900);

      await service.connect('JK1', name: 'KevinJK');
      expect(service.stats.accepted, 0);
      expect(service.stats.badChecksum, 0);
      expect(service.stats.unsupportedType, 0);
      expect(service.stats.bytesReceived, 0);
      expect(service.cellInfoFrames, 0);
      expect(service.bytesReceivedTotal, 900);

      link.announce(BleLinkState.connected);
      await link.deliver(cellInfo24s[2]);
      await pumpEventQueue();
      expect(service.stats.accepted, 1);
      expect(service.stats.bytesReceived, 300);
      expect(service.bytesReceivedTotal, 1200);
    });
  });
}
