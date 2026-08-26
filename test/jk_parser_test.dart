import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/model/bms_warning.dart';
import 'package:jk_bms/src/protocol/jk_frame.dart';
import 'package:jk_bms/src/protocol/jk_parser.dart';
import 'package:jk_bms/src/protocol/protocol_variant.dart';

import 'fixtures/captured_frames.dart';

/// Expected values in this file are read off the byte-layout tables and the
/// worked examples in the reference implementation:
///   https://github.com/syssi/esphome-jk-bms/blob/main/components/jk_bms_ble/jk_bms_ble.cpp
/// They are not derived from this parser's own output.
void main() {
  const parser = JkParser();
  final at = DateTime.utc(2026, 1, 1, 12);

  JkFrame frame(Uint8List bytes) => JkFrame(bytes: bytes, receivedAt: at);

  group('device info', () {
    test('decodes a JK02_24S device', () {
      // Reference example labelled "JK02_24S response example".
      final info = parser.parseDeviceInfo(frame(deviceInfoFrames[1]));

      expect(info.model, 'JK-B2A24S15P');
      expect(info.hardwareVersion, '10.XW');
      expect(info.softwareVersion, '10.07');
      expect(info.uptimeSeconds, 110400);
      expect(info.powerOnCount, 6);
      expect(info.manufacturingDate, '20220407');
      expect(info.serialNumber, '2021602096');
      expect(info.receivedAt, at);
    });

    test('decodes a JK02_32S device', () {
      final info = parser.parseDeviceInfo(frame(deviceInfoFrames[2]));

      expect(info.model, 'JK_PB2A16S15P');
      expect(info.hardwareVersion, '14.XA');
      expect(info.softwareVersion, '14.20');
      expect(info.uptimeSeconds, 124500);
      expect(info.powerOnCount, 156);
      expect(info.manufacturingDate, '20231118');
      expect(info.serialNumber, '3092572134');
    });

    test('decodes the JK04 device and leaves its empty fields empty', () {
      // Reference example: "Vendor ID: JK-B2A16S, Hardware version: 3.0,
      // Software version: 3.3.0, Uptime: 36867600 s, Power on count: 19".
      final info = parser.parseDeviceInfo(frame(deviceInfoFrames[0]));

      expect(info.model, 'JK-B2A16S');
      expect(info.hardwareVersion, '3.0');
      expect(info.softwareVersion, '3.3.0');
      expect(info.uptimeSeconds, 36867600);
      expect(info.powerOnCount, 19);
      expect(info.deviceName, 'BMS');
      expect(info.manufacturingDate, '');
      expect(info.serialNumber, '');
    });

    test('rejects a frame of the wrong record type', () {
      expect(
        () => parser.parseDeviceInfo(frame(cellInfo24s[0])),
        throwsA(isA<JkParseException>()),
      );
    });
  });

  group('protocol variant detection', () {
    // Cross-checked against the compatibility table in
    // https://github.com/syssi/esphome-jk-bms/blob/main/README.md
    test('software major >= 11 means JK02_32S, confidently', () {
      final info = parser.parseDeviceInfo(frame(deviceInfoFrames[2]));
      expect(info.variant, JkProtocolVariant.jk02_32s);
      expect(info.detection.confident, isTrue);
    });

    test('software major < 11 means JK02_24S, but not confidently', () {
      // The README lists this exact device (JK-B2A24S15P, sw 10.07) as JK02_24S.
      final info = parser.parseDeviceInfo(frame(deviceInfoFrames[1]));
      expect(info.variant, JkProtocolVariant.jk02_24s);
      expect(
        info.detection.confident,
        isFalse,
        reason: 'JK04 devices also report versions below 11, so this needs '
            'confirming against the hardware',
      );
    });

    test('an unreadable version yields no variant at all', () {
      final d = JkProtocolVariantDetector.detect(model: 'X', softwareVersion: '');
      expect(d.variant, isNull);
      expect(d.confident, isFalse);
    });
  });

  group('cell info, JK02_24S', () {
    late final snap = parser.parseCellInfo(
      frame(cellInfo24s[0]),
      JkProtocolVariant.jk02_24s,
    );

    test('timestamp comes from the phone, not the BMS', () {
      expect(snap.timestamp, at);
      expect(snap.timestamp.isUtc, isTrue);
    });

    test('reports the enabled cells only', () {
      // Byte 54: 0xFF 0xFF 0x00 0x00 -> 16 cells enabled.
      expect(snap.enabledCellMask, 0xFFFF);
      expect(snap.cellCount, 16);
      expect(snap.cellVoltages, hasLength(16));
      expect(snap.cellResistances, hasLength(16));
    });

    test('decodes cell voltages at 0.001 V', () {
      // Byte 6: 0xFF 0x0C -> 3327 -> 3.327 V. Byte 8: 0x01 0x0D -> 3.329 V.
      expect(snap.cellVoltages[0], closeTo(3.327, 1e-9));
      expect(snap.cellVoltages[1], closeTo(3.329, 1e-9));
    });

    test('decodes cell resistances at 0.001 Ohm', () {
      // Byte 64: 0x9D 0x01 -> 413 -> 0.413 Ohm. Byte 66: 0x96 0x01 -> 0.406.
      expect(snap.cellResistances[0], closeTo(0.413, 1e-9));
      expect(snap.cellResistances[1], closeTo(0.406, 1e-9));
    });

    test('decodes pack voltage and current', () {
      // Byte 118: 0x03 0xD0 0x00 0x00 -> 53251 -> 53.251 V.
      expect(snap.packVoltage, closeTo(53.251, 1e-9));
      // Byte 126 is zero in this capture: the pack is sitting idle.
      expect(snap.current, closeTo(0.0, 1e-9));
      expect(snap.power, closeTo(0.0, 1e-9));
      expect(snap.isCharging, isFalse);
      expect(snap.isDischarging, isFalse);
    });

    test('pack voltage agrees with the sum of the cells', () {
      final sum = snap.cellVoltages.reduce((a, b) => a + b);
      expect(sum, closeTo(snap.packVoltage, 0.05));
    });

    test('decodes temperatures at 0.1 degC', () {
      // Byte 130: 0xBE 0x00 -> 190 -> 19.0. Byte 132: 0xBF 0x00 -> 19.1.
      // Byte 134: 0xD2 0x00 -> 210 -> 21.0 (MOSFET, JK02_24S only).
      expect(snap.temperatures, hasLength(2));
      expect(snap.temperatures[0], closeTo(19.0, 1e-9));
      expect(snap.temperatures[1], closeTo(19.1, 1e-9));
      expect(snap.mosfetTemp, closeTo(21.0, 1e-9));
    });

    test('decodes charge state', () {
      // Byte 141: 0x54 -> 84 %. Byte 158: 0x64 -> 100 %.
      expect(snap.soc, 84);
      expect(snap.soh, 100);
      // Byte 142: 0x8E 0x0B 0x01 0x00 -> 68494 -> 68.494 Ah.
      expect(snap.remainingCapacityAh, closeTo(68.494, 1e-9));
      // Byte 146: 0x68 0x3C 0x01 0x00 -> 81000 -> 81.0 Ah.
      expect(snap.nominalCapacityAh, closeTo(81.0, 1e-9));
      // Byte 150: all zero.
      expect(snap.cycleCount, 0);
      // Byte 154: 0x3D 0x04 0x00 0x00 -> 1085 -> 1.085 Ah.
      expect(snap.cycleCapacityAh, closeTo(1.085, 1e-9));
    });

    test('decodes MOSFET and balancer state', () {
      // Bytes 166 and 167 are both 0x01.
      expect(snap.chargeMosfetOn, isTrue);
      expect(snap.dischargeMosfetOn, isTrue);
      // Byte 140 is 0x00: balancer idle. On JK02_24S that byte is what the
      // balancer state is derived from, because byte 169 holds 0x06 there.
      expect(snap.balancingAction, 0);
      expect(snap.balancerActive, isFalse);
      expect(snap.prechargeOn, isNull);
      expect(snap.balanceCurrent, closeTo(0.0, 1e-9));
      expect(snap.inferredBalancingCells, everyElement(isFalse));
    });

    test('reports no warnings for a healthy pack', () {
      expect(snap.warnings.raw, 0);
      expect(snap.warnings.active, isEmpty);
      expect(snap.warnings.hasFault, isFalse);
      expect(snap.warnings.unknownBits, isEmpty);
    });

    test('computes derived values without storing them', () {
      final min = snap.cellVoltages.reduce((a, b) => a < b ? a : b);
      final max = snap.cellVoltages.reduce((a, b) => a > b ? a : b);
      expect(snap.minCellVoltage, min);
      expect(snap.maxCellVoltage, max);
      expect(snap.deltaCellVoltage, closeTo(max - min, 1e-12));
      expect(snap.deltaCellVoltage, closeTo(0.002, 1e-9));
      expect(snap.minCellIndex, inInclusiveRange(1, 16));
      expect(snap.maxCellIndex, inInclusiveRange(1, 16));
      expect(
        snap.averageCellVoltage,
        closeTo(
          snap.cellVoltages.reduce((a, b) => a + b) / 16,
          1e-12,
        ),
      );
    });

    test('all six captured frames decode consistently', () {
      for (final raw in cellInfo24s) {
        final s = parser.parseCellInfo(frame(raw), JkProtocolVariant.jk02_24s);
        expect(s.cellCount, 16);
        expect(s.soc, inInclusiveRange(0, 100));
        expect(s.soh, inInclusiveRange(0, 100));
        expect(s.packVoltage, inInclusiveRange(40, 70));
        expect(s.deltaCellVoltage, lessThan(0.05));
        for (final v in s.cellVoltages) {
          expect(v, inInclusiveRange(2.5, 4.3));
        }
      }
    });

    test('serialises to JSON without throwing', () {
      final json = snap.toJson();
      expect(json['cellCount'], 16);
      expect(json['variant'], 'jk02_24s');
      expect(json['timestamp'], at.toIso8601String());
    });

    test('refuses to decode with the JK04 variant rather than guessing', () {
      expect(
        () => parser.parseCellInfo(frame(cellInfo24s[0]), JkProtocolVariant.jk04),
        throwsA(isA<JkParseException>()),
      );
    });
  });

  group('cell info, variant mismatch', () {
    test('decoding a 24S frame as 32S produces visibly wrong values', () {
      // This is the failure mode the whole variant-detection dance exists to
      // avoid: it does not throw, it just lies. The test documents that, so
      // nobody "fixes" detection by defaulting to one variant.
      final wrong = parser.parseCellInfo(
        frame(cellInfo24s[0]),
        JkProtocolVariant.jk02_32s,
      );
      final right = parser.parseCellInfo(
        frame(cellInfo24s[0]),
        JkProtocolVariant.jk02_24s,
      );
      expect(wrong.packVoltage, isNot(closeTo(right.packVoltage, 0.5)));
    });
  });

  group('settings', () {
    test('decodes a JK02_24S settings frame', () {
      final s = parser.parseSettings(
        frame(settingsJk02_24s),
        JkProtocolVariant.jk02_24s,
      );

      // Values from the "JK02_24S response example" byte table.
      // 10: 0x54 0x0B 0x00 0x00 -> 2900 -> 2.9 V
      expect(s.cellUvp, closeTo(2.9, 1e-9));
      // 14: 0x80 0x0C 0x00 0x00 -> 3200 -> 3.2 V
      expect(s.cellUvpRecovery, closeTo(3.2, 1e-9));
      // 18: 0xCC 0x10 0x00 0x00 -> 4300 -> 4.3 V
      expect(s.cellOvp, closeTo(4.3, 1e-9));
      // 22: 0x68 0x10 0x00 0x00 -> 4200 -> 4.2 V
      expect(s.cellOvpRecovery, closeTo(4.2, 1e-9));
      // 26: 0x0A 0x00 0x00 0x00 -> 10 -> 0.01 V
      expect(s.balanceTriggerVoltage, closeTo(0.01, 1e-9));
      // 46: 0xF0 0x0A 0x00 0x00 -> 2800 -> 2.8 V
      expect(s.powerOffVoltage, closeTo(2.8, 1e-9));
      // 50: 0xA8 0x61 0x00 0x00 -> 25000 -> 25 A
      expect(s.maxChargeCurrent, closeTo(25.0, 1e-9));
      // 54: 30 s, 58: 60 s
      expect(s.chargeOcpDelaySeconds, 30);
      expect(s.chargeOcpRecoverySeconds, 60);
      // 62: 0xF0 0x49 0x02 0x00 -> 150000 -> 150 A
      expect(s.maxDischargeCurrent, closeTo(150.0, 1e-9));
      // 78: 0xD0 0x07 0x00 0x00 -> 2000 -> 2 A
      expect(s.maxBalanceCurrent, closeTo(2.0, 1e-9));
      // 82: 0xBC 0x02 0x00 0x00 -> 700 -> 70.0 degC
      expect(s.chargeOtp, closeTo(70.0, 1e-9));
      // 98: 0x38 0xFF 0xFF 0xFF -> -200 -> -20.0 degC
      expect(s.chargeUtp, closeTo(-20.0, 1e-9));
      // 114: 0x0D 0x00 0x00 0x00 -> 13 cells
      expect(s.cellCount, 13);
      // 118 / 122 / 126 all 0x01
      expect(s.chargeSwitchOn, isTrue);
      expect(s.dischargeSwitchOn, isTrue);
      expect(s.balancerSwitchOn, isTrue);
      // 130: 0x88 0x13 0x00 0x00 -> 5000 -> 5 Ah
      expect(s.nominalCapacityAh, closeTo(5.0, 1e-9));
      // 134: 0xDC 0x05 0x00 0x00 -> 1500 us
      expect(s.scpDelayMicroseconds, 1500);
      // 138: 0xE4 0x0C 0x00 0x00 -> 3300 -> 3.3 V
      expect(s.balanceStartVoltage, closeTo(3.3, 1e-9));

      expect(s.connectionWireResistances, hasLength(24));
    });

    test('the 32S layout shifts the wire resistance block', () {
      // There is no JK02_32S settings capture in the reference, so this only
      // pins the structural difference: 32 entries starting at byte 142
      // instead of 24 starting at 158. The values themselves still need
      // checking against the real pack.
      final s = parser.parseSettings(
        frame(settingsJk02_24s),
        JkProtocolVariant.jk02_32s,
      );
      expect(s.connectionWireResistances, hasLength(32));
    });

    test('rejects a frame of the wrong record type', () {
      expect(
        () => parser.parseSettings(
          frame(cellInfo24s[0]),
          JkProtocolVariant.jk02_24s,
        ),
        throwsA(isA<JkParseException>()),
      );
    });
  });

  group('warning bitmask', () {
    test('maps bits to their upstream labels', () {
      final w = BmsWarnings.fromBitmask(
        (1 << BmsWarning.cellUndervoltage.bit) |
            (1 << BmsWarning.chargeOvercurrent.bit),
      );
      expect(w.active, {
        BmsWarning.cellUndervoltage,
        BmsWarning.chargeOvercurrent,
      });
      expect(w.hasFault, isTrue);
      expect(
        w.active.map((e) => e.label),
        containsAll(['Cell undervoltage', 'Charge overcurrent']),
      );
    });

    test('"battery fully charged" is informational, not a fault', () {
      final w = BmsWarnings.fromBitmask(1 << BmsWarning.batteryFullyCharged.bit);
      expect(w.active, {BmsWarning.batteryFullyCharged});
      expect(w.hasFault, isFalse);
    });

    test('unlabelled bits are surfaced rather than dropped', () {
      final w = BmsWarnings.fromBitmask(1 << 3 | 1 << 30);
      expect(w.active, isEmpty);
      expect(w.unknownBits, [3, 30]);
    });
  });
}
