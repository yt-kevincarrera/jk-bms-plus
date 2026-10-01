import 'jk_constants.dart';

/// A JK read request for [register].
///
/// What the app writes to a JK on its own: a read. The only other frame it
/// can ever write is a switch write ([jkWriteRegisterCommand]), and only
/// through the write gate with the rider's permission on.
///
/// Frame layout source: `build_frame()` in
/// https://github.com/syssi/esphome-jk-bms/blob/main/components/jk_bms_ble/jk_bms_ble.cpp
List<int> jkReadCommand(int register) => _frame(register, 0x00, 0);

/// A JK register write: [address] set to [value], [length] bytes wide.
///
/// Built here so the layout lives in one place with the read, and called
/// only by the write gate, which decides whether a write may exist at all.
/// Same 20-byte frame as a read: `AA 55 90 EB`, the register, the value
/// length, the value as a little-endian uint32 in bytes 6..9, zeros, and
/// the sum of bytes 0..18 in byte 19.
///
/// Source: `build_frame()` and `crc()` in jk_bms_ble.cpp (as above):
///
///   frame[4] = address; frame[5] = length;
///   frame[6] = value >> 0; ... frame[9] = value >> 24;
///   frame[19] = crc(frame.data(), frame.size() - 1);
List<int> jkWriteRegisterCommand(
  int address,
  int value, {
  required int length,
}) {
  if (length == 0) {
    // Length 0 is what makes a frame a read. A "write" of length 0 would be
    // a read of whatever register the address names, so it is refused here
    // rather than sent as something it is not.
    throw ArgumentError.value(length, 'length', 'a write has a length');
  }
  return _frame(address, length, value);
}

/// Whether [frame] is a JK register write rather than a read: a command
/// frame whose value length is not zero.
///
/// The transport's ordinary write path refuses these, so the only way one
/// reaches a pack is the gated one.
bool isJkRegisterWrite(List<int> frame) {
  if (frame.length != commandFrameSize) return false;
  for (var i = 0; i < commandPreamble.length; i++) {
    if (frame[i] != commandPreamble[i]) return false;
  }
  return frame[5] != 0x00;
}

List<int> _frame(int register, int length, int value) {
  final frame = List<int>.filled(commandFrameSize, 0);
  frame.setRange(0, 4, commandPreamble);
  frame[4] = register & 0xFF; // holding register
  frame[5] = length & 0xFF; // value length in bytes; 0 for a read
  frame[6] = value & 0xFF;
  frame[7] = (value >> 8) & 0xFF;
  frame[8] = (value >> 16) & 0xFF;
  frame[9] = (value >> 24) & 0xFF;
  var sum = 0;
  for (var i = 0; i < commandFrameSize - 1; i++) {
    sum = (sum + frame[i]) & 0xFF;
  }
  frame[commandFrameSize - 1] = sum;
  return List.unmodifiable(frame);
}
