import 'dart:typed_data';

import '../../protocol/jk_constants.dart';
import '../../protocol/protocol_variant.dart';

/// Encodes JK02_24S frames.
///
/// This exists only to feed demo mode. It writes the byte layout that
/// [JkParser] reads, which means it can never be used to *validate* the parser
/// — the two would simply agree with each other, right or wrong. The frames
/// that validate the parser are the real captures in
/// `test/fixtures/captured_frames.dart`.
///
/// What it does buy: demo mode exercises the genuine path — checksum, 20-byte
/// notification chunking, frame reassembly, variant detection, parsing — so
/// what you see on screen is produced the same way real readings will be.
class JkFrameBuilder {
  const JkFrameBuilder();

  /// Builds a cell info frame (record type 0x02) in the JK02_24S framing.
  ///
  /// [cellVoltages] may be shorter than 24; the unused slots are left at zero
  /// and excluded from the enabled-cells bitmask, exactly as a real 20S BMS
  /// does.
  Uint8List cellInfo({
    required int counter,
    required List<double> cellVoltages,
    required List<double> cellResistances,
    required double packVoltage,
    required double current,
    required List<double> temperatures,
    required double mosfetTemp,
    required double soc,
    required double soh,
    required double remainingCapacityAh,
    required double nominalCapacityAh,
    required int cycleCount,
    required double cycleCapacityAh,
    required int balancingAction,
    required double balanceCurrent,
    required bool chargeMosfetOn,
    required bool dischargeMosfetOn,
    required int errorBitmask,
    required int totalRuntimeSeconds,
    bool chargerPlugged = false,
    JkProtocolVariant variant = JkProtocolVariant.jk02_24s,
  }) {
    final f = _blank(JkRecordType.cellInfo.code, counter);

    // The same shifts [JkParser.parseCellInfo] applies, so a frame built here
    // for a variant is one that variant's decoder reads back. Until this
    // existed the builder only ever produced the 24-cell framing, which made
    // the one thing nobody could test the one thing that matters most: what a
    // decoder does to the *other* variant's frame.
    final o1 = variant.cellBlockOffset;
    final o2 = o1 * 2;
    final slots = variant.cellSlots;

    var enabledMask = 0;
    for (var i = 0; i < cellVoltages.length && i < slots; i++) {
      _u16(f, 6 + i * 2, (cellVoltages[i] * 1000).round());
      _u16(f, 64 + o1 + i * 2, (cellResistances[i] * 1000).round());
      enabledMask |= 1 << i;
    }
    _u32(f, 54 + o1, enabledMask);

    // The BMS reports these too. The app recomputes them from the cell list
    // rather than reading them, but a real frame carries them, so a realistic
    // one should as well.
    if (cellVoltages.isNotEmpty) {
      final avg = cellVoltages.reduce((a, b) => a + b) / cellVoltages.length;
      var minI = 0;
      var maxI = 0;
      for (var i = 1; i < cellVoltages.length; i++) {
        if (cellVoltages[i] < cellVoltages[minI]) minI = i;
        if (cellVoltages[i] > cellVoltages[maxI]) maxI = i;
      }
      _u16(f, 58 + o1, (avg * 1000).round());
      _u16(
        f,
        60 + o1,
        ((cellVoltages[maxI] - cellVoltages[minI]) * 1000).round(),
      );
      f[62 + o1] = maxI;
      f[63 + o1] = minI;
    }

    _u32(f, 118 + o2, (packVoltage * 1000).round());
    // Byte 122 is unsigned power; the app ignores it and derives V x I instead.
    _u32(f, 122 + o2, (packVoltage * current).abs().round() * 1000);
    _i32(f, 126 + o2, (current * 1000).round());

    _i16(
      f,
      130 + o2,
      (temperatures.isNotEmpty ? temperatures[0] * 10 : 0).round(),
    );
    _i16(
      f,
      132 + o2,
      (temperatures.length > 1 ? temperatures[1] * 10 : 0).round(),
    );

    if (variant == JkProtocolVariant.jk02_32s) {
      // The MOSFET probe moves, three more probes appear, and the error
      // bitmask widens to 32 bits over the bytes the 24S framing used for the
      // MOSFET probe.
      _i16(f, 112 + o2, (mosfetTemp * 10).round());
      _u32(f, 134 + o2, errorBitmask);
      // Stored in descending address order, as the reference has them.
      _i16(f, 226 + o2, (temperatures.length > 2 ? temperatures[2] * 10 : 0).round());
      _i16(f, 224 + o2, (temperatures.length > 3 ? temperatures[3] * 10 : 0).round());
      _i16(f, 222 + o2, (temperatures.length > 4 ? temperatures[4] * 10 : 0).round());
      f[168 + o2] = 0; // precharging
      f[169 + o2] = balancingAction != 0 ? 1 : 0;
      f[243 + o2] = 0; // battery type: LFP
      f[248 + o2] = 0; // charge status: bulk
    } else {
      _i16(f, 134 + o2, (mosfetTemp * 10).round());
      _u16(f, 136 + o2, errorBitmask & 0xFFFF);
    }

    _i16(f, 138 + o2, (balanceCurrent * 1000).round());
    f[140 + o2] = balancingAction;
    f[141 + o2] = soc.round().clamp(0, 255);
    _u32(f, 142 + o2, (remainingCapacityAh * 1000).round());
    _u32(f, 146 + o2, (nominalCapacityAh * 1000).round());
    _u32(f, 150 + o2, cycleCount);
    _u32(f, 154 + o2, (cycleCapacityAh * 1000).round());
    f[158 + o2] = soh.round().clamp(0, 255);
    _u32(f, 162 + o2, totalRuntimeSeconds);
    f[166 + o2] = chargeMosfetOn ? 1 : 0;
    f[167 + o2] = dischargeMosfetOn ? 1 : 0;

    // Byte 182 is reproduced as the real captures have it (0x07). See the note
    // in docs/PROTOCOL.md: the app does not filter on it.
    _u16(f, 182 + o2, 0x0007);
    f[213 + o2] = chargerPlugged ? 1 : 0;

    return _seal(f);
  }

