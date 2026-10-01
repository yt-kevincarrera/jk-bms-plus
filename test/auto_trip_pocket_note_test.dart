import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:jk_bms/l10n/app_localizations.dart';
import 'package:jk_bms/src/ui/widgets/auto_trip_pocket_note.dart';

void main() {
  Future<AppL10n> open(
    WidgetTester tester, {
    required LocationPermission now,
    LocationPermission? afterRequest,
    bool linkWatchOn = true,
    List<String>? calls,
  }) async {
    var current = now;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: AutoTripPocketNote(
            linkWatchOn: linkWatchOn,
            checkPermission: () async => current,
            requestPermission: () async {
              calls?.add('request');
              current = afterRequest ?? current;
              return current;
            },
            openSettings: () async {
              calls?.add('settings');
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppL10n.of(tester.element(find.byType(AutoTripPocketNote)));
  }

  testWidgets('"while in use" says what a pocket start depends on, and offers '
      'the fix', (tester) async {
    final t = await open(tester, now: LocationPermission.whileInUse);
    expect(find.text(t.autoTripPocketWhileInUse), findsOneWidget);
    expect(find.text(t.autoTripPocketAllowAlways), findsOneWidget);
  });

  testWidgets('a request Android answers with nothing sends the rider to the '
      'settings page, and says what to pick there', (tester) async {
    final calls = <String>[];
    final t = await open(
      tester,
      now: LocationPermission.whileInUse,
      calls: calls,
    );
    await tester.tap(find.text(t.autoTripPocketAllowAlways));
    await tester.pumpAndSettle();
    expect(calls, ['request', 'settings']);
    expect(find.text(t.autoTripPocketSettingsHint), findsOneWidget);
  });

  testWidgets('granted all the time, it says so and asks for nothing',
      (tester) async {
    final t = await open(tester, now: LocationPermission.always);
    expect(find.text(t.autoTripPocketAlways), findsOneWidget);
    expect(find.text(t.autoTripPocketAllowAlways), findsNothing);
  });

  testWidgets('with the screen-off reading switched off it says no pocket '
      'ride can start', (tester) async {
    final t = await open(
      tester,
      now: LocationPermission.always,
      linkWatchOn: false,
    );
    expect(find.text(t.autoTripPocketNeedsLinkWatch), findsOneWidget);
  });
}
