import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/l10n/app_localizations_es.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/model/bms_warning.dart';
import 'package:jk_bms/src/ui/fault_history_screen.dart';
import 'package:jk_bms/src/ui/offline_pack_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';
import 'support/fakes.dart';
import 'support/stored_readings.dart';

void main() {
  late AppDatabase db;
  late BmsRepository repo;
  final t = AppL10nEs();
  final t0 = DateTime.utc(2026, 9, 20, 10);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = BmsRepository(database: db);
  });

  tearDown(() async {
    await repo.dispose();
    await db.close();
  });

  Future<void> fault(WidgetTester tester) => tester.runAsync(
    () => db.insertSnapshots([
      for (var i = 0; i < 20; i++)
        storedReading(
          deviceId: 'A',
          at: t0.add(Duration(seconds: i)),
          cells: cellsAt(3.40, {7: -0.200}),
          current: -38.5,
          soc: 11,
          warningsMask: i >= 5 && i < 12
              ? 1 << BmsWarning.cellUndervoltage.bit
              : 0,
        ),
    ]),
  );

  testWidgets('lists the fault in Spanish, with what the pack was doing', (
    tester,
  ) async {
    await fault(tester);
    final license = await unlockedLicense(tester);
    await tester.pumpWidget(
      harness(
        license,
        FaultHistoryScreen(
          repository: repo,
          deviceId: 'A',
          packName: 'KevinJK',
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(find.text(t.faultHistoryTitle), findsOneWidget);
    expect(find.text('CELDA POR DEBAJO DEL MÍNIMO'), findsOneWidget);
    expect(find.text('6 s'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('-38.5 A  ·  11 %'), findsOneWidget);
    expect(find.text(t.faultHistoryThinned), findsOneWidget);
  });

  testWidgets('says so when nothing was ever raised', (tester) async {
    final license = await unlockedLicense(tester);
    await tester.pumpWidget(
      harness(
        license,
        FaultHistoryScreen(
          repository: repo,
          deviceId: 'A',
          packName: 'KevinJK',
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text(t.faultHistoryEmpty), findsOneWidget);
  });

  testWidgets(
    'is reachable from the saved-pack screen, with nothing connected',
    (tester) async {
      await fault(tester);
      final now = DateTime.now().toUtc();
      await tester.runAsync(
        () => db.upsertDevice(
          DevicesCompanion.insert(id: 'A', firstSeenAt: now, lastSeenAt: now),
        ),
      );
      final device = (await tester.runAsync(() => db.device('A')))!;
      final service = BmsService(
        transport: FakeLink(),
        locationFactory: StubLocation.new,
      )..repository = repo;
      final license = await unlockedLicense(tester);
      await tester.pumpWidget(
        harness(license, OfflinePackScreen(service: service, device: device)),
      );
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      final button = find.text(t.faultHistoryTitle);
      await tester.scrollUntilVisible(
        button,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.byType(FaultHistoryScreen), findsOneWidget);
      expect(find.text('CELDA POR DEBAJO DEL MÍNIMO'), findsOneWidget);
      service.dispose();
    },
  );
}
