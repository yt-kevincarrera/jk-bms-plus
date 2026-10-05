import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/l10n/app_localizations_es.dart';
import 'package:jk_bms/src/app_settings.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/bms_write_gate.dart';
import 'package:jk_bms/src/ble/proximity_watcher.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/ui/app_settings_screen.dart';
import 'package:jk_bms/src/ui/locale_controller.dart';
import 'package:jk_bms/src/ui/tabs/system_tab.dart';
import 'package:jk_bms/src/update/app_version.dart';
import 'package:jk_bms/src/update/update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/real_kevinjk_frames.dart';
import 'support/app_harness.dart';
import 'support/fakes.dart';

/// The app is read-only again (owner, 2026-10-05). 2.29 shipped switch
/// writes behind a setting; the code stays, dormant, and nothing on screen
/// may offer it, whatever a phone that ran 2.29 has stored.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final t = AppL10nEs();

  Future<(BmsService, FakeLink)> connected() async {
    final link = FakeLink();
    final service = BmsService(
      transport: link,
      locationFactory: StubLocation.new,
    );
    await service.connect('C8:47:80:00:00:01', name: 'KevinJK');
    link.announce(BleLinkState.connected);
    await link.deliver(kevinJkDeviceInfo[0]);
    await link.deliver(kevinJkSettings[0]);
    await link.deliver(kevinJkCellInfo[0]);
    return (service, link);
  }

  test('the writes are not shipped in this build', () {
    expect(bmsWritesShipped, isFalse);
  });

  test('a permission stored as on by 2.29 is ignored, and stays out of a '
      'backup', () async {
    SharedPreferences.setMockInitialValues({'allow_bms_writes': true});
    final s = AppSettings();
    await s.load();
    expect(s.allowBmsWrites, isFalse);
    expect(s.toBackup().keys.where((k) => k.contains('Write')), isEmpty);
    // A backup that carries it anyway cannot switch it on either.
    final fresh = AppSettings();
    await fresh.restoreBackup({'allowBmsWrites': true});
    expect(fresh.allowBmsWrites, isFalse);
  });

  testWidgets('the System tab shows the switches as Sí/No rows, with no '
      'control and no write note', (tester) async {
    final (service, link) = (await tester.runAsync(connected))!;
    // As if 2.29 had left the permission on: it must change nothing here.
    final settings = AppSettings()..allowBmsWrites = true;
    service.bmsWritesAllowed = true;
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
            settings: settings,
            updateService: UpdateService(
              currentVersion: const AppVersion(2, 29, 1),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final list = find.byType(Scrollable).first;
    Future<void> see(String text) async {
      await tester.scrollUntilVisible(find.text(text), 200, scrollable: list);
      expect(find.text(text), findsOneWidget);
    }

    await see(t.systemSettingsTitle.toUpperCase());
    expect(t.systemSettingsTitle, contains('solo lectura'));
    for (final label in [
      t.configBalancerSwitch,
      t.configChargeSwitch,
      t.configDischargeSwitch,
    ]) {
      await see(label);
      // The real pack has all three on: a plain row saying so.
      final row = find.ancestor(of: find.text(label), matching: find.byType(Row));
      expect(
        find.descendant(of: row.first, matching: find.text(t.configOn)),
        findsOneWidget,
        reason: label,
      );
    }
    await see(t.systemReadOnlyNote);
    expect(t.systemReadOnlyNote, startsWith('La app no cambia nada en el BMS'));
    expect(find.byType(SwitchListTile), findsNothing);
    for (final name in ['charge', 'discharge', 'balancer']) {
      expect(find.byKey(ValueKey('bms-switch-$name')), findsNothing);
    }
    expect(find.text(t.systemWritesOnNote), findsNothing);
    expect(find.text(t.bmsSwitchesLocked), findsNothing);
    expect(link.registerWrites, isEmpty);
    service.dispose();
  });

  testWidgets('Settings has no "let the app change the BMS" row', (
    tester,
  ) async {
    final (service, _) = (await tester.runAsync(connected))!;
    final settings = AppSettings()..allowBmsWrites = true;
    final license = await unlockedLicense(tester);
    await tester.pumpWidget(
      harness(
        license,
        AppSettingsScreen(
          service: service,
          settings: settings,
          localeController: LocaleController(),
          updateService: UpdateService(
            currentVersion: const AppVersion(2, 29, 1),
          ),
        ),
      ),
    );
    await tester.pump();

    // Walk the whole screen, top to bottom.
    final list = find.byType(Scrollable).first;
    for (var i = 0; i < 40; i++) {
      expect(find.byKey(const ValueKey('allow-bms-writes')), findsNothing);
      expect(find.text(t.bmsWritesTitle), findsNothing);
      expect(find.text(t.settingsSectionBmsWrites), findsNothing);
      expect(find.text(t.settingsSectionBmsWrites.toUpperCase()), findsNothing);
      await tester.drag(list, const Offset(0, -400));
      await tester.pump();
    }
    service.dispose();
  });
}
