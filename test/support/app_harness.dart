import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/l10n/app_localizations.dart';
import 'package:jk_bms/src/license/device_code.dart';
import 'package:jk_bms/src/license/device_identity.dart';
import 'package:jk_bms/src/license/license_controller.dart';
import 'package:jk_bms/src/ui/license_scope.dart';

/// A licence controller with licensing switched off, as every build ships
/// today: nothing gated. Loaded inside [WidgetTester.runAsync] because it
/// reads preferences.
Future<LicenseController> unlockedLicense(WidgetTester tester) async {
  final c = LicenseController(
    identity: FixedDeviceIdentity(DeviceCode(const [1, 2, 3, 4, 5, 6, 7, 8])),
    enabled: false,
  );
  await tester.runAsync(c.load);
  return c;
}

/// [home] inside the app's localisations and licence scope, in Spanish
/// unless told otherwise.
Widget harness(
  LicenseController license,
  Widget home, {
  Locale locale = const Locale('es'),
}) => LicenseScope(
  controller: license,
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: home,
  ),
);
