import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/l10n/app_localizations_es.dart';
import 'package:jk_bms/src/app_settings.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/proximity_watcher.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/model/ant_settings.dart';
import 'package:jk_bms/src/ui/app_settings_screen.dart';
import 'package:jk_bms/src/ui/locale_controller.dart';
import 'package:jk_bms/src/ui/tabs/system_tab.dart';
import 'package:jk_bms/src/update/app_version.dart';
import 'package:jk_bms/src/update/update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ant_settings_test.dart' show settingReply;
import 'fixtures/ant_frames.dart';
import 'support/app_harness.dart';
import 'support/fakes.dart';

/// What the System tab shows for an ANT, from the rider's own 20S capture.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final t = AppL10nEs();

  Future<(BmsService, FakeLink)> connected() async {
    final link = FakeLink();
    final service = BmsService(
      transport: link,
      locationFactory: StubLocation.new,
    );
    await service.connect('ANT1', name: 'ANT@BLE22AAUB');
    link.announce(BleLinkState.connected);
    await link.deliver(antInfo22ph);
    await link.deliver(antStatus20s4tCharging);
    return (service, link);
  }

  Future<void> pump(WidgetTester tester, BmsService service) async {
    final license = await unlockedLicense(tester);
    await tester.pumpWidget(
      harness(
        license,
        Scaffold(
          body: SystemTab(
            service: service,
            snapshot: service.lastSnapshot,
            link: BleLinkState.connected,
            localeController: LocaleController(),
            proximity: ProximityWatcher(),
            settings: AppSettings(),
            updateService: UpdateService(
              currentVersion: const AppVersion(2, 29, 1),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the cell type and the lifetime counters the BMS reports', (
    tester,
  ) async {
    final (service, _) = (await tester.runAsync(connected))!;
    expect(service.lastAntStatus, isNotNull);
    await pump(tester, service);

    final list = find.byType(Scrollable).first;
    Future<void> see(String text) async {
      await tester.scrollUntilVisible(find.text(text), 200, scrollable: list);
      expect(find.text(text), findsOneWidget);
    }

    await see(t.antStatusTitle.toUpperCase());
    await see(t.antBatteryType);
    await see(t.antBatteryTypeName('ternary'));
    await see(t.antTotalCharged);
    await see('5056.8 Ah');
    await see(t.antTotalDischarged);
    await see('4553.2 Ah');
    await see(t.antChargingTime);
    await see(t.antDischargingTime);
    service.dispose();
  });

  testWidgets('settings: pending until answered, then the answered rows only', (
    tester,
  ) async {
    final (service, link) = (await tester.runAsync(connected))!;
    await pump(tester, service);
    final list = find.byType(Scrollable).first;
    Future<void> see(String text) async {
      await tester.scrollUntilVisible(find.text(text), 200, scrollable: list);
      expect(find.text(text), findsOneWidget);
    }

    await see(t.antSettingsPending);
    expect(find.text(t.settingsNotExposed), findsNothing);

    await tester.runAsync(() async {
      await link.deliver(antSettingCellOvpReply);
      await link.deliver(settingReply(AntSetting.dischargeOcp, 1200));
    });
    await tester.pump();
    await see(t.settingCellOvp);
    await see('4.150 V');
    await see(t.settingMaxDischarge);
    await see('120.0 A');
    await see(t.antSettingsNote);
    expect(find.text(t.antSettingsPending), findsNothing);
    // Not answered, so not shown, rather than shown as zero.
    expect(find.text(t.settingCellUvp), findsNothing);
    service.dispose();
  });

  testWidgets('the near-limit alert is unavailable only until the ANT gives '
      'its limit', (tester) async {
    // Built inside runAsync: the database's work has to run on the real
    // clock, which the widget test's fake one never advances on its own.
    final (db, repo, link, service) = (await tester.runAsync(() async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = BmsRepository(database: db);
      final link = FakeLink();
      final service = BmsService(
        transport: link,
        locationFactory: StubLocation.new,
      )..repository = repo;
      await service.connect('ANT1', name: 'ANT@BLE22AAUB');
      link.announce(BleLinkState.connected);
      await link.deliver(antInfo22ph);
      await link.deliver(antStatus20s4tCharging);
      await pumpEventQueue();
      return (db, repo, link, service);
    }))!;
    expect(service.activeDevice, isNotNull);

    Future<bool> hintShown() async {
      final license = await unlockedLicense(tester);
      await tester.pumpWidget(
        harness(
          license,
          AppSettingsScreen(
            service: service,
            settings: AppSettings(),
            localeController: LocaleController(),
            updateService: UpdateService(
              currentVersion: const AppVersion(2, 29, 1),
            ),
          ),
        ),
      );
      await tester.pump();
      final list = find.byType(Scrollable).first;
      for (var i = 0; i < 40; i++) {
        if (find.text(t.alertNearLimitUnavailable).evaluate().isNotEmpty) {
          return true;
        }
        await tester.drag(list, const Offset(0, -400));
        await tester.pump();
      }
      return false;
    }

    expect(await hintShown(), isTrue);
    await tester.runAsync(
      () => link.deliver(settingReply(AntSetting.dischargeOcp, 1200)),
    );
    expect(await hintShown(), isFalse);
    await tester.runAsync(() async {
      await service.dispose();
      await repo.dispose();
      await db.close();
    });
  });
}
