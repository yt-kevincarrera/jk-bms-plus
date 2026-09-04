import 'dart:math' as math;

/// What should happen when the rider taps a pack.
enum TapVerdict {
  /// Connect.
  go,

  /// An attempt is already running. Tapping again cannot help.
  busy,

  /// This pack failed recently and its cooldown has not expired.
  cooling,

  /// Enough attempts have failed in a row that the phone's Bluetooth stack is
  /// the suspect, not the pack. Another attempt makes it worse.
  saturated,
}

/// Decides whether a tap becomes a connection attempt, and when to stop
/// offering attempts altogether.
///
/// Exists because tapping repeatedly is actively harmful and the app used to
/// invite it. Every cancelled or failed attempt is a chance to leave a
/// connection Android never closes: the plugin closes the GATT client when the
/// disconnect callback arrives, and its own comment says that without that
/// close "we will quickly run out of bluetooth resources, preventing new
/// connections". Those resources are shared by the whole phone, which is why
/// the rider saw the official JK app hang on "connecting" too, and why only a
/// reboot cleared it.
///
/// So the app stops treating a tap as free. One attempt at a time; a growing
/// pause after each failure, shown as a countdown rather than a dead button;
/// and after enough consecutive failures it says the phone is the problem
/// instead of letting the rider exhaust it further.
///
/// Pure, so all of that can be tested without a radio.
class ConnectGuard {
  ConnectGuard({
    this.firstCooldown = const Duration(seconds: 5),
    this.maxCooldown = const Duration(seconds: 40),
    this.saturatedAfter = 4,
  });

  /// The pause after the first failure. Doubles with each further failure on
  /// the same pack, up to [maxCooldown].
  ///
  /// Long enough to matter: the BMS itself needs a few seconds to notice it
  /// was let go, and Android needs the disconnect callback to arrive before it
  /// can reclaim anything. Tapping inside this window is what turns one stuck
  /// connection into several.
  final Duration firstCooldown;

  /// The ceiling, so a pack that has failed all evening does not lock the
  /// rider out for minutes at a time.
  final Duration maxCooldown;

  /// Consecutive failures, across every pack, after which attempts stop being
  /// offered. Across packs on purpose: what runs out is the phone's, not the
  /// pack's, so failures on two different packs are evidence of the same
  /// thing.
  final int saturatedAfter;

  final Map<String, _Attempts> _attempts = {};
  int _consecutiveFailures = 0;

  /// Failures in a row, with no success in between.
  int get consecutiveFailures => _consecutiveFailures;

  /// Whether the phone's Bluetooth stack is the likely culprit by now.
  bool get saturated => _consecutiveFailures >= saturatedAfter;

  /// How long this pack still has to wait, or null if it can be tapped now.
  Duration? cooldownLeft({required String deviceId, required DateTime now}) {
    final a = _attempts[deviceId];
    if (a == null || a.failures == 0) return null;
    final left = _cooldownFor(a.failures) - now.difference(a.lastFailureAt);
    return left > Duration.zero ? left : null;
  }

  TapVerdict judge({
    required String deviceId,
    required DateTime now,
    required bool busy,
  }) {
    if (busy) return TapVerdict.busy;
    // Before the cooldown: once the stack is the suspect, which pack was
    // tapped stops mattering.
    if (saturated) return TapVerdict.saturated;
    if (cooldownLeft(deviceId: deviceId, now: now) != null) {
      return TapVerdict.cooling;
    }
    return TapVerdict.go;
  }

  void recordFailure({required String deviceId, required DateTime at}) {
    final a = _attempts.putIfAbsent(deviceId, _Attempts.new);
    a.failures++;
    a.lastFailureAt = at;
    _consecutiveFailures++;
  }

  /// A reading arrived. Everything the failures implied is disproved.
  void recordSuccess({required String deviceId}) {
    _attempts.remove(deviceId);
    _consecutiveFailures = 0;
  }

  /// Clears the ledger after the rider has been told what to do about the
  /// phone, so the screen offers one more attempt rather than refusing for
  /// the rest of the session. Restarting Bluetooth or the phone is exactly
  /// what makes the next attempt worth trying.
  void forgive() {
    _attempts.clear();
    _consecutiveFailures = 0;
  }

  Duration _cooldownFor(int failures) {
    // 5s, 10s, 20s, 40s. Doubling rather than linear because the second
    // failure in a row means something is wrong that a moment will not fix.
    final grown = firstCooldown * math.pow(2, failures - 1).toDouble();
    return grown > maxCooldown ? maxCooldown : grown;
  }
}

class _Attempts {
  int failures = 0;
  DateTime lastFailureAt = DateTime.fromMillisecondsSinceEpoch(0);
}
