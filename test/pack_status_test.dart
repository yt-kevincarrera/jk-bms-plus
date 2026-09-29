import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/pack/chemistry.dart';
import 'package:jk_bms/src/protocol/protocol_variant.dart';
import 'package:jk_bms/src/ui/widgets/common.dart';

import 'fixtures/snapshot_builder.dart';

void main() {
  group('the status band judges the battery and the BMS apart', () {
    // It used to take one "hottest" over every raw slot and the MOSFET, so a
    // switch at 50 C next to cells at 25 painted the band "running warm", and
    // on a JK02_32S the MOSFET was in there twice.

    test('a MOSFET warm for a switch leaves the band clear', () {
      final s = buildSnapshot(temperatures: const [25, 24], mosfetTemp: 60);
      expect(packStatusOf(s).reason, PackStatusReason.allClear);
    });

    test('a hot MOSFET says the BMS, not the pack', () {
      final warm = packStatusOf(
        buildSnapshot(temperatures: const [25, 24], mosfetTemp: 75),
      );
      expect(warm.reason, PackStatusReason.bmsHot);
      expect(warm.health, PackHealth.watch);
      expect(warm.value, 75);

      final hot = packStatusOf(
        buildSnapshot(temperatures: const [25, 24], mosfetTemp: 85),
      );
      expect(hot.reason, PackStatusReason.bmsHot);
      expect(hot.health, PackHealth.bad);
    });

    test('a hot battery probe is still the pack', () {
      final s = buildSnapshot(temperatures: const [48, 30], mosfetTemp: 40);
      final status = packStatusOf(s);
      expect(status.reason, PackStatusReason.temperature);
      expect(status.value, 48);
    });

    test("slot 5 repeating the MOSFET is not a battery probe here either", () {
      final s = buildSnapshot(
        variant: JkProtocolVariant.jk02_32s,
        temperatures: const [30, 30, -200, -200, 50],
        mosfetTemp: 50,
      );
      expect(packStatusOf(s).reason, PackStatusReason.allClear);
    });
  });

  group('the spread, by chemistry', () {
    // 16 cells at the top of an LFP charge, 60 mV apart: normal up there,
    // where a few millivolts of charge are tens of millivolts of voltage.
    final top = [for (var i = 1; i <= 16; i++) i == 5 ? 3.42 : 3.48];

    test('is not judged above the LFP knee on an LFP pack', () {
      final s = buildSnapshot(cells: top, current: 5);
      expect(
        packStatusOf(s, chemistry: CellChemistry.lfp).reason,
        PackStatusReason.allClear,
      );
    });

    test('is judged as before when the chemistry is not LFP', () {
      final s = buildSnapshot(cells: top, current: 5);
      expect(packStatusOf(s).reason, PackStatusReason.cellSpread);
    });

    test('is judged on the LFP plateau, where it means something', () {
      final mid = [for (var i = 1; i <= 16; i++) i == 5 ? 3.24 : 3.30];
      final s = buildSnapshot(cells: mid, current: 0);
      expect(
        packStatusOf(s, chemistry: CellChemistry.lfp).reason,
        PackStatusReason.cellSpread,
      );
    });
  });
}
