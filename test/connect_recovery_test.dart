import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/connect_recovery.dart';

import 'support/fake_radio.dart';

void main() {
  // Why this exists. A rider's phone would not connect the morning after a
  // normal evening disconnect, with the pack beside it: retries did nothing, a
  // Bluetooth toggle did nothing, a phone restart fixed it. The errors were
  // Android's GATT 147 and an MTU request on a link already gone. Nothing in
  // the app wrote down what each attempt could see, and nothing did anything
  // differently on the fifth attempt than on the first.

  const id = 'C8:47:80:00:00:01';
  const gatt147 = 'FlutterBluePlusException | connect | android-code: 147 | '
      'GATT_CONNECTION_TIMEOUT';

  late FakeRecoveryRadio radio;
  late AdvertBook book;
  late InMemoryRecoveryMemory memory;
  late DateTime now;
  late ConnectRecovery recovery;
  late List<RecoveryEvent> events;

  ConnectRecovery build({Future<DateTime?> Function()? bootTime}) {
    final r = ConnectRecovery(
      radio: radio,
      adverts: book,
      memory: memory,
      bootTime: bootTime,
      now: () => now,
      releasePause: const Duration(milliseconds: 1),
      holdFor: const Duration(milliseconds: 30),
    );
    r.events.listen(events.add);
    return r;
  }

  setUp(() {
    radio = FakeRecoveryRadio();
    book = AdvertBook();
    memory = InMemoryRecoveryMemory();
    now = DateTime(2026, 10, 1, 7, 30);
    events = [];
    recovery = build();
  });

  tearDown(() => recovery.dispose());

  List<ConnectAttemptRecord> records() => [
    for (final e in events)
      if (e is AttemptRecorded) e.record,
  ];

  /// One attempt that fails with [error].
  Future<PreparedAttempt> failOnce([String error = gatt147]) async {
    final a = recovery.begin(id);
    await recovery.prepare(a, stillWanted: () => true);
    now = now.add(const Duration(seconds: 3));
    recovery.failed(a, error);
    return a;
  }

  group('what runs before each attempt, in order', () {
    test('the first two attempts are plain, the third releases and waits '
        'for an advert with a longer timeout', () async {
      final first = await failOnce();
      expect(first.escalated, isFalse);
      expect(first.connectTimeout, const Duration(seconds: 8));
      final second = await failOnce();
      expect(second.escalated, isFalse);
      expect(radio.log, isEmpty);

      final third = recovery.begin(id);
      expect(third.number, 3);
      expect(third.escalated, isTrue);
      expect(third.connectTimeout, const Duration(seconds: 15));
      await recovery.prepare(third, stillWanted: () => true);
      expect(radio.log, ['release $id', 'freshAdvert $id 8s']);
    });

    test('a link the phone still lists is joined and let go of, between the '
        'release and the scan', () async {
      await failOnce();
      await failOnce();
      radio.systemIds = [id];
      final a = recovery.begin(id);
      await recovery.prepare(a, stillWanted: () => true);
      expect(radio.log, [
        'release $id',
        'closeStranded $id',
        'freshAdvert $id 8s',
      ]);
      expect(a.steps.join(' '), contains('close stranded'));
    });

    test('a pack the phone was found holding is released on the very next '
        'attempt, without waiting for failures', () async {
      recovery.suspectStranded(id);
      radio.appIds = [id];
      final a = recovery.begin(id);
      expect(a.escalated, isFalse);
      expect(a.releases, isTrue);
      await recovery.prepare(a, stillWanted: () => true);
      expect(radio.log, ['release $id', 'closeStranded $id']);
      // Once: the attempt after it is ordinary again.
      radio.log.clear();
      recovery.failed(a, 'Bluetooth must be turned on');
      final b = recovery.begin(id);
      await recovery.prepare(b, stillWanted: () => true);
      expect(radio.log, isEmpty);
    });

    test('a rider who let go stops the preparation short', () async {
      await failOnce();
      await failOnce();
      final a = recovery.begin(id);
      await recovery.prepare(a, stillWanted: () => false);
      expect(radio.log, ['release $id']);
    });

    test('last night\'s failures do not escalate this morning', () async {
      await failOnce();
      await failOnce();
      now = now.add(const Duration(minutes: 31));
      final a = recovery.begin(id);
      expect(a.number, 1);
      expect(a.escalated, isFalse);
    });
  });

  group('what counts towards the streak', () {
    test('147, 133 and a timeout count; a switched-off adapter does not',
        () async {
      await failOnce('Bluetooth must be turned on');
      expect(recovery.failuresFor(id), 0);
      await failOnce(gatt147);
      await failOnce('FlutterBluePlusException | connect | android-code: 133 | '
          'GATT_ERROR');
      await failOnce('FlutterBluePlusException | connect | fbp-code: 1 | '
          'Timed out after 8s');
      expect(recovery.failuresFor(id), 3);
      expect(records().map((r) => r.counted), [false, true, true, true]);
      expect(records().last.outcome, AttemptOutcome.timedOut);
    });

    test('an MTU refusal on a link that is already gone counts as a drop '
        'right after connecting', () async {
      final a = recovery.begin(id);
      await recovery.prepare(a, stillWanted: () => true);
      recovery.linkUp(a);
      recovery.failed(
        a,
        'FlutterBluePlusException | requestMtu | fbp-code: 6 | Device is '
        'disconnected',
      );
      final r = records().single;
      expect(r.outcome, AttemptOutcome.droppedAfterConnect);
      expect(r.counted, isTrue);
    });

    test('a link that goes within the hold time counts; one that holds '
        'clears the streak', () async {
      final a = recovery.begin(id);
      await recovery.prepare(a, stillWanted: () => true);
      recovery.linkUp(a);
      recovery.connected(a);
      recovery.dropped();
      expect(records().single.outcome, AttemptOutcome.droppedAfterConnect);
      expect(recovery.failuresFor(id), 1);

      final b = recovery.begin(id);
      await recovery.prepare(b, stillWanted: () => true);
      recovery.linkUp(b);
      recovery.connected(b);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(records().last.outcome, AttemptOutcome.connected);
      expect(recovery.failuresFor(id), 0);
      // A drop long after is a drop, not a failed attempt.
      recovery.dropped();
      expect(records(), hasLength(2));
    });

    test('an attempt let go of on purpose is written down and not counted',
        () async {
      final a = recovery.begin(id);
      await recovery.prepare(a, stillWanted: () => true);
      recovery.cancelled(a);
      recovery.cancelled(a);
      expect(records().single.outcome, AttemptOutcome.cancelled);
      expect(records().single.counted, isFalse);
      expect(recovery.failuresFor(id), 0);
    });
  });

  group('when the phone looks stuck', () {
    test('four failures in a row say so, once', () async {
      for (var i = 0; i < 3; i++) {
        await failOnce();
      }
      expect(recovery.looksStuck, isFalse);
      await failOnce();
      expect(recovery.looksStuck, isTrue);
      await failOnce();
      expect(events.whereType<StuckDeclared>(), hasLength(1));
      expect(events.whereType<StuckDeclared>().single.failures, 4);
    });

    test('the in-app reset hides the card until the next failure, and the '
        'recovery says it was tried', () async {
      for (var i = 0; i < 4; i++) {
        await failOnce();
      }
      await recovery.resetEverything();
      expect(radio.log.last, 'resetAll');
      expect(recovery.looksStuck, isFalse);
      expect(
        events.whereType<RemedyTaken>().single.remedy,
        BluetoothRemedy.inAppReset,
      );
      await failOnce();
      expect(recovery.looksStuck, isTrue);

      final a = recovery.begin(id);
      await recovery.prepare(a, stillWanted: () => true);
      recovery.linkUp(a);
      recovery.connected(a);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final back = events.whereType<RecoveredAfterStuck>().single;
      expect(back.detail, contains('inAppReset'));
      expect(recovery.looksStuck, isFalse);
      expect(memory.values, isNot(contains('ble_stuck_since')));
    });

    test('a Bluetooth toggle while stuck is noticed without being told',
        () async {
      for (var i = 0; i < 4; i++) {
        await failOnce();
      }
      radio.adapterChanges
        ..add('turningOff')
        ..add('off')
        ..add('turningOn')
        ..add('on');
      expect(
        events.whereType<RemedyTaken>().map((e) => e.remedy),
        [BluetoothRemedy.bluetoothToggled],
      );
    });

    test('the next process notices it was restarted, or that the phone was',
        () async {
      for (var i = 0; i < 4; i++) {
        await failOnce();
      }
      await recovery.dispose();
      final stuckAt = now;

      // Force-stopped and reopened: the phone has been up since before.
      now = now.add(const Duration(minutes: 5));
      events = [];
      recovery = build(
        bootTime: () async => stuckAt.subtract(const Duration(days: 3)),
      );
      await recovery.load();
      expect(
        events.whereType<RemedyTaken>().single.remedy,
        BluetoothRemedy.appRestarted,
      );
      // Not on screen until something fails in this process too.
      expect(recovery.looksStuck, isFalse);
      await recovery.dispose();

      // Then the phone was restarted.
      now = now.add(const Duration(minutes: 5));
      events = [];
      recovery = build(
        bootTime: () async => stuckAt.add(const Duration(minutes: 8)),
      );
      await recovery.load();
      expect(
        events.whereType<RemedyTaken>().single.remedy,
        BluetoothRemedy.phoneRestarted,
      );
      expect(recovery.remedies.join(' '), contains('appRestarted'));
      expect(recovery.remedies.join(' '), contains('phoneRestarted'));
    });

    test('a stuck judgement from days ago is forgotten', () async {
      memory.values['ble_stuck_since'] = now
          .subtract(const Duration(days: 2))
          .toUtc()
          .toIso8601String();
      await recovery.load();
      expect(events, isEmpty);
      expect(memory.values, isNot(contains('ble_stuck_since')));
    });
  });

  group('what an attempt record says', () {
    test('whether the pack was heard, and what the phone listed', () async {
      book.saw(id, rssi: -61, at: now.subtract(const Duration(seconds: 3)));
      radio.systemIds = ['AA:AA:AA:AA:AA:AA', id];
      await failOnce();
      final d = records().single.detail;
      expect(d, startsWith('#1 failed in 3000 ms: '));
      expect(d, contains('advert -61 dBm 3 s before'));
      expect(d, contains('system connected 2 (ours yes)'));
      expect(d, contains('app connected 0 (ours no)'));
      expect(d, contains('adapter on'));
      expect(d, contains('android-code: 147'));
      expect(d, contains('uptime'));
      expect(d, contains('no success on record'));
    });

    test('a pack not heard in the last minute, and one never heard', () async {
      book.saw('other', rssi: -40, at: now);
      await failOnce();
      expect(records().last.detail, contains('advert never heard'));
      book.saw(id, rssi: -70, at: now.subtract(const Duration(minutes: 5)));
      await failOnce();
      expect(records().last.detail, contains('no advert in the last 60 s'));
    });

    test('the escalated attempt names what ran before it', () async {
      await failOnce();
      await failOnce();
      radio.advert = AdvertSighting(rssi: -58, at: now);
      await failOnce();
      final d = records().last.detail;
      expect(d, startsWith('#3 '));
      expect(d, contains('before it: release, advert heard after'));
      expect(d, contains('timeout 15 s'));
    });
  });

  group('the hourly budget', () {
    test('thirty an hour, and the next one after says how many were skipped',
        () {
      final budget = AttemptBudget();
      final t = DateTime(2026, 10, 1, 7);
      for (var i = 0; i < 30; i++) {
        expect(budget.admit(t.add(Duration(seconds: i))), 0);
      }
      expect(budget.admit(t.add(const Duration(seconds: 40))), isNull);
      expect(budget.admit(t.add(const Duration(seconds: 50))), isNull);
      expect(budget.admit(t.add(const Duration(minutes: 61))), 2);
    });
  });

  group('the advert book', () {
    test('keeps the newest sighting and ignores the plugin\'s repeats', () {
      final t = DateTime(2026, 10, 1, 7);
      book.saw(id, rssi: -60, at: t);
      book.saw(id, rssi: -90, at: t);
      book.saw(id, rssi: -50, at: t.subtract(const Duration(seconds: 1)));
      expect(book.lastSeen(id)!.rssi, -60);
      book.saw(id, rssi: -55, at: t.add(const Duration(seconds: 1)));
      expect(book.lastSeen(id)!.rssi, -55);
    });

    test('forgets the oldest past its capacity', () {
      final small = AdvertBook(capacity: 2);
      final t = DateTime(2026, 10, 1, 7);
      small
        ..saw('a', rssi: -1, at: t)
        ..saw('b', rssi: -1, at: t)
        ..saw('c', rssi: -1, at: t);
      expect(small.lastSeen('a'), isNull);
      expect(small.lastSeen('c'), isNotNull);
    });
  });
}
