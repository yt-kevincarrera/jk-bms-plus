/// CRC-16/MODBUS: init 0xFFFF, reflected polynomial 0xA001, no final XOR.
///
/// Source: `crc16()` in syssi/esphome-ant-bms components/ant_bms_ble. ANT
/// computes it from byte 1 (the A1 after the 7E) through the last data byte
/// and stores it little-endian.
int antCrc16(List<int> data, int start, int endExclusive) {
  var crc = 0xFFFF;
  for (var i = start; i < endExclusive; i++) {
    crc ^= data[i] & 0xFF;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xA001 : crc >> 1;
    }
  }
  return crc & 0xFFFF;
}
