import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart'
    as ble;
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:jk_bms/l10n/app_localizations.dart';
import 'package:jk_bms/src/app_settings.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/hands_free_controller.dart';
import 'package:jk_bms/src/ble/proximity_connection.dart';
import 'package:jk_bms/src/ble/proximity_watcher.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/platform/hands_free_platform.dart';
import 'package:jk_bms/src/ui/connect_screen.dart';
import 'package:jk_bms/src/ui/home_shell.dart';
import 'package:jk_bms/src/ui/locale_controller.dart';
import 'package:jk_bms/src/ui/widgets/hands_free_card.dart';
import 'package:jk_bms/src/update/update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

class _Radio extends FakeLink {
  int scans = 0;
  final connects = <String>[];
  @override
  Stream<List<DiscoveredBms>> scan() {
    scans++;
    return super.scan();
  }

  @override
  Future<void> connect(String deviceId) async {
    connects.add(deviceId);
  }
}

class _Updates extends UpdateService {
  int checks = 0;
  @override
  Future<bool> checkQuietly({
    required DateTime? lastCheckedAt,
    required Duration interval,
    required Future<void> Function(DateTime) onChecked,
  }) async {
    checks++;
    return false;
  }
}

final class _PreparingBluetooth extends ble.FlutterBluePlusPlatform {
  final supported = Completer<bool>();
  int supportRequests = 0;
  @override
  Future<bool> isSupported(ble.BmIsSupportedRequest request) {
    supportRequests++;
    return supported.future;
  }

  @override
  Stream<ble.BmBluetoothAdapterState> get onAdapterStateChanged =>
      const Stream.empty();
  @override
  Future<ble.BmBluetoothAdapterState> getAdapterState(
    ble.BmBluetoothAdapterStateRequest request,
  ) async =>
      ble.BmBluetoothAdapterState(adapterState: ble.BmAdapterStateEnum.on);
}

class _ReadyLocation extends geo.GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<geo.LocationPermission> checkPermission() async =>
      geo.LocationPermission.always;
}

void main() {
  const channel = MethodChannel('test.jk_bms/hands_free_ui');
  const deviceId = 'AA:00:00:00:77:01';

  testWidgets(
    'cancelling during Bluetooth preparation cannot start a late scan',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final bluetooth = _PreparingBluetooth();
      ble.FlutterBluePlusPlatform.instance = bluetooth;
      final previousLocation = geo.GeolocatorPlatform.instance;
      geo.GeolocatorPlatform.instance = _ReadyLocation();
      addTearDown(() => geo.GeolocatorPlatform.instance = previousLocation);
      final radio = _Radio();
      final service = (await tester.runAsync(
        () async =>
            BmsService(transport: radio, locationFactory: StubLocation.new),
      ))!;
      final locale = LocaleController();
      final settings = AppSettings();
      final updates = _Updates();
      final watcher = ProximityWatcher();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: ConnectScreen(
            service: service,
            localeController: locale,
            proximity: watcher,
            settings: settings,
            updateService: updates,
          ),
        ),
      );
      await tester.pump();
      expect(bluetooth.supportRequests, 1);
      await tester.tap(find.byIcon(Icons.stop_circle_outlined));
      await tester.pump();
      bluetooth.supported.complete(true);
      await tester.pump();
      await tester.runAsync(() => pumpEventQueue());
      await tester.pump();
      expect(
        radio.scans,
        0,
        reason:
            'cancellation retires the pending preparation before CDM setup can take the radio',
      );
      expect(find.byIcon(Icons.stop_circle_outlined), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await watcher.dispose();
        await service.dispose();
      });
      locale.dispose();
      settings.dispose();
      updates.dispose();
    },
  );

  testWidgets(
    'a companion cold start connects without scanning, updates or navigation',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final nativeCalls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        nativeCalls.add(call.method);
        return <String, Object?>{
          'supported': true,
          'enabled': true,
          'associated': true,
          'present': true,
          'running': true,
          'deviceId': deviceId,
          'deviceName': 'KevinJK',
          'reason': 'running',
        };
      });
      final radio = _Radio();
      final service = (await tester.runAsync(
        () async =>
            BmsService(transport: radio, locationFactory: StubLocation.new)
              ..appVisible = false,
      ))!;
      final watcher = ProximityWatcher(radioBusy: () => service.radioBusy);
      final platform = HandsFreePlatform(channel: channel, isAndroid: true);
      final connection = ProximityConnection(
        watcher: watcher,
        service: service,
      );
      final controller = HandsFreeController(
        platform: platform,
        watcher: watcher,
        connection: connection,
        service: service,
      );
      await tester.runAsync(controller.initialize);
      final locale = LocaleController();
      final settings = AppSettings();
      final updates = _Updates();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: ConnectScreen(
            service: service,
            localeController: locale,
            proximity: watcher,
            settings: settings,
            updateService: updates,
            handsFree: controller,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(radio.connects, [deviceId]);
      expect(radio.scans, 0);
      expect(updates.checks, 0);
      expect(nativeCalls, ['refresh']);
      expect(find.byType(HomeShell), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await tester.runAsync(() async {
        await connection.dispose();
        await watcher.dispose();
        await service.dispose();
      });
      platform.dispose();
      locale.dispose();
      settings.dispose();
      updates.dispose();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    },
  );

  for (final language in ['es', 'en']) {
    testWidgets('permission recovery is readable at large text in $language', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => <String, Object?>{
          'supported': true,
          'enabled': true,
          'associated': true,
          'present': false,
          'running': false,
          'deviceId': deviceId,
          'deviceName': 'KevinJK',
          'reason': 'background_location_permission',
        },
      );
      final service = (await tester.runAsync(
        () async => BmsService(
          transport: FakeLink(),
          locationFactory: StubLocation.new,
        ),
      ))!;
      final watcher = ProximityWatcher();
      final platform = HandsFreePlatform(channel: channel, isAndroid: true);
      final connection = ProximityConnection(
        watcher: watcher,
        service: service,
      );
      final controller = HandsFreeController(
        platform: platform,
        watcher: watcher,
        connection: connection,
        service: service,
      );
      await tester.runAsync(controller.initialize);
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: HandsFreeCard(controller: controller),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.textContaining(
          language == 'es' ? 'Permitir siempre' : 'Allow all the time',
        ),
        findsWidgets,
      );
      expect(
        find.widgetWithText(
          OutlinedButton,
          language == 'es'
              ? 'Abrir ajustes de Android'
              : 'Open Android settings',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await tester.runAsync(() async {
        await connection.dispose();
        await watcher.dispose();
        await service.dispose();
      });
      platform.dispose();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    });
  }
}
