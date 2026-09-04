import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/bms_link.dart';
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

  @override
  Stream<List<int>> get bytes => _bytes.stream;
  @override
  Stream<BleLinkState> get state => _state.stream;
  @override
  Stream<BleLinkError> get errors => _errors.stream;
  @override
  int? negotiatedMtu = 244;

  @override
  LinkHealth get health => LinkHealth.unknown;

  @override
  Stream<List<DiscoveredBms>> scan() => const Stream.empty();
  @override
  Future<void> connect(String deviceId) async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> dispose() async {
    await _bytes.close();
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
