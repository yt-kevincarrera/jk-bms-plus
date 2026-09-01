import '../model/bms_snapshot.dart';
import '../model/bms_warning.dart';
import '../model/jk_device_info.dart';
import '../model/jk_settings.dart';
import 'byte_reader.dart';
import 'jk_constants.dart';
import 'jk_frame.dart';
import 'protocol_variant.dart';

/// Thrown when a frame cannot be decoded. The frame is already checksum valid at
/// this point, so this means a variant mismatch or a firmware we do not
/// understand, not line noise.
class JkParseException implements Exception {
  JkParseException(this.message);
  final String message;
  @override
  String toString() => 'JkParseException: $message';
}

/// Stateless decoder: validated frame in, immutable model out.
///
/// EVERY byte offset below is annotated with the field it maps to in
///   https://github.com/syssi/esphome-jk-bms/blob/main/components/jk_bms_ble/jk_bms_ble.cpp
/// If you add a field, add the citation. Do not guess offsets: a wrong one
/// decodes silently into plausible-looking garbage.
class JkParser {
  const JkParser();

  /// Decodes a device info frame (record type 0x03).
  ///
  /// Source: `decode_device_info_()`. The fields we read sit at the same
  /// offsets in every variant.
  JkDeviceInfo parseDeviceInfo(JkFrame frame) {
    if (frame.type != JkRecordType.deviceInfo) {
      throw JkParseException(
        'Expected a device info frame, got record type '
        '0x${frame.rawType.toRadixString(16)}',
      );
    }
    final d = frame.bytes;

    // 6   16  Vendor ID / model
    final model = d.str(6, 16);
    // 22   8  Hardware version
    final hardwareVersion = d.str(22, 8);
    // 30   8  Software version
    final softwareVersion = d.str(30, 8);
    // 38   4  Uptime, seconds
    final uptime = d.u32(38);
    // 42   4  Power on count
    final powerOnCount = d.u32(42);
    // 46  16  Device name
    final deviceName = d.str(46, 16);
    // 78   6  Manufacturing date, YYMMDD; empty on JK04
    final rawDate = d.str(78, 6);
    // 86  11  Serial number
    final serial = d.str(86, 11);
    // 62  16  Device passcode, in clear text
    final devicePasscode = d.str(62, 16);
    // 118 16  Setup passcode, in clear text
    final setupPasscode = d.str(118, 16);

    return JkDeviceInfo(
      receivedAt: frame.receivedAt,
      model: model,
      hardwareVersion: hardwareVersion,
      softwareVersion: softwareVersion,
      uptimeSeconds: uptime,
      powerOnCount: powerOnCount,
      deviceName: deviceName,
      manufacturingDate: rawDate.isEmpty ? '' : '20$rawDate',
      serialNumber: serial,
      devicePasscode: devicePasscode,
      setupPasscode: setupPasscode,
      detection: JkProtocolVariantDetector.detect(
        model: model,
        softwareVersion: softwareVersion,
      ),
    );
  }

