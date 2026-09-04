import 'dart:async';

import 'ble_transport.dart';
import 'bms_link.dart';
import 'simulator/simulated_link.dart';
import 'simulator/simulated_pack.dart';

/// Lets the app switch between the real radio and the demo simulator without
/// building a second [BmsService].
///
/// That matters: the BMS accepts one BLE connection, so the app is built around
/// exactly one service, one assembler, one parser and one snapshot stream.
/// Swapping what feeds the bottom of that stack is the only honest way to add a
/// demo mode without duplicating the pipeline it is supposed to be previewing.
class SwitchableLink implements BmsLink {
  SwitchableLink({BleTransport? real})
      : _real = real ?? BleTransport() {
    _bind(_real);
  }

  final BleTransport _real;
  SimulatedLink? _simulator;

  /// The radio, for the one caller that needs to write to the pack directly:
  /// the service asking for cell info again when none has arrived.
  BleTransport get real => _real;

  final _bytes = StreamController<List<int>>.broadcast();
  final _state = StreamController<BleLinkState>.broadcast();
  final _errors = StreamController<BleLinkError>.broadcast();

  final List<StreamSubscription<Object?>> _subs = [];

  BmsLink _active = _Uninitialised();

  bool get isSimulated => _active is SimulatedLink;

  /// The running simulator, when demo mode is on.
  SimulatedLink? get simulator => _simulator;

  @override
  Stream<List<int>> get bytes => _bytes.stream;
  @override
  Stream<BleLinkState> get state => _state.stream;
  @override
  Stream<BleLinkError> get errors => _errors.stream;

  @override
  int? get negotiatedMtu => _active.negotiatedMtu;

  @override
  Stream<List<DiscoveredBms>> scan() => _active.scan();

  @override
  Future<void> connect(String deviceId) => _active.connect(deviceId);

  @override
  LinkHealth get health => _active.health;

  @override
  Future<void> disconnect() => _active.disconnect();

  /// Switches to the simulated pack. Any real connection is dropped first: the
  /// point of demo mode is to work with no BMS in the room, and leaving a live
  /// connection open would keep the channel busy for no reason.
  Future<void> useSimulator({
    DemoScenario scenario = DemoScenario.riding,
  }) async {
    await _real.disconnect();
    await _simulator?.dispose();
    final sim = SimulatedLink(scenario: scenario);
    _simulator = sim;
    _bind(sim);
  }

  /// Switches back to the radio.
  Future<void> useRealBms() async {
    await _simulator?.dispose();
    _simulator = null;
    _bind(_real);
  }

  void _bind(BmsLink link) {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    _active = link;
    _subs.addAll([
      link.bytes.listen(_bytes.add),
      link.state.listen(_state.add),
      link.errors.listen(_errors.add),
    ]);
  }

  @override
  Future<void> dispose() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    await _simulator?.dispose();
    await _real.dispose();
    await _bytes.close();
    await _state.close();
    await _errors.close();
  }
}

/// Placeholder so [SwitchableLink._active] is never null before the first bind.
/// Never actually used: the constructor binds immediately.
class _Uninitialised implements BmsLink {
  @override
  Stream<List<int>> get bytes => const Stream.empty();
  @override
  Stream<BleLinkState> get state => const Stream.empty();
  @override
  Stream<BleLinkError> get errors => const Stream.empty();
  @override
  int? get negotiatedMtu => null;
  @override
  LinkHealth get health => LinkHealth.unknown;
  @override
  Stream<List<DiscoveredBms>> scan() => const Stream.empty();
  @override
  Future<void> connect(String deviceId) async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> dispose() async {}
}
