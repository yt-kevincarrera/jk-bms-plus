import 'ble_transport.dart';

/// The surface [BmsService] needs from a transport.
///
/// Exists so the service can be tested by feeding it captured bytes, without a
/// phone, a BLE stack, or a battery in the room. [BleTransport] is the only
/// production implementation.
abstract interface class BmsLink {
  /// Raw notification payloads, in arrival order.
  Stream<List<int>> get bytes;

  Stream<BleLinkState> get state;

  Stream<BleLinkError> get errors;

  /// Negotiated ATT MTU once known, null before that.
  int? get negotiatedMtu;

  Stream<List<DiscoveredBms>> scan();

  Future<void> connect(String deviceId);

  Future<void> disconnect();

  Future<void> dispose();
}
