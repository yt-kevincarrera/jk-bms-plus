import 'dart:convert';
import 'dart:typed_data';

import '../../model/ant_settings.dart';
import '../../protocol/ant_constants.dart';
import '../../protocol/ant_crc.dart';

/// Builds ANT 2021 response frames for demo mode, byte for byte in the layout
/// `AntParser` reads (`on_status_data_()` in syssi/esphome-ant-bms), with a
/// real CRC-16/MODBUS, so the demo goes through the same assembler, CRC check
/// and parser as a pack.
///
/// Everything here is the simulator speaking. The values are modelled, not
/// captured; the layout is the reference's.
class AntFrameBuilder {
  const AntFrameBuilder();

  /// A status frame (function 0x11). [current] is in this app's convention,
  /// positive while charging; on the wire it is written the way an ANT sends
  /// it, charge negative, as measured on the rider's 20S (and the power field
  /// with it).
  Uint8List status({
    required List<double> cellVoltages,
    required List<double> temperatures,
    required double mosfetTemp,
    required double balancerTemp,
    required double packVoltage,
    required double current,
    required double soc,
    required double soh,
    required bool chargeMosfetOn,
    required bool dischargeMosfetOn,
    required int balancerCode,
    required int balancingCellMask,
    required double nominalCapacityAh,
    required double remainingCapacityAh,
    required double totalDischargedAh,
    required double totalChargedAh,
    required int runtimeSeconds,
    required int dischargingSeconds,
    required int chargingSeconds,
    int batteryTypeCode = 0xFAF1,
  }) {
    final n = cellVoltages.length;
    final t = temperatures.length;
    final o = 2 * n + 2 * t;
    final dataLength = 106 + o;
    final b = ByteData(6 + dataLength + 4);
    void u8(int i, int v) => b.setUint8(i, v & 0xFF);
    void u16(int i, int v) => b.setUint16(i, v & 0xFFFF, Endian.little);
    void i16(int i, int v) => b.setInt16(i, v, Endian.little);
    void u32(int i, int v) => b.setUint32(i, v & 0xFFFFFFFF, Endian.little);
    void i32(int i, int v) => b.setInt32(i, v, Endian.little);

    u8(0, 0x7E);
    u8(1, 0xA1);
    u8(2, antFnStatusReply);
    u16(3, 0);
    u8(5, dataLength);
    u8(6, 0x05); // permissions, as on the 16S and 14S captures
    final wireAmps = -current; // charge negative on the wire
    u8(
      7,
      wireAmps < -0.5
          ? antStateCharge
          : wireAmps > 0.5
          ? antStateDischarge
          : 0x01,
    );
    u8(8, t);
    u8(9, n);
    for (var i = 0; i < n; i++) {
      u16(34 + 2 * i, (cellVoltages[i] * 1000).round());
    }
    for (var j = 0; j < t; j++) {
      i16(34 + 2 * n + 2 * j, temperatures[j].round());
    }
    i16(34 + o, mosfetTemp.round());
    i16(36 + o, balancerTemp.round());
    u16(38 + o, (packVoltage * 100).round());
    i16(40 + o, (wireAmps * 10).round());
    i16(42 + o, soc.round());
    u16(44 + o, soh.round());
    u8(46 + o, chargeMosfetOn ? 0x01 : 0x00);
    u8(47 + o, dischargeMosfetOn ? 0x01 : 0x00);
    u8(48 + o, balancerCode);
    u32(50 + o, (nominalCapacityAh * 1e6).round());
    u32(54 + o, (remainingCapacityAh * 1e6).round());
    // The pack's cycle capacity is the mean of the two totals, as on the
    // rider's capture.
    u32(58 + o, ((totalDischargedAh + totalChargedAh) / 2 * 1000).round());
    i32(62 + o, (packVoltage * wireAmps).round());
    u32(66 + o, runtimeSeconds);
    u32(70 + o, balancingCellMask);
    var hi = 0, lo = 0;
    for (var i = 1; i < n; i++) {
      if (cellVoltages[i] > cellVoltages[hi]) hi = i;
      if (cellVoltages[i] < cellVoltages[lo]) lo = i;
    }
    final avg = cellVoltages.reduce((a, c) => a + c) / n;
    u16(74 + o, (cellVoltages[hi] * 1000).round());
    u16(76 + o, hi + 1);
    u16(78 + o, (cellVoltages[lo] * 1000).round());
    u16(80 + o, lo + 1);
    u16(82 + o, ((cellVoltages[hi] - cellVoltages[lo]) * 1000).round());
    u16(84 + o, (avg * 1000).round());
    u16(94 + o, batteryTypeCode);
    u32(96 + o, (totalDischargedAh * 1000).round());
    u32(100 + o, (totalChargedAh * 1000).round());
    u32(104 + o, dischargingSeconds);
    u32(108 + o, chargingSeconds);
    return _seal(b.buffer.asUint8List());
  }

  /// The device info reply (function 0x12 at 0x026C): 48 bytes although
  /// data_len says 0x20, CRC where data_len puts it, then the four reserved
  /// bytes and the unused CRC the captures carry.
  Uint8List deviceInfo({required String model, required String software}) {
    List<int> field(String s) {
      final bytes = latin1.encode(s);
      return [...bytes.take(16), ...List.filled(16 - bytes.take(16).length, 0)];
    }

    final head = [
      0x7E, 0xA1, antFnReadReply, antDeviceInfoAddress & 0xFF, //
      antDeviceInfoAddress >> 8, 0x20,
      ...field(model),
      ...field(software),
    ];
    final crc = antCrc16(head, 1, head.length);
    return Uint8List.fromList([
      ...head,
      crc & 0xFF,
      crc >> 8,
      0xFF, 0x0B, 0x00, 0x00, 0x41, 0xF2, 0xAA, 0x55, //
    ]);
  }

  /// The reply to a two-byte settings read of [setting]: function 0x12 at its
  /// address, the raw value little-endian at byte 6.
  Uint8List settingReply(AntSetting setting, double value) {
    final raw = (value / setting.scale).round() & 0xFFFF;
    return _seal(
      Uint8List.fromList([
        0x7E, 0xA1, antFnReadReply, setting.address & 0xFF, //
        setting.address >> 8, 0x02, raw & 0xFF, raw >> 8, 0, 0, 0xAA, 0x55,
      ]),
    );
  }

  /// Writes the CRC over byte 1 to the end of the data, and the trailer.
  Uint8List _seal(Uint8List f) {
    final crcAt = 6 + f[5];
    final crc = antCrc16(f, 1, crcAt);
    f[crcAt] = crc & 0xFF;
    f[crcAt + 1] = crc >> 8;
    f[crcAt + 2] = 0xAA;
    f[crcAt + 3] = 0x55;
    return f;
  }
}
