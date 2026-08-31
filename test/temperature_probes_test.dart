import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/model/bms_snapshot.dart';

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
      expect(s.plausibleTemperatures, isEmpty);
    });

    test('an absent probe cannot drag a maximum or an alert', () {
      final s = buildSnapshot(temperatures: [-200.0, 41.0]);
      final hottest = s.plausibleTemperatures.reduce((a, b) => a > b ? a : b);
      final coldest = s.plausibleTemperatures.reduce((a, b) => a < b ? a : b);
      expect(hottest, 41.0);
      // The one that matters: a cold-battery warning must not fire on a
      // reading that means "no sensor".
      expect(coldest, 41.0);
    });
  });
}
