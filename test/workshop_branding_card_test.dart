import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:jk_bms/l10n/app_localizations_es.dart';
import 'package:jk_bms/src/license/entitlements.dart';
import 'package:jk_bms/src/report/workshop_branding.dart';
import 'package:jk_bms/src/ui/widgets/workshop_branding_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

/// The workshop tier promised the workshop's own logo on the PDFs, and there
/// was nowhere to give one.
void main() {
  final t = AppL10nEs();
  final png = Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 2)));
  late Directory dir;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('workshop');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test(
    'keeps the words and the logo, and refuses what is not an image',
    () async {
      final store = WorkshopBrandingStore(directory: () async => dir);
      expect((await store.load()).isEmpty, isTrue);

      await store.saveText(name: ' Taller Voltio ', line: '600 000 000');
      expect(await store.saveLogo(png), isTrue);
      expect(
        await store.saveLogo(Uint8List.fromList(utf8.encode('GIF89a'))),
        isFalse,
      );

      final b = await store.load();
      expect(b.name, 'Taller Voltio');
      expect(b.line, '600 000 000');
      expect(b.logo, png);

      await store.clearLogo();
      expect((await store.load()).logo, isNull);
    },
  );

  test(
    'the workshop tier is what unlocks it, and licensing off unlocks it',
    () {
      expect(Entitlements.unrestricted.allows(Feature.workshopExtras), isTrue);
      expect(
        const Entitlements(
          status: LicenseStatus.pro,
        ).allows(Feature.workshopExtras),
        isFalse,
      );
    },
  );

  testWidgets('the settings card saves a name and picks a logo', (
    tester,
  ) async {
    final store = WorkshopBrandingStore(directory: () async => dir);
    final file = File('${dir.path}/picked.png')..writeAsBytesSync(png);
    final license = await unlockedLicense(tester);
    await tester.pumpWidget(
      harness(
        license,
        Scaffold(
          body: SingleChildScrollView(
            child: WorkshopBrandingCard(
              store: store,
              pickImage: () async => file.path,
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
    expect(find.text(t.workshopTitle.toUpperCase()), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Taller Voltio');
    await tester.tap(find.text(t.profileSave));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
    expect((await tester.runAsync(store.load))!.name, 'Taller Voltio');

    // The file is real, so the tap's work runs on the real clock.
    await tester.runAsync(() async {
      await tester.tap(find.text(t.workshopLogoPick));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect((await tester.runAsync(store.load))!.logo, png);
    expect(find.text(t.workshopLogoRemove), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