  /// Builds a device info frame (record type 0x03).
  Uint8List deviceInfo({
    required int counter,
    required String model,
    required String hardwareVersion,
    required String softwareVersion,
    required int uptimeSeconds,
    required int powerOnCount,
    required String deviceName,
    required String devicePasscode,
    required String manufacturingDate,
    required String serialNumber,
  }) {
    final f = _blank(JkRecordType.deviceInfo.code, counter);
    _ascii(f, 6, 16, model);
    _ascii(f, 22, 8, hardwareVersion);
    _ascii(f, 30, 8, softwareVersion);
    _u32(f, 38, uptimeSeconds);
    _u32(f, 42, powerOnCount);
    _ascii(f, 46, 16, deviceName);
    _ascii(f, 62, 16, devicePasscode);
    _ascii(f, 78, 6, manufacturingDate);
    _ascii(f, 86, 11, serialNumber);
    return _seal(f);
  }

  /// Builds a settings frame (record type 0x01) in the JK02_24S framing.
  Uint8List settings({
    required int counter,
    required double cellUvp,
    required double cellUvpRecovery,
    required double cellOvp,
    required double cellOvpRecovery,
    required double balanceTriggerVoltage,
    required double powerOffVoltage,
    required double maxChargeCurrent,
    required double maxDischargeCurrent,
    required double maxBalanceCurrent,
    required double chargeOtp,
    required double dischargeOtp,
    required double chargeUtp,
    required int cellCount,
    required double nominalCapacityAh,
    required double balanceStartVoltage,
  }) {
    final f = _blank(JkRecordType.settings.code, counter);
    _u32(f, 10, (cellUvp * 1000).round());
    _u32(f, 14, (cellUvpRecovery * 1000).round());
    _u32(f, 18, (cellOvp * 1000).round());
    _u32(f, 22, (cellOvpRecovery * 1000).round());
    _u32(f, 26, (balanceTriggerVoltage * 1000).round());
    _u32(f, 46, (powerOffVoltage * 1000).round());
    _u32(f, 50, (maxChargeCurrent * 1000).round());
    _u32(f, 54, 30); // charge OCP delay, s
    _u32(f, 58, 60); // charge OCP recovery, s
    _u32(f, 62, (maxDischargeCurrent * 1000).round());
    _u32(f, 66, 30); // discharge OCP delay, s
    _u32(f, 70, 60); // discharge OCP recovery, s
    _u32(f, 74, 60); // SCP recovery, s
    _u32(f, 78, (maxBalanceCurrent * 1000).round());
    _i32(f, 82, (chargeOtp * 10).round());
    _i32(f, 86, ((chargeOtp - 10) * 10).round());
    _i32(f, 90, (dischargeOtp * 10).round());
    _i32(f, 94, ((dischargeOtp - 10) * 10).round());
    _i32(f, 98, (chargeUtp * 10).round());
    _i32(f, 102, ((chargeUtp + 5) * 10).round());
    _i32(f, 106, 900); // MOSFET OTP, 90.0 degC
    _i32(f, 110, 700); // MOSFET OTP recovery
    _u32(f, 114, cellCount);
    f[118] = 1; // charge switch
    f[122] = 1; // discharge switch
    f[126] = 1; // balancer switch
    _u32(f, 130, (nominalCapacityAh * 1000).round());
    _u32(f, 134, 1500); // SCP delay, microseconds
    _u32(f, 138, (balanceStartVoltage * 1000).round());
    return _seal(f);
  }

  static Uint8List _blank(int recordType, int counter) {
    final f = Uint8List(responseFrameSize);
    f.setRange(0, 4, responsePreamble);
    f[4] = recordType;
    f[5] = counter & 0xFF;
    return f;
  }

  /// Fills in the trailing checksum, so the frame passes exactly the same
  /// validation a real one does.
  static Uint8List _seal(Uint8List f) {
    var sum = 0;
    for (var i = 0; i < responseFrameSize - 1; i++) {
      sum = (sum + f[i]) & 0xFF;
    }
    f[responseFrameSize - 1] = sum;
    return f;
  }

  static void _u16(Uint8List f, int i, int v) {
    final x = v & 0xFFFF;
    f[i] = x & 0xFF;
    f[i + 1] = (x >> 8) & 0xFF;
  }

  static void _i16(Uint8List f, int i, int v) => _u16(f, i, v & 0xFFFF);

  static void _u32(Uint8List f, int i, int v) {
    final x = v & 0xFFFFFFFF;
    f[i] = x & 0xFF;
    f[i + 1] = (x >> 8) & 0xFF;
    f[i + 2] = (x >> 16) & 0xFF;
    f[i + 3] = (x >> 24) & 0xFF;
  }

  static void _i32(Uint8List f, int i, int v) => _u32(f, i, v & 0xFFFFFFFF);

  static void _ascii(Uint8List f, int i, int maxLength, String s) {
    for (var k = 0; k < maxLength; k++) {
      f[i + k] = k < s.length ? s.codeUnitAt(k) & 0x7F : 0;
    }
  }
}
