import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/simulator/jk_frame_builder.dart';
import 'package:jk_bms/src/protocol/jk_frame.dart';
import 'package:jk_bms/src/protocol/jk_parser.dart';
import 'package:jk_bms/src/protocol/protocol_variant.dart';
import 'package:jk_bms/src/protocol/variant_prober.dart';

import 'fixtures/captured_frames.dart';
import 'fixtures/real_kevinjk_frames.dart';

/// A frame for [variant] carrying a pack that could exist.
Uint8List sane(
  JkProtocolVariant variant, {
  int cells = 16,
  double perCell = 3.30,
  double? packVoltage,
  double current = -18.5,
}) {
  const builder = JkFrameBuilder();
  final voltages = List<double>.generate(cells, (i) => perCell + i * 0.001);
  return builder.cellInfo(
    counter: 1,
    cellVoltages: voltages,
    cellResistances: List<double>.filled(cells, 0.2),
    packVoltage: packVoltage ?? voltages.reduce((a, c) => a + c),
    current: current,
    temperatures: const [22, 23, 24, 25, 26],
    mosfetTemp: 30,
    soc: 78,
    soh: 100,
    remainingCapacityAh: 40.2,
    nominalCapacityAh: 52,
    cycleCount: 12,
    cycleCapacityAh: 300,
    balancingAction: 0,
    balanceCurrent: 0,
    chargeMosfetOn: true,
    dischargeMosfetOn: true,
    errorBitmask: 0,
    totalRuntimeSeconds: 90000,
    variant: variant,
  );
}

JkFrame frameOf(Uint8List bytes) =>
    JkFrame(bytes: bytes, receivedAt: DateTime.utc(2026, 9, 4));