  /// Decodes a cell info frame (record type 0x02) for a JK02 device.
  ///
  /// Source: `decode_jk02_cell_info_()`.
  BmsSnapshot parseCellInfo(JkFrame frame, JkProtocolVariant variant) {
    if (frame.type != JkRecordType.cellInfo) {
      throw JkParseException(
        'Expected a cell info frame, got record type '
        '0x${frame.rawType.toRadixString(16)}',
      );
    }
    if (!variant.isJk02) {
      throw JkParseException(
        'Protocol variant ${variant.name} is not supported. This app decodes '
        'the JK02 framings only; JK04 stores cell voltages as IEEE floats at '
        'different offsets and would decode to garbage here.',
      );
    }

    final d = frame.bytes;

    // A JK02_32S frame carries 8 extra cell slots. That shifts everything after
    // the per-cell voltage block by 16 bytes, and everything after the per-cell
    // resistance block by a further 16 (32 in total).
    final o1 = variant.cellBlockOffset; // 0 or 16
    final o2 = o1 * 2; // 0 or 32
    final slots = variant.cellSlots; // 24 or 32

    // 54   4   Enabled cells bitmask
    final enabledMask = d.u32(54 + o1);

    // 6 + i*2      2   Voltage of cell i+1, 0.001 V
    // 64 + o1 + i*2 2  Resistance of cell i+1, 0.001 Ohm
    final voltages = <double>[];
    final resistances = <double>[];
    for (var i = 0; i < slots; i++) {
      final v = d.u16(6 + i * 2) * 0.001;
      final r = d.u16(64 + o1 + i * 2) * 0.001;
      // Prefer the bitmask over a voltage-is-nonzero heuristic, so a cell that
      // has genuinely collapsed to 0 V still shows up. Fall back to the
      // heuristic only if the mask is empty, which should not happen.
      final enabled = enabledMask == 0 ? v > 0 : (enabledMask >> i) & 1 == 1;
      if (enabled) {
        voltages.add(v);
        resistances.add(r);
      }
    }

    // 112  2   MOSFET temperature, 0.1 degC  -- JK02_32S only.
    // 134  2   MOSFET temperature, 0.1 degC  -- JK02_24S only; on JK02_32S the
    //          same bytes hold the low half of the 32-bit error bitmask.
    final double mosfetTemp = variant == JkProtocolVariant.jk02_32s
        ? d.i16(112 + o2) * 0.1
        : d.i16(134 + o2) * 0.1;

    // 114  4   Per-cell wire resistance warning bitmask
    final wireResistanceWarningMask = d.u32(114 + o2);

    // 118  4   Battery voltage, 0.001 V
    final packVoltage = d.u32(118 + o2) * 0.001;

    // 126  4   Current, signed, 0.001 A.
    // Byte 122 holds power too, but unsigned, so it cannot distinguish charge
    // from discharge. Power is derived from V x I instead.
    final current = d.i32(126 + o2) * 0.001;

    // 130  2   Temperature sensor 1, 0.1 degC
    // 132  2   Temperature sensor 2, 0.1 degC
    final temperatures = <double>[
      d.i16(130 + o2) * 0.1,
      d.i16(132 + o2) * 0.1,
    ];
    if (variant == JkProtocolVariant.jk02_32s) {
      // 226 / 224 / 222  2  Temperature sensors 3 / 4 / 5, 0.1 degC.
      // They really are stored in descending address order.
      temperatures.addAll([
        d.i16(226 + o2) * 0.1,
        d.i16(224 + o2) * 0.1,
        d.i16(222 + o2) * 0.1,
      ]);
    }

    // 134  4   Error bitmask, 32 bits (JK02_32S)
    // 136  2   Error bitmask, 16 bits (JK02_24S). The upper 16 bits do not
    //          exist in this framing, so those warnings can never fire.
    final errorMask = variant == JkProtocolVariant.jk02_32s
        ? d.u32(134 + o2)
        : d.u16(136 + o2);

    // 138  2   Balance current, signed, 0.001 A
    final balanceCurrent = d.i16(138 + o2) * 0.001;

    // 140  1   Balancing action: 0x00 off, 0x01 charging, 0x02 discharging
    final balancingAction = d.u8(140 + o2);

    // 141  1   State of charge, %
    final soc = d.u8(141 + o2).toDouble();

    // 142  4   Remaining capacity, 0.001 Ah
    final remaining = d.u32(142 + o2) * 0.001;

    // 146  4   Nominal capacity, 0.001 Ah
    final nominal = d.u32(146 + o2) * 0.001;

    // 150  4   Cycle count
    final cycleCount = d.u32(150 + o2);

    // 154  4   Cycle capacity, 0.001 Ah
    final cycleCapacity = d.u32(154 + o2) * 0.001;

    // 158  1   State of health, %
    final soh = d.u8(158 + o2).toDouble();

    // 162  4   Total runtime, seconds
    final runtime = d.u32(162 + o2);

    // 166  1   Charge MOSFET enabled
    // 167  1   Discharge MOSFET enabled
    final chargeMosfet = d.boolAt(166 + o2);
    final dischargeMosfet = d.boolAt(167 + o2);

    // 168  1   Precharging      -- JK02_32S only
    // 169  1   Balancer working -- JK02_32S only
    //
    // The reference reads both of these for every variant, but in the captured
    // JK02_24S frames they hold 0xAA and 0x06, which are not booleans. The
    // reference byte table was written from a JK02_32S capture, so these two
    // fields most likely do not exist in the 24S framing at all. Rather than
    // report "precharging: true" off a 0xAA, they are left null there.
    final bool? precharging = variant == JkProtocolVariant.jk02_32s
        ? d.boolAt(168 + o2)
        : null;

    // For the balancer, JK02_24S still has a usable signal: byte 140, which the
    // reference calls the legacy balancing indicator, reads a sane 0x00 in the
    // same captures.
    // Current actually moving between cells is the strongest evidence there
    // is, and it is measured rather than flagged. The action byte is taken as
    // well because a balancer can be engaged in the instant before current
    // shows, but a balancer passing current while byte 140 reads zero was
    // being reported as idle, and that byte is one of the offsets docs/
    // PROTOCOL.md still lists as unsettled for this framing.
    final balancingByCurrent = balanceCurrent.abs() >= 0.005;
    final balancerActive = variant == JkProtocolVariant.jk02_32s
        ? d.boolAt(169 + o2) || balancingByCurrent
        : balancingAction != 0 || balancingByCurrent;

    // 182  2   Bitmask the reference calls "temperature sensor absent"
    //          (bit0 MOSFET, bit1..bit5 sensors 1..5). The captured JK02_24S
    //          frames report 0x07 while those same three sensors read fine, so
    //          the polarity or the label is wrong. Passed through raw; nothing
    //          is filtered on it until the real pack settles the question.
    final sensorMask = d.u16(182 + o2);

    // 183  1   Heating on
    final heating = d.boolAt(183 + o2);

    // 204  2   Heating current, signed, 0.001 A
    final heatingCurrent = d.i16(204 + o2) * 0.001;

    // 213  1   Charger plugged
    final chargerPlugged = d.boolAt(213 + o2);

    // JK02_32S only:
    // 243  1   Battery type code (0 LFP, 1 Li-ion, 2 LTO)
    // 248  1   Charge status code (0 bulk, 1 absorption, 2 float)
    final int? batteryTypeCode =
        variant == JkProtocolVariant.jk02_32s ? d.u8(243 + o2) : null;
    final int? chargeStatusCode =
        variant == JkProtocolVariant.jk02_32s ? d.u8(248 + o2) : null;

    return BmsSnapshot(
      timestamp: frame.receivedAt,
      variant: variant,
      frameCounter: frame.counter,
      cellVoltages: List.unmodifiable(voltages),
      cellResistances: List.unmodifiable(resistances),
      enabledCellMask: enabledMask,
      packVoltage: packVoltage,
      current: current,
      temperatures: List.unmodifiable(temperatures),
      temperatureSensorMask: sensorMask,
      mosfetTemp: mosfetTemp,
      soc: soc,
      soh: soh,
      remainingCapacityAh: remaining,
      nominalCapacityAh: nominal,
      cycleCount: cycleCount,
      cycleCapacityAh: cycleCapacity,
      balancingAction: balancingAction,
      balanceCurrent: balanceCurrent,
      chargeMosfetOn: chargeMosfet,
      dischargeMosfetOn: dischargeMosfet,
      prechargeOn: precharging,
      balancerActive: balancerActive,
      heatingOn: heating,
      warnings: BmsWarnings.fromBitmask(errorMask),
      wireResistanceWarningMask: wireResistanceWarningMask,
      heatingCurrent: heatingCurrent,
      totalRuntimeSeconds: runtime,
      batteryTypeCode: batteryTypeCode,
      chargeStatusCode: chargeStatusCode,
      chargerPlugged: chargerPlugged,
    );
  }

