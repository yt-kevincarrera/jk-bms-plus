import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/l10n/app_localizations.dart';
import 'package:jk_bms/src/ui/license_scope.dart';
import 'package:jk_bms/l10n/app_localizations_en.dart';
import 'package:jk_bms/l10n/app_localizations_es.dart';
import 'package:jk_bms/src/app_settings.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/ui/app_settings_screen.dart';
import 'package:jk_bms/src/ui/locale_controller.dart';
import 'package:jk_bms/src/ui/theme.dart';
import 'package:jk_bms/src/update/app_version.dart';
import 'package:jk_bms/src/update/update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/app_harness.dart';
import 'support/fakes.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'settings categories retain working controls at text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = BmsService(transport: FakeLink());
        final settings = AppSettings();
        final locale = ValueNotifier(const Locale('es'));
        addTearDown(service.dispose);
        addTearDown(settings.dispose);
        addTearDown(locale.dispose);
        final license = await unlockedLicense(tester);
        final t = AppL10nEs();
        await tester.pumpWidget(
          ValueListenableBuilder(
            valueListenable: locale,
            builder: (context, value, _) => LicenseScope(
              controller: license,
              child: MaterialApp(
                locale: value,
                theme: AppTheme.build(brightness: Brightness.light),
                localizationsDelegates: AppL10n.localizationsDelegates,
                supportedLocales: AppL10n.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: AppSettingsScreen(
                  service: service,
                  settings: settings,
                  localeController: LocaleController(),
                  updateService: UpdateService(
                    currentVersion: const AppVersion(2, 32, 0),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(t.appearanceTitle), findsOneWidget);
        expect(find.byType(SwitchListTile), findsNothing);
        await tester.scrollUntilVisible(find.text(t.settingsSectionRides), 200);
        await tester.tap(find.text(t.settingsSectionRides));
        await tester.pumpAndSettle();
        final before = settings.autoTripEnabled;
        await tester.scrollUntilVisible(find.text(t.autoTripTitle), 200);
        await tester.tap(find.text(t.autoTripTitle));
        await tester.pumpAndSettle();
        expect(settings.autoTripEnabled, !before);
        expect(service.autoTripEnabled, settings.autoTripEnabled);
        await tester.scrollUntilVisible(find.text(t.settingsSectionLink), 200);
        expect(find.text(t.settingsSectionLink), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text(t.settingsSectionApp), 200);
        await tester.tap(find.text(t.settingsSectionApp));
        await tester.pumpAndSettle();
        locale.value = const Locale('en');
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text(AppL10nEn().systemLanguageTitle),
          200,
        );
        expect(find.text(AppL10nEn().settingsSectionApp), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
