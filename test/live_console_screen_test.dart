import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/l10n/app_localizations.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/connect_recovery.dart';
import 'package:jk_bms/src/ble/switchable_link.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/protocol/jk_commands.dart';
import 'package:jk_bms/src/protocol/jk_constants.dart';
import 'package:jk_bms/src/ui/live_console_screen.dart';

import 'support/fake_radio.dart';
import 'support/fakes.dart';

void main() {
  // The console is opened from the connect screen after an attempt has
  // failed, so what it has to show is what happened before it was opened.
  // It used to show decoded frames only, which a failing pack has none of.

  Future<void> open(WidgetTester tester, BmsService service) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: LiveConsoleScreen(service: service, deviceName: 'Frames crudos'),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the bytes of an attempt made before it was opened, '
      'both ways, and keeps adding to them', (tester) async {
    final link = FakeLink();
    final service = BmsService(
      transport: link,
      locationFactory: StubLocation.new,
    );
    await tester.runAsync(() async {
      await service.connect('X', name: 'KevinJK');
      link.announce(BleLinkState.connected);
      link.wrote(jkReadCommand(commandDeviceInfo));
      // Bytes that are not JK at all: what a failing pack leaves behind.
      await link.deliver(Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]));
      await service.disconnect();
    });

    await open(tester, service);
    // Chrome in the rider's language, not hard-coded English.
    expect(find.text('Decodificado'), findsOneWidget);
    expect(find.byTooltip('Siguiendo'), findsOneWidget);
    expect(find.byTooltip('Copiar todo para diagnóstico'), findsOneWidget);
    expect(find.textContaining('Esta conexión'), findsOneWidget);

    await tester.tap(find.text('Bytes'));
    await tester.pump();

    expect(find.textContaining('← RX  4 B\nDE AD BE EF'), findsOneWidget);
    expect(find.textContaining('→ TX  20 B\nAA 55 90 EB 97'), findsOneWidget);
    expect(find.text('--- en vivo desde aquí ---'), findsOneWidget);

    await tester.runAsync(
      () => link.deliver(Uint8List.fromList([0x01, 0x02])),
    );
    await tester.pump();
    expect(find.textContaining('← RX  2 B\n01 02'), findsOneWidget);

    // Paused holds the list still; what arrives meanwhile shows on resume.
    await tester.tap(find.byTooltip('Siguiendo'));
    await tester.pump();
    await tester.runAsync(
      () => link.deliver(Uint8List.fromList([0x03, 0x04])),
    );
    await tester.pump();
    expect(find.textContaining('03 04'), findsNothing);
    await tester.tap(find.byTooltip('Pausado'));
    await tester.pump();
    expect(find.textContaining('← RX  2 B\n03 04'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(service.dispose);
  });

  testWidgets('the diagnostic copy carries the last connect attempts',
      (tester) async {
    // A morning that would not connect has no frames to show, so the copy
    // has to carry what each attempt could see, or it says nothing useful.
    final recovery = ConnectRecovery(
      radio: FakeRecoveryRadio(),
      adverts: AdvertBook(),
    );
    final service = BmsService(
      transport: SwitchableLink(real: BleTransport(recovery: recovery)),
      locationFactory: StubLocation.new,
    );
    await tester.runAsync(() async {
      final a = recovery.begin('C8:47');
      await recovery.prepare(a, stillWanted: () => true);
      recovery.failed(a, 'android-code: 147 | GATT_CONNECTION_TIMEOUT');
    });
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );

    await open(tester, service);
    await tester.tap(find.byTooltip('Copiar todo para diagnóstico'));
    await tester.pump();
    expect(copied, contains('== Intentos de conexión'));
    expect(copied, contains('#1 failed'));
    expect(copied, contains('GATT_CONNECTION_TIMEOUT'));

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(service.dispose);
  });

  testWidgets('says so when nothing has crossed the link', (tester) async {
    final service = BmsService(
      transport: FakeLink(),
      locationFactory: StubLocation.new,
    );
    await open(tester, service);
    await tester.tap(find.text('Bytes'));
    await tester.pump();
    expect(
      find.textContaining('Todavía no pasó ningún byte'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(service.dispose);
  });
}
