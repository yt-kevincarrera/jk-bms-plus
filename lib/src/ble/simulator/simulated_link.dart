import 'dart:async';
import 'dart:typed_data';

import '../../model/ant_settings.dart';
import '../../protocol/ant_constants.dart';
import '../../protocol/ant_crc.dart';
import '../../protocol/bms_brand.dart';
import '../../protocol/jk_constants.dart';
import '../ble_transport.dart';
import '../bms_link.dart';
import '../bms_write_gate.dart';
import '../link_script.dart';
import 'ant_frame_builder.dart';
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
///
/// For an ANT scenario it speaks ANT instead, and like an ANT it says nothing
/// unless asked: it runs the app's own [LinkScript.ant] the way the transport
/// does, and answers each request it is sent (status, device info, settings
/// reads) with a CRC'd 2021 frame. A request it does not recognise, or one
/// whose CRC is wrong, gets no answer, as on a pack.
class SimulatedLink implements BmsLink {
  SimulatedLink({
    this.tickInterval = const Duration(seconds: 1),
    DemoScenario scenario = DemoScenario.riding,
  }) : pack = SimulatedPack(scenario: scenario),
       brand = scenario.brand;

  final Duration tickInterval;
  final SimulatedPack pack;

  /// Which BMS this simulator is. Fixed for its life: a different brand is a
  /// different pack, and the service starts demo mode again for it.
  final BmsBrand brand;

  static const _builder = JkFrameBuilder();
  static const _antBuilder = AntFrameBuilder();

  /// The settings the simulated ANT answers with. Modelled, like the pack.
  static const Map<AntSetting, double> antSettingValues = {
    AntSetting.cellOvp: 4.20,
    AntSetting.cellOvpRecovery: 4.10,
    AntSetting.cellUvp: 2.80,
    AntSetting.cellUvpRecovery: 3.00,
    AntSetting.chargeOcp: 20,
    AntSetting.chargeOcpDelay: 3,
    AntSetting.dischargeOcp: 120,
    AntSetting.dischargeOcpDelay: 5,
    AntSetting.shortCircuit: 400,
    AntSetting.balanceStart: 3.40,
    AntSetting.balanceTrigger: 0.010,
    AntSetting.balanceCurrent: 120,
    AntSetting.cellCount: 20,
    AntSetting.shutdownVoltage: 2.70,
  };

  // The ANT poll loop's own state, kept the way the transport keeps it.
  final LinkScript _antScript = LinkScript.ant;
  Timer? _pollTimer;
  int _pollTick = 0;
  bool _antInfoSeen = false;
  int _settingsReadsSent = 0;
  DateTime? _connectedAt;
  DateTime? _lastAnsweredAt;

  final _bytes = StreamController<List<int>>.broadcast();
  final _state = StreamController<BleLinkState>.broadcast();
  final _errors = StreamController<BleLinkError>.broadcast();

  Timer? _timer;
  int _counter = 0;

  final _writes = StreamController<List<int>>.broadcast();

  @override
  Stream<List<int>> get bytes => _bytes.stream;

  /// What the app sent the simulated pack. For a JK, which streams on its
  /// own, only switch writes; for an ANT, every read request it was polled
  /// with, as the console shows for a real one.
  @override
  Stream<List<int>> get writes => _writes.stream;
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
  Stream<List<DiscoveredBms>> scan() => Stream.value([
        brand == BmsBrand.ant
            ? const DiscoveredBms(id: 'demo', name: 'ANT-BLE20S (demo)', rssi: -54)
            : const DiscoveredBms(
                id: 'demo',
                name: 'JK-B2A24S20P (demo)',
                rssi: -54,
              ),
      ]);

  @override
  Future<void> connect(String deviceId) async {
    _state.add(BleLinkState.connecting);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _state.add(BleLinkState.negotiating);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _state.add(BleLinkState.connected);

    if (brand == BmsBrand.ant) {
      _startAnt();
      return;
    }

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

    _emitSettings();

    _emitCellInfo();
    _timer?.cancel();
    _timer = Timer.periodic(tickInterval, (_) {
      pack.tick(tickInterval);
      _emitCellInfo();
    });
  }

