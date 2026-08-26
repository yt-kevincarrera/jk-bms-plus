import 'dart:typed_data';

/// The JK "CRC" is not a CRC at all: it is the low byte of the sum of every
/// preceding byte in the frame.
///
/// Source: `crc()` in
/// https://github.com/syssi/esphome-jk-bms/blob/main/components/jk_bms_ble/jk_bms_ble.cpp
int jkChecksum(Uint8List data, int length) {
  var sum = 0;
  for (var i = 0; i < length; i++) {
    sum = (sum + data[i]) & 0xFF;
  }
  return sum;
}