void main() {
  const parser = JkParser();
  const plausibility = Plausibility();

  // Why this exists. The framing was worked out from the firmware version
  // string, which is a rule about a string. A version the regex cannot read
  // left the app with no framing at all and every reading held back forever;
  // a version that implies the wrong one produces numbers no battery could
  // produce, silently. The frames themselves can answer better, because the
  // wrong framing does not read slightly wrong, it reads impossibly wrong.

  group('what the wrong framing actually produces', () {
    test('a real 24-cell capture read as 32-cell is impossible', () {
      // Measured, not imagined: this is the repo's own captured frame.
      final s = parser.parseCellInfo(
        frameOf(cellInfo24s[0]),
        JkProtocolVariant.jk02_32s,
      );
      final reasons = plausibility.reject(s);
      expect(reasons, isNotEmpty);
      // 0xFFFF read as a cell voltage, and tens of thousands of amps.
      expect(reasons.join(' '), contains('65.535 V'));
      expect(reasons.join(' '), contains('75039 A'));
    });

    test('and the same capture read correctly is possible', () {
      final s = parser.parseCellInfo(
        frameOf(cellInfo24s[0]),
        JkProtocolVariant.jk02_24s,
      );
      expect(plausibility.reject(s), isEmpty);
    });

    test('a 32-cell frame read as 24-cell is caught by the pack voltage', () {
      // The cell block starts at the same offset in both framings, so the
      // cells read fine and everything after them does not. The sum of the
      // cells against the reported pack voltage is what settles it.
      final s = parser.parseCellInfo(
        frameOf(sane(JkProtocolVariant.jk02_32s)),
        JkProtocolVariant.jk02_24s,
      );
      final reasons = plausibility.reject(s);
      expect(reasons, isNotEmpty);
      expect(reasons.last, contains('over cells totalling'));
    });
  });

  group('probing one frame', () {
    test('picks 24-cell for a real 24-cell capture', () {
      final result = probeVariant(frame: frameOf(cellInfo24s[0]));
      expect(result.decided, isTrue);
      expect(result.variant, JkProtocolVariant.jk02_24s);
    });

    test('picks 32-cell for a 32-cell frame', () {
      final result = probeVariant(
        frame: frameOf(sane(JkProtocolVariant.jk02_32s)),
      );
      expect(result.decided, isTrue);
      expect(result.variant, JkProtocolVariant.jk02_32s);
    });

    test('every captured frame is read the same way', () {
      // All six captures from the same pack, so a probe that depends on which
      // instant it landed on would show up here.
      for (final f in cellInfo24s) {
        expect(
          probeVariant(frame: frameOf(f)).variant,
          JkProtocolVariant.jk02_24s,
        );
      }
    });

    test('keeps the reasons for both candidates, for the notice', () {
      final result = probeVariant(frame: frameOf(cellInfo24s[0]));
      expect(result.rejections[JkProtocolVariant.jk02_24s], isEmpty);
      expect(result.rejections[JkProtocolVariant.jk02_32s], isNotEmpty);
    });

    test('refuses to answer rather than guess between two survivors', () {
      // The rule that keeps this honest. A probe that picked one of two
      // plausible framings would be the old version guess in a lab coat, and
      // confidently wrong numbers are worse than a gap the rider can see.
      final result = probeVariant(
        frame: frameOf(cellInfo24s[0]),
        candidates: const [
          JkProtocolVariant.jk02_24s,
          JkProtocolVariant.jk02_24s,
        ],
      );
      expect(result.decided, isFalse);
    });

    test('and refuses when nothing reads it', () {
      final rubbish = Uint8List.fromList(cellInfo24s[0]);
      for (var i = 6; i < 260; i++) {
        rubbish[i] = 0xFF;
      }
      expect(probeVariant(frame: frameOf(rubbish)).decided, isFalse);
    });
  });

  group('what the rules must never reject', () {
    test('a pack with one collapsed cell', () {
      // A broken wire reads 0.000 V and the parser deliberately keeps it. A
      // rule that threw the pack away over it would be worse than the bug.
      const builder = JkFrameBuilder();
      final voltages = [0.0, ...List<double>.filled(15, 3.30)];
      final frame = builder.cellInfo(
        counter: 1,
        cellVoltages: voltages,
        cellResistances: List<double>.filled(16, 0.2),
        packVoltage: voltages.reduce((a, c) => a + c),
        current: -5,
        temperatures: const [20, 21],
        mosfetTemp: 25,
        soc: 40,
        soh: 90,
        remainingCapacityAh: 20,
        nominalCapacityAh: 52,
        cycleCount: 30,
        cycleCapacityAh: 900,
        balancingAction: 0,
        balanceCurrent: 0,
        chargeMosfetOn: true,
        dischargeMosfetOn: false,
        errorBitmask: 0,
        totalRuntimeSeconds: 1000,
      );
      final s = parser.parseCellInfo(
        frameOf(frame),
        JkProtocolVariant.jk02_24s,
      );
      expect(plausibility.reject(s), isEmpty);
    });

    test('a pack at rest, and one being charged hard', () {
      for (final current in [0.0, -180.0, 90.0]) {
        final s = parser.parseCellInfo(
          frameOf(sane(JkProtocolVariant.jk02_24s, current: current)),
          JkProtocolVariant.jk02_24s,
        );
        expect(plausibility.reject(s), isEmpty, reason: '$current A');
      }
    });

    test('a small pack, and a big one', () {
      for (final cells in [4, 8, 24]) {
        final s = parser.parseCellInfo(
          frameOf(sane(JkProtocolVariant.jk02_24s, cells: cells)),
          JkProtocolVariant.jk02_24s,
        );
        expect(plausibility.reject(s), isEmpty, reason: '$cells cells');
      }
    });

    test('a pack whose voltage rounds a little away from its cells', () {
      final voltages = List<double>.generate(16, (i) => 3.30 + i * 0.001);
      final sum = voltages.reduce((a, c) => a + c);
      final s = parser.parseCellInfo(
        frameOf(sane(JkProtocolVariant.jk02_24s, packVoltage: sum + 0.4)),
        JkProtocolVariant.jk02_24s,
      );
      expect(plausibility.reject(s), isEmpty);
    });

    test('a pack with probes that are not wired to anything', () {
      // The rider's own pack. It has two temperature probes wired; the
      // 32-cell framing carries five inputs, and the BMS reports the empty
      // ones as -200 C. That is not a temperature, it is the sentinel for
      // nothing connected, and the rest of the app already knows it as such
      // (BmsSnapshot.isPlausibleTemperature). This rule did not, so it called
      // the only framing that reads this pack impossible.
      final s = parser.parseCellInfo(
        frameOf(kevinJkCellInfo[0]),
        JkProtocolVariant.jk02_32s,
      );
      expect(s.absentTemperatureProbes, [2, 3],
          reason: 'the fixture really does carry the sentinel');
      expect(plausibility.reject(s), isEmpty);
    });

    test('but a probe reading an impossible temperature is still caught', () {
      // The rule keeps its teeth: a wrong offset landing on 300 C or -100 C
      // is exactly what it is for. Only the sentinel is excused.
      const builder = JkFrameBuilder();
      for (final temps in [
        [300.0, 20.0],
        [20.0, -100.0],
      ]) {
        final frame = builder.cellInfo(
          counter: 1,
          cellVoltages: List<double>.filled(16, 3.30),
          cellResistances: List<double>.filled(16, 0.2),
          packVoltage: 16 * 3.30,
          current: -5,
          temperatures: temps,
          mosfetTemp: 25,
          soc: 40,
          soh: 90,
          remainingCapacityAh: 20,
          nominalCapacityAh: 52,
          cycleCount: 30,
          cycleCapacityAh: 900,
          balancingAction: 0,
          balanceCurrent: 0,
          chargeMosfetOn: true,
          dischargeMosfetOn: false,
          errorBitmask: 0,
          totalRuntimeSeconds: 1000,
        );
        final s = parser.parseCellInfo(
          frameOf(frame),
          JkProtocolVariant.jk02_24s,
        );
        expect(plausibility.reject(s).join(' '), contains('a probe at'),
            reason: '$temps');
      }
    });
  });

  group("the rider's own pack", () {
    // Why this group exists. Every probe test above ran against frames the
    // simulator built or a 24-cell capture from the reference. The real pack
    // speaks JK02_32S, and nothing real in that framing had ever been through
    // the prober. When its device-info frame did not arrive -- which is what
    // happens after a link is dropped and picked up again -- the prober was
    // the only way to a framing, and it refused, so every reading was held
    // back and the connect screen said the pack was talking in a language the
    // app did not understand. It was not. It was reporting two empty
    // temperature inputs.

    test('is read as 32-cell from any of its frames', () {
      for (final f in kevinJkCellInfo) {
        final result = probeVariant(frame: frameOf(f));
        expect(result.decided, isTrue, reason: '${result.rejections}');
        expect(result.variant, JkProtocolVariant.jk02_32s);
      }
    });

    test('and the 24-cell framing is turned down for the right reason', () {
      // Read as 24-cell, the pack voltage lands on a field holding 0.358 V
      // under cells totalling 80-odd volts. That is the rejection that should
      // carry the decision, and it is the one the notice should quote.
      final result = probeVariant(frame: frameOf(kevinJkCellInfo[0]));
      expect(
        result.rejections[JkProtocolVariant.jk02_24s]!.join(' '),
        contains('over cells totalling'),
      );
      expect(result.rejections[JkProtocolVariant.jk02_32s], isEmpty);
    });

    test('its version string agrees with what its frames say', () {
      final info = parser.parseDeviceInfo(frameOf(kevinJkDeviceInfo[0]));
      expect(info.softwareVersion, '20.20');
      expect(info.variant, JkProtocolVariant.jk02_32s);
      expect(info.detection.confident, isTrue);
    });
  });
}
