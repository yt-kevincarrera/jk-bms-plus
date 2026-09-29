import 'dart:convert';

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
  });

  final BmsSnapshot snapshot;
  final int batteryState;
  final int chargeMosfetCode;
  final int dischargeMosfetCode;
  final int balancerCode;
  final double balancerTemp;
  final int balancingCellMask;

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
    final expected = 116 + 2 * (n + t);
    if (b.length != expected) {
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
      // Taken as positive while charging, this app's convention. Unverified
      // on real ANT hardware: every capture so far is an idle pack. The
      // service checks it against the battery state byte and reverses it for
      // a pack whose own state contradicts it (AntCurrentSign).
      current: i16(40 + o) / 10,
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
    return AntStatus(
      snapshot: snapshot,
      batteryState: b[7],
      chargeMosfetCode: charge,
      dischargeMosfetCode: discharge,
      balancerCode: balancer,
      balancerTemp: i16(36 + o).toDouble(),
      balancingCellMask: balancingMask,
    );
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
