import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/l10n/app_localizations_es.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/pack/pack_baseline.dart';
import 'package:jk_bms/src/ui/pack/pack_profile_card.dart';
import 'package:jk_bms/src/ui/pack/pack_profile_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/captured_frames.dart';
import 'fixtures/snapshot_builder.dart';
import 'support/app_harness.dart';
import 'support/fakes.dart';

/// The day-one baseline had a note column, a note setter and a delete, and
/// nothing on screen called any of them. Worse, the profile sheet offered to
/// capture a baseline every time it opened, ticked, so editing a pack's name
/// replaced its day one with today and wiped the note.
void main() {
  late AppDatabase db;
  late BmsRepository repo;
  late BmsService service;
  final t = AppL10nEs();
  final dayOne = DateTime.utc(2026, 3, 14, 10);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final link = FakeLink();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = BmsRepository(database: db);
    service = BmsService(transport: link, locationFactory: StubLocation.new)
      ..repository = repo;
    await service.connect('AA:BB', name: 'KevinJK');
    await link.deliver(deviceInfoFrames[1]);
    await link.deliver(cellInfo24s[0]);
    await repo.saveBaseline(
      service.activeDeviceId!,
      PackBaseline.capture(
        snapshot: buildSnapshot(timestamp: dayOne, current: 0),
        at: dayOne,
      ),
      note: 'Comprada usada a un vecino',
    );
  });

  tearDown(() async {
    service.dispose();
    await repo.dispose();
    await db.close();
  });

  test('redoing the day one replaces it and keeps the note', () async {
    final id = service.activeDeviceId!;
    final now = DateTime.utc(2026, 10, 1, 9);
    await repo.redoBaseline(
      id,
      PackBaseline.capture(
        snapshot: buildSnapshot(timestamp: now),
        at: now,
      ),
    );
    expect((await repo.baseline(id))!.capturedAt, now);
    expect(await repo.baselineNote(id), 'Comprada usada a un vecino');
    expect(await db.allBaselines(), hasLength(1));
  });

  Future<void> pumpCard(WidgetTester tester) async {
    final license = await unlockedLicense(tester);
    await tester.pumpWidget(
      harness(
        license,
        Scaffold(
          body: SingleChildScrollView(child: PackProfileCard(service: service)),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  testWidgets('the card shows the note, and edits it', (tester) async {
    await pumpCard(tester);
    expect(find.text('Comprada usada a un vecino'), findsOneWidget);

    await tester.tap(find.text(t.profileBaselineNoteEdit));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Del taller de Pepe');
    await tester.tap(find.text(t.profileSave));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(
      await tester.runAsync(() => repo.baselineNote(service.activeDeviceId!)),
      'Del taller de Pepe',
    );
    expect(find.text('Del taller de Pepe'), findsOneWidget);
  });

  testWidgets('redo asks first, says what goes, and recaptures from now', (
    tester,
  ) async {
    await pumpCard(tester);
    await tester.tap(find.text(t.profileBaselineRedo));
    await tester.pumpAndSettle();

    // The dialog names the day one being thrown away.
    expect(find.text(t.profileBaselineRedoTitle), findsOneWidget);
    expect(find.textContaining('14/03/2026'), findsWidgets);

    // Cancelling keeps it.
    await tester.tap(find.text(t.cancel));
    await tester.pumpAndSettle();
    final id = service.activeDeviceId!;
    expect(
      (await tester.runAsync(() => repo.baseline(id)))!.capturedAt,
      dayOne,
    );

    await tester.tap(find.text(t.profileBaselineRedo));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.profileBaselineRedoConfirm));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    final fresh = (await tester.runAsync(() => repo.baseline(id)))!;
    expect(fresh.capturedAt, isNot(dayOne));
    expect(
      await tester.runAsync(() => repo.baselineNote(id)),
      'Comprada usada a un vecino',
    );
    expect(find.text(t.profileBaselineRedone), findsOneWidget);
  });

  testWidgets('saving the profile sheet leaves an existing day one alone', (
    tester,
  ) async {
    final id = service.activeDeviceId!;
    final device = (await tester.runAsync(() => repo.device(id)))!;
    final license = await unlockedLicense(tester);
    await tester.pumpWidget(
      harness(
        license,
        Scaffold(
          body: PackProfileSheet(service: service, device: device),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    // Not offered: there already is one.
    expect(find.text(t.profileCaptureBaseline), findsNothing);

    await tester.ensureVisible(find.text(t.profileSave));
    await tester.tap(find.text(t.profileSave));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(
      (await tester.runAsync(() => repo.baseline(id)))!.capturedAt,
      dayOne,
    );
    expect(
      await tester.runAsync(() => repo.baselineNote(id)),
      'Comprada usada a un vecino',
    );
  });
}
