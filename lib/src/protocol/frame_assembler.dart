import 'dart:typed_data';

import 'jk_checksum.dart';
import 'jk_constants.dart';
import 'jk_frame.dart';

/// Reassembles 300-byte response frames out of the 20-byte (or larger, if the
/// MTU negotiation succeeded) BLE notification chunks.
///
/// Modelled on `JkBmsBle::assemble()` in
/// https://github.com/syssi/esphome-jk-bms/blob/main/components/jk_bms_ble/jk_bms_ble.cpp
/// with one deliberate difference: the reference only recognises a preamble when
/// it lands at the start of a notification chunk. We scan the whole buffer, so a
/// preamble that arrives mid-chunk — which is what happens when a frame is cut
/// short by a disconnect and the next one starts in the same packet — still
/// resynchronises instead of poisoning the following frame.
class FrameAssembler {
  FrameAssembler({DateTime Function()? clock})
      : _clock = clock ?? (() => DateTime.now().toUtc());

  final DateTime Function() _clock;
  final BytesBuilder _buffer = BytesBuilder(copy: true);
  final FrameStats stats = FrameStats();

  /// Called for every rejected frame, so the UI can show link quality.
  void Function(FrameRejection reason)? onRejected;

  /// Bytes currently held waiting for the rest of a frame. Exposed so tests
  /// and the System tab can confirm a bad link is not leaking memory.
  int get bufferedBytes => _buffer.length;

  /// Feed one BLE notification payload. Returns every complete, checksum-valid
  /// frame it produced — usually zero or one, but a burst can yield more.
  List<JkFrame> addChunk(List<int> chunk) {
    stats.bytesReceived += chunk.length;
    _buffer.add(chunk);
    return _drain();
  }

  /// Drop everything buffered. Call on disconnect so a half-received frame does
  /// not get glued to the first frame of the next session.
  void reset() => _buffer.clear();

  List<JkFrame> _drain() {
    final frames = <JkFrame>[];

    while (true) {
      var data = _buffer.toBytes();

      final start = _indexOfPreamble(data, 0);
      if (start == null) {
        // No preamble anywhere. Keep only the last 3 bytes: a preamble could be
        // straddling the boundary with the next chunk.
        if (data.length > responsePreamble.length - 1) {
          _replaceBuffer(
            data.sublist(data.length - (responsePreamble.length - 1)),
          );
        }
        return frames;
      }

      if (start > 0) {
        // Junk before the preamble (or the tail of a truncated frame). Drop it.
        data = data.sublist(start);
        _replaceBuffer(data);
      }

      if (data.length < responseFrameSize) {
        // Incomplete. But if a second preamble already showed up inside what we
        // have, the frame in front of it was truncated — skip to the new one.
        final next = _indexOfPreamble(data, responsePreamble.length);
        if (next != null) {
          _replaceBuffer(data.sublist(next));
          continue;
        }
        // The buffer cannot grow without bound here: once it reaches
        // responseFrameSize the loop above either accepts a frame or
        // resynchronises past it, and a stream with no preamble at all is
        // trimmed to the 3 bytes that could still be straddling a boundary.
        return frames;
      }

      final candidate = Uint8List.fromList(data.sublist(0, responseFrameSize));
      final computed = jkChecksum(candidate, responseFrameSize - 1);
      final declared = candidate[responseFrameSize - 1];

      if (computed != declared) {
        stats.badChecksum++;
        onRejected?.call(FrameRejection.badChecksum);
        // Resynchronise on the next preamble rather than blowing the whole
        // buffer away, so a single corrupt frame costs one frame, not two.
        final next = _indexOfPreamble(data, responsePreamble.length);
        _replaceBuffer(next == null ? Uint8List(0) : data.sublist(next));
        continue;
      }

      stats.accepted++;
      final frame = JkFrame(bytes: candidate, receivedAt: _clock());
      if (frame.type == null) stats.unsupportedType++;
      frames.add(frame);

      // Firmware that sends >300 byte frames pads the tail before the next
      // preamble, so skip forward to it rather than assuming 300 exactly.
      final next = _indexOfPreamble(data, responseFrameSize);
      _replaceBuffer(next == null ? Uint8List(0) : data.sublist(next));
    }
  }

  void _replaceBuffer(Uint8List data) {
    _buffer.clear();
    if (data.isNotEmpty) _buffer.add(data);
  }

  static int? _indexOfPreamble(Uint8List data, int from) {
    final limit = data.length - responsePreamble.length;
    for (var i = from; i <= limit; i++) {
      if (data[i] == responsePreamble[0] &&
          data[i + 1] == responsePreamble[1] &&
          data[i + 2] == responsePreamble[2] &&
          data[i + 3] == responsePreamble[3]) {
        return i;
      }
    }
    return null;
  }
}
