/// Protocol constants for the JK (Jikong) Smart BMS BLE interface.
///
/// PROVENANCE — read before touching anything in this file.
///
/// The JK BLE protocol is not documented by the vendor. Every constant and byte
/// offset in this package was transcribed from the community reverse-engineering
/// work in:
///
///   syssi/esphome-jk-bms, components/jk_bms_ble/jk_bms_ble.cpp
///   https://github.com/syssi/esphome-jk-bms/blob/main/components/jk_bms_ble/jk_bms_ble.cpp
///
/// Nothing here is remembered, inferred, or guessed. If you need to add a field,
/// go read that file and cite the line you took it from. A wrong offset produces
/// silently wrong data, which is the worst failure mode this app has.
library;

/// BLE GATT service exposed by the BMS.
///
/// Source: `JK_BMS_SERVICE_UUID` in jk_bms_ble.cpp.
const int jkServiceUuid16 = 0xFFE0;

/// Characteristic used for both notifications (BMS -> phone) and commands
/// (phone -> BMS).
///
/// Source: `JK_BMS_CHARACTERISTIC_UUID` in jk_bms_ble.cpp.
const int jkCharacteristicUuid16 = 0xFFE1;

/// Full 128-bit forms of the two UUIDs above, using the Bluetooth SIG base UUID.
const String jkServiceUuid = '0000ffe0-0000-1000-8000-00805f9b34fb';
const String jkCharacteristicUuid = '0000ffe1-0000-1000-8000-00805f9b34fb';

/// Frame preamble. Note the byte order differs between the two directions:
/// responses from the BMS start with `55 AA EB 90`, commands written to the BMS
/// start with `AA 55 90 EB`.
///
/// Source: `assemble()` and `build_frame()` in jk_bms_ble.cpp.
const List<int> responsePreamble = [0x55, 0xAA, 0xEB, 0x90];
const List<int> commandPreamble = [0xAA, 0x55, 0x90, 0xEB];

/// Every response frame is treated as exactly 300 bytes, with the checksum in
/// the last byte. Newer firmware sends longer frames (up to 320) but the
/// checksum stays at index 299, followed by a second preamble.
///
/// Source: `MIN_RESPONSE_SIZE`, `MAX_RESPONSE_SIZE` and the `frame_size = 300`
/// comment in `assemble()` in jk_bms_ble.cpp.
const int responseFrameSize = 300;
const int maxResponseBufferSize = 384 + 16;

/// Command frames written to the characteristic are always 20 bytes.
///
/// Source: `build_frame()` in jk_bms_ble.cpp.
const int commandFrameSize = 20;

/// Register addresses used as commands. We only ever use the read-only ones:
/// this app does not write settings to the BMS.
///
/// Source: `COMMAND_CELL_INFO`, `COMMAND_DEVICE_INFO`, `COMMAND_LOGBOOK`.
const int commandCellInfo = 0x96;
const int commandDeviceInfo = 0x97;
const int commandLogbook = 0xA1;

/// Record type, at byte 4 of a response frame.
///
/// Source: `decode_()` in jk_bms_ble.cpp.
enum JkRecordType {
  settings(0x01),
  cellInfo(0x02),
  deviceInfo(0x03),
  logbook(0x05);

  const JkRecordType(this.code);
  final int code;

  static JkRecordType? fromCode(int code) {
    for (final t in JkRecordType.values) {
      if (t.code == code) return t;
    }
    return null;
  }
}

/// Bit names for the 32-bit error/warning bitmask in the cell info frame.
///
/// Source: `DEFAULT_ERRORS_JK02` in
/// https://github.com/syssi/esphome-jk-bms/blob/main/components/jk_bms_ble/__init__.py
///
/// Bits 3, 29, 30 and 31 are blank upstream (bit 3 used to be labelled
/// "Current sensor anomaly" but was retracted), so they are left unnamed here
/// rather than invented.
const List<String?> jk02ErrorBitNames = [
  'Wire resistance', // bit 0
  'MOSFET overtemperature', // bit 1
  'Cell count is not equal to settings', // bit 2
  null, // bit 3
  'Battery is fully charged', // bit 4
  'Battery pack overvoltage', // bit 5
  'Charge overcurrent', // bit 6
  'Charge short circuit', // bit 7
  'Charge overtemperature', // bit 8
  'Charge undertemperature', // bit 9
  'Coprocessor communication error', // bit 10
  'Cell undervoltage', // bit 11
  'Battery pack undervoltage', // bit 12
  'Discharge overcurrent', // bit 13
  'Discharge short circuit', // bit 14
  'Discharge overtemperature', // bit 15
  'Charging MOSFET abnormal', // bit 16
  'Discharging MOSFET abnormal', // bit 17
  'GPS disconnected', // bit 18
  'Modify password in time', // bit 19
  'Discharge on failed', // bit 20
  'Battery overtemperature', // bit 21
  'Temperature sensor anomaly', // bit 22
  'PL module anomaly', // bit 23
  'SCP release failed', // bit 24
  'Discharge OCP II', // bit 25
  'Discharge OCP III', // bit 26
  'Discharge undertemperature alarm', // bit 27
  'GPS remote lock', // bit 28
  null, // bit 29
  null, // bit 30
  null, // bit 31
];

/// Battery chemistry codes reported at byte 243+offset of the cell info frame
/// (JK02_32S only).
///
/// Source: `battery_type_id_to_string_()` in jk_bms_ble.cpp.
const Map<int, String> jkBatteryTypeNames = {
  0: 'LFP',
  1: 'Li-ion',
  2: 'LTO',
};

/// Charge stage reported at byte 248+offset of the cell info frame
/// (JK02_32S only).
///
/// Source: `charge_status_id_to_string_()` in jk_bms_ble.cpp.
const Map<int, String> jkChargeStatusNames = {
  0: 'Bulk',
  1: 'Absorption',
  2: 'Float',
};
