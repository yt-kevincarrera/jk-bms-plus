import 'ble_transport.dart';

/// How well the link has been behaving, for a screen to show.
///
/// Exists because a diagnosis was made from a backup after the fact, and the
/// next one should not have to be. A rider whose ride has holes in it deserves
/// to be able to see whether the link dropped, or whether the pack simply went
/// quiet while the link stayed up. Those have different causes and the app was
/// unable to tell them apart from the outside.
class LinkHealth {
  const LinkHealth({
    this.drops = 0,
    this.timeDisconnected = Duration.zero,
    this.nudges = 0,
  });

  /// Times the link went away since the app started.
  final int drops;

  /// How long has been spent disconnected in total.
  final Duration timeDisconnected;

  /// Times the pack had to be prodded because it stopped talking on its own.
  ///
  /// The number that settles an argument. The app used to prod it every five
  /// seconds regardless; if this stays near zero on a ride whose readings are
  /// continuous, the prodding was the problem.
  final int nudges;

  static const LinkHealth unknown = LinkHealth();
}

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

  /// Link behaviour so far. Defaults to nothing worth reporting, which is the
  /// honest answer for a simulated or captured-byte transport.
  LinkHealth get health => LinkHealth.unknown;

  Stream<List<DiscoveredBms>> scan();

  Future<void> connect(String deviceId);

  Future<void> disconnect();

  Future<void> dispose();
}
