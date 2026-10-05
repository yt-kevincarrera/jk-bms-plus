import 'dart:typed_data';

import 'jk_constants.dart';

/// A checksum-validated 300-byte response frame.
class JkFrame {
  JkFrame({
    required this.bytes,
    required this.receivedAt,
  });

  /// Exactly [responseFrameSize] bytes, preamble included, checksum included.
  final Uint8List bytes;

  /// Phone clock, UTC. The BMS clock is never trusted.
  final DateTime receivedAt;

  /// Record type byte. Null when it is a value we have no decoder for.
  JkRecordType? get type => JkRecordType.fromCode(bytes[4]);

  /// Raw record type byte, for logging unsupported types.
  int get rawType => bytes[4];

  /// Frame counter the BMS increments per frame. Useful for spotting drops.
  int get counter => bytes[5];

  int get checksum => bytes[responseFrameSize - 1];
}

/// Why bytes were thrown away. Surfaced in the System tab so a flaky link is
/// visible instead of just looking like missing data.
///
/// Only [badChecksum] is a frame, and only it is counted in [FrameStats]. The
/// others are bytes that never became a frame at all. They are reported so
/// the bytes can be written down: a pack that connects and sends nothing this
/// app can frame is exactly the pack whose bytes are needed, and the
/// assembler used to drop them without a trace.
enum FrameRejection {
  /// Sum-of-bytes checksum did not match the trailing byte.
  badChecksum,

  /// Bytes with no JK preamble anywhere in them.
  noPreamble,

  /// Bytes in front of a preamble: the tail of a frame whose head was lost,
  /// or something that is not JK at all.
  beforePreamble,

  /// The head of a frame, cut short by the next preamble arriving before it
  /// was complete.
  truncated,
}

/// Bytes the assembler threw away, kept whole so they can be written down.
class JkRejected {
  const JkRejected(this.reason, this.bytes);
  final FrameRejection reason;
  final Uint8List bytes;
}

/// Running tally of link quality.
///
/// Counts from whenever it was last [reset]. An assembler never resets its
/// own, so on its own it covers the life of the service; the service resets
/// the ones it reports on every connect, like its other counters, so a line
/// never mixes "since the app started" with "on this connection".
class FrameStats {
  int accepted = 0;
  int badChecksum = 0;
  int unsupportedType = 0;
  int bytesReceived = 0;

  void reset() {
    accepted = 0;
    badChecksum = 0;
    unsupportedType = 0;
    bytesReceived = 0;
  }

  int get rejected => badChecksum;

  double get acceptRate {
    final total = accepted + rejected;
    return total == 0 ? 1.0 : accepted / total;
  }

  Map<String, Object> toJson() => {
        'accepted': accepted,
        'badChecksum': badChecksum,
        'unsupportedType': unsupportedType,
        'bytesReceived': bytesReceived,
        'acceptRate': acceptRate,
      };
}
