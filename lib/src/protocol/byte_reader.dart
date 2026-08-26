import 'dart:typed_data';

/// Little-endian accessors for JK frames.
///
/// The BMS sends every multi-byte field little-endian; signed fields are
/// two's complement. Matches the `jk_get_16bit` / `jk_get_32bit` lambdas in
/// https://github.com/syssi/esphome-jk-bms/blob/main/components/jk_bms_ble/jk_bms_ble.cpp
extension JkByteReader on Uint8List {
  int u8(int i) => this[i];

  int u16(int i) => this[i] | (this[i + 1] << 8);

  int i16(int i) {
    final v = u16(i);
    return v >= 0x8000 ? v - 0x10000 : v;
  }

  int u32(int i) =>
      this[i] | (this[i + 1] << 8) | (this[i + 2] << 16) | (this[i + 3] << 24);

  int i32(int i) {
    final v = u32(i);
    return v >= 0x80000000 ? v - 0x100000000 : v;
  }

  bool boolAt(int i) => this[i] != 0;

  /// Null-terminated ASCII string of at most [maxLength] bytes starting at [i].
  String str(int i, int maxLength) {
    final end = (i + maxLength).clamp(0, length);
    final buf = StringBuffer();
    for (var k = i; k < end; k++) {
      final c = this[k];
      if (c == 0) break;
      // Firmware occasionally pads with high bytes; keep output printable.
      if (c >= 0x20 && c < 0x7F) buf.writeCharCode(c);
    }
    return buf.toString().trim();
  }
}
