import 'ble_transport.dart';

/// How a connect attempt ended, once it is worth saying.
enum FirstContactOutcome {
  /// A frame this app decodes arrived. The device is a JK BMS; open the
  /// screens, whatever else is still missing.
  proven,

  /// The link never reached `connected` inside its budget. Whatever link
  /// error is already on screen is the explanation, not this.
  linkNeverCameUp,

  /// The link came up and bytes arrived, but none of them decoded as a JK
  /// frame. The pack is talking; the app does not understand it.
  talkingButUndecoded,

  /// The link came up and nothing at all arrived. The pack is connected and
  /// mute, which on a JK BMS means someone else has its attention.
  connectedButSilent,
}

/// Judges one connect attempt from what the link and the decoder report.
///
/// Exists because the screen used to give every attempt fourteen seconds from
/// the tap to produce a snapshot, and call anything slower "almost certainly
/// not a JK BMS". Fourteen seconds is not enough for one failed connect (eight
/// seconds, the transport's cap) plus a retry, so a pack that needed two goes
/// was called a pair of headphones. And a snapshot is the wrong proof: the
/// service holds cell info back until device info has named the protocol
/// variant, so a pack whose device-info frame is slow, or whose variant the
/// detector cannot place, produced the same verdict, and the one screen that
/// lets a rider pick the variant by hand was behind the door that verdict kept
/// shut.
///
/// So the clock does not start on the connection until the connection exists,
/// device info counts as proof, and silence is told apart from noise that does
/// not decode. Pure so it can be tested without a radio: the caller feeds it
/// events and asks [judge] with the time.
class FirstContact {
  FirstContact({
    required this.startedAt,
    required this.bytesBefore,
    this.linkBudget = const Duration(seconds: 25),
    this.silenceBudget = const Duration(seconds: 12),
  });

  /// When the rider tapped.
  final DateTime startedAt;

  /// The decoder's byte count before this attempt, so bytes from an earlier
  /// connection are not mistaken for this pack talking.
  final int bytesBefore;

  /// How long the link gets to come up. Covers a failed eight-second attempt,
  /// the transport's 400 ms pause, and a second attempt that succeeds.
  final Duration linkBudget;

  /// How long a connected pack gets to say something. Matches the service's
  /// own silence watchdog, so the two never disagree about what "quiet" is.
  final Duration silenceBudget;

  DateTime? _connectedAt;
  late int _bytesNow = bytesBefore;
  bool _proven = false;

  /// When the link first reached `connected`, null before that.
  DateTime? get connectedAt => _connectedAt;

  /// Bytes that arrived during this attempt.
  int get bytesHeard => _bytesNow - bytesBefore;

  void onLinkState(BleLinkState state, DateTime now) {
    if (state == BleLinkState.connected) _connectedAt ??= now;
  }

  /// The decoder's running total, as reported by its stats stream.
  void onBytesTotal(int total) {
    if (total > _bytesNow) _bytesNow = total;
  }

  /// A device-info frame or a snapshot decoded. Either settles it.
  void onDecoded() => _proven = true;

  /// The verdict, or null while the attempt is still worth waiting on.
  FirstContactOutcome? judge(DateTime now) {
    if (_proven) return FirstContactOutcome.proven;
    final connectedAt = _connectedAt;
    if (connectedAt == null) {
      return now.difference(startedAt) >= linkBudget
          ? FirstContactOutcome.linkNeverCameUp
          : null;
    }
    if (now.difference(connectedAt) < silenceBudget) return null;
    return bytesHeard > 0
        ? FirstContactOutcome.talkingButUndecoded
        : FirstContactOutcome.connectedButSilent;
  }
}
