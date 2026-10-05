import 'dart:typed_data';

import 'ant_constants.dart';

/// One CRC-valid ANT response, preamble and trailer included.
class AntFrame {
  AntFrame({required this.bytes, required this.receivedAt});

  final Uint8List bytes;

  /// Phone clock, UTC.
  final DateTime receivedAt;

  /// Request function + 0x10: 0x11 status, 0x12 read (device info, settings).
  int get function => bytes[2];
  int get address => bytes[3] | (bytes[4] << 8);
  int get dataLength => bytes[5];

  bool get isStatus => function == antFnStatusReply;
  bool get isDeviceInfo =>
      function == antFnReadReply && address == antDeviceInfoAddress;

  /// A read reply from any other address: one settings register. The
  /// reference routes them the same way (`on_ant_bms_ble_data_()`).
  bool get isSettingsReply =>
      function == antFnReadReply && address != antDeviceInfoAddress;
}

enum AntRejection {
  /// Shape was right, CRC was not.
  badCrc,

  /// Ended in AA 55 but the length disagrees with data_len.
  badLength,

  /// Ended in AA 55 without ever starting with 7E A1.
  notAFrame,

  /// Grew past [antMaxBuffer] without ending.
  overflow,
}

/// A buffer the assembler threw away, kept whole so it can be written down.
class AntRejected {
  const AntRejected(this.reason, this.bytes);
  final AntRejection reason;
  final Uint8List bytes;
}
