import '../protocol/jk_constants.dart';

/// One bit of the JK02 error/warning bitmask.
///
/// Bit indices come from `DEFAULT_ERRORS_JK02` in
/// https://github.com/syssi/esphome-jk-bms/blob/main/components/jk_bms_ble/__init__.py
/// Bits with no upstream label (3, 29, 30, 31) have no enum value; if one of
/// them is ever set it shows up in [BmsWarnings.unknownBits] instead of being
/// silently dropped.
enum BmsWarning {
  wireResistance(0),
  mosfetOvertemperature(1),
  cellCountMismatch(2),
  batteryFullyCharged(4),
  packOvervoltage(5),
  chargeOvercurrent(6),
  chargeShortCircuit(7),
  chargeOvertemperature(8),
  chargeUndertemperature(9),
  coprocessorCommunicationError(10),
  cellUndervoltage(11),
  packUndervoltage(12),
  dischargeOvercurrent(13),
  dischargeShortCircuit(14),
  dischargeOvertemperature(15),
  chargingMosfetAbnormal(16),
  dischargingMosfetAbnormal(17),
  gpsDisconnected(18),
  modifyPasswordInTime(19),
  dischargeOnFailed(20),
  batteryOvertemperature(21),
  temperatureSensorAnomaly(22),
  plModuleAnomaly(23),
  scpReleaseFailed(24),
  dischargeOcpII(25),
  dischargeOcpIII(26),
  dischargeUndertemperatureAlarm(27),
  gpsRemoteLock(28);

  const BmsWarning(this.bit);
  final int bit;

  String get label => jk02ErrorBitNames[bit]!;

  /// "Battery is fully charged" is informational, not a fault. Everything else
  /// on this list means something is wrong.
  bool get isFault => this != BmsWarning.batteryFullyCharged;
}

/// Decoded warning bitmask, keeping the raw value so an unrecognised bit is
/// still visible and still reparseable later.
class BmsWarnings {
  const BmsWarnings({required this.raw, required this.active});

  factory BmsWarnings.fromBitmask(int raw) {
    final active = <BmsWarning>{};
    for (final w in BmsWarning.values) {
      if ((raw >> w.bit) & 1 == 1) active.add(w);
    }
    return BmsWarnings(raw: raw, active: active);
  }

  static const BmsWarnings none = BmsWarnings(raw: 0, active: {});

  final int raw;
  final Set<BmsWarning> active;

  Set<BmsWarning> get faults => active.where((w) => w.isFault).toSet();

  bool get hasFault => faults.isNotEmpty;

  /// Bits that are set but have no upstream label.
  List<int> get unknownBits => [
        for (var bit = 0; bit < 32; bit++)
          if ((raw >> bit) & 1 == 1 && jk02ErrorBitNames[bit] == null) bit,
      ];

  Map<String, Object> toJson() => {
        'raw': '0x${raw.toRadixString(16).padLeft(8, '0').toUpperCase()}',
        'active': active.map((w) => w.label).toList(),
        if (unknownBits.isNotEmpty) 'unknownBits': unknownBits,
      };
}
