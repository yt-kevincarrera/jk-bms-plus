import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/l10n/app_localizations.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/inspection/inspection_result.dart';
import 'package:jk_bms/src/inspection/inspection_session.dart';
import 'package:jk_bms/src/license/device_code.dart';
import 'package:jk_bms/src/license/device_identity.dart';
import 'package:jk_bms/src/license/license_controller.dart';
import 'package:jk_bms/src/ui/inspection/inspection_screen.dart';
import 'package:jk_bms/src/ui/inspection/inspection_verdict_screen.dart';
import 'package:jk_bms/src/ui/inspection/inspection_texts.dart';
import 'package:jk_bms/src/ui/inspection/inspections_list_screen.dart';
import 'package:jk_bms/src/ui/license_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<LicenseController> license(WidgetTester tester) async {
    final c = LicenseController(
      identity: FixedDeviceIdentity(DeviceCode(const [1, 2, 3, 4, 5, 6, 7, 8])),
      enabled: false,
    );
    await tester.runAsync(c.load);
    return c;
  }

  Widget app(LicenseController c, Widget home) => LicenseScope(
    controller: c,
    child: MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: home,
    ),
  );

  testWidgets('"repeat" reaches the screen that opened the test', (
    tester,
  ) async {
    // The connect screen pushes the guided test and waits for a bool: true
    // means stay in inspection mode and scan again. The test used to swap
    // itself for the verdict, which completed that wait at once with
    // nothing, so the link was dropped and the mode left while the verdict
    // was still showing, and "repeat" did what "discard" did.
    final service = BmsService(
      transport: FakeLink(),
      locationFactory: StubLocation.new,
    );
    final c = await license(tester);
    final answers = <bool?>[];
    await tester.pumpWidget(
      app(
        c,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async {
                answers.add(
                  await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (_) => InspectionScreen(
                        service: service,
                        bmsId: 'AA:BB',
                        bmsName: 'Pack del vendedor',
                      ),
                    ),
                  ),
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    // The test screen waits for readings behind a spinner, which never
    // settles: pump through the route animations by time instead.
    await tester.tap(find.text('abrir'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Terminar ahora'));
    // The analysis and the subscription cancel run on real futures.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // On the verdict, and the opener is still waiting.
    expect(find.byType(InspectionVerdictScreen), findsOneWidget);
    expect(answers, isEmpty);

    final repeat = find.text('Repetir la prueba');
    await tester.scrollUntilVisible(
      repeat,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(repeat);
    await tester.pump();
    await tester.tap(repeat);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(answers, [true]);
  });

  testWidgets('saving with no store says so instead of doing nothing', (
    tester,
  ) async {
    final service = BmsService(
      transport: FakeLink(),
      locationFactory: StubLocation.new,
    );
    final c = await license(tester);
    await tester.pumpWidget(
      app(
        c,
        InspectionVerdictScreen(
          service: service,
          result: InspectionResult(
            at: DateTime.utc(2026, 9, 5),
            cells: const [CellInspection(index: 1, restVolts: 3.7)],
            restDeltaVolts: 0,
            peakDischargeAmps: 0,
            currentStepAmps: 0,
            caveats: const [InspectionCaveat.noHeavyLoad],
            reported: const ReportedFigures(),
          ),
          samples: const <InspectionSample>[],
          bmsId: 'AA:BB',
          bmsName: 'Pack',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final save = find.text('Guardar inspección');
    await tester.scrollUntilVisible(
      save,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(save);
    await tester.pump();
    await tester.tap(save);
    await tester.pump();
    expect(
      find.text(
        'No se pudo guardar: el almacenamiento de la app no está disponible.',
      ),
      findsOneWidget,
    );
  });

  test('a saved run that measured nothing is not listed as good', () {
    // Saved before the unmeasured light existed: the row says "good" for a
    // test that never loaded the pack. The stored result says otherwise.
    final r = InspectionResult(
      at: DateTime.utc(2026, 9, 5),
      cells: const [CellInspection(index: 1, restVolts: 3.7)],
      restDeltaVolts: 0,
      peakDischargeAmps: 14.2,
      currentStepAmps: 0,
      caveats: const [InspectionCaveat.noHeavyLoad],
      reported: const ReportedFigures(),
    );
    Inspection row(String light, String json) => Inspection(
      id: 1,
      at: DateTime.utc(2026, 9, 5),
      bmsId: 'AA:BB',
      bmsName: '',
      model: '',
      serialNumber: '',
      light: light,
      resultJson: json,
      samplesJson: '[]',
      note: '',
    );
    expect(
      InspectionsListScreen.lightOf(row('good', jsonEncode(r.toJson()))),
      InspectionLight.unmeasured,
    );
    // And a row nothing can read keeps what it stored.
    expect(
      InspectionsListScreen.lightOf(row('watch', 'not json')),
      InspectionLight.watch,
    );
  });

  test('a cell still not back prints as more than the window, everywhere', () {
    // The sheet printed the end-of-window time as a plain number, as if the
    // cell had made it back then; the screen said "> 45 s".
    final t = lookupAppL10n(const Locale('es'));
    const late = CellInspection(
      index: 1,
      restVolts: 3.7,
      recoverySeconds: 45,
      recovered: false,
    );
    expect(inspectionRecoveryCell(t, late, unit: false), '> 45.0');
    expect(inspectionRecoveryCell(t, late, digits: 0), '> 45 s');
    const back = CellInspection(index: 1, restVolts: 3.7, recoverySeconds: 4);
    expect(inspectionRecoveryCell(t, back, unit: false), '4.0');
    const never = CellInspection(index: 1, restVolts: 3.7, recovered: false);
    expect(inspectionRecoveryCell(t, never), t.reportNotRecovered);
  });
}
