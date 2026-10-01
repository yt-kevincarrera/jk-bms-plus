import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/simulator/jk_frame_builder.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/platform/alert_notifications.dart';

import 'fixtures/captured_frames.dart';
import 'support/fakes.dart';

/// Notifications that are always ready and only count.
class CountingNotifications extends AlertNotifications {
  CountingNotifications({required this.ready});

  final bool ready;
  int vibrating = 0;
  int quiet = 0;

  @override
  bool get isReady => ready;

  @override
  Future<void> show({
    required String key,
    required String title,
    required String body,
    bool critical = false,
    bool vibrate = true,
  }) async {
    if (!ready) return;
    vibrate ? vibrating++ : quiet++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late int haptics;

  setUp(() {
    haptics = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') haptics++;
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  /// Connects, and charges a pack past an 80 % target.
  Future<CountingNotifications> chargePastTarget({
    required bool notificationsReady,
  }) async {
    final link = FakeLink();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = BmsRepository(database: db);
    final notes = CountingNotifications(ready: notificationsReady);
    final service =
        BmsService(transport: link, locationFactory: StubLocation.new)
          ..repository = repo
          ..alertNotifications = notes
          ..chargeAlertText = ((a, s) => ('title', 'body'))
          ..notifyAlerts = true;
    addTearDown(() async {
      await service.dispose();
      await repo.dispose();
      await db.close();
    });
    await service.connect('AA:BB', name: 'KevinJK');
    service.applySettings(
      haptics: true,
      rawFrames: false,
      chargeTargetSoc: 80,
      autoTrip: false,
    );
    await link.deliver(deviceInfoFrames[1]);
    await link.deliver(cellInfo24s[0]);
    const builder = JkFrameBuilder();
    for (var i = 0; i < 6; i++) {
      await link.deliver(
        builder.cellInfo(
          counter: 20 + i,
          cellVoltages: List.filled(16, 3.40),
          cellResistances: List.filled(16, 0.003),
          packVoltage: 54.4,
          current: 10,
          temperatures: const [24, 25],
          mosfetTemp: 27,
          soc: 85,
          soh: 100,
          remainingCapacityAh: 34,
          nominalCapacityAh: 40,
          cycleCount: 60,
          cycleCapacityAh: 2400,
          balancingAction: 0,
          balanceCurrent: 0,
          chargeMosfetOn: true,
          dischargeMosfetOn: true,
          errorBitmask: 0,
          totalRuntimeSeconds: 3600,
        ),
      );
      await pumpEventQueue();
    }
    return notes;
  }

  test('a vibrating notification is the only buzz', () async {
    // With the app on screen an alert used to buzz twice: the in-app haptic
    // and the notification's own vibration, for the same alert.
    final notes = await chargePastTarget(notificationsReady: true);
    expect(notes.vibrating, greaterThan(0));
    expect(haptics, 0);
  });

  test('with no notification to vibrate, the haptic still buzzes', () async {
    final notes = await chargePastTarget(notificationsReady: false);
    expect(notes.vibrating, 0);
    expect(haptics, greaterThan(0));
  });
}
