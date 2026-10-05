import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/l10n/app_localizations.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/protocol/jk_frame.dart';
import 'package:jk_bms/src/protocol/jk_parser.dart';
import 'package:jk_bms/src/protocol/protocol_variant.dart';
import 'package:jk_bms/src/ui/tabs/thermal_tab.dart';

import 'fixtures/real_kevinjk_frames.dart';
import 'support/fakes.dart';

void main() {
  // The rider's own pack: probes 1 and 2 fitted, inputs 3 and 4 empty, and a
  // fifth slot that repeats the MOSFET. The tab used to show a "Probe 5"
  // tile carrying the MOSFET's number next to the MOSFET's own tile, and
  // count "3 / 5" probes on a pack with two.
  testWidgets('shows two probes and the MOSFET once, on the real pack',
      (tester) async {
    final snapshot = const JkParser().parseCellInfo(
      JkFrame(bytes: kevinJkCellInfo[2], receivedAt: DateTime.utc(2026, 9, 1)),
      JkProtocolVariant.jk02_32s,
    );
    final service = BmsService(
      transport: FakeLink(),
      locationFactory: StubLocation.new,
    );
    addTearDown(service.dispose);

    // The test font is far wider than the real one, so the fixed-width
    // tiles overflow here and only here. That is not what this checks.
    final reportError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      reportError?.call(details);
    };
    addTearDown(() => FlutterError.onError = reportError);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: ThermalTab(service: service, snapshot: snapshot),
        ),
      ),
    );
    await tester.pump();

    // One tile per battery probe, and one for the MOSFET.
    expect(find.text('SONDA 1'), findsOneWidget);
    expect(find.text('SONDA 2'), findsOneWidget);
    expect(find.text('SONDA 5'), findsNothing);
    expect(find.text('34.2'), findsOneWidget);
    // 36.0 is the MOSFET. It appears once, on its own tile.
    expect(find.text('36.0'), findsOneWidget);
    expect(find.text('MOSFET'), findsNWidgets(2)); // tile, and the slot 5 row

    // Two of four inputs connected: the mirror is not an input.
    expect(find.text('2 / 4'), findsOneWidget);
    // Slot 5 is named for what it is, not offered as a probe.
    expect(find.text('Sonda 5'), findsOneWidget);
    expect(
      find.textContaining('repite la temperatura del MOSFET'),
      findsOneWidget,
    );
    // The mask is the one byte it is.
    expect(find.text('0xff'), findsOneWidget);
  });
}
