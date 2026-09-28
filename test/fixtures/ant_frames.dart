import 'dart:typed_data';

/// Real ANT BMS (2021 protocol) frames, copied verbatim from
/// syssi/esphome-ant-bms: tests/components/ant_bms_ble/frames_16s_status.h,
/// docs/pdus/model2021-req-7ea1010000be1855aa55.txt and issue #172.
Uint8List hex(String s) {
  final clean = s.replaceAll(RegExp(r'\s+'), '');
  return Uint8List.fromList([
    for (var i = 0; i < clean.length; i += 2)
      int.parse(clean.substring(i, i + 2), radix: 16),
  ]);
}

/// 16S / 2T, 152 bytes. 52.84 V, +0.3 A, SOC 91, 280 Ah, 252.602325 Ah left,
/// probes 1 and 2 degC, MOSFET 2 degC, balancer 7 degC, both MOSFETs on.
final Uint8List antStatus16s = hex(
  '7E A1 11 00 00 8E 05 01 02 10 00 00 00 00 00 00 00 00 80 00 80 01 00 00 00 00 00 00 00 00 00 00 00 00 E4 0C E4 0C E5 0C E5 0C E8 0C E7 0C E7 0C E6 0C E8 0C E7 0C E7 0C E7 0C E7 0C E7 0C E6 0C E9 0C 01 00 02 00 02 00 07 00 A4 14 03 00 5B 00 64 00 01 01 00 00 00 76 B0 10 D5 67 0E 0F BA 32 4A 00 0F 00 00 00 10 58 2E 02 00 00 00 00 E9 0C 10 00 E4 0C 01 00 05 00 E6 0C 00 00 80 00 7A 00 0F 02 F2 FA B9 8C 3B 00 BB D8 58 00 DA 2D 43 00 E8 B6 49 00 05 43 AA 55',
);

/// 14S / 4T, 152 bytes, real capture. 57.58 V, 0 A, SOC 96, 30 Ah,
/// probes 28, 28, -40 (unwired), 28. Discharge MOSFET reports 0x02.
final Uint8List antStatus14s4t = hex(
  '7E A1 11 00 00 8E 05 01 04 0E 02 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 11 10 11 10 11 10 11 10 11 10 11 10 11 10 11 10 11 10 11 10 11 10 11 10 11 10 11 10 1C 00 1C 00 D8 FF 1C 00 1C 00 1C 00 7E 16 00 00 60 00 64 00 01 02 00 00 80 C3 C9 01 4F 55 B3 01 08 53 00 00 00 00 00 00 6B 28 12 00 00 00 00 00 11 10 01 00 11 10 01 00 00 00 11 10 02 00 70 00 03 00 AC 02 F1 FA 7D 2E 00 00 94 77 00 00 DE 07 00 00 77 76 00 00 35 E2 AA 55',
);

/// Device info "16ZM" / "16ZMUB00-211026A". 48 bytes although data_len says 0x20.
final Uint8List antInfo16zm = hex(
  '7E A1 12 6C 02 20 31 36 5A 4D 00 00 00 00 00 00 00 00 00 00 00 00 31 36 5A 4D 55 42 30 30 2D 32 31 31 30 32 36 41 72 08 FF 0B 00 00 41 F2 AA 55',
);

/// Device info "22PHB8TB130A" / "22AAUB00-241008A". Byte 26 is 0x55 ('U').
final Uint8List antInfo22ph = hex(
  '7E A1 12 6C 02 20 32 32 50 48 42 38 54 42 31 33 30 41 00 00 00 00 32 32 41 41 55 42 30 30 2D 32 34 31 30 30 38 41 EF 2F FF 0B 00 00 41 F2 AA 55',
);
