import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/bms_link.dart';
import 'package:jk_bms/src/ble/link_trouble.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/link_event.dart';
import 'package:jk_bms/src/data/repository.dart';

import 'fixtures/captured_frames.dart';
import 'support/fakes.dart';

void main() {
  // Why this exists. The transport judged a link alive by bytes: any
  // notification at all reset its silence clock and its failure ledger. The
  // rider's report was a link that came back after a drop, the banner going
  // away, and every value on screen frozen for good; on the connect screen the
  // same pack produced "connected, bytes arriving, none decode". Bytes that
  // never become a frame are not a pack talking, and a link judged by them
  // never lets go. So the service, which is the only thing that knows whether
  // a frame decoded, tells the link when one did.
  //
  // The second half is the log. Four kinds of link event were defined for
  // exactly this report (an attempt, a failure, giving up, letting go of a
  // mute link) and nothing ever wrote them, so a backup could not say whether
  // the reconnect ran and found silence or never ran at all.

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

  Future<List<LinkEvent>> events() => repo.recentLinkEvents();

  /// A link that came up and proved itself with a reading.
  Future<void> liveLink() async {
    await service.connect('AA:BB', name: 'KevinJK');
    link.announce(BleLinkState.connected);
    await link.deliver(deviceInfoFrames[1]);
    await link.deliver(cellInfo24s[0]);
    await pumpEventQueue();
  }

  group('what proves the pack is talking', () {
    test('a frame that decodes is reported to the link', () async {
      await service.connect('AA:BB', name: 'KevinJK');
      await link.deliver(deviceInfoFrames[1]);
      expect(link.framesHeard, 1);
      await link.deliver(cellInfo24s[0]);
      expect(link.framesHeard, 2);
    });

    test('bytes that never become a frame are not', () async {
      await service.connect('AA:BB', name: 'KevinJK');
      await link.deliver(Uint8List.fromList(List.filled(300, 0x42)));
      expect(service.stats.bytesReceived, 300);
      expect(link.framesHeard, 0);
    });

    test('a frame with a bad checksum is not', () async {
      await service.connect('AA:BB', name: 'KevinJK');
      final corrupt = Uint8List.fromList(cellInfo24s[0]);
      corrupt[100] ^= 0xFF;
      await link.deliver(corrupt);
      expect(service.stats.badChecksum, 1);
      expect(link.framesHeard, 0);
    });

    test('a frame of a kind this app does not decode still counts', () async {
      // The pack is talking JK; whether the app understands the record type
      // is the app's problem, not a reason to drop the link.
      await service.connect('AA:BB', name: 'KevinJK');
      final unknownType = Uint8List.fromList(cellInfo24s[0]);
      unknownType[4] = 0x07;
      // Re-seal it: the last byte is a running sum of the ones before.
      var sum = 0;
      for (var i = 0; i < 299; i++) {
        sum = (sum + unknownType[i]) & 0xFF;
      }
      unknownType[299] = sum;
      await link.deliver(unknownType);
      expect(service.stats.accepted, 1);
      expect(link.framesHeard, 1);
    });
  });

  group('what the log says about a reconnect', () {
    test('the first connect is not a reconnect', () async {
      await service.connect('AA:BB', name: 'KevinJK');
      link.announce(BleLinkState.connecting);
      link.announce(BleLinkState.connected);
      await pumpEventQueue();

      final kinds = (await events()).map((e) => e.kind);
      expect(kinds, isNot(contains(LinkEventKind.reconnectAttempted.name)));
    });

    test('an attempt after a drop is written down, numbered', () async {
      await liveLink();
      link.announce(BleLinkState.reconnecting);
      link.announce(BleLinkState.connecting);
      await pumpEventQueue();

      final rows = await events();
      final attempt = rows.firstWhere(
        (e) => e.kind == LinkEventKind.reconnectAttempted.name,
      );
      expect(attempt.detail, contains('attempt 1'));
      expect(attempt.deviceId, 'AA:BB');
      expect(
        rows.map((e) => e.kind),
        contains(LinkEventKind.linkDropped.name),
      );
    });

    test('a failure carries the radio\'s own words', () async {
      await liveLink();
      link.announce(BleLinkState.reconnecting);
      link.announce(BleLinkState.connecting);
      link.announce(BleLinkState.failed);
      link.fail(
        BleLinkError.from(
          Exception('FlutterBluePlusException | connect | android-code: 133'),
        ),
      );
      await pumpEventQueue();

      final failed = (await events()).firstWhere(
        (e) => e.kind == LinkEventKind.reconnectFailed.name,
      );
      expect(failed.detail, contains('android-code: 133'));
    });

    test('a smaller packet size is not a failure', () async {
      await liveLink();
      link.announce(BleLinkState.reconnecting);
      link.fail(
        const BleLinkError(
          'MTU stayed at 23 bytes',
          trouble: LinkTrouble(LinkTroubleKind.slowFrames, detail: 'mtu'),
        ),
      );
      await pumpEventQueue();

      final kinds = (await events()).map((e) => e.kind);
      expect(kinds, isNot(contains(LinkEventKind.reconnectFailed.name)));
    });

    test('the loop giving up is written down once', () async {
      await liveLink();
      link.announce(BleLinkState.reconnecting);
      link.retry = const LinkRetryState(failures: 12, gaveUp: true);
      link.announce(BleLinkState.failed);
      await pumpEventQueue();
      // The transport restates `failed` on the way out of every later call;
      // the decision was made once.
      link.announce(BleLinkState.failed);
      await pumpEventQueue();

      final rows = (await events())
          .where((e) => e.kind == LinkEventKind.reconnectGaveUp.name)
          .toList();
      expect(rows, hasLength(1));
      expect(rows.single.detail, contains('12'));
    });

    test('letting go of a mute link is written down with what arrived',
        () async {
      await liveLink();
      const detail = 'connected, 21 s without a frame, 300 bytes arrived, '
          '3 nudge(s) unanswered';
      link.fail(
        const BleLinkError(
          detail,
          trouble: LinkTrouble(LinkTroubleKind.packMute, detail: detail),
        ),
      );
      await pumpEventQueue();

      final row = (await events()).firstWhere(
        (e) => e.kind == LinkEventKind.muteLinkReleased.name,
      );
      expect(row.detail, contains('300 bytes'));
      expect(row.deviceId, 'AA:BB');
    });

    test('nothing is written about a link the rider let go of', () async {
      await liveLink();
      await service.disconnect();
      link.announce(BleLinkState.idle);
      link.announce(BleLinkState.failed);
      await pumpEventQueue();

      final kinds = (await events()).map((e) => e.kind).toSet();
      expect(kinds, isNot(contains(LinkEventKind.reconnectAttempted.name)));
      expect(kinds, isNot(contains(LinkEventKind.reconnectFailed.name)));
      expect(kinds, isNot(contains(LinkEventKind.linkDropped.name)));
    });
  });

  group('what the console can show after the fact', () {
    test('link errors are kept, newest first, across attempts', () async {
      // The console used to show only what happened after it was opened, and
      // it could only be opened from a screen a failed connect never reaches.
      await service.connect('AA:BB', name: 'KevinJK');
      link.fail(BleLinkError.from(Exception('android-code: 133')));
      await pumpEventQueue();
      await service.disconnect();
      await service.connect('AA:BB', name: 'KevinJK');
      link.fail(BleLinkError.from(Exception('android-code: 8')));
      await pumpEventQueue();

      final texts = service.recentNotices.map((n) => n.text).toList();
      expect(texts.first, contains('android-code: 8'));
      expect(texts, anyElement(contains('android-code: 133')));
    });

    test('and so are the app\'s own notices', () async {
      await service.connect('AA:BB', name: 'KevinJK');
      final unsupported = Uint8List.fromList(cellInfo24s[0]);
      unsupported[4] = 0x07;
      var sum = 0;
      for (var i = 0; i < 299; i++) {
        sum = (sum + unsupported[i]) & 0xFF;
      }
      unsupported[299] = sum;
      await link.deliver(unsupported);

      expect(
        service.recentNotices.map((n) => n.text),
        anyElement(contains('unsupported record type')),
      );
      expect(service.recentNotices.first.at, isNotNull);
    });
  });
}
