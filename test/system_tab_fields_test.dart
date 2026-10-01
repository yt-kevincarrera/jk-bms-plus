import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/l10n/app_localizations_en.dart';
import 'package:jk_bms/l10n/app_localizations_es.dart';
import 'package:jk_bms/src/app_settings.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/proximity_watcher.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/ui/bms_code_labels.dart';
import 'package:jk_bms/src/ui/locale_controller.dart';
import 'package:jk_bms/src/ui/tabs/system_tab.dart';
import 'package:jk_bms/src/update/app_version.dart';
import 'package:jk_bms/src/update/update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/real_kevinjk_frames.dart';
import 'support/app_harness.dart';
import 'support/fakes.dart';

/// The parser decodes every field of the settings and cell info frames, and
/// the System tab used to show about half of them: every delay and recovery,
/// the short-circuit timing, the lead resistances, the settings passcode, the
/// precharge and charger flags, the charge phase, the battery type, the
/// runtime, the cell mask and the throughput counter were read and dropped.
/// The switches it did show were labelled in English whatever the language.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<BmsService> connected() async {
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
    return service;
  }

  testWidgets('shows the real pack\'s hidden settings, grouped, in Spanish', (
    tester,
  ) async {
    final service = (await tester.runAsync(connected))!;
    expect(service.lastSettings, isNotNull);
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
              currentVersion: const AppVersion(2, 28, 1),
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

    final t = AppL10nEs();
    await see(t.bmsStateTitle.toUpperCase());
    await see(t.bmsStateRuntime);
    await see(t.bmsStateEnabledCells);
    // Twenty cells enabled on the real pack, and the mask shown beside it.
    expect(find.textContaining('20  ·  0x'), findsOneWidget);
    await see(t.bmsStateCycleCapacity);
    await see(t.settingsGroupCell.toUpperCase());
    await see(t.settingSmartSleep);
    await see(t.settingsGroupCurrent.toUpperCase());
    await see(t.settingChargeOcpDelay);
    await see(t.settingScpDelay);
    await see(t.settingsGroupTemperature.toUpperCase());
    await see(t.settingMosfetOtpRecovery);
    await see(t.settingsGroupBalance.toUpperCase());
    await see(t.settingsGroupOther.toUpperCase());
    await see(t.settingRequestFloat);
    await see(t.settingWireResistances);
    // The switches by name, with Sí/No: never the English words.
    await see(t.configChargeSwitch);
    expect(find.textContaining('charge /'), findsNothing);
    expect(find.text('discharge'), findsNothing);

    service.dispose();
  });

  test('the BMS codes read as words, and an unknown one as its code', () {
    final es = AppL10nEs();
    final en = AppL10nEn();
    expect(chargeStatusLabel(es, 1), 'absorción');
    expect(chargeStatusLabel(en, 2), 'float');
    expect(chargeStatusLabel(es, 7), 'código 7');
    expect(batteryTypeLabel(es, 0), 'LFP (LiFePO4)');
    expect(batteryTypeLabel(en, 1), 'Li-ion');
    expect(batteryTypeLabel(en, 9), 'code 9');
  });
}
