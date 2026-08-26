import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../protocol/jk_constants.dart';
import 'bms_link.dart';

/// What the link is doing right now.
enum BleLinkState {
  idle,
  scanning,
  connecting,
  negotiating,
  connected,
  reconnecting,
  failed,
}

/// A JK BMS advertising nearby.
class DiscoveredBms {
  const DiscoveredBms({
    required this.id,
    required this.name,
    required this.rssi,
  });

  final String id;
  final String name;
  final int rssi;
}

/// Why the link is down, in words a rider can act on.
class BleLinkError {
  const BleLinkError(this.message, {this.likelyBusy = false});

  final String message;

  /// The BMS accepts exactly one BLE connection at a time. When the official
  /// app (or an ESP32) already holds it, connection attempts fail in ways that
  /// look like a generic error, so we call it out explicitly.
  final bool likelyBusy;

  @override
  String toString() => message;
}

/// Owns the one and only BLE connection to the BMS.
///
/// Deliberately knows nothing about frame contents: it emits raw notification
/// payloads and lets [FrameAssembler] and [JkParser] make sense of them.
///
/// There is exactly one of these in the app. The BMS will not accept a second
/// connection, so a second transport would not just be wasteful, it would fight
/// the first one for the channel.
class BleTransport implements BmsLink {
  BleTransport({
    this.mtuRequest = 244,
    this.reconnectDelay = const Duration(seconds: 2),
    this.pollInterval = const Duration(seconds: 5),
  });

  /// MTU we ask for on connect. 244 is the largest an Android BLE stack will
  /// grant over a 247-byte ATT MTU, and it drops a 300-byte frame from 15
  /// notifications to 2.
  final int mtuRequest;

  final Duration reconnectDelay;

  /// How often to re-ask for cell info if the BMS goes quiet. The BMS normally
  /// pushes on its own once asked; this is a nudge, not a poll loop.
  final Duration pollInterval;

  final _stateController = StreamController<BleLinkState>.broadcast();
  final _bytesController = StreamController<List<int>>.broadcast();
  final _errorController = StreamController<BleLinkError>.broadcast();

  @override
  Stream<BleLinkState> get state => _stateController.stream;

  /// Raw notification payloads, in arrival order.
  @override
  Stream<List<int>> get bytes => _bytesController.stream;

  @override
  Stream<BleLinkError> get errors => _errorController.stream;

  BleLinkState _currentState = BleLinkState.idle;
  BleLinkState get currentState => _currentState;

  /// Negotiated MTU, once known. Useful for the System tab: a link stuck at 23
  /// explains a lot of dropped frames.
  
  @override
  int? negotiatedMtu;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  Timer? _pollTimer;

  bool _wantConnection = false;
  bool _disposed = false;

  /// Scans for devices exposing the JK service. Some firmware does not put the
  /// service UUID in the advertisement, so name-matched devices are included
  /// too rather than being invisible.
  
  @override
  Stream<List<DiscoveredBms>> scan({
    Duration timeout = const Duration(seconds: 12),
  }) {
    _setState(BleLinkState.scanning);
    final found = <String, DiscoveredBms>{};
    final controller = StreamController<List<DiscoveredBms>>();

    late StreamSubscription<List<ScanResult>> sub;
    sub = FlutterBluePlus.scanResults.listen((results) {
      var changed = false;
      for (final r in results) {
        final name = r.advertisementData.advName.isNotEmpty
            ? r.advertisementData.advName
            : r.device.platformName;
        final advertisesService = r.advertisementData.serviceUuids
            .any((u) => u.str.toLowerCase().contains('ffe0'));
        final looksLikeJk = name.toUpperCase().contains('JK');
        if (!advertisesService && !looksLikeJk) continue;

        final id = r.device.remoteId.str;
        final existing = found[id];
        if (existing == null || existing.rssi != r.rssi) {
          found[id] = DiscoveredBms(id: id, name: name, rssi: r.rssi);
          changed = true;
        }
      }
      if (changed) controller.add(found.values.toList());
    });

    FlutterBluePlus.startScan(timeout: timeout).catchError((Object e) {
      _errorController.add(BleLinkError('Could not start scanning: $e'));
    });

    controller.onCancel = () async {
      await sub.cancel();
      await FlutterBluePlus.stopScan();
      if (_currentState == BleLinkState.scanning) _setState(BleLinkState.idle);
    };

    return controller.stream;
  }