  void _emitSettings() {
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
        chargeSwitchOn: pack.chargeSwitchOn,
        dischargeSwitchOn: pack.dischargeSwitchOn,
        balancerSwitchOn: pack.balancerSwitchOn,
      ),
    );
  }

  /// The ANT side: the pack ages on its own timer, and speaks only when the
  /// poll loop asks, exactly as [BleTransport] drives a real one.
  void _startAnt() {
    _connectedAt = DateTime.now();
    _pollTick = 0;
    _antInfoSeen = false;
    _settingsReadsSent = 0;
    _timer?.cancel();
    _timer = Timer.periodic(tickInterval, (_) => pack.tick(tickInterval));
    for (final f in _antScript.onConnect) {
      _request(f);
    }
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_antScript.tickEvery, (_) => pollAnt());
  }

  /// One tick of the ANT poll loop. Public so a test can step it.
  void pollAnt() {
    if (_timer == null) return;
    _pollTick++;
    final action = _antScript.tick(
      now: DateTime.now(),
      lastFrameAt: _lastAnsweredAt,
      connectedAt: _connectedAt,
      tickNumber: _pollTick,
      deviceInfoSeen: _antInfoSeen,
      quietBefore: const Duration(seconds: 6),
      muteBefore: const Duration(minutes: 5),
      settingsReadsSent: _settingsReadsSent,
    );
    if (action case WriteFrame(:final bytes, :final settingsRead)) {
      if (settingsRead) _settingsReadsSent++;
      _request(bytes);
    }
  }

  /// Takes one request the way the pack would: shows it as sent, checks it,
  /// and answers it a moment later.
  void _request(List<int> f) {
    if (!_writes.isClosed) _writes.add(List<int>.from(f));
    final reply = antReplyTo(f);
    if (reply != null) scheduleMicrotask(() => _emit(reply));
  }

  /// The frame a simulated ANT answers [request] with, or null for none.
  ///
  /// Only the three reads are answered: function 0x01 for the status, and
  /// function 0x02 at the device info address or at one of the settings
  /// registers. Anything else, a write included, is ignored, and nothing a
  /// request says ever changes the pack.
  Uint8List? antReplyTo(List<int> request) {
    final f = request;
    if (f.length != 10 ||
        f[0] != 0x7E ||
        f[1] != 0xA1 ||
        f[8] != 0xAA ||
        f[9] != 0x55 ||
        antCrc16(f, 1, 6) != (f[6] | (f[7] << 8))) {
      return null;
    }
    final address = f[3] | (f[4] << 8);
    if (f[2] == 0x01) return _antStatus();
    if (f[2] != antFnRead) return null;
    if (address == antDeviceInfoAddress) {
      return _antBuilder.deviceInfo(
        model: 'DEMO20S',
        software: 'DEMO-2021-SIM',
      );
    }
    final setting = AntSetting.byAddress(address);
    final value = setting == null ? null : antSettingValues[setting];
    if (setting == null || value == null) return null;
    return _antBuilder.settingReply(setting, value);
  }

  Uint8List _antStatus() {
    final cycle = pack.cycleCapacityAh;
    final runtime = pack.runtimeSeconds;
    return _antBuilder.status(
      cellVoltages: pack.cellVoltages,
      temperatures: pack.temperatures,
      mosfetTemp: pack.mosfetTemp,
      balancerTemp: pack.mosfetTemp + 1,
      packVoltage: pack.packVoltage,
      current: pack.current,
      soc: pack.soc,
      soh: pack.soh,
      chargeMosfetOn: pack.chargeMosfetOn,
      dischargeMosfetOn: pack.dischargeMosfetOn,
      // Code 1, "exceeds the limit equilibrium", is one of the two the app
      // reads as balancing under way.
      balancerCode: pack.balancerActive ? 0x01 : 0x00,
      balancingCellMask: 0,
      nominalCapacityAh: pack.nominalCapacityAh,
      remainingCapacityAh: pack.remainingCapacityAh,
      totalDischargedAh: cycle - 20,
      totalChargedAh: cycle + 20,
      runtimeSeconds: runtime,
      dischargingSeconds: runtime * 3 ~/ 10,
      chargingSeconds: runtime * 2 ~/ 10,
    );
  }

  /// Honours a switch write the way a pack would: reads the register and the
  /// value out of the frame itself, after checking its checksum, rather than
  /// trusting the fields beside it. A frame a real BMS would drop is dropped
  /// here too, so demo mode cannot show working what would fail on a pack.
  /// A simulated ANT takes none: the switches are JK registers.
  @override
  Future<bool> writeRegister(RegisterWrite write) async {
    if (_timer == null || brand == BmsBrand.ant) return false;
    final f = write.frame;
    if (f.length != commandFrameSize) return false;
    var sum = 0;
    for (var i = 0; i < commandFrameSize - 1; i++) {
      sum = (sum + f[i]) & 0xFF;
    }
    if (!_writes.isClosed) _writes.add(f);
    if (sum != f[commandFrameSize - 1] || f[5] != switchValueLength) {
      return true;
    }
    final on = f[6] != 0;
    switch (f[4]) {
      case registerChargeSwitch:
        pack.chargeSwitchOn = on;
      case registerDischargeSwitch:
        pack.dischargeSwitchOn = on;
      case registerBalancerSwitch:
        pack.balancerSwitchOn = on;
    }
    return true;
  }

  /// Answers with a settings frame, so a write can be confirmed in demo mode
  /// the same way as on a pack: by what the frame says.
  @override
  Future<void> askSettings() async {
    if (_timer != null && brand == BmsBrand.jk) _emitSettings();
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
  LinkHealth get health => LinkHealth.unknown;
  @override
  LinkRetryState get retry => LinkRetryState.none;
  @override
  Future<void> retryNow() async {}

  /// The decoder heard a frame. The ANT poll loop needs it, as the transport
  /// does: device info seen stops it asking again, and opens the settings
  /// reads.
  @override
  void frameAccepted({bool deviceInfo = false}) {
    _lastAnsweredAt = DateTime.now();
    if (deviceInfo) _antInfoSeen = true;
  }

  /// The simulator runs the script of the brand it is, whatever the radio's
  /// is set to, so there is nothing to steer here.
  @override
  set script(LinkScript value) {}

  /// A simulated ANT is asked like a real one; a simulated JK streams anyway.
  @override
  Future<void> askAgain() async {
    if (_timer != null && brand == BmsBrand.ant) _request(_antScript.askAgain);
  }

  @override
  set persistRetries(bool value) {}

  @override
  Future<void> disconnect() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _timer?.cancel();
    _timer = null;
    if (!_state.isClosed) _state.add(BleLinkState.idle);
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _bytes.close();
    await _writes.close();
    await _state.close();
    await _errors.close();
  }
}
