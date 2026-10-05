import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/l10n/app_localizations_en.dart';
import 'package:jk_bms/l10n/app_localizations_es.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/link_event.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/ui/link_event_labels.dart';
import 'package:jk_bms/src/ui/link_events_screen.dart';
import 'package:jk_bms/src/ui/live_console_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';
import 'support/fakes.dart';

/// The link log could only be read by exporting a backup and opening the
/// JSON.
void main() {
  final t = AppL10nEs();

  group('the detail', () {
    test('splits the reason from the bytes after it', () {
      final hex = 'aa5590eb' * 4;
      final d = splitLinkEventDetail('badChecksum $hex');
      expect(d.text, 'badChecksum');
      expect(d.hex, hex);
      expect(spacedHex(hex), 'AA 55 90 EB AA 55 90 EB AA 55 90 EB AA 55 90 EB');
    });

    test('leaves short codes and plain words in the text', () {
      final d = splitLinkEventDetail('unsupported type=0x05 after 12 s');
      expect(d.hex, isNull);
      expect(d.text, 'unsupported type=0x05 after 12 s');
    });

    test('every kind has a name in both languages', () {
      final en = AppL10nEn();
      for (final k in LinkEventKind.values) {
        expect(linkEventLabel(t, k), isNotEmpty);
        expect(linkEventLabel(en, k), isNotEmpty);
        expect(linkEventKindNamed(k.name), k);
      }
      expect(linkEventKindNamed('somethingNew'), isNull);
    });
  });

  group('the screen', () {
    late AppDatabase db;
    late BmsRepository repo;
    final clipboard = <String>[];

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = BmsRepository(database: db);
      final now = DateTime.now().toUtc();
      await db.upsertDevice(
        DevicesCompanion.insert(
          id: 'AA:BB',
          name: const Value('KevinJK'),
          firstSeenAt: now,
          lastSeenAt: now,
        ),
      );
      await repo.note(LinkEventKind.connectAttempt, detail: 'ok in 1.2 s');
      await repo.note(
        LinkEventKind.linkDropped,
        detail: 'up 340 s',
        deviceId: 'AA:BB',
      );
      await repo.note(
        LinkEventKind.jkFrameRejected,
        detail: 'badChecksum ${'aa5590eb' * 4}',
        deviceId: 'AA:BB',
      );
      await db.insertLinkEvent(
        LinkEventsCompanion.insert(at: now, kind: 'retiredKind'),
      );
    });

    tearDown(() async {
      await repo.dispose();
      await db.close();
    });

    Future<void> pump(WidgetTester tester, Widget home) async {
      clipboard.clear();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      final license = await unlockedLicense(tester);
      await tester.pumpWidget(harness(license, home));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    }

    testWidgets('lists every row newest first, in Spanish, with its pack', (
      tester,
    ) async {
      await pump(tester, LinkEventsScreen(repository: repo, deviceId: 'AA:BB'));
      expect(find.text(t.linkEventsTitle), findsOneWidget);
      expect(find.text(t.linkEventConnectAttempt), findsOneWidget);
      expect(find.text(t.linkEventLinkDropped), findsOneWidget);
      expect(find.text(t.linkEventJkFrameRejected), findsOneWidget);
      expect(find.text(t.linkEventsUnknownKind('retiredKind')), findsOneWidget);
      expect(find.text('KevinJK'), findsNWidgets(2));
      expect(find.text(t.linkEventsNoPack), findsNWidgets(2));
      expect(find.text(t.linkEventsCount(4)), findsOneWidget);

      // The bytes fold away under the reason, and open on a tap.
      expect(find.text('badChecksum'), findsOneWidget);
      expect(find.textContaining('AA 55 90 EB'), findsNothing);
      await tester.tap(find.text(t.linkEventsBytes(16)));
      await tester.pump();
      expect(find.textContaining('AA 55 90 EB'), findsOneWidget);
      await tester.tap(find.byTooltip(t.linkEventsCopyBytes));
      await tester.pump();
      expect(clipboard.last, startsWith('AA 55 90 EB'));
    });

    testWidgets('filters to this pack and to one kind, and copies what shows', (
      tester,
    ) async {
      await pump(tester, LinkEventsScreen(repository: repo, deviceId: 'AA:BB'));
      await tester.tap(find.text(t.linkEventsThisPack));
      await tester.pumpAndSettle();
      expect(find.text(t.linkEventsCount(2)), findsOneWidget);
      expect(find.text(t.linkEventConnectAttempt), findsNothing);

      await tester.tap(find.text(t.linkEventsAnyKind));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.linkEventLinkDropped).last);
      await tester.pumpAndSettle();
      expect(find.text(t.linkEventsCount(1)), findsOneWidget);

      await tester.tap(find.byTooltip(t.linkEventsCopyAll));
      await tester.pump();
      expect(clipboard.last, contains('linkDropped'));
      expect(clipboard.last, contains('up 340 s'));
      expect(clipboard.last, isNot(contains('connectAttempt')));
    });

    testWidgets('opens from the raw console', (tester) async {
      final service = BmsService(
        transport: FakeLink(),
        locationFactory: StubLocation.new,
      )..repository = repo;
      await pump(
        tester,
        LiveConsoleScreen(service: service, deviceName: 'KevinJK'),
      );
      await tester.tap(find.byTooltip(t.linkEventsTitle));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.byType(LinkEventsScreen), findsOneWidget);
      expect(find.text(t.linkEventLinkDropped), findsOneWidget);
      service.dispose();
    });
  });
}