  /// Decodes a settings frame (record type 0x01) for a JK02 device.
  ///
  /// Source: `decode_jk02_settings_()`. Offsets 6..141 are shared by both JK02
  /// framings; only the connection-wire-resistance block moves.
  JkSettings parseSettings(JkFrame frame, JkProtocolVariant variant) {
    if (frame.type != JkRecordType.settings) {
      throw JkParseException(
        'Expected a settings frame, got record type '
        '0x${frame.rawType.toRadixString(16)}',
      );
    }
    if (!variant.isJk02) {
      throw JkParseException(
        'Settings frames for protocol variant ${variant.name} are not '
        'supported.',
      );
    }

    final d = frame.bytes;
    double mv(int i) => d.u32(i) * 0.001;
    double deciC(int i) => d.i32(i) * 0.1;

    // The wire resistance block starts at 158 on JK02_24S (24 entries) and at
    // 142 on JK02_32S (32 entries).
    final resistanceBase = variant == JkProtocolVariant.jk02_32s ? 142 : 158;
    final wireResistances = <double>[
      for (var i = 0; i < variant.cellSlots; i++) mv(resistanceBase + i * 4),
    ];

    return JkSettings(
      receivedAt: frame.receivedAt,
      smartSleepVoltage: mv(6), //          6   4  Smart sleep voltage
      cellUvp: mv(10), //                  10   4  Cell UVP
      cellUvpRecovery: mv(14), //          14   4  Cell UVP recovery
      cellOvp: mv(18), //                  18   4  Cell OVP
      cellOvpRecovery: mv(22), //          22   4  Cell OVP recovery
      balanceTriggerVoltage: mv(26), //    26   4  Balance trigger voltage
      soc100Voltage: mv(30), //            30   4  SOC 100% voltage
      soc0Voltage: mv(34), //              34   4  SOC 0% voltage
      cellRequestChargeVoltage: mv(38), // 38   4  Request charge voltage
      cellRequestFloatVoltage: mv(42), //  42   4  Request float voltage
      powerOffVoltage: mv(46), //          46   4  Power off voltage
      maxChargeCurrent: mv(50), //         50   4  Max charge current
      chargeOcpDelaySeconds: d.u32(54), // 54   4  Charge OCP delay
      chargeOcpRecoverySeconds: d.u32(58), //     58   4  Charge OCP recovery
      maxDischargeCurrent: mv(62), //             62   4  Max discharge current
      dischargeOcpDelaySeconds: d.u32(66), //     66   4  Discharge OCP delay
      dischargeOcpRecoverySeconds: d.u32(70), //  70   4  Discharge OCP recovery
      scpRecoverySeconds: d.u32(74), //           74   4  SCP recovery time
      maxBalanceCurrent: mv(78), //               78   4  Max balance current
      chargeOtp: deciC(82), //             82   4  Charge OTP
      chargeOtpRecovery: deciC(86), //     86   4  Charge OTP recovery
      dischargeOtp: deciC(90), //          90   4  Discharge OTP
      dischargeOtpRecovery: deciC(94), //  94   4  Discharge OTP recovery
      chargeUtp: deciC(98), //             98   4  Charge UTP, signed
      chargeUtpRecovery: deciC(102), //   102   4  Charge UTP recovery, signed
      mosfetOtp: deciC(106), //           106   4  MOSFET OTP
      mosfetOtpRecovery: deciC(110), //   110   4  MOSFET OTP recovery
      cellCount: d.u32(114), //           114   4  Cell count
      chargeSwitchOn: d.boolAt(118), //   118   4  Charge switch
      dischargeSwitchOn: d.boolAt(122), // 122  4  Discharge switch
      balancerSwitchOn: d.boolAt(126), //  126  4  Balancer switch
      nominalCapacityAh: mv(130), //       130  4  Nominal battery capacity
      scpDelayMicroseconds: d.u32(134), // 134  4  SCP delay, microseconds
      balanceStartVoltage: mv(138), //     138  4  Balance start voltage
      connectionWireResistances: List.unmodifiable(wireResistances),
    );
  }
}
