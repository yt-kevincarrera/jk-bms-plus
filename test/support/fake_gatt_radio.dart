import 'dart:async';

import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';

import 'fake_radio.dart';

/// A discovered characteristic's capabilities, including duplicate UUIDs.
class FakeGattCharacteristic {
  const FakeGattCharacteristic({
    required this.instanceId,
    this.notify = false,
    this.indicate = false,
    this.write = false,
    this.writeWithoutResponse = false,
  });

  final int instanceId;
  final bool notify;
  final bool indicate;
  final bool write;
  final bool writeWithoutResponse;

  BmBluetoothCharacteristic forDevice(DeviceIdentifier id) =>
      BmBluetoothCharacteristic(
        remoteId: id,
        primaryServiceUuid: null,
        serviceUuid: Guid('ffe0'),
        characteristicUuid: Guid('ffe1'),
        instanceId: instanceId,
        descriptors: [],
        properties: BmCharacteristicProperties(
          broadcast: false,
          read: false,
          writeWithoutResponse: writeWithoutResponse,
          write: write,
          notify: notify,
          indicate: indicate,
          authenticatedSignedWrites: false,
          extendedProperties: false,
          notifyEncryptionRequired: false,
          indicateEncryptionRequired: false,
        ),
      );
}

/// Answers the real FlutterBluePlus plugin's discovery, CCCD and write calls.
/// The fake rejects writes to a notify-only instance, as a peripheral would.
final class FakeGattPlatform extends FlutterBluePlusPlatform {
  final radio = FakeFbpPlatform();
  final _services = StreamController<BmDiscoverServicesResult>.broadcast();
  final _written = StreamController<BmCharacteristicData>.broadcast();
  final _received = StreamController<BmCharacteristicData>.broadcast();
  final _descriptors = StreamController<BmDescriptorData>.broadcast();

  List<FakeGattCharacteristic> characteristics = const [];
  final subscriptions = <BmSetNotifyValueRequest>[];
  final writes = <BmWriteCharacteristicRequest>[];
  int failedWritesRemaining = 0;
  Future<void> Function(BmWriteCharacteristicRequest request)? beforeWrite;
  void Function(BmWriteCharacteristicRequest request)? afterWrite;

  @override
  Stream<BmConnectionStateResponse> get onConnectionStateChanged =>
      radio.onConnectionStateChanged;
  @override
  Stream<BmDiscoverServicesResult> get onDiscoveredServices => _services.stream;
  @override
  Stream<BmCharacteristicData> get onCharacteristicWritten => _written.stream;
  @override
  Stream<BmCharacteristicData> get onCharacteristicReceived => _received.stream;
  @override
  Stream<BmDescriptorData> get onDescriptorWritten => _descriptors.stream;

  @override
  Future<bool> connect(BmConnectRequest request) {
    radio.onConnect = (id) => radio.emit(id, BmConnectionStateEnum.connected);
    return radio.connect(request);
  }

  @override
  Future<bool> disconnect(BmDisconnectRequest request) async {
    radio.disconnects.add(request.remoteId.str);
    radio.emit(request.remoteId.str, BmConnectionStateEnum.disconnected);
    return true;
  }

  @override
  Future<bool> discoverServices(BmDiscoverServicesRequest request) async {
    scheduleMicrotask(
      () => _services.add(
        BmDiscoverServicesResult(
          remoteId: request.remoteId,
          services: [
            BmBluetoothService(
              remoteId: request.remoteId,
              primaryServiceUuid: null,
              serviceUuid: Guid('ffe0'),
              characteristics: [
                for (final c in characteristics) c.forDevice(request.remoteId),
              ],
            ),
          ],
          success: true,
          errorCode: 0,
          errorString: '',
        ),
      ),
    );
    return true;
  }

  @override
  Future<bool> setNotifyValue(BmSetNotifyValueRequest request) async {
    subscriptions.add(request);
    scheduleMicrotask(
      () => _descriptors.add(
        BmDescriptorData(
          remoteId: request.remoteId,
          primaryServiceUuid: request.primaryServiceUuid,
          serviceUuid: request.serviceUuid,
          characteristicUuid: request.characteristicUuid,
          instanceId: request.instanceId,
          descriptorUuid: Guid('2902'),
          value: [1, 0],
          success: true,
          errorCode: 0,
          errorString: '',
        ),
      ),
    );
    return true;
  }

  @override
  Future<bool> writeCharacteristic(BmWriteCharacteristicRequest request) async {
    writes.add(request);
    await beforeWrite?.call(request);
    if (failedWritesRemaining > 0) {
      failedWritesRemaining--;
      throw Exception('initial GATT write rejected');
    }
    final characteristic = characteristics.singleWhere(
      (c) => c.instanceId == request.instanceId,
    );
    if (!(characteristic.write || characteristic.writeWithoutResponse)) {
      throw Exception('write not permitted on notify-only FFE1');
    }
    scheduleMicrotask(() {
      _written.add(_data(request.remoteId, request.instanceId, request.value));
      afterWrite?.call(request);
    });
    return true;
  }

  void notify(DeviceIdentifier id, int instanceId, List<int> bytes) =>
      _received.add(_data(id, instanceId, bytes));

  BmCharacteristicData _data(
    DeviceIdentifier id,
    int instanceId,
    List<int> bytes,
  ) => BmCharacteristicData(
    remoteId: id,
    primaryServiceUuid: null,
    serviceUuid: Guid('ffe0'),
    characteristicUuid: Guid('ffe1'),
    instanceId: instanceId,
    value: bytes,
    success: true,
    errorCode: 0,
    errorString: '',
  );
}
