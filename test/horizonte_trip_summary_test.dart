import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/l10n/app_localizations.dart';
import 'package:jk_bms/l10n/app_localizations_es.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/metrics/range_estimator.dart';
import 'package:jk_bms/src/metrics/trip_recorder.dart';
import 'package:jk_bms/src/ui/theme.dart';
import 'package:jk_bms/src/ui/widgets/trip_summary_sheet.dart';
import 'package:jk_bms/src/ui/widgets/trip_summary_view.dart';
import 'support/fakes.dart';

TripSummaryView summary({
  bool measured = true,
  double? temperature = 37,
  double minVoltage = 73.2,
  double maxVoltage = 79.8,
}) => TripSummaryView(
  tripId: 7,
  distanceKm: 12.8,
  movingDuration: const Duration(minutes: 24, seconds: 16),
  totalDuration: const Duration(minutes: 27, seconds: 40),
  maxSpeedKmh: 57,
  climbM: 82,
  descentM: 74,
  energyOutWh: measured ? 411 : 0,
  energyInWh: measured ? 14.2 : 0,
  startSoc: 84,
  endSoc: 72,
  minPackVoltage: minVoltage,
  maxPackVoltage: maxVoltage,
  maxDischargeCurrent: 65,
  maxTemperature: temperature,
  maxDeltaVolts: .086,
  whPerKmBefore: 31.2,
  whPerKmAfter: 31,
  representative: null,
  energySource: measured ? 'integrated' : 'unmeasurable',
  packResistanceMilliohms: 46,
  conclusions: const TripConclusions(
    whPerKmBefore: 31.2,
    whPerKmAfter: 31,
    learnedKm: 244.2,
    rangeKmAtEnd: 58,
    confidence: RangeConfidence.medium,
  ),
);

void main() {
  final t = AppL10nEs();
  Future<void> pump(WidgetTester tester, TripSummaryView view) async {
    final service = BmsService(transport: FakeLink());
    addTearDown(service.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        locale: const Locale('es'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: TripSummarySheet(view: view, service: service, t: t),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'finishing retains terrain, timings, battery evidence and learning',
    (tester) async {
      await pump(tester, summary());
      final scroll = find.byType(Scrollable).first;
      for (final text in [
        t.tripTerrain,
        t.tripMoving,
        t.tripElapsed,
        t.tripStopped,
        t.tripMaxSpeed,
        t.tripAvgSpeed,
        t.tripEnergyOut,
        t.tripEnergyIn,
        t.tripEnergyNet,
        t.tripPackVoltage,
        t.tripSocUsed,
        t.tripSocPerKm,
        t.tripResistance,
        t.tripMaxCurrent,
        t.tripMaxTemp,
        t.tripMaxDelta,
        t.tripLearnedTitle,
      ]) {
        await tester.scrollUntilVisible(
          find.text(text),
          180,
          scrollable: scroll,
        );
        expect(find.text(text), findsWidgets, reason: text);
      }
      expect(find.text('Buen recorrido.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing energy and a missing sensor stay missing in the summary',
    (tester) async {
      await pump(tester, summary(measured: false, temperature: null));
      final scroll = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text(t.tripEnergyOut),
        180,
        scrollable: scroll,
      );
      expect(find.text(t.tripNotMeasured), findsWidgets);
      await tester.scrollUntilVisible(
        find.text(t.tripMaxTemp),
        180,
        scrollable: scroll,
      );
      expect(find.text('0.0 °C'), findsNothing);
      expect(find.text('--'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('missing pack voltages are not rendered as zero or infinity', (
    tester,
  ) async {
    await pump(
      tester,
      summary(measured: false, minVoltage: double.infinity, maxVoltage: 0),
    );
    await tester.scrollUntilVisible(
      find.text(t.tripPackVoltage),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('-- / -- V'), findsOneWidget);
    expect(find.textContaining('Infinity'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
