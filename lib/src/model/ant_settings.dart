/// One ANT setting the app reads, with the register it lives at and the
/// scale its raw value is stored in.
///
/// Source: `SETTINGS_REGISTERS` in syssi/esphome-ant-bms
/// components/ant_bms_ble/ant_bms_ble.cpp, and the request and response
/// frames in tests/components/ant_bms_ble/frames_settings.h (from issue #18
/// of that repository). Only a subset: the protections and balancing
/// figures this app does something with. The reference lists no
/// temperature thresholds at all, so none are read; the 4-byte capacity
/// registers are left out too, because the status frame already carries the
/// configured capacity and the reference's scale for them ("Ah", times 1)
/// does not match the micro-amp-hours the status frame uses.
enum AntSetting {
  cellOvp(0x0000, 0.001),
  cellOvpRecovery(0x0002, 0.001),
  cellUvp(0x000C, 0.001),
  cellUvpRecovery(0x000E, 0.001),

  /// Amps.
  chargeOcp(0x0068, 0.1),

  /// Seconds.
  chargeOcpDelay(0x006A, 1),

  /// Amps.
  dischargeOcp(0x006C, 0.1),

  /// Seconds.
  dischargeOcpDelay(0x006E, 1),

  /// Amps.
  shortCircuit(0x0074, 1),

  /// Volts: where balancing starts.
  balanceStart(0x008E, 0.001),

  /// Volts: the cell difference that turns balancing on.
  balanceTrigger(0x0090, 0.001),

  /// Milliamps.
  balanceCurrent(0x0094, 1),
  cellCount(0x009A, 1),

  /// Volts a cell: where the BMS shuts itself down.
  shutdownVoltage(0x009E, 0.001);

  const AntSetting(this.address, this.scale);

  final int address;
  final double scale;

  static AntSetting? byAddress(int address) {
    for (final s in values) {
      if (s.address == address) return s;
    }
    return null;
  }
}

/// The ANT settings read so far on this pack. Each register arrives as its
/// own reply, so this fills in one value at a time and any of them can be
/// missing: a getter returns null for a setting the pack has not answered
/// for, never a default.
class AntSettings {
  const AntSettings([this.values = const {}]);

  final Map<AntSetting, double> values;

  bool get isEmpty => values.isEmpty;

  AntSettings withValue(AntSetting s, double value) =>
      AntSettings({...values, s: value});

  double? operator [](AntSetting s) => values[s];

  double? get cellOvp => values[AntSetting.cellOvp];
  double? get cellUvp => values[AntSetting.cellUvp];
  double? get chargeOcp => values[AntSetting.chargeOcp];
  double? get dischargeOcp => values[AntSetting.dischargeOcp];
}
