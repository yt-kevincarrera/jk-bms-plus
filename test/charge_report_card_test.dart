import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/l10n/app_localizations.dart';
import 'package:jk_bms/src/metrics/charge_session.dart';
import 'package:jk_bms/src/ui/widgets/charge_report_card.dart';

ChargeReport report({int gapSeconds = 0}) => ChargeReport(
  startedAt: DateTime.utc(2026, 9, 1, 22),
  endedAt: DateTime.utc(2026, 9, 2, 2),
  startSoc: 30,
  endSoc: 100,
  ahIn: 31.5,
  whIn: 2400,
  peakCurrent: 10,
  maxTemperature: 29,
  deltaAtStart: 0.008,
  deltaAtTop: 0.062,
  worstDeltaHigh: 0.070,
  weakCellAtTop: 7,
  strongCellAtTop: 14,
  balancerWorkedSeconds: 1800,
  reachedTop: true,
  gapSeconds: gapSeconds,
);

Future<void> pump(WidgetTester tester, ChargeReport r) => tester.pumpWidget(
  MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(child: ChargeReportCard(report: r)),
    ),
  ),
);

void main() {
  testWidgets('names the highest cell as the one that fills first', (
    tester,
  ) async {
    // In series every cell takes the same current, so the one with the least
    // room reaches the top first and reads highest. The card used to name
    // the lowest cell, 7, as the one filling first.
    await pump(tester, report());
    expect(
      find.textContaining('la celda 14 se llena antes que las demás'),
      findsOneWidget,
    );
    expect(find.textContaining('la 7 es la que va más atrás'), findsOneWidget);
  });

  testWidgets('says when the BMS counted part of the charge', (tester) async {
    await pump(tester, report(gapSeconds: 1800));
    expect(find.textContaining('30 min sin conexión'), findsOneWidget);
  });
}
