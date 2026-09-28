import 'dart:typed_data';

import 'ant_frame.dart';
import 'bms_brand.dart';
import 'jk_frame.dart';

/// Bytes as they arrived, labelled with the protocol that can read them.
class RawBmsFrame {
  const RawBmsFrame({
    required this.brand,
    required this.recordType,
    required this.bytes,
    required this.receivedAt,
  });

  factory RawBmsFrame.jk(JkFrame f) => RawBmsFrame(
      brand: BmsBrand.jk, recordType: f.rawType, bytes: f.bytes,
      receivedAt: f.receivedAt);

  factory RawBmsFrame.ant(AntFrame f) => RawBmsFrame(
      brand: BmsBrand.ant, recordType: f.function, bytes: f.bytes,
      receivedAt: f.receivedAt);

  /// A buffer the ANT assembler threw away. Record type 0x00, which no ANT
  /// response uses, so these rows are easy to find and never reparsed as data.
  factory RawBmsFrame.antRejected(Uint8List bytes, DateTime at) => RawBmsFrame(
      brand: BmsBrand.ant, recordType: 0x00, bytes: bytes, receivedAt: at);

  final BmsBrand brand;
  final int recordType;
  final Uint8List bytes;
  final DateTime receivedAt;
}
