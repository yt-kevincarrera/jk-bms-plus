import '../protocol/ant_constants.dart';
import '../protocol/ant_legacy.dart';
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
  const WriteFrame(
    this.bytes, {
    this.countsAsNudge = false,
    this.settingsRead = false,
  });
  final List<int> bytes;

  /// Whether this write was prompted by silence, for [LinkHealth.nudges].
  final bool countsAsNudge;

  /// Whether this is one of [LinkScript.settingsReads], so the transport can
  /// move on to the next one.
  final bool settingsRead;
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
    this.settingsReads = const [],
    this.silentProbe,
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
  ///
  /// Its settings come one register per request, so once the pack has
  /// identified itself every other tick reads one of them instead, until
  /// each has been asked once on this link. The status still arrives every
  /// four seconds meanwhile, and a pack that does not answer a settings read
  /// costs nothing but the question.
  static final LinkScript ant = LinkScript._(
    brand: BmsBrand.ant,
    onConnect: const [antDeviceInfoRequest, antStatusRequest],
    tickEvery: const Duration(seconds: 2),
    askAgain: antStatusRequest,
    pollsAlways: true,
    deviceInfo: antDeviceInfoRequest,
    settingsReads: antSettingsReadRequests,
    silentProbe: antLegacyStatusRequest,
  );

  /// The ANT protocol from before 2021 (see protocol/ant_legacy.dart): one
  /// request, the live-data read, every tick. There is no device info and no
  /// settings read in it.
  static const LinkScript antLegacy = LinkScript._(
    brand: BmsBrand.ant,
    onConnect: [antLegacyStatusRequest],
    tickEvery: Duration(seconds: 2),
    askAgain: antLegacyStatusRequest,
    pollsAlways: true,
    deviceInfo: antLegacyStatusRequest,
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

  /// Read requests for the pack's settings, asked once each per link. Empty
  /// for a JK, whose settings arrive as one frame of their own.
  final List<List<int>> settingsReads;

  /// A read in the brand's other protocol, asked now and then of a pack that
  /// has not answered anything at all on this link: for ANT, the pre-2021
  /// live-data read, which a board that predates the 2021 protocol answers
  /// and the 2021 requests do not reach.
  final List<int>? silentProbe;

  /// Every frame this script can ever write, as hex, so the read-only promise
  /// is a set a test can compare rather than a claim.
  Set<String> get everyFrameHex => {
        for (final f in [
          ...onConnect,
          askAgain,
          deviceInfo,
          ...settingsReads,
          ?silentProbe,
        ])
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
    int settingsReadsSent = 0,
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
    // Nothing at all heard on this link: every fifth tick, offset from the
    // device info retry, try the other protocol's read too.
    final probe = silentProbe;
    if (probe != null && lastFrameAt == null && tickNumber % 5 == 3) {
      return WriteFrame(probe);
    }
    // Settings only once the pack has answered something and is answering
    // now: a quiet pack is asked for its status, which is what tells the
    // link it is alive.
    if (deviceInfoSeen &&
        !quiet &&
        tickNumber.isEven &&
        settingsReadsSent < settingsReads.length) {
      return WriteFrame(settingsReads[settingsReadsSent], settingsRead: true);
    }
    return WriteFrame(askAgain, countsAsNudge: quiet);
  }
}
