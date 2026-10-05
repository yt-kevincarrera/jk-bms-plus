import '../model/ant_settings.dart';
import '../model/bms_warning.dart';
import 'ant_crc.dart';

/// Everything the app will ever write to an ANT BMS: read requests. The
/// status request (function 0x01), and function 0x02 reads, which fetch the
/// device info and, one register each, the settings in [AntSetting].
///
/// The protocol also has an authentication frame and register writes
/// (function 0x51) that switch MOSFETs, reset the pack and so on. They are
/// deliberately not here, not even as constants: this app only sends read
/// requests (the dormant JK switch writes would refuse an ANT in the write
/// gate too), and a write path that does not exist cannot be reached by
/// mistake.
const List<int> antStatusRequest = [
  0x7E, 0xA1, 0x01, 0x00, 0x00, 0xBE, 0x18, 0x55, 0xAA, 0x55, //
];
const List<int> antDeviceInfoRequest = [
  0x7E, 0xA1, 0x02, 0x6C, 0x02, 0x20, 0x58, 0xC4, 0xAA, 0x55, //
];

/// The read function: device info and settings registers alike.
const int antFnRead = 0x02;

/// A function 0x02 read of [length] bytes at [address]:
/// `7E A1 02 addr_lo addr_hi len crc_lo crc_hi AA 55`.
///
/// Source: `build_frame()` and `read_settings()` in ant_bms_ble.cpp; the
/// request frames in tests/components/ant_bms_ble/frames_settings.h are
/// these bytes exactly. [antDeviceInfoRequest] is the same frame for 0x026C
/// and 0x20. Only ever a read: the function is fixed here.
List<int> antReadRequest(int address, int length) {
  final f = [
    0x7E, 0xA1, antFnRead, address & 0xFF, (address >> 8) & 0xFF, //
    length & 0xFF,
  ];
  final crc = antCrc16(f, 1, f.length);
  return [...f, crc & 0xFF, crc >> 8, 0xAA, 0x55];
}

/// The settings reads, one per register in [AntSetting], all two bytes.
final List<List<int>> antSettingsReadRequests = [
  for (final s in AntSetting.values) antReadRequest(s.address, 2),
];

const int antFnStatusReply = 0x11;
const int antFnReadReply = 0x12;
const int antDeviceInfoAddress = 0x026C;

/// The reference drops its buffer past this; the largest status frame
/// (32 cells, 4 probes) is 188 bytes.
const int antMaxBuffer = 192;

const List<String> antBatteryStateText = [
  'Unknown', 'Idle', 'Charge', 'Discharge', 'Standby', 'Error', //
];

const List<String> antChargeMosfetText = [
  'Off', 'On', 'Overcharge protection', 'Over current protection',
  'Battery full', 'Total overpressure', 'Battery over temperature',
  'MOSFET over temperature', 'Abnormal current', 'Balanced line dropped string',
  'Motherboard over temperature', 'Reserved', 'Open failed',
  'Discharge MOSFET abnormality', 'Waiting', 'Manually turned off',
  'Two level exceed voltage', 'Low temperature protection',
  'Voltage difference exceeded', 'Reserved', 'Self detect error', //
];

const List<String> antDischargeMosfetText = [
  'Off', 'On', 'Overdischarge protection', 'Over current protection',
  'Two current exceeded', 'Total pressure undervoltage',
  'Battery over temperature', 'MOSFET over temperature', 'Abnormal current',
  'Balanced line dropped string', 'Motherboard over temperature',
  'Charge MOSFET on', 'Short circuit protection',
  'Discharge MOSFET abnormality', 'Open failed', 'Manually turned off',
  'Two level low voltage', 'Low temperature protection',
  'Voltage difference exceeded', 'Self detect error', //
];

const List<String> antBalancerText = [
  'Off', 'Exceeds the limit equilibrium', 'Charge differential pressure balance',
  'Balanced over temperature', 'Automatic equalization', 'Unknown', 'Unknown',
  'Unknown', 'Unknown', 'Unknown', 'Motherboard over temperature', //
];

/// Text for a code, or "Unknown (0xNN)" past the end of the table.
String antText(List<String> table, int code) => code < table.length
    ? table[code]
    : 'Unknown (0x${code.toRadixString(16).padLeft(2, '0')})';

/// Why the charge MOSFET is off, in the app's own warning vocabulary.
///
/// A closed table (spec §5.2). Codes with no clear equivalent produce no bit
/// and are shown as text instead; inventing a mapping would put words in the
/// BMS's mouth.
const Map<int, BmsWarning> antChargeWarnings = {
  0x02: BmsWarning.packOvervoltage, // JK02 has no cell-overvoltage bit
  0x03: BmsWarning.chargeOvercurrent,
  0x04: BmsWarning.batteryFullyCharged,
  0x05: BmsWarning.packOvervoltage,
  0x06: BmsWarning.chargeOvertemperature,
  0x07: BmsWarning.mosfetOvertemperature,
  0x11: BmsWarning.chargeUndertemperature,
};

const Map<int, BmsWarning> antDischargeWarnings = {
  0x02: BmsWarning.cellUndervoltage,
  0x03: BmsWarning.dischargeOvercurrent,
  0x04: BmsWarning.dischargeOcpII,
  0x05: BmsWarning.packUndervoltage,
  0x06: BmsWarning.dischargeOvertemperature,
  0x07: BmsWarning.mosfetOvertemperature,
  0x0C: BmsWarning.dischargeShortCircuit,
  0x0D: BmsWarning.dischargingMosfetAbnormal,
  0x0E: BmsWarning.dischargeOnFailed,
  0x11: BmsWarning.dischargeUndertemperatureAlarm,
};

/// The battery state byte (7), by what it says. Index into
/// [antBatteryStateText].
const int antStateCharge = 0x02;
const int antStateDischarge = 0x03;

/// Balancer codes (byte 48+o) that mean cells are being balanced right now.
///
/// Read off `BALANCER_STATUS` in the reference: 1 "exceeds the limit
/// equilibrium" and 2 "charge differential pressure balance" both describe
/// balancing that is under way. The rest do not, and two of them are faults:
/// 3 "balanced over temperature" and 0x0A "motherboard over temperature" are
/// the balancer stopped by heat, not the balancer working. 4 "automatic
/// equalization" is the balancer switched on and waiting (the reference maps
/// it to its balancer *switch*), which is not the same as moving charge.
/// The cell bitmask at 70+o is the stronger signal and is taken as well.
const Set<int> antBalancerBalancingCodes = {0x01, 0x02};

/// Balancer codes that are faults rather than states.
const Set<int> antBalancerFaultCodes = {0x03, 0x0A};

/// The cell type the BMS was set up for, as the status frame reports it.
///
/// Source: the comment on the battery type word in `on_status_data_()`,
/// syssi/esphome-ant-bms ant_bms_ble.cpp ("0xfaf1: Ternary Lithium, 0xfaf2:
/// Lithium Iron Phosphate, 0xfaf3: Lithium Titanate, 0xfaf4: Custom").
enum AntBatteryType { ternary, lfp, lto, custom }

/// The type for [code], or null for a word the reference does not name.
AntBatteryType? antBatteryTypeOf(int? code) => switch (code) {
  0xFAF1 => AntBatteryType.ternary,
  0xFAF2 => AntBatteryType.lfp,
  0xFAF3 => AntBatteryType.lto,
  0xFAF4 => AntBatteryType.custom,
  _ => null,
};
