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

/// Why a frame was thrown away. Surfaced in the System tab so a flaky link is
/// visible instead of just looking like missing data.
enum FrameRejection {
  /// Sum-of-bytes checksum did not match the trailing byte.
  badChecksum,
}

/// Running tally of link quality.
class FrameStats {
  int accepted = 0;
  int badChecksum = 0;
  int unsupportedType = 0;
  int bytesReceived = 0;

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
