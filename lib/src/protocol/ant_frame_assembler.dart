import 'dart:typed_data';

import 'ant_constants.dart';
import 'ant_crc.dart';
import 'ant_frame.dart';
import 'jk_frame.dart' show FrameStats;

/// Reassembles ANT responses from BLE notifications.
///
/// Follows `AntBmsBle::assemble()` in syssi/esphome-ant-bms: a notification
/// that starts with 7E A1 opens a new frame, the buffer is dropped past 192
/// bytes, and a frame ends when the last *two* bytes are AA 55. Checking one
/// byte is not enough: device info carries ASCII, and 'U' is 0x55.
class AntFrameAssembler {
  AntFrameAssembler({DateTime Function()? clock})
      : _clock = clock ?? (() => DateTime.now().toUtc());

  final DateTime Function() _clock;
  final BytesBuilder _buffer = BytesBuilder(copy: true);
  final FrameStats stats = FrameStats();

  void Function(AntRejected rejected)? onRejected;

  int get bufferedBytes => _buffer.length;

  void reset() => _buffer.clear();

  List<AntFrame> addChunk(List<int> chunk) {
    stats.bytesReceived += chunk.length;
    if (chunk.isEmpty) return const [];

    if (chunk.length >= 2 && chunk[0] == 0x7E && chunk[1] == 0xA1) {
      _buffer.clear();
    }
    if (_buffer.length > antMaxBuffer) {
      _reject(AntRejection.overflow, _buffer.takeBytes());
    }
    _buffer.add(chunk);

    final data = _buffer.toBytes();
    final n = data.length;
    if (n < 10 || data[n - 2] != 0xAA || data[n - 1] != 0x55) return const [];

    _buffer.clear();
    if (data[0] != 0x7E || data[1] != 0xA1) {
      _reject(AntRejection.notAFrame, data);
      return const [];
    }

    // Device info declares 0x20 bytes of data and carries 48 bytes in all;
    // its CRC is still where data_len says. Every other frame is exact.
    final isInfo = data[2] == antFnReadReply &&
        (data[3] | (data[4] << 8)) == antDeviceInfoAddress;
    final crcAt = 6 + data[5];
    final lengthOk = isInfo ? n >= crcAt + 4 : n == crcAt + 4;
    if (!lengthOk) {
      _reject(AntRejection.badLength, data);
      return const [];
    }

    final declared = data[crcAt] | (data[crcAt + 1] << 8);
    if (antCrc16(data, 1, crcAt) != declared) {
      stats.badChecksum++;
      _reject(AntRejection.badCrc, data);
      return const [];
    }

    stats.accepted++;
    return [AntFrame(bytes: data, receivedAt: _clock())];
  }

  void _reject(AntRejection reason, Uint8List bytes) =>
      onRejected?.call(AntRejected(reason, bytes));
}
