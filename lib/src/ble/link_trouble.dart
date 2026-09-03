/// What kind of Bluetooth trouble this is, in terms a rider can act on.
///
/// The transport used to hand the UI the exception text and the UI used to
/// print it. That is how a rider ends up reading
/// `FlutterBluePlusException | connect | android-code: 133` on the screen of
/// their motorcycle app: true, unactionable, and alarming in a way the actual
/// situation (walked away from the bike) is not.
///
/// The raw text is not thrown away. It is the only thing worth having when
/// something genuinely unexpected happens, so it travels alongside as
/// [LinkTrouble.detail] and the screen keeps it one tap away.
enum LinkTroubleKind {
  /// Another client holds the one connection the BMS allows.
  busy,

  /// The pack did not answer. Out of range, or switched off.
  outOfRange,

  /// The phone's Bluetooth is off.
  bluetoothOff,

  /// The app lacks the Bluetooth or location permission it needs.
  permission,

  /// Location services are off, which stops Android returning scan results.
  locationOff,

  /// A smaller MTU than requested. Slower, still correct, not a failure.
  slowFrames,

  /// The device connected and has no JK service on it: the wrong device.
  notJkBms,

  /// The pack was connected and sent nothing for long enough that the
  /// transport let go on purpose, to make its module drop a stuck session.
  packMute,

  /// Something else. The detail is all there is to go on.
  unknown,
}

/// A connected device that does not expose the JK service and characteristic.
///
/// Its own type because the transport must not treat it like a dropped link:
/// reconnecting to a pair of headphones every 400 ms until the rider gives up
/// is not persistence. It used to be a [StateError], which the transport's
/// `on Exception` never caught, so the attempt died without a word, nothing
/// reached the screen, and the screen blamed the pack for the silence.
class NotAJkBmsException implements Exception {
  const NotAJkBmsException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One piece of Bluetooth trouble: what it is, and the raw text behind it.
class LinkTrouble {
  const LinkTrouble(this.kind, {this.detail = '', this.likelyBusy = false});

  final LinkTroubleKind kind;

  /// The original exception text, for the details view and the frame console.
  /// Never the headline.
  final String detail;

  /// Kept for the connect screen, which already treats this case specially.
  final bool likelyBusy;

  /// Whether this is worth interrupting anybody over.
  ///
  /// A smaller packet size is a note, not a problem: the frames still decode.
  bool get isNoteworthy => kind != LinkTroubleKind.slowFrames;

  /// Reads an exception, or any message, and works out what it is really about.
  ///
  /// Matching on text is unlovely, and it is what the platform gives us:
  /// flutter_blue_plus reports Android GATT failures as codes inside an
  /// exception string. Anything unrecognised falls through to [unknown] with
  /// the text intact, which is the honest answer rather than a guess.
  static LinkTrouble from(Object error) {
    final text = error.toString();
    if (error is NotAJkBmsException) {
      return LinkTrouble(LinkTroubleKind.notJkBms, detail: text);
    }
    final lower = text.toLowerCase();

    // Android GATT 133 is the catch-all for "the peripheral is not there":
    // out of range, powered down, or already holding its one connection.
    final gatt133 = lower.contains('android-code: 133') ||
        lower.contains('status: 133');

    if (lower.contains('already connected') ||
        lower.contains('connection_congested') ||
        lower.contains('android-code: 8') ||
        lower.contains('android-code: 22')) {
      return LinkTrouble(
        LinkTroubleKind.busy,
        detail: text,
        likelyBusy: true,
      );
    }

    if (lower.contains('bluetooth must be turned on') ||
        lower.contains('bluetooth is off') ||
        lower.contains('adapter is off') ||
        lower.contains('poweredoff')) {
      return LinkTrouble(LinkTroubleKind.bluetoothOff, detail: text);
    }

    if (lower.contains('permission')) {
      return LinkTrouble(LinkTroubleKind.permission, detail: text);
    }

    if (lower.contains('location') &&
        (lower.contains('disabled') || lower.contains('off'))) {
      return LinkTrouble(LinkTroubleKind.locationOff, detail: text);
    }

    if (lower.contains('mtu')) {
      return LinkTrouble(LinkTroubleKind.slowFrames, detail: text);
    }

    if (gatt133 ||
        lower.contains('timeout') ||
        lower.contains('timed out') ||
        lower.contains('device is disconnected') ||
        lower.contains('not found')) {
      return LinkTrouble(LinkTroubleKind.outOfRange, detail: text);
    }

    return LinkTrouble(LinkTroubleKind.unknown, detail: text);
  }
}
