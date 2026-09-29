import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/model/bms_snapshot.dart';
import 'package:jk_bms/src/model/bms_warning.dart';
import 'package:jk_bms/src/protocol/ant_frame.dart';
import 'package:jk_bms/src/protocol/ant_parser.dart';
import 'package:jk_bms/src/protocol/bms_brand.dart';

import 'fixtures/ant_frames.dart';

AntFrame frame(List<int> b) => AntFrame(
    bytes: Uint8List.fromList(b), receivedAt: DateTime.utc(2026, 9, 28));

void main() {
  const p = AntParser();

  group('16S / 2T fixture', () {
    final st = p.parseStatus(frame(antStatus16s));
    final s = st.snapshot;

    test('identity', () {
      expect(s.brand, BmsBrand.ant);
      expect(s.variant, isNull);
      expect(s.cellCount, 16);
    });
    test('cells', () {
      expect(s.cellVoltages.first, closeTo(3.300, 1e-9));
      expect(s.cellVoltages.last, closeTo(3.305, 1e-9));
    });
    test('pack, current, charge', () {
      expect(s.packVoltage, closeTo(52.84, 1e-9));
      // Decoded as it stands, not inverted. This pins the decode and not the
      // sign convention: the state byte says idle (0x01), not charging, so
      // the frame cannot say which way 0.3 A flows. The service checks the
      // sign against the state on real traffic (AntCurrentSign).
      expect(st.batteryState, 0x01);
      expect(s.current, closeTo(0.3, 1e-9));
      expect(s.isCharging, isTrue);
      expect(s.soc, 91);
      expect(s.soh, 100);
    });
    test('temperatures', () {
      expect(s.temperatures, [1.0, 2.0]);
      expect(s.mosfetTemp, 2.0);
      expect(st.balancerTemp, 7.0);
    });
    test('capacities and runtime', () {
      expect(s.nominalCapacityAh, closeTo(280.0, 1e-6));
      expect(s.remainingCapacityAh, closeTo(252.602325, 1e-6));
      expect(s.cycleCapacityAh, closeTo(4862.65, 1e-6));
      expect(s.totalRuntimeSeconds, 0x022E5810);
    });
    test('MOSFETs, balancer, no warnings', () {
      expect(s.chargeMosfetOn, isTrue);
      expect(s.dischargeMosfetOn, isTrue);
      expect(s.balancerActive, isFalse);
      expect(s.warnings.active, isEmpty);
    });
    test('JK-only fields are null, not zero', () {
      expect(s.cellResistances, isNull);
      expect(s.cycleCount, isNull);
      expect(s.frameCounter, isNull);
      expect(s.heatingOn, isNull);
    });
  });

  group('14S / 4T real capture', () {
    final st = p.parseStatus(frame(antStatus14s4t));
    final s = st.snapshot;

    test('values', () {
      expect(s.cellCount, 14);
      expect(s.packVoltage, closeTo(57.58, 1e-9));
      expect(s.current, 0);
      expect(s.soc, 96);
      expect(s.nominalCapacityAh, closeTo(30.0, 1e-6));
      // The frame carries 28529999 uAh, not a round 28.53 Ah.
      expect(s.remainingCapacityAh, closeTo(28.529999, 1e-9));
    });
    test('an exact -40 degC is an unwired probe and is hidden', () {
      expect(s.temperatures[2], BmsSnapshot.absentProbeCelsius);
      expect(s.connectedTemperatures.map((t) => t.index), [0, 1, 3]);
      expect(s.batteryTemperatures, [28.0, 28.0, 28.0]);
    });
    test('discharge MOSFET 0x02 is reported literally', () {
      expect(st.dischargeMosfetCode, 0x02);
      expect(s.dischargeMosfetOn, isFalse);
      expect(s.warnings.active, {BmsWarning.cellUndervoltage});
    });
  });

  group('the balancer, as the BMS describes it', () {
    // The 16S fixture: 16 cells, 2 probes, so o = 36. Balancer code at
    // 48+o = 84, cell bitmask at 70+o = 106..109.
    AntStatus withBalancer(int code, {int mask = 0}) {
      final b = Uint8List.fromList(antStatus16s);
      b[84] = code;
      for (var i = 0; i < 4; i++) {
        b[106 + i] = (mask >> (8 * i)) & 0xFF;
      }
      return p.parseStatus(frame(b));
    }

    test('balancing codes with cells named are working, on those cells', () {
      final st = withBalancer(0x02, mask: (1 << 2) | (1 << 7));
      expect(st.snapshot.balancerActive, isTrue);
      expect(st.snapshot.balancingCellsReported, isTrue);
      final cells = st.snapshot.balancingCells;
      expect(
        [for (var i = 0; i < cells.length; i++) if (cells[i]) i + 1],
        [3, 8],
      );
    });

    test('a balancer stopped by heat is not working', () {
      // Codes 3 and 0x0A are the balancer over temperature: faults. It used
      // to be "anything but 0 is working".
      for (final code in [0x03, 0x0A]) {
        final st = withBalancer(code);
        expect(st.snapshot.balancerActive, isFalse, reason: '$code');
        expect(st.balancerCode, code);
      }
    });

    test('switched on and waiting is not balancing', () {
      // Code 4, "automatic equalization", is the balancer enabled, which the
      // reference maps to its switch, not to charge moving.
      expect(withBalancer(0x04).snapshot.balancerActive, isFalse);
    });

    test('but a bitmask naming cells is balancing whatever the code', () {
      final st = withBalancer(0x04, mask: 1);
      expect(st.snapshot.balancerActive, isTrue);
      expect(st.snapshot.balancingCells.first, isTrue);
    });

    test('with nothing named, no cell is shown as balancing', () {
      // The inference from voltages is for a BMS that does not say. An ANT
      // says, and "none" is its answer.
      final st = withBalancer(0x01);
      expect(st.snapshot.balancerActive, isTrue);
      expect(st.snapshot.balancingCells, everyElement(isFalse));
    });
  });

  group('warning table', () {
    for (final e in {
      (true, 0x02): BmsWarning.packOvervoltage,
      (true, 0x03): BmsWarning.chargeOvercurrent,
      (true, 0x04): BmsWarning.batteryFullyCharged,
      (true, 0x05): BmsWarning.packOvervoltage,
      (true, 0x06): BmsWarning.chargeOvertemperature,
      (true, 0x07): BmsWarning.mosfetOvertemperature,
      (true, 0x11): BmsWarning.chargeUndertemperature,
      (false, 0x02): BmsWarning.cellUndervoltage,
      (false, 0x03): BmsWarning.dischargeOvercurrent,
      (false, 0x04): BmsWarning.dischargeOcpII,
      (false, 0x05): BmsWarning.packUndervoltage,
      (false, 0x06): BmsWarning.dischargeOvertemperature,
      (false, 0x07): BmsWarning.mosfetOvertemperature,
      (false, 0x0C): BmsWarning.dischargeShortCircuit,
      (false, 0x0D): BmsWarning.dischargingMosfetAbnormal,
      (false, 0x0E): BmsWarning.dischargeOnFailed,
      (false, 0x11): BmsWarning.dischargeUndertemperatureAlarm,
    }.entries) {
      test('${e.key.$1 ? "charge" : "discharge"} 0x${e.key.$2.toRadixString(16)}', () {
        expect(antWarnings(charge: e.key.$1 ? e.key.$2 : 1,
                discharge: e.key.$1 ? 1 : e.key.$2).active,
            {e.value});
      });
    }
    test('off, on, manual and unknown codes raise nothing', () {
      for (final c in [0x00, 0x01, 0x0F, 0x13, 0x55]) {
        expect(antWarnings(charge: c, discharge: c).active, isEmpty);
      }
    });
  });

  group('device info', () {
    test('16ZM', () {
      final i = p.parseDeviceInfo(frame(antInfo16zm));
      expect(i.brand, BmsBrand.ant);
      expect(i.model, '16ZM');
      expect(i.softwareVersion, '16ZMUB00-211026A');
      expect(i.serialNumber, '');
      expect(i.jk, isNull);
    });
    test('22PH', () {
      final i = p.parseDeviceInfo(frame(antInfo22ph));
      expect(i.model, '22PHB8TB130A');
      expect(i.softwareVersion, '22AAUB00-241008A');
    });
  });

  test('a frame whose cell count disagrees with its length throws', () {
    final wrong = List<int>.from(antStatus16s)..[9] = 17;
    expect(() => p.parseStatus(frame(wrong)), throwsA(isA<AntParseException>()));
  });
}
