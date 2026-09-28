import 'jk_constants.dart';

/// A JK read request for [register].
///
/// The only kind of frame the app ever writes to a JK: a read. Writing
/// settings is out of scope, because the protocol is reverse-engineered and a
/// wrong value can disable a protection.
///
/// Frame layout source: `build_frame()` in
/// https://github.com/syssi/esphome-jk-bms/blob/main/components/jk_bms_ble/jk_bms_ble.cpp
List<int> jkReadCommand(int register) {
  final frame = List<int>.filled(commandFrameSize, 0);
  frame.setRange(0, 4, commandPreamble);
  frame[4] = register; // holding register
  frame[5] = 0x00; // value length in bytes; 0 for a read
  // Bytes 6..9 carry the value, which stays zero for a read.
  var sum = 0;
  for (var i = 0; i < commandFrameSize - 1; i++) {
    sum = (sum + frame[i]) & 0xFF;
  }
  frame[commandFrameSize - 1] = sum;
  return List.unmodifiable(frame);
}
