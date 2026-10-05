import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/model/bms_snapshot.dart';
import 'package:jk_bms/src/protocol/bms_brand.dart';
import 'package:jk_bms/src/protocol/protocol_variant.dart';

import 'fixtures/snapshot_builder.dart';

void main() {
  group('probes that are not connected', () {
    test('a -200 C reading is not a temperature', () {
      // Straight off a real pack: two of its inputs read about -200 C, which
      // is not a frozen battery, it is nothing wired to that input.
      final s = buildSnapshot(temperatures: [24.5, -200.0, 26.1, -200.0]);

      expect(s.connectedTemperatures.map((p) => p.celsius), [24.5, 26.1]);
      expect(s.absentTemperatureProbes, [1, 3]);
    });

    test('keeps the probe number, so 3 does not become 2', () {
      // The index is which sensor the BMS reported it at. Renumbering would
      // send you looking at the wrong part of the pack.
      final s = buildSnapshot(temperatures: [-200.0, 30.0]);
      expect(s.connectedTemperatures.single.index, 1);
    });

    test('a genuinely cold pack still reads', () {
      // The bounds are generous on purpose: hiding a real reading as a fault
      // would be the same mistake in the other direction.
      final s = buildSnapshot(temperatures: [-15.0, 2.0]);
      expect(s.connectedTemperatures, hasLength(2));
      expect(s.absentTemperatureProbes, isEmpty);
    });

    test('a genuinely hot pack still reads', () {
      final s = buildSnapshot(temperatures: [78.0]);
      expect(s.connectedTemperatures, hasLength(1));
    });

    test('nothing plausible at all leaves an empty list, not a zero', () {
      final s = buildSnapshot(temperatures: [-200.0, -200.0]);
      expect(s.connectedTemperatures, isEmpty);
      expect(s.batteryTemperatures, isEmpty);
    });

    test('an absent probe cannot drag a maximum or an alert', () {
      final s = buildSnapshot(temperatures: [-200.0, 41.0]);
      final hottest = s.batteryTemperatures.reduce((a, b) => a > b ? a : b);
      final coldest = s.batteryTemperatures.reduce((a, b) => a < b ? a : b);
      expect(hottest, 41.0);
      // The one that matters: a cold-battery warning must not fire on a
      // reading that means "no sensor".
      expect(coldest, 41.0);
    });
  });

  group('the fifth slot that repeats the MOSFET', () {
    // On the rider's JK02_32S the fifth probe slot reads exactly the MOSFET
    // temperature in every captured frame. Counted as a battery probe it
    // showed the MOSFET twice and let a warm switch call the pack hot.
    BmsSnapshot jk32({required double slot5, double mosfet = 36.0}) =>
        buildSnapshot(
          variant: JkProtocolVariant.jk02_32s,
          temperatures: [34.1, 34.2, -200.0, -200.0, slot5],
          mosfetTemp: mosfet,
        );

    test('is not a battery probe when it equals the MOSFET', () {
      final s = jk32(slot5: 36.0);
      expect(s.mosfetMirrorSlot, 4);
      expect(s.connectedTemperatures.map((p) => p.index), [0, 1]);
      expect(s.batteryTemperatures, [34.1, 34.2]);
      expect(s.hottestBatteryTemp, 34.2);
      // Four probe inputs, two of them empty: the mirror is not an input.
      expect(s.probeInputCount, 4);
      expect(s.absentTemperatureProbes, [2, 3]);
    });

    test('a fifth probe reading its own value is a probe', () {
      final s = jk32(slot5: 29.5);
      expect(s.mosfetMirrorSlot, isNull);
      expect(s.batteryTemperatures, [34.1, 34.2, 29.5]);
      expect(s.probeInputCount, 5);
    });

    test('only on the 32-cell framing, which is where it was seen', () {
      // A JK02_24S frame carries two probes and no fifth slot; an ANT has its
      // own layout. Neither gets a probe dropped by this rule.
      final jk24 = buildSnapshot(
        temperatures: [30.0, 28.0, 25.0, 26.0, 36.0],
        mosfetTemp: 36.0,
      );
      expect(jk24.mosfetMirrorSlot, isNull);
      final ant = buildSnapshot(
        brand: BmsBrand.ant,
        variant: null,
        temperatures: [30.0, 28.0, 25.0, 26.0, 36.0],
        mosfetTemp: 36.0,
      );
      expect(ant.mosfetMirrorSlot, isNull);
      expect(ant.batteryTemperatures, hasLength(5));
    });

    test('the MOSFET never counts as the hottest battery probe', () {
      final s = buildSnapshot(temperatures: const [25, 24], mosfetTemp: 70);
      expect(s.hottestBatteryTemp, 25);
    });

    test('no probe fitted leaves no battery temperature, not a zero', () {
      final s = buildSnapshot(temperatures: const [-200, -200]);
      expect(s.hottestBatteryTemp, isNull);
    });
  });
}
