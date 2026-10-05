import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/l10n/app_localizations_es.dart';
import 'package:jk_bms/src/app_settings.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/proximity_watcher.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/ui/locale_controller.dart';
import 'package:jk_bms/src/ui/tabs/system_tab.dart';
import 'package:jk_bms/src/update/app_version.dart';
import 'package:jk_bms/src/update/update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}
