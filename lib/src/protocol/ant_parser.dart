import 'dart:convert';

import '../model/ant_settings.dart';
import '../model/bms_device_info.dart';
import '../model/bms_snapshot.dart';
import '../model/bms_warning.dart';
import 'ant_constants.dart';
import 'ant_frame.dart';
import 'bms_brand.dart';

class AntParseException implements Exception {
  const AntParseException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A decoded status frame: the reading, plus the ANT-only details the System
/// tab shows as text.
class AntStatus {
  const AntStatus({
    required this.snapshot,
    required this.batteryState,
    required this.chargeMosfetCode,
    required this.dischargeMosfetCode,
    required this.balancerCode,
    required this.balancerTemp,
    required this.balancingCellMask,
    this.batteryTypeCode,
    this.totalDischargedAh,
    this.totalChargedAh,
    this.totalDischargingSeconds,
    this.totalChargingSeconds,
    this.legacy = false,
  });

  final BmsSnapshot snapshot;
  /// The battery state byte (7). Null for a pre-2021 frame, which has none.
  final int? batteryState;
  final int chargeMosfetCode;
  final int dischargeMosfetCode;
  final int balancerCode;
  /// Null for a pre-2021 frame, which reports six unlabelled temperatures.
  final double? balancerTemp;
  final int balancingCellMask;

  /// The BMS's own cell type, the raw word at 94+o. See [antBatteryTypeOf].
  final int? batteryTypeCode;

  /// The pack's lifetime counters as the BMS keeps them (96+o to 111+o): the
  /// amp-hours that went out and in, and the seconds it spent discharging
  /// and charging. The BMS's numbers, not the app's: they cover whatever the
  /// board has seen since it was set up, rides this app never watched
  /// included.
  final double? totalDischargedAh;
  final double? totalChargedAh;
  final int? totalDischargingSeconds;
  final int? totalChargingSeconds;

  /// Whether this came from the pre-2021 protocol (ant_legacy.dart), whose
  /// MOSFET tables differ from 2021 at a few codes.
  final bool legacy;

  /// The same frame with a corrected reading, for the one correction the
  /// service makes after decoding: an ANT whose current sign contradicts its
  /// own battery state.
  AntStatus withSnapshot(BmsSnapshot s) => AntStatus(
        snapshot: s,
        batteryState: batteryState,
        chargeMosfetCode: chargeMosfetCode,
        dischargeMosfetCode: dischargeMosfetCode,
        balancerCode: balancerCode,
        balancerTemp: balancerTemp,
        balancingCellMask: balancingCellMask,
        batteryTypeCode: batteryTypeCode,
        totalDischargedAh: totalDischargedAh,
        totalChargedAh: totalChargedAh,
        totalDischargingSeconds: totalDischargingSeconds,
        totalChargingSeconds: totalChargingSeconds,
        legacy: legacy,
      );
}

/// The MOSFET codes, in the app's warning vocabulary (spec §5.2).
BmsWarnings antWarnings({required int charge, required int discharge}) {
  var mask = 0;
  final c = antChargeWarnings[charge];
  final d = antDischargeWarnings[discharge];
  if (c != null) mask |= 1 << c.bit;
  if (d != null) mask |= 1 << d.bit;
  return BmsWarnings.fromBitmask(mask);
}

/// Decodes ANT 2021 frames. Layout: `ant_bms_ble.cpp` in
/// syssi/esphome-ant-bms, reproduced in spec §3.4. Everything little-endian.
class AntParser {
  const AntParser();

  /// What an ANT reads on a probe input with nothing wired to it. The real
  /// 14S capture shows three probes at 28 degC and the fourth at exactly -40,
  /// with the MOSFET and balancer also at 28: that input is empty.
  static const double unwiredProbeCelsius = -40;

