import 'dart:async';
import 'dart:typed_data';

import '../ble_transport.dart';
import '../bms_link.dart';
import 'jk_frame_builder.dart';
import 'simulated_pack.dart';

/// A stand-in BMS for demo mode.
///
/// It emits real 300-byte frames in 20-byte notification chunks, so everything
/// downstream — checksum, reassembly, variant detection, parsing — runs exactly
/// as it will against the hardware. Only the radio is missing.
///
/// It reports itself as a JK-B2A24S20P on software 10.07, which detects as
/// JK02_24S: the framing a 20S pack uses.
class SimulatedLink implements BmsLink {
  SimulatedLink({
    this.tickInterval = const Duration(seconds: 1),
    DemoScenario scenario = DemoScenario.riding,
  }) : pack = SimulatedPack(scenario: scenario);

  final Duration tickInterval;
  final SimulatedPack pack;

  static const _builder = JkFrameBuilder();

  final _bytes = StreamController<List<int>>.broadcast();
  final _state = StreamController<BleLinkState>.broadcast();
  final _errors = StreamController<BleLinkError>.broadcast();

  Timer? _timer;
  int _counter = 0;

  @override
  Stream<List<int>> get bytes => _bytes.stream;
  @override
  Stream<BleLinkState> get state => _state.stream;
  @override
  Stream<BleLinkError> get errors => _errors.stream;

  /// Demo mode reports the MTU a successful negotiation gives you, so the
  /// System tab shows what a healthy link looks like.
  @override
  int? negotiatedMtu = 244;

  DemoScenario get scenario => pack.scenario;
  set scenario(DemoScenario value) => pack.scenario = value;

  @override
  Stream<List<DiscoveredBms>> scan() => Stream.value(const [
        DiscoveredBms(id: 'demo', name: 'JK-B2A24S20P (demo)', rssi: -54),
      ]);

  @override
  Future<void> connect(String deviceId) async {
    _state.add(BleLinkState.connecting);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _state.add(BleLinkState.negotiating);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _state.add(BleLinkState.connected);

    _emit(
      _builder.deviceInfo(
        counter: _counter++,
        model: 'JK-B2A24S20P',
        hardwareVersion: '10.XW',
        softwareVersion: '10.07',
        uptimeSeconds: pack.runtimeSeconds,
        powerOnCount: 412,
        deviceName: 'JK BMS',
        devicePasscode: '1234',
        manufacturingDate: '240118',
        serialNumber: 'DEMO0000001',
      ),
    );

    _emit(
      _builder.settings(
        counter: _counter++,
        cellUvp: 2.8,
        cellUvpRecovery: 3.0,
        cellOvp: 4.2,
        cellOvpRecovery: 4.1,
        balanceTriggerVoltage: 0.01,
        powerOffVoltage: 2.7,
        maxChargeCurrent: 20,
        maxDischargeCurrent: 120,
        maxBalanceCurrent: 1,
        chargeOtp: 55,
        dischargeOtp: 65,
        chargeUtp: 0,
        cellCount: pack.cellCount,
        nominalCapacityAh: pack.nominalCapacityAh,
        balanceStartVoltage: 3.4,
      ),
    );

    _emitCellInfo();
    _timer?.cancel();
    _timer = Timer.periodic(tickInterval, (_) {
      pack.tick(tickInterval);
      _emitCellInfo();
    });
  }

  void _emitCellInfo() {
    _emit(
      _builder.cellInfo(
        counter: _counter++,
        cellVoltages: pack.cellVoltages,
        cellResistances: pack.cellResistances,
        packVoltage: pack.packVoltage,
        current: pack.current,
        temperatures: pack.temperatures,
        mosfetTemp: pack.mosfetTemp,
        soc: pack.soc,
        soh: pack.soh,
        remainingCapacityAh: pack.remainingCapacityAh,
        nominalCapacityAh: pack.nominalCapacityAh,
        cycleCount: pack.cycleCount,
        cycleCapacityAh: pack.cycleCapacityAh,
        balancingAction: pack.balancingAction,
        balanceCurrent: pack.balanceCurrent,
        chargeMosfetOn: pack.chargeMosfetOn,
        dischargeMosfetOn: pack.dischargeMosfetOn,
        errorBitmask: pack.errorBitmask,
        totalRuntimeSeconds: pack.runtimeSeconds,
        chargerPlugged: pack.chargerPlugged,
      ),
    );
  }

  /// Delivers a frame the way BLE does: 20 bytes at a time.
  void _emit(Uint8List frame) {
    if (_bytes.isClosed) return;
    for (var i = 0; i < frame.length; i += 20) {
      _bytes.add(frame.sublist(i, (i + 20).clamp(0, frame.length)));
    }
  }

  @override
  Future<void> disconnect() async {
    _timer?.cancel();
    _timer = null;
    if (!_state.isClosed) _state.add(BleLinkState.idle);
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _bytes.close();
    await _state.close();
    await _errors.close();
  }
}
