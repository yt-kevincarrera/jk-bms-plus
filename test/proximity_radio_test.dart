import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/proximity_watcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _ScanRadio extends FlutterBluePlusPlatform {
  final responses = StreamController<BmScanResponse>.broadcast();
  final adapters = StreamController<BmBluetoothAdapterState>.broadcast();
  BmAdapterStateEnum adapter = BmAdapterStateEnum.on;
  int starts = 0;
  int stops = 0;
  int supportAsks = 0;
  int adapterAsks = 0;
  @override
  Stream<BmScanResponse> get onScanResponse => responses.stream;
  @override
  Stream<BmBluetoothAdapterState> get onAdapterStateChanged => adapters.stream;
  @override
  Future<bool> isSupported(BmIsSupportedRequest request) async {
    supportAsks++;
    return true;
  }

  @override
  Future<BmBluetoothAdapterState> getAdapterState(
    BmBluetoothAdapterStateRequest request,
  ) async {
    adapterAsks++;
    return BmBluetoothAdapterState(adapterState: adapter);
  }

  @override
  Future<bool> startScan(BmScanSettings request) async {
    starts++;
    return true;
  }

  @override
  Future<bool> stopScan(BmStopScanRequest request) async {
    stops++;
    return true;
  }

  void hear(String id) => responses.add(
    BmScanResponse(
      advertisements: [
        BmScanAdvertisement(
          remoteId: DeviceIdentifier(id),
          platformName: 'KevinJK',
          advName: 'KevinJK',
          connectable: true,
          txPowerLevel: null,
          appearance: null,
          manufacturerData: {},
          serviceData: {},
          serviceUuids: [Guid('ffe0')],
          rssi: -45,
        ),
      ],
      success: true,
      errorCode: 0,
      errorString: '',
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'real plugin cache and an old watcher deadline cannot poison manual scan',
    () async {
      SharedPreferences.setMockInitialValues({});
      final radio = _ScanRadio();
      FlutterBluePlusPlatform.instance = radio;
      const id = 'AA:00:00:00:90:01';
      // Seed the real plugin's replay cache using an earlier completed scan.
      unawaited(
        fbp.FlutterBluePlus.startScan(timeout: const Duration(seconds: 30)),
      );
      await pumpEventQueue();
      radio.hear(id);
      await pumpEventQueue();
      expect(fbp.FlutterBluePlus.lastScanResults, hasLength(1));
      unawaited(fbp.FlutterBluePlus.stopScan());
      await pumpEventQueue();

      final watcher = ProximityWatcher(
        scanInterval: const Duration(minutes: 1),
        scanDuration: const Duration(milliseconds: 50),
      );
      final found = <DiscoveredBms>[];
      watcher.found.listen(found.add);
      unawaited(watcher.remember(id, 'KevinJK'));
      await pumpEventQueue();
      radio.adapter = BmAdapterStateEnum.unknown;
      unawaited(watcher.setEnabled(true));
      await pumpEventQueue();
      // The real plugin can begin at unknown while Bluetooth is settling.
      // This same first sweep must wait for ON, rather than silently wait
      // another entire 45-second interval before looking for the bike.
      radio.adapters.add(
        BmBluetoothAdapterState(adapterState: BmAdapterStateEnum.on),
      );
      await pumpEventQueue();
      expect(radio.starts, 2);
      expect(
        found,
        isEmpty,
        reason: 'the earlier stopped scan is not fresh presence',
      );

      var handedOff = false;
      unawaited(watcher.suspend().then((_) => handedOff = true));
      await pumpEventQueue();
      expect(handedOff, isTrue);
      unawaited(
        fbp.FlutterBluePlus.startScan(timeout: const Duration(minutes: 2)),
      );
      await pumpEventQueue();
      final stopsAtHandoff = radio.stops;
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      expect(fbp.FlutterBluePlus.isScanningNow, isTrue);
      expect(
        radio.stops,
        stopsAtHandoff,
        reason: 'neither the old scan timeout nor its backstop owns this scan',
      );
      radio.hear(id);
      await pumpEventQueue();
      expect(found, isEmpty);
      unawaited(watcher.setEnabled(false));
      unawaited(watcher.dispose());
      await pumpEventQueue();
      expect(
        radio.stops,
        stopsAtHandoff,
        reason:
            'disabling/disposal without an owned session cannot stop the manual scan',
      );
      unawaited(fbp.FlutterBluePlus.stopScan());
      await pumpEventQueue();
    },
  );
}
