import '../protocol/ant_constants.dart';
import '../protocol/bms_brand.dart';
import '../protocol/jk_commands.dart';
import '../protocol/jk_constants.dart';
import 'link_quiet.dart';

/// What the transport should do on one tick of its timer.
sealed class TickAction {
  const TickAction();
}

/// Nothing to write this tick.
class NoAction extends TickAction {
  const NoAction();
}

/// Write [bytes] to the pack.
class WriteFrame extends TickAction {
  const WriteFrame(this.bytes, {this.countsAsNudge = false});
  final List<int> bytes;

  /// Whether this write was prompted by silence, for [LinkHealth.nudges].
  final bool countsAsNudge;
}

/// The link has been up and mute for too long; let go and come back.
class ReleaseMute extends TickAction {
  const ReleaseMute();
}

/// What the transport writes, and when, for one brand.
///
/// Data plus one pure decision, so the transport stays ignorant of every
/// protocol and the read-only promise can be tested without a radio: the
/// frames a script can ever produce are exactly [everyFrameHex].
class LinkScript {
  const LinkScript._({
    required this.brand,
    required this.onConnect,
    required this.tickEvery,
    required this.askAgain,
    required this.pollsAlways,
    required this.deviceInfo,
  });

  /// JK streams on its own; the script only nudges a pack that went quiet.
  ///
  /// Device info goes first on connect because the variant everything else is
  /// decoded with comes out of that frame.
  factory LinkScript.jk({Duration tickEvery = const Duration(seconds: 5)}) =>
      LinkScript._(
        brand: BmsBrand.jk,
        onConnect: [
          jkReadCommand(commandDeviceInfo),
          jkReadCommand(commandCellInfo),
        ],
        tickEvery: tickEvery,
        askAgain: jkReadCommand(commandCellInfo),
        pollsAlways: false,
        deviceInfo: jkReadCommand(commandDeviceInfo),
      );

  /// ANT says nothing unless asked, so it is asked for its status every tick.
  static const LinkScript ant = LinkScript._(
    brand: BmsBrand.ant,
    onConnect: [antDeviceInfoRequest, antStatusRequest],
    tickEvery: Duration(seconds: 2),
    askAgain: antStatusRequest,
    pollsAlways: true,
    deviceInfo: antDeviceInfoRequest,
  );

  /// The script for [b], with the JK one at its default tick.
  static LinkScript forBrand(BmsBrand b) =>
      b == BmsBrand.ant ? ant : LinkScript.jk();

  final BmsBrand brand;

  /// Written in order as soon as the link is subscribed.
  final List<List<int>> onConnect;

  /// How often [tick] is consulted.
  final Duration tickEvery;

  /// The request that brings the next reading, for a nudge or a caller that
  /// wants one now.
  final List<int> askAgain;

  /// Whether the pack must be asked every tick, because it never streams on
  /// its own.
  final bool pollsAlways;

  /// The request that makes the pack identify itself.
  final List<int> deviceInfo;

  /// Every frame this script can ever write, as hex, so the read-only promise
  /// is a set a test can compare rather than a claim.
  Set<String> get everyFrameHex => {
        for (final f in [...onConnect, askAgain, deviceInfo])
          f.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      };

  /// Decides what one tick does. Pure, so the whole schedule can be tested
  /// without a timer or a radio.
  TickAction tick({
    required DateTime now,
    DateTime? lastFrameAt,
    DateTime? connectedAt,
    required int tickNumber,
    required bool deviceInfoSeen,
    required Duration quietBefore,
    required Duration muteBefore,
  }) {
    final lastSign = lastFrameAt ?? connectedAt;
    if (lastSign != null && now.difference(lastSign) > muteBefore) {
      return const ReleaseMute();
    }
    final quiet = shouldNudge(
      lastHeardAt: lastFrameAt,
      now: now,
      quietBefore: quietBefore,
    );
    if (!pollsAlways) {
      return quiet
          ? WriteFrame(askAgain, countsAsNudge: true)
          : const NoAction();
    }
    // A pack that never identified itself is asked again now and then, not
    // every tick, so the status stream it is also being asked for keeps
    // flowing.
    if (!deviceInfoSeen && tickNumber % 5 == 0) return WriteFrame(deviceInfo);
    return WriteFrame(askAgain, countsAsNudge: quiet);
  }
}
