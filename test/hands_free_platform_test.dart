import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/platform/hands_free_platform.dart';

const _channel = MethodChannel('test.jk_bms/hands_free');

Map<String, Object?> _native({
  bool enabled = true,
  bool present = false,
  String reason = 'ready',
}) => {
  'supported': true,
  'enabled': enabled,
  'associated': true,
  'present': present,
  'running': true,
  'deviceId': 'AA:BB',
  'deviceName': 'KevinJK',
  'reason': reason,
};

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late HandsFreePlatform platform;
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
      call,
    ) async {
      calls.add(call);
      return _native();
    });
    platform = HandsFreePlatform(channel: _channel, isAndroid: true);
  });

  tearDown(() {
    platform.dispose();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test(
    'native state preserves consent, presence and the remembered pack',
    () async {
      final state = await platform.refresh();
      expect(state.ownsForeground, isTrue);
      expect(state.present, isFalse);
      expect(state.running, isTrue);
      expect(state.deviceId, 'AA:BB');
      expect(state.deviceName, 'KevinJK');
      expect(calls.single.method, 'refresh');
      expect(platform.lastFailure, isNull);
    },
  );

  test('only explicit actions request permissions or association', () async {
    await platform.refresh();
    await platform.requestPrerequisites(usesLocation: true);
    await platform.enable(
      deviceId: 'AA:BB',
      deviceName: 'KevinJK',
      usesLocation: true,
    );
    expect(calls.map((c) => c.method), [
      'refresh',
      'requestPrerequisites',
      'enable',
    ]);
    expect(calls[1].arguments, {'usesLocation': true});
    expect(calls[2].arguments, {
      'deviceId': 'AA:BB',
      'deviceName': 'KevinJK',
      'usesLocation': true,
    });
  });

  test(
    'presence callbacks update listeners without requesting setup',
    () async {
      await platform.refresh();
      var updates = 0;
      platform.addListener(() => updates++);
      await binding.defaultBinaryMessenger.handlePlatformMessage(
        _channel.name,
        _channel.codec.encodeMethodCall(
          MethodCall('presenceChanged', _native(present: true)),
        ),
        (_) {},
      );
      expect(platform.status.present, isTrue);
      expect(updates, 1);
      expect(calls.map((c) => c.method), ['refresh']);
    },
  );

  test(
    'platform errors retain association and expose the recovery reason',
    () async {
      await platform.refresh();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
        call,
      ) async {
        throw PlatformException(code: 'background_location_permission');
      });
      final state = await platform.requestPrerequisites(usesLocation: true);
      expect(state.deviceId, 'AA:BB');
      expect(state.associated, isTrue);
      expect(state.reason, 'background_location_permission');
      expect(platform.lastFailure, 'background_location_permission');
    },
  );

  test(
    'an absent plugin is reported and a later refresh clears the failure',
    () async {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _channel,
        (call) async => throw MissingPluginException(),
      );
      final missing = await platform.refresh();
      expect(missing.reason, 'platform_unavailable');
      expect(platform.lastFailure, 'hands_free_unavailable');
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _channel,
        (call) async => _native(),
      );
      expect((await platform.refresh()).reason, 'ready');
      expect(platform.lastFailure, isNull);
    },
  );

  test(
    'notification bridge reports start failure and forwards applied type',
    () async {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
        call,
      ) async {
        calls.add(call);
        if (call.method == 'notificationStart') return false;
        if (call.method == 'notificationRunning') return true;
        return null;
      });
      expect(
        await platform.notificationStart(
          title: 'Ride',
          text: 'Recording',
          usesLocation: true,
        ),
        isFalse,
      );
      expect(platform.lastFailure, 'start_failed');
      expect(calls.single.arguments, {
        'title': 'Ride',
        'text': 'Recording',
        'usesLocation': true,
      });
      await platform.notificationUpdate(title: 'Ride', text: '1 km');
      expect(await platform.notificationRunning(), isTrue);
      await platform.notificationStop();
      expect(calls.map((c) => c.method), [
        'notificationStart',
        'notificationUpdate',
        'notificationRunning',
        'notificationStop',
      ]);
    },
  );

  test('other platforms never invoke Android setup', () async {
    platform.dispose();
    platform = HandsFreePlatform(channel: _channel, isAndroid: false);
    await platform.refresh();
    await platform.requestPrerequisites(usesLocation: true);
    await platform.enable(
      deviceId: 'AA:BB',
      deviceName: 'KevinJK',
      usesLocation: true,
    );
    await platform.disable();
    await platform.forget();
    await platform.openAppSettings();
    expect(calls, isEmpty);
    expect(platform.status.supported, isFalse);
  });
}
