import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/l10n/app_localizations_es.dart';
import 'package:jk_bms/src/app_settings.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/ui/widgets/bms_switches.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/real_kevinjk_frames.dart';
import 'support/app_harness.dart';
import 'support/fakes.dart';

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

  Future<void> pump(
    WidgetTester tester,
    BmsService service,
    AppSettings settings,
  ) async {
    final license = await unlockedLicense(tester);
    await tester.pumpWidget(
      harness(
        license,
        Scaffold(
          body: ListView(
            children: [
              BmsSwitchesGroup(
                service: service,
                settings: service.lastSettings!,
                appSettings: settings,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  SwitchListTile tile(WidgetTester tester, String name) => tester
      .widget<SwitchListTile>(find.byKey(ValueKey('bms-switch-$name')));

  testWidgets('with the permission off the switches show the state and '
      'cannot be touched', (tester) async {
    final (service, link) = (await tester.runAsync(connected))!;
    await pump(tester, service, AppSettings());

    for (final name in ['charge', 'discharge', 'balancer']) {
      expect(tile(tester, name).value, isTrue, reason: name);
      expect(tile(tester, name).onChanged, isNull, reason: name);
    }
    expect(find.text(t.bmsSwitchesLocked), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bms-switch-discharge')));
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
    expect(link.registerWrites, isEmpty);
    service.dispose();
  });

  testWidgets('a tap asks first, says what it does, and cancel sends nothing',
      (tester) async {
    final (service, link) = (await tester.runAsync(connected))!;
    service.bmsWritesAllowed = true;
    final settings = AppSettings()..allowBmsWrites = true;
    await pump(tester, service, settings);

    expect(tile(tester, 'discharge').onChanged, isNotNull);
    await tester.tap(find.byKey(const ValueKey('bms-switch-discharge')));
    await tester.pumpAndSettle();
    expect(find.text(t.bmsSwitchConfirmTitle('dischargeOff')), findsOneWidget);
    expect(find.text(t.bmsSwitchConfirmBody('dischargeOff')), findsOneWidget);
    await tester.tap(find.text(t.cancel));
    await tester.pumpAndSettle();
    expect(link.registerWrites, isEmpty);
    // Still what the BMS said, not what was tapped.
    expect(tile(tester, 'discharge').value, isTrue);
    service.dispose();
  });

  testWidgets('discharge off during a ride is refused with no confirmation',
      (tester) async {
    final (service, link) = (await tester.runAsync(connected))!;
    await tester.runAsync(service.startTrip);
    service.bmsWritesAllowed = true;
    final settings = AppSettings()..allowBmsWrites = true;
    await pump(tester, service, settings);

    await tester.tap(find.byKey(const ValueKey('bms-switch-discharge')));
    await tester.pump();
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(t.bmsSwitchRefused('riding')), findsOneWidget);
    expect(t.bmsSwitchRefused('riding'), startsWith('Para la moto primero'));
    expect(link.registerWrites, isEmpty);
    service.dispose();
  });

  test('the permission is off until turned on, and stays out of a backup',
      () async {
    final s = AppSettings();
    await s.load();
    expect(s.allowBmsWrites, isFalse);
    await s.setAllowBmsWrites(true);
    final again = AppSettings();
    await again.load();
    expect(again.allowBmsWrites, isTrue);
    expect(again.toBackup().keys.where((k) => k.contains('Write')), isEmpty);
    // A backup that carries it anyway cannot switch it on.
    final fresh = AppSettings();
    await fresh.restoreBackup({'allowBmsWrites': true});
    expect(fresh.allowBmsWrites, isFalse);
  });
}
