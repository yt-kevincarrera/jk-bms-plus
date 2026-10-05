import 'dart:typed_data';

import '../model/bms_snapshot.dart';
import 'ant_constants.dart';
import 'ant_parser.dart';
import 'bms_brand.dart';
import 'jk_frame.dart' show FrameStats;

// The ANT protocol from before 2021, over BLE.
//
// Source: components/ant_bms_old_ble/ant_bms_old_ble.cpp in
// syssi/esphome-ant-bms (assemble(), on_status_data_(), read_registers_(),
// chksum_() in the .h), the status frame table in that repository's
// README.md, and the real captures in docs/pdus/model2019-req-dbdb00000000.txt
// and model2021-req-dbdb00000000.txt (a 2021 board answers this request too,
// in this format). The tests read the reference's own frames.

/// The live-data request over Bluetooth: `DB DB 00 00 00 00`.
///
/// What `read_registers_()` sends (`send_(0xDB, 0x00, 0x0000)`), and what the
/// klotztech/VBMS notes on the official app call the Bluetooth live-data
/// read ("Send 0xDBDB00000000 - Returns 140 bytes of data"). Address 0, value
/// 0, checksum 0: it asks, and carries nothing to write. The same notes list
/// the DB DB header itself, with a question mark, as a write to the display
/// board; this exact frame is the one both the reference and the official
/// app poll with, and it is the only one this app sends in this protocol.
const List<int> antLegacyStatusRequest = [0xDB, 0xDB, 0x00, 0x00, 0x00, 0x00];

/// Every status frame is this long; the reference waits for exactly this
/// many bytes.
const int antLegacyFrameLength = 140;

const List<int> antLegacyHeader = [0xAA, 0x55, 0xAA, 0xFF];

/// The sum of bytes 4 to 137, stored big-endian at 138. Source: `chksum_()`.
int antLegacyChecksum(List<int> f) {
  var sum = 0;
  for (var i = 4; i < antLegacyFrameLength - 2; i++) {
    sum += f[i];
  }
  return sum & 0xFFFF;
}

/// One checksum-valid 140-byte status frame.
class AntLegacyFrame {
  AntLegacyFrame({required this.bytes, required this.receivedAt});
  final Uint8List bytes;
  final DateTime receivedAt;
}

/// Reassembles legacy frames from notifications, as `assemble()` does: a
/// chunk starting AA 55 AA opens a frame, a buffer past 140 bytes is dropped,
/// and a frame is complete at exactly 140 bytes, then checked.
class AntLegacyAssembler {
  AntLegacyAssembler({DateTime Function()? clock})
    : _clock = clock ?? (() => DateTime.now().toUtc());

  final DateTime Function() _clock;
  final BytesBuilder _buffer = BytesBuilder(copy: true);
  final FrameStats stats = FrameStats();

  /// A 140-byte buffer whose checksum did not match, kept whole.
  void Function(Uint8List bytes)? onBadChecksum;

  void reset() => _buffer.clear();

  List<AntLegacyFrame> addChunk(List<int> chunk) {
    stats.bytesReceived += chunk.length;
    if (chunk.isEmpty) return const [];
    if (_buffer.length > antLegacyFrameLength) _buffer.clear();
    if (chunk.length >= 3 &&
        chunk[0] == 0xAA &&
        chunk[1] == 0x55 &&
        chunk[2] == 0xAA) {
      _buffer.clear();
    }
    _buffer.add(chunk);
    if (_buffer.length != antLegacyFrameLength) return const [];
    final data = _buffer.takeBytes();
    for (var i = 0; i < antLegacyHeader.length; i++) {
      if (data[i] != antLegacyHeader[i]) return const [];
    }
    final declared = (data[138] << 8) | data[139];
    if (antLegacyChecksum(data) != declared) {
      stats.badChecksum++;
      onBadChecksum?.call(data);
      return const [];
    }
    stats.accepted++;
    return [AntLegacyFrame(bytes: data, receivedAt: _clock())];
  }
}

/// Decodes a legacy status frame. Big-endian throughout, unlike 2021.
class AntLegacyParser {
  const AntLegacyParser();

