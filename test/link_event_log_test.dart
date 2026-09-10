import 'dart:io';

import 'package:drift/drift.dart' show Value;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/backup.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/link_event.dart';
import 'package:jk_bms/src/data/repository.dart';

void main() {
  // Why this table exists. Three problems were open at once, all of them only
  // reproducible on a moving motorcycle with the phone in a pocket: a ride
  // that never started itself, a link that dropped and never came back, and a
  // phone that sometimes needed restarting before it would connect. Each was
  // argued from the source, and the first confident answer, a missing
  // background location permission, turned out to be wrong.
  //
  // So the log has one job: reach somebody who can read it. A row written and
  // then lost on the way out is worth nothing, which is what these check.

  late AppDatabase db;
  late BmsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = BmsRepository(database: db);
  });

  tearDown(() async {
    await repo.dispose();
    await db.close();
  });

  test('a decision is written straight through, not buffered', () async {
    // Readings are batched on a five second timer, and that is right for them.
    // It is wrong here: a log's whole value is that the last row before things
    // went quiet survived, and a buffer is exactly what loses that row.
    await repo.note(
      LinkEventKind.linkDropped,
      detail: '1840s up, recording: true',
      deviceId: 'AA:BB',
    );

    final rows = await repo.recentLinkEvents();
    expect(rows, hasLength(1));
    expect(rows.single.kind, 'linkDropped');
    expect(rows.single.detail, '1840s up, recording: true');
    expect(rows.single.deviceId, 'AA:BB');
  });

  test('a write that fails does not take the ride down with it', () async {
    // The log exists to explain a problem. One that can itself break the ride
    // it is recording would be worse than no log at all.
    await db.close();
    await expectLater(repo.note(LinkEventKind.linkDropped), completes);
    // Reopened so tearDown has something to close.
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  test('the newest rows come back first', () async {
    await repo.note(LinkEventKind.autoTripStarted);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await repo.note(LinkEventKind.linkDropped);

    final rows = await repo.recentLinkEvents();
    expect(rows.first.kind, 'linkDropped');
  });

  test('the log leaves in the backup, which is the file a rider can share',
      () async {
    await repo.note(
      LinkEventKind.ridingCurrentSeen,
      detail: '-12.4',
      deviceId: 'AA:BB',
    );
    await repo.note(LinkEventKind.reconnectGaveUp, detail: 'failures: 12');

    final dir = await Directory.systemTemp.createTemp('jk-log-backup');
    addTearDown(() => dir.delete(recursive: true));
    final file = await BackupCodec(db).export(into: dir);

    final fresh = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(fresh.close);
    await BackupCodec(fresh).import(file);

    final restored = await fresh.recentLinkEvents();
    expect(restored.map((e) => e.kind), containsAll(<String>[
      'ridingCurrentSeen',
      'reconnectGaveUp',
    ]));
    expect(
      restored.firstWhere((e) => e.kind == 'ridingCurrentSeen').detail,
      '-12.4',
    );
  });

  test('a kind this build has never heard of survives the round trip',
      () async {
    // A log restored from a newer build may name a decision this one does not
    // make. Dropping those rows would quietly delete the most interesting half
    // of somebody's bug report, so the column is text and it stays text.
    await db.insertLinkEvent(
      LinkEventsCompanion.insert(
        at: DateTime.utc(2026, 9, 10, 12),
        kind: 'somethingFromTheFuture',
        detail: const Value('unknown to this build'),
      ),
    );

    final dir = await Directory.systemTemp.createTemp('jk-log-future');
    addTearDown(() => dir.delete(recursive: true));
    final file = await BackupCodec(db).export(into: dir);

    final fresh = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(fresh.close);
    await BackupCodec(fresh).import(file);

    final restored = await fresh.recentLinkEvents();
    expect(restored.single.kind, 'somethingFromTheFuture');
  });

  test('old rows are dropped, recent ones kept', () async {
    await db.insertLinkEvent(
      LinkEventsCompanion.insert(
        at: DateTime.now().toUtc().subtract(const Duration(days: 30)),
        kind: 'linkDropped',
      ),
    );
    await repo.note(LinkEventKind.linkDropped);

    final removed = await repo.pruneLinkEvents();
    expect(removed, 1);
    expect(await repo.recentLinkEvents(), hasLength(1));
  });
}