  /// Connects and keeps the link up until [disconnect] is called.
  @override
  Future<void> connect(String deviceId) async {
    _wantConnection = true;
    final device = BluetoothDevice.fromId(deviceId);
    _device = device;

    await _connectionSub?.cancel();
    _connectionSub = device.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected && _wantConnection) {
        _onDropped();
      }
    });

    await _attach();
  }

  Future<void> _attach() async {
    final device = _device;
    if (device == null || _disposed) return;

    try {
      _setState(BleLinkState.connecting);
      await FlutterBluePlus.stopScan();
      await device.connect(
        // flutter_blue_plus requires this declaration. This app is a personal
        // tool for one rider and one motorcycle, and section 2 of the PRD rules
        // out publishing it, so the nonprofit terms apply. Revisit if that ever
        // changes.
        license: License.nonprofit,
        timeout: const Duration(seconds: 20),
        // Null so the MTU request below is ours to observe and report on.
        mtu: null,
        autoConnect: false,
      );

      _setState(BleLinkState.negotiating);

      // Ask for a big MTU straight away. Android may grant less; the frame
      // assembler copes either way, so a refusal is worth recording, not fatal.
      try {
        await device.requestMtu(mtuRequest);
        negotiatedMtu = device.mtuNow;
      } on Exception catch (e) {
        negotiatedMtu = device.mtuNow;
        _errorController.add(
          BleLinkError(
            'MTU stayed at ${device.mtuNow} bytes ($e). Frames will arrive in '
            'more pieces, which is slower but still correct.',
          ),
        );
      }

      final characteristic = await _findCharacteristic(device);
      _characteristic = characteristic;

      await _notifySub?.cancel();
      _notifySub = characteristic.onValueReceived.listen(
        _bytesController.add,
        onError: (Object e) =>
            _errorController.add(BleLinkError('Notification error: $e')),
      );
      await characteristic.setNotifyValue(true);

      _setState(BleLinkState.connected);

      // The BMS answers device info first; the variant we decode everything
      // else with comes out of that frame, so it has to be the first request.
      await requestDeviceInfo();
      await requestCellInfo();

      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(pollInterval, (_) => requestCellInfo());
    } on Exception catch (e) {
      _setState(BleLinkState.failed);
      _errorController.add(_describeConnectFailure(e));
      if (_wantConnection) _scheduleReconnect();
    }
  }

  Future<BluetoothCharacteristic> _findCharacteristic(
    BluetoothDevice device,
  ) async {
    final services = await device.discoverServices();
    for (final service in services) {
      if (!service.uuid.str.toLowerCase().contains('ffe0')) continue;
      for (final c in service.characteristics) {
        if (!c.uuid.str.toLowerCase().contains('ffe1')) continue;
        // Newer BLE modules expose 0xFFE1 twice: one write-only, one notify.
        // We need the one that can notify.
        if (c.properties.notify || c.properties.indicate) return c;
      }
    }
    throw StateError(
      'This device does not expose a notifying $jkCharacteristicUuid16 '
      'characteristic on service $jkServiceUuid16, so it is not a JK BMS '
      'this app can talk to.',
    );
  }

  BleLinkError _describeConnectFailure(Object e) {
    final text = e.toString();
    // Android surfaces "already connected elsewhere" as GATT 133 / 8 / 22 more
    // often than as anything readable.
    final busy = text.contains('133') ||
        text.contains('ANDROID_SPECIFIC_ERROR') ||
        text.contains('status: 8') ||
        text.contains('status: 22');
    if (busy) {
      return BleLinkError(
        'Could not connect. The JK BMS accepts only one Bluetooth connection '
        'at a time, so close the official JK app (and any ESP32 logger) and '
        'try again.',
        likelyBusy: true,
      );
    }
    return BleLinkError('Connection failed: $text');
  }

  void _onDropped() {
    _pollTimer?.cancel();
    _notifySub?.cancel();
    _notifySub = null;
    _characteristic = null;
    _setState(BleLinkState.reconnecting);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_wantConnection || _disposed) return;
    Timer(reconnectDelay, () {
      if (_wantConnection && !_disposed) _attach();
    });
  }

  /// Asks the BMS for a device info frame (record type 0x03).
  Future<void> requestDeviceInfo() => _writeCommand(commandDeviceInfo);

  /// Asks the BMS for a cell info frame (record type 0x02).
  Future<void> requestCellInfo() => _writeCommand(commandCellInfo);

  /// Builds and sends a read command.
  ///
  /// This is the only place the app ever writes to the BMS, and it only ever
  /// writes read requests. Writing settings is out of scope: the protocol is
  /// reverse-engineered, and a wrong value can disable a protection.
  ///
  /// Frame layout source: `build_frame()` in
  /// https://github.com/syssi/esphome-jk-bms/blob/main/components/jk_bms_ble/jk_bms_ble.cpp
  Future<void> _writeCommand(int register) async {
    final c = _characteristic;
    if (c == null) return;

    final frame = List<int>.filled(commandFrameSize, 0);
    frame.setRange(0, 4, commandPreamble);
    frame[4] = register; // holding register
    frame[5] = 0x00; // value length in bytes; 0 for a read
    // Bytes 6..9 carry the value, which stays zero for a read.
    var sum = 0;
    for (var i = 0; i < commandFrameSize - 1; i++) {
      sum = (sum + frame[i]) & 0xFF;
    }
    frame[commandFrameSize - 1] = sum;

    try {
      await c.write(frame, withoutResponse: c.properties.writeWithoutResponse);
    } on Exception catch (e) {
      _errorController.add(BleLinkError('Could not send request: $e'));
    }
  }

  @override
  Future<void> disconnect() async {
    _wantConnection = false;
    _pollTimer?.cancel();
    await _notifySub?.cancel();
    await _connectionSub?.cancel();
    _notifySub = null;
    _connectionSub = null;
    _characteristic = null;
    try {
      await _device?.disconnect();
    } on Exception catch (_) {
      // Already gone; nothing useful to do.
    }
    _setState(BleLinkState.idle);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _stateController.close();
    await _bytesController.close();
    await _errorController.close();
  }

  void _setState(BleLinkState s) {
    _currentState = s;
    if (!_stateController.isClosed) _stateController.add(s);
  }
}
