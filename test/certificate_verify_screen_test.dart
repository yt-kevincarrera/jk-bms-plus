import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/l10n/app_localizations.dart';
import 'package:jk_bms/src/inspection/inspection_result.dart';
import 'package:jk_bms/src/report/certificate.dart';
import 'package:jk_bms/src/ui/inspection/certificate_verify_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A test that never got its load: the case a certificate must not dress up.
InspectionResult _unloaded({bool? simulated}) => InspectionResult(
  at: DateTime.utc(2026, 9, 5, 20, 7),
  cells: [
    for (var i = 1; i <= 4; i++) CellInspection(index: i, restVolts: 3.75),
  ],
  restDeltaVolts: 0.005,
  peakDischargeAmps: 2.3,
  currentStepAmps: 0,
  caveats: const [
    InspectionCaveat.noHeavyLoad,
    InspectionCaveat.recoveryNoLoad,
  ],
  reported: const ReportedFigures(
    model: 'JK-BD6A20S6P',
    serialNumber: 'SN-1',
    cycleCount: 3,
    configuredCapacityAh: 40,
  ),
  durationSeconds: 300,
  readings: 700,
  simulated: simulated,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> open(WidgetTester tester, CertificateIdentity identity) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: CertificateVerifyScreen(identity: identity),
      ),
    );
  }

  Future<Certificate> sign(InspectionResult r, CertificateIdentity id) async =>
      const Certificates().issue(
        CertificateContent(
          issuedAt: DateTime.utc(2026, 9, 5, 20, 20),
          packName: 'KevinJK',
          result: r,
          note: 'Pedía 300',
          history: [CertifiedRun(at: DateTime.utc(2026, 8, 1), worstCell: 3)],
        ),
        await id.keyPair(),
      );

  final list = find
      .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
      .first;

  Future<void> check(WidgetTester tester, String token) async {
    await tester.enterText(find.byType(TextField), token);
    await tester.runAsync(() async {
      await tester.tap(find.text('Comprobar'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('says whose signature it is, what it does not prove, and the '
      'whole signed test', (tester) async {
    final mine = CertificateIdentity(seed: List<int>.filled(32, 3));
    final theirs = CertificateIdentity(seed: List<int>.filled(32, 4));
    final cert = (await tester.runAsync(
      () => sign(_unloaded(simulated: false), theirs),
    ))!;
    await open(tester, mine);
    await check(tester, cert.token);

    expect(
      find.textContaining('Firma válida para el emisor ${cert.issuer}'),
      findsOneWidget,
    );
    expect(find.textContaining('no demuestra'), findsWidgets);
    // Not from this phone, so it must not say it is.
    expect(find.text('Emitido por este teléfono.'), findsNothing);
    // The verdict the figures give, not three numbers and a tinted border.
    expect(find.text('Sin veredicto: nunca se cargó el pack'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Batería'),
      200,
      scrollable: list,
    );
    expect(find.text('Batería'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('CELDA POR CELDA'),
      300,
      scrollable: list,
    );
    await tester.scrollUntilVisible(
      find.text('Pedía 300'),
      300,
      scrollable: list,
    );
    // An earlier run with no sag figure prints a dash, not 0.000 V.
    await tester.scrollUntilVisible(
      find.text('Celda 3  --'),
      300,
      scrollable: list,
    );
    expect(find.textContaining('0.000 V'), findsNothing);
  });

  testWidgets('a certificate this phone signed says so', (tester) async {
    final mine = CertificateIdentity(seed: List<int>.filled(32, 3));
    final cert = (await tester.runAsync(
      () => sign(_unloaded(simulated: false), mine),
    ))!;
    // The checker only reads a key that is already stored; it never makes
    // one. Store this phone's seed the way the app does.
    SharedPreferences.setMockInitialValues({
      CertificateIdentity.seedKey: base64Url.encode(List<int>.filled(32, 3)),
    });
    await open(tester, CertificateIdentity());
    await check(tester, cert.token);
    expect(find.text('Emitido por este teléfono.'), findsOneWidget);
  });

  testWidgets('a simulated pack is said loudly, and an old certificate '
      'is said to be unknown', (tester) async {
    final id = CertificateIdentity(seed: List<int>.filled(32, 4));
    final demo = (await tester.runAsync(
      () => sign(_unloaded(simulated: true), id),
    ))!;
    await open(tester, id);
    await check(tester, demo.token);
    expect(find.textContaining('PRUEBA CON PACK SIMULADO'), findsOneWidget);

    final old = (await tester.runAsync(() => sign(_unloaded(), id)))!;
    await check(tester, old.token);
    expect(find.textContaining('PRUEBA CON PACK SIMULADO'), findsNothing);
    expect(find.textContaining('versión anterior de la app'), findsOneWidget);
  });
}
