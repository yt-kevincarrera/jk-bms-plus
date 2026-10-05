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

/// 20S / 4T, 178 bytes, the rider's own capture of 2026-09-30 (device info
/// "22PHA1TB080A" / "22AAUB00-240401A"), reassembled from the raw console.
/// 14 bytes longer than 116 + 2 * (cells + probes): this firmware appends
/// data after the fields the reference reads, and data_len (0xA8) covers it.
/// State byte 0x02 (charge) with the current field at -51 (-5.1 A raw), the
/// remaining capacity rising about 2.9 mAh every 2 s and the power field at
/// -383 W: this pack reports charge as negative. 73.78 V, SOC 48, 45 Ah,
/// probes 30 degC, MOSFET 32 degC, balancer 33 degC.
final Uint8List antStatus20s4tCharging = hex(
  '7E A1 11 00 00 A8 01 02 04 14 00 00 00 00 00 00 00 00 00 00 '
  'C4 01 00 00 00 00 00 00 00 00 00 00 00 00 69 0E 67 0E 68 0E '
  '69 0E 69 0E 67 0E 69 0E 68 0E 69 0E 68 0E 6B 0E 69 0E 6A 0E '
  '6A 0E 69 0E 6A 0E 67 0E 67 0E 67 0E 69 0E 1E 00 1E 00 1E 00 '
  '1E 00 20 00 21 00 D2 1C CD FF 30 00 64 00 01 01 00 00 40 A5 '
  'AE 02 36 00 4A 01 79 51 49 00 88 FE FF FF FA 28 60 03 00 00 '
  '00 00 6B 0E 0B 00 67 0E 02 00 04 00 68 0E 00 00 84 00 7D 00 '
  'B1 02 F1 FA C6 79 45 00 2D 29 4D 00 B6 2A 21 00 A7 70 4A 00 '
  '79 05 00 00 D4 08 01 00 14 01 C0 05 CD FF 03 98 AA 55',
);

/// Device info "16ZM" / "16ZMUB00-211026A". 48 bytes although data_len says 0x20.
final Uint8List antInfo16zm = hex(
  '7E A1 12 6C 02 20 31 36 5A 4D 00 00 00 00 00 00 00 00 00 00 00 00 31 36 5A 4D 55 42 30 30 2D 32 31 31 30 32 36 41 72 08 FF 0B 00 00 41 F2 AA 55',
);

/// Device info "22PHB8TB130A" / "22AAUB00-241008A". Byte 26 is 0x55 ('U').
final Uint8List antInfo22ph = hex(
  '7E A1 12 6C 02 20 32 32 50 48 42 38 54 42 31 33 30 41 00 00 00 00 32 32 41 41 55 42 30 30 2D 32 34 31 30 30 38 41 EF 2F FF 0B 00 00 41 F2 AA 55',
);

/// A settings read reply, the only real one the reference has:
/// `SETTINGS_RESP_CELL_HIGH_PROTECT` in
/// tests/components/ant_bms_ble/frames_settings.h (from issue #18). Cell
/// overvoltage protection, register 0x0000, raw 0x1036 = 4.150 V.
final Uint8List antSettingCellOvpReply = hex(
  '7E A1 12 00 00 02 36 10 1F 14 AA 55',
);

/// Pre-2021 protocol (AA 55 AA FF, 140 bytes, big-endian), the answer to the
/// Bluetooth live-data read DB DB 00 00 00 00. Copied verbatim from
/// syssi/esphome-ant-bms docs/pdus/model2019-req-dbdb00000000.txt, first
/// line (also STATUS_FRAME_14S in tests/components/ant_bms_old_ble). 14S,
/// 48.8 V, +8.0 A on the wire, SOC 41, 170 Ah, 68.770 Ah left.
final Uint8List antLegacyStatus14s = hex(
  'AA 55 AA FF 01 E8 0D AA 0D 9C 0D A4 0D 8E 0D 9C 0D 90 0D B4 0D 97 0D B5 0D B5 0D A8 0D 91 0D 9E 0D 8C 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 50 29 0A 21 FE 80 04 19 58 93 00 A9 84 0F 00 FA 08 31 00 16 00 15 00 15 00 15 00 15 00 15 01 01 00 03 E8 00 17 00 00 00 01 86 09 0D B5 0E 0D 8C 0D 9F 0E 00 00 00 70 00 6B 02 AC 00 00 00 00 40 01 15 F4',
);

/// The same capture's ninth line: 12.0 A on the wire, and 90 mAh less left
/// than the first, 38 s of runtime later.
final Uint8List antLegacyStatus14sLater = hex(
  'AA 55 AA FF 01 E6 0D 96 0D 87 0D 90 0D 7B 0D 88 0D 7D 0D A3 0D 85 0D A6 0D A7 0D 92 0D 7E 0D 85 0D 83 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 78 29 0A 21 FE 80 04 17 F6 3A 00 A9 84 69 00 FA 08 57 00 16 00 15 00 15 00 15 00 15 00 15 01 01 00 03 E8 00 17 00 00 00 02 46 0A 0D A7 04 0D 7B 0D 8D 0E 00 00 00 6F 00 6B 02 AC 00 00 00 00 50 01 15 71',
);

/// A 2021 board answering the same read in the old format, from
/// docs/pdus/model2021-req-dbdb00000000.txt, first line. 16S, 0 A, probes
/// 23, 25, 21, 22 and two empty inputs at -40.
final Uint8List antLegacyStatus16sFrom2021Board = hex(
  'AA 55 AA FF 02 7D 0F 8F 0F 8F 0F 8E 0F 8E 0F 8D 0F 90 0F 90 0F 91 0F 8F 0F 8F 0F 90 0F 8D 0F 8C 0F 8E 0F 8C 0F 8F 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 54 0D F2 8E 80 0B A3 90 F8 00 04 34 E2 00 17 B8 D0 00 17 00 19 00 15 00 16 FF D8 FF D8 01 01 00 00 00 00 00 FF 00 00 00 00 08 0F 91 11 0F 8C 0F 8E 10 00 01 00 7F 00 7B 02 AF 00 00 00 00 00 00 1A 5E',
);
