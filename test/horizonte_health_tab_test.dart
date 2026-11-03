import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/ui/tabs/health_tab.dart';
import 'package:jk_bms/src/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fixtures/ant_frames.dart';
import 'support/app_harness.dart';
import 'support/fakes.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('health cards fit 320 dp at text scale $scale', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = (await tester.runAsync(() async {
        final link = FakeLink();
        final service = BmsService(
          transport: link,
          locationFactory: StubLocation.new,
        );
        await service.connect('ANT1', name: 'ANT@BLE22AAUB');
        link.announce(BleLinkState.connected);
        await link.deliver(antInfo22ph);
        await link.deliver(antStatus20s4tCharging);
        return service;
      }))!;
      addTearDown(service.dispose);
      final license = await unlockedLicense(tester);
      await tester.pumpWidget(
        harness(
          license,
          Theme(
            data: AppTheme.build(brightness: Brightness.light),
            child: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: HealthTab(
                    service: service,
                    snapshot: service.lastSnapshot,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
