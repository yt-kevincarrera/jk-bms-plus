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

/// How the automatic reconnect is getting on, for a screen to show.
///
/// Exists because the app had no way to say "it tried and it failed". The
/// transport cycled connecting, failed, connecting every few hundred
/// milliseconds, so the banner never rested on a failure and showed a spinner
/// instead — while the rider's only way to learn the reason was to leave the
/// screen and open the connect screen, where the same error had been arriving
/// all along.
class LinkRetryState {
  const LinkRetryState({this.failures = 0, this.gaveUp = false});

  /// Attempts that have failed in a row, with no reading in between.
  final int failures;

  /// Whether the loop has stopped trying. Nothing starts it again on its own;
  /// [BmsLink.retryNow] is how the rider asks for another go.
  final bool gaveUp;

  static const LinkRetryState none = LinkRetryState();
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

  /// How the automatic reconnect is getting on. Defaults to nothing to
  /// report, which is the honest answer for a transport that cannot drop.
  LinkRetryState get retry => LinkRetryState.none;

  /// Another go after the loop has given up, because the rider asked. A
  /// transport with no loop has nothing to do here.
  Future<void> retryNow() async {}

  Stream<List<DiscoveredBms>> scan();

  Future<void> connect(String deviceId);

  Future<void> disconnect();

  Future<void> dispose();
}
