import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/bms_link.dart';
import 'package:jk_bms/src/ble/bms_write_gate.dart';
import 'package:jk_bms/src/ble/link_script.dart';
import 'package:jk_bms/src/gps/location_source.dart';

/// A [BmsLink] double any test can drive by hand: feed it frames, announce
/// link states, and it never touches real Bluetooth.
///
/// Shared rather than redeclared per test file, so a change to [BmsLink]
/// only needs fixing in one fake instead of one per file that drifts from it.
class FakeLink implements BmsLink {
  final _bytes = StreamController<List<int>>.broadcast();
  final _state = StreamController<BleLinkState>.broadcast();
  final _errors = StreamController<BleLinkError>.broadcast();
  final _writes = StreamController<List<int>>.broadcast();

  @override
  Stream<List<int>> get bytes => _bytes.stream;
  @override
  Stream<List<int>> get writes => _writes.stream;

  /// What the radio would report after a write went through.
  void wrote(List<int> frame) => _writes.add(frame);
  @override
  Stream<BleLinkState> get state => _state.stream;
  @override
  Stream<BleLinkError> get errors => _errors.stream;
  @override
  int? negotiatedMtu = 244;

  @override
  LinkHealth get health => LinkHealth.unknown;

  /// Settable, so a test can put the loop in the given-up state and check
  /// what the service writes down about it.
  @override
  LinkRetryState retry = LinkRetryState.none;

  @override
  Future<void> retryNow() async {}

  /// Frames the service vouched for. The transport judges the link alive by
  /// these now, not by bytes, so a test has to be able to count them.
  int framesHeard = 0;

  /// Of those, how many were the pack identifying itself, so a test can see
  /// the service tell the transport so.
  int deviceInfoHeard = 0;

  @override
  void frameAccepted({bool deviceInfo = false}) {
    framesHeard++;
    if (deviceInfo) deviceInfoHeard++;
  }

  /// The last script the service handed over, so a test can check the brand
  /// it chose. Null until one is set.
  LinkScript? scriptSet;

  @override
  set script(LinkScript value) => scriptSet = value;

  /// Times the service asked the pack again.
  int asks = 0;

  @override
  Future<void> askAgain() async => asks++;

  /// Every switch write the service handed over, in order. A test that
  /// expects none checks this is empty: it is the bytes that would have
  /// reached the pack.
  final List<RegisterWrite> registerWrites = [];

  /// What the radio answers to a write: true for "the bytes went out".
  bool acceptWrites = true;

  /// Runs on every write, so a test can play the pack answering with a
  /// settings frame.
  Future<void> Function(RegisterWrite write)? onRegisterWrite;

  @override
  Future<bool> writeRegister(RegisterWrite write) async {
    registerWrites.add(write);
    if (acceptWrites) _writes.add(write.frame);
    await onRegisterWrite?.call(write);
    return acceptWrites;
  }

  /// Times the service asked for the settings again.
  int settingsAsks = 0;

  /// Runs on every settings request, for a pack that answers only when
  /// asked.
  Future<void> Function()? onAskSettings;

  @override
  Future<void> askSettings() async {
    settingsAsks++;
    await onAskSettings?.call();
  }

  /// What the radio would report, said from the test.
  void fail(BleLinkError error) => _errors.add(error);

  /// Whether the service asked the loop to refuse to give up. Recorded rather
  /// than ignored: it is the whole point of the ride-in-progress mode, and a
  /// test that cannot see it can only assert that nothing crashed.
  bool persisting = false;

  @override
  set persistRetries(bool value) => persisting = value;

  @override
  Stream<List<DiscoveredBms>> scan() => const Stream.empty();
  @override
  Future<void> connect(String deviceId) async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> dispose() async {
    await _bytes.close();
    await _writes.close();
    await _state.close();
    await _errors.close();
  }

  void announce(BleLinkState s) => _state.add(s);

  Future<void> deliver(Uint8List frame, {int chunk = 20}) async {
    for (var i = 0; i < frame.length; i += chunk) {
      _bytes.add(frame.sublist(i, (i + chunk).clamp(0, frame.length)));
    }
    await pumpEventQueue();
  }
}

/// A [LocationSource] double that never emits a fix and never fails to
/// start, so a test can connect a service without a real GPS underneath it.
class StubLocation implements LocationSource {
  final _controller = StreamController<GeoFix>.broadcast();
  @override
  Stream<GeoFix> get fixes => _controller.stream;
  @override
  Future<LocationProblem?> start() async => null;
  @override
  Future<void> stop() async {}
}
