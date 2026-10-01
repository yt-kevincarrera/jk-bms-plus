import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/proximity_watcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Counts scan requests, which is all this test needs to know about the
/// radio.
final class _CountingPlatform extends FlutterBluePlusPlatform {
  int supportedAsks = 0;

  @override
  Future<bool> isSupported(BmIsSupportedRequest request) async {
    supportedAsks++;
    return false;
  }
}

void main() {
  // The watcher swept every 45 seconds whatever the link was doing, so a
  // background scan could start in the middle of a connect attempt, which on
  // Android is a well-known way to make that attempt fail.

  late _CountingPlatform platform;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    platform = _CountingPlatform();
    FlutterBluePlusPlatform.instance = platform;
  });

  test('keeps out of the way while the radio is busy with a link', () async {
    var busy = true;
    final watcher = ProximityWatcher(radioBusy: () => busy);
    await watcher.remember('C8:47', 'KevinJK');
    await watcher.setEnabled(true);
    await pumpEventQueue();
    expect(platform.supportedAsks, 0);
    expect(watcher.isScanning, isFalse);
    await watcher.dispose();

    busy = false;
    final idle = ProximityWatcher(radioBusy: () => busy);
    await idle.remember('C8:47', 'KevinJK');
    await idle.setEnabled(true);
    await pumpEventQueue();
    // It looked, and stopped there because the fake says there is no radio.
    expect(platform.supportedAsks, 1);
    await idle.dispose();
  });
}