  AntStatus parseStatus(AntFrame f) {
    final b = f.bytes;
    if (!f.isStatus) {
      throw AntParseException(
          'Not a status frame (function 0x${f.function.toRadixString(16)}).');
    }
    final t = b[8];
    final n = b[9];
    if (n == 0 || n > 32 || t > 8) {
      throw AntParseException('Implausible layout: $n cells, $t probes.');
    }
    // A minimum, not an exact size. The assembler has already held the frame
    // to its own data_len, which is the check the reference makes; this one
    // only guarantees every offset read below is inside the frame. It was an
    // exact match, and the rider's 20S ANT (firmware 22AAUB00-240401A) sends
    // 14 bytes more than the fields read here: every status frame it sent was
    // refused, and the pack never produced a reading.
    final expected = 116 + 2 * (n + t);
    if (b.length < expected) {
      throw AntParseException(
          '$n cells and $t probes need $expected bytes, frame has ${b.length}.');
    }
    final o = 2 * n + 2 * t;

    int u16(int i) => b[i] | (b[i + 1] << 8);
    int i16(int i) => u16(i).toSigned(16);
    int u32(int i) => u16(i) | (u16(i + 2) << 16);

    final probes = [
      for (var j = 0; j < t; j++)
        i16(34 + 2 * n + 2 * j).toDouble() == unwiredProbeCelsius
            ? BmsSnapshot.absentProbeCelsius
            : i16(34 + 2 * n + 2 * j).toDouble(),
    ];
    final charge = b[46 + o];
    final discharge = b[47 + o];
    final balancer = b[48 + o];
    // 70+o, 4 bytes: which cells are being balanced, one bit each.
    final balancingMask = u32(70 + o);
    // Working means charge is being moved: either the BMS names cells, or its
    // balancer code is one of the two that describe balancing under way. It
    // used to be "any code but 0", which called a balancer stopped by
    // overheating "working", and one merely switched on (code 4) too.
    final balancing =
        balancingMask != 0 || antBalancerBalancingCodes.contains(balancer);

    final snapshot = BmsSnapshot(
      timestamp: f.receivedAt,
      brand: BmsBrand.ant,
      variant: null,
      frameCounter: null,
      cellVoltages: [for (var i = 0; i < n; i++) u16(34 + 2 * i) / 1000],
      cellResistances: null,
      enabledCellMask: null,
      packVoltage: u16(38 + o) / 100,
      // Reversed, because an ANT reports charge as negative. Measured on the
      // rider's 20S pack on 2026-09-30: state byte "charge", the field at
      // -5.1 A, the remaining capacity climbing 2.9 mAh every two seconds
      // (+5.2 A) and the power field negative too. This app's convention is
      // positive while charging. The service still checks the sign against
      // the state byte, so a firmware that reports the other way round is
      // caught and reversed back (AntCurrentSign).
      current: -i16(40 + o) / 10,
      temperatures: probes,
      temperatureSensorMask: null,
      mosfetTemp: i16(34 + o).toDouble(),
      soc: i16(42 + o).toDouble(),
      soh: u16(44 + o).toDouble(),
      remainingCapacityAh: u32(54 + o) / 1e6,
      nominalCapacityAh: u32(50 + o) / 1e6,
      cycleCount: null,
      cycleCapacityAh: u32(58 + o) / 1000,
      balancingAction: null,
      balanceCurrent: null,
      chargeMosfetOn: charge == 0x01,
      dischargeMosfetOn: discharge == 0x01,
      balancerActive: balancing,
      heatingOn: null,
      warnings: antWarnings(charge: charge, discharge: discharge),
      wireResistanceWarningMask: null,
      heatingCurrent: null,
      totalRuntimeSeconds: u32(66 + o),
      balancingCellMask: balancingMask,
    );
    // Power (62+o) is deliberately not stored: BmsSnapshot.power is V x I,
    // computed in one place rather than trusted from two.
    //
    // Past the balancing mask, `on_status_data_()` in the reference also
    // publishes the highest and lowest cell with their index, the delta and
    // the average (74+o to 85+o). They are not read here: the app computes
    // all four from the cell voltages of the same frame, and on the three
    // captures they agree to the millivolt. 86+o to 93+o (MOSFET D-S and
    // drive voltages, "F40com") are listed in its comments with no unit and
    // never published, so they are left alone too.
    //
    // The rider's firmware (22AAUB00-240401A) sends 14 bytes after 111+o
    // that the reference does not read at all. Their last two repeat the
    // current field (-51 on the capture), the rest have no source; nothing
    // is decoded from them.
    return AntStatus(
      snapshot: snapshot,
      batteryState: b[7],
      chargeMosfetCode: charge,
      dischargeMosfetCode: discharge,
      balancerCode: balancer,
      balancerTemp: i16(36 + o).toDouble(),
      balancingCellMask: balancingMask,
      // Source: the comment table in `on_status_data_()`, byte 130 of the
      // 14S layout ("0xfaf1: Ternary Lithium, 0xfaf2: Lithium Iron
      // Phosphate, 0xfaf3: Lithium Titanate, 0xfaf4: Custom"). All three
      // captures agree with their cells: the 16S pack at 3.30 V a cell says
      // 0xFAF2, the 14S one at 4.11 V and the rider's NMC 20S say 0xFAF1.
      batteryTypeCode: u16(94 + o),
      // Published by the reference with these scales: amp-hours x 0.001,
      // seconds as they are.
      totalDischargedAh: u32(96 + o) / 1000,
      totalChargedAh: u32(100 + o) / 1000,
      totalDischargingSeconds: u32(104 + o),
      totalChargingSeconds: u32(108 + o),
    );
  }

  /// One settings register reply, or null for a reply this app does not
  /// read: an address outside [AntSetting], or a data length that is not
  /// the two or four bytes a value takes (a pack refusing a read answers
  /// with none). Value at byte 6, little-endian; the scale is the
  /// register's. Source: `on_settings_data_()` in ant_bms_ble.cpp.
  (AntSetting, double)? parseSetting(AntFrame f) {
    if (!f.isSettingsReply) {
      throw const AntParseException('Not a settings reply.');
    }
    final b = f.bytes;
    final len = f.dataLength;
    if ((len != 2 && len != 4) || b.length < 6 + len + 4) return null;
    final setting = AntSetting.byAddress(f.address);
    if (setting == null) return null;
    var raw = b[6] | (b[7] << 8);
    if (len == 4) raw |= (b[8] << 16) | (b[9] << 24);
    return (setting, raw * setting.scale);
  }

  BmsDeviceInfo parseDeviceInfo(AntFrame f) {
    if (!f.isDeviceInfo || f.bytes.length < 38) {
      throw const AntParseException('Not a device info frame.');
    }
    String ascii(int from) => latin1
        .decode(f.bytes.sublist(from, from + 16))
        .replaceAll('\u0000', '')
        .trim();
    return BmsDeviceInfo(
      brand: BmsBrand.ant,
      receivedAt: f.receivedAt,
      model: ascii(6),
      softwareVersion: ascii(22),
    );
  }
}
