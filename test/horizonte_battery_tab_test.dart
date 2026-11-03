import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/l10n/app_localizations_es.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/ui/tabs/battery_tab.dart';
import 'package:jk_bms/src/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fixtures/ant_frames.dart';
import 'support/app_harness.dart';
import 'support/fakes.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'cells and temperature remain reachable at 320 dp, text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = (await tester.runAsync(() async {
          final link = FakeLink();
          final service = BmsService(
            transport: link,
            locationFactory: StubLocation.new,
          );
          await service.connect('ANT1', name: 'ANT@BLE22AAUB');
          link.announce(BleLinkState.connected);
          await link.deliver(antInfo22ph);
          await link.deliver(antStatus20s4tCharging);
          return service;
        }))!;
        addTearDown(service.dispose);
        final license = await unlockedLicense(tester);
        final t = AppL10nEs();
        await tester.pumpWidget(
          harness(
            license,
            Theme(
              data: AppTheme.build(brightness: Brightness.light),
              child: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: Scaffold(
                    body: BatteryTab(
                      service: service,
                      snapshot: service.lastSnapshot,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text(t.tabCells), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(t.tabThermal));
        await tester.pump();
        expect(find.text(t.thermalMosfet), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(t.tabCells));
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
