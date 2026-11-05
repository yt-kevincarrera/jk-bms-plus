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

  /// The link came up but nothing arrived before the attempt ended.
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
/// Each connection gets time for the transport's mute-link recovery (20 seconds
/// plus its five-second poll), without a verdict cutting off negotiation on
/// the next link. The whole attempt has a fixed deadline so repeated drops
/// cannot leave the screen waiting forever. Device info counts as proof, and
/// silence is told apart from bytes that do not decode.
class FirstContact {
  FirstContact({
    required this.startedAt,
    required this.bytesBefore,
    this.linkBudget = const Duration(seconds: 75),
    this.silenceBudget = const Duration(seconds: 30),
  });

  /// When the rider tapped.
  final DateTime startedAt;

  /// The decoder's byte count before this attempt, so bytes from an earlier
  /// connection are not mistaken for this pack talking.
  final int bytesBefore;

  /// The fixed budget for the entire attempt, including preparation,
  /// negotiation and recovery. Reconnecting never restarts it.
  final Duration linkBudget;

  /// How long each connected link gets to say something. Longer than the
  /// transport's mute timeout plus its poll interval, so recovery can run.
  final Duration silenceBudget;

  DateTime? _connectedAt;
  DateTime? _firstConnectedAt;
  late int _bytesNow = bytesBefore;
  bool _proven = false;

  /// The last thing the link said about itself, for the evidence line.
  BleLinkState? lastState;

  /// When the current link reached `connected`, null before the first link.
  DateTime? get connectedAt => _connectedAt;

  /// Bytes that arrived during this attempt.
  int get bytesHeard => _bytesNow - bytesBefore;

  void onLinkState(BleLinkState state, DateTime now) {
    if (state == BleLinkState.connected && lastState != state) {
      _connectedAt = now;
      _firstConnectedAt ??= now;
    }
    lastState = state;
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
    final expired = now.difference(startedAt) >= linkBudget;
    if (connectedAt == null) {
      return expired ? FirstContactOutcome.linkNeverCameUp : null;
    }
    if (!expired) {
      if (lastState != BleLinkState.connected) return null;
      if (now.difference(connectedAt) < silenceBudget) return null;
    }
    return bytesHeard > 0
        ? FirstContactOutcome.talkingButUndecoded
        : FirstContactOutcome.connectedButSilent;
  }

  /// The evidence behind a verdict, for the details line under the headline.
  ///
  /// Terse and technical on purpose, and the same in every language, like the
  /// exception text it sits beside: the headline says what happened in the
  /// rider's words, this says what the app saw, so a screenshot is enough to
  /// tell a slow link from a mute pack from bytes that would not decode.
  String evidence(DateTime now) {
    final parts = <String>[];
    final connectedAt = _connectedAt;
    if (connectedAt == null) {
      parts.add(
        'link never reached connected in ${_secs(now.difference(startedAt))}',
      );
      final last = lastState;
      if (last != null) parts.add('last state ${last.name}');
    } else {
      parts.add(
        'link up ${_secs(_firstConnectedAt!.difference(startedAt))} after tap',
      );
      if (lastState == BleLinkState.connected) {
        parts.add('connected ${_secs(now.difference(connectedAt))}');
      } else if (lastState case final state?) {
        parts.add('last state ${state.name}');
      }
    }
    parts.add('$bytesHeard bytes received');
    return parts.join(' · ');
  }

  static String _secs(Duration d) =>
      '${(d.inMilliseconds / 1000).toStringAsFixed(1)} s';
}