  AntStatus parseStatus(AntLegacyFrame f) {
    final b = f.bytes;
    if (b.length != antLegacyFrameLength) {
      throw AntParseException('Legacy frame of ${b.length} bytes.');
    }
    int u16(int i) => (b[i] << 8) | b[i + 1];
    int i16(int i) => u16(i).toSigned(16);
    int u32(int i) => (u16(i) << 16) | u16(i + 2);
    int i32(int i) => u32(i).toSigned(32);

    final n = b[123];
    if (n == 0 || n > 32) {
      throw AntParseException('Implausible legacy layout: $n cells.');
    }
    // Six temperatures, which neither the reference nor the official app's
    // notes say more about than "temperature 1 to 6". All six are taken as
    // probes, and none as the MOSFET: guessing which one is the board would
    // put a number under a label nobody can vouch for. As in 2021, exactly
    // -40 is an empty input: the 2021 board's answer to this request reads
    // 23, 25, 21, 22, -40, -40.
    final temperatures = [
      for (var j = 0; j < 6; j++)
        i16(91 + 2 * j).toDouble() == AntParser.unwiredProbeCelsius
            ? BmsSnapshot.absentProbeCelsius
            : i16(91 + 2 * j).toDouble(),
    ];
    final charge = b[103];
    final discharge = b[104];
    final balancer = b[105];
    final balancingMask = u32(132);
    final balancing =
        balancingMask != 0 || antBalancerBalancingCodes.contains(balancer);

    final snapshot = BmsSnapshot(
      timestamp: f.receivedAt,
      brand: BmsBrand.ant,
      variant: null,
      frameCounter: null,
      cellVoltages: [for (var i = 0; i < n; i++) u16(6 + 2 * i) / 1000],
      cellResistances: null,
      enabledCellMask: null,
      packVoltage: u16(4) / 10,
      // Reversed: in this protocol a positive current is discharge. On the
      // reference's own 2019 capture the current reads +8.0 A and the power
      // +390 W while the remaining capacity falls 7 to 11 mAh every few
      // seconds of runtime, nine frames running. This app's convention is
      // positive while charging. There is no battery state byte here to
      // cross-check it frame by frame, as AntCurrentSign does for 2021.
      current: -i32(70) / 10,
      temperatures: temperatures,
      temperatureSensorMask: null,
      mosfetTemp: null,
      soc: b[74].toDouble(),
      // The legacy frame has no health figure.
      soh: null,
      remainingCapacityAh: u32(79) / 1e6,
      nominalCapacityAh: u32(75) / 1e6,
      cycleCount: null,
      cycleCapacityAh: u32(83) / 1000,
      balancingAction: null,
      balanceCurrent: null,
      chargeMosfetOn: charge == 0x01,
      dischargeMosfetOn: discharge == 0x01,
      balancerActive: balancing,
      heatingOn: null,
      // Discharge 0x04 is "Two current exceeded" in 2021 and unnamed here,
      // so it raises nothing rather than the 2021 meaning.
      warnings: antWarnings(
        charge: charge,
        discharge: antLegacyDischargeUnknownCodes.contains(discharge)
            ? 0x00
            : discharge,
      ),
      wireResistanceWarningMask: null,
      heatingCurrent: null,
      totalRuntimeSeconds: u32(87),
      balancingCellMask: balancingMask,
    );
    // Not read: the power (111, V x I is computed in one place), the highest
    // and lowest cell and the average (computed from the cells), the tire
    // length, pulses and relay (106 to 110, a scooter's), the MOSFET drive
    // voltages (124 to 129) and the status word at 136 that the reference
    // itself marks with a question mark.
    return AntStatus(
      snapshot: snapshot,
      batteryState: null,
      chargeMosfetCode: charge,
      dischargeMosfetCode: discharge,
      balancerCode: balancer,
      balancerTemp: null,
      balancingCellMask: balancingMask,
      legacy: true,
    );
  }
}

/// MOSFET codes the 2021 tables name and the pre-2021 ones do not
/// (`CHARGE_MOSFET_STATUS` and `DISCHARGE_MOSFET_STATUS` in
/// ant_bms_old_ble.cpp list them as "Unknown"). Both tables end at 0x0F.
const Set<int> antLegacyChargeUnknownCodes = {0x0B, 0x0C, 0x0E};
const Set<int> antLegacyDischargeUnknownCodes = {0x04};
const int antLegacyCodeTableSize = 16;

/// Whether a legacy MOSFET [code] has a name in the legacy table. Where it
/// does, the name is the 2021 one, apart from discharge 0x0E ("Start
/// exception" there, "Open failed" in 2021), which say the same thing.
bool antLegacyCodeKnown(int code, {required bool charge}) =>
    code < antLegacyCodeTableSize &&
    !(charge ? antLegacyChargeUnknownCodes : antLegacyDischargeUnknownCodes)
        .contains(code);
