import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/protocol/ant_constants.dart';
import 'package:jk_bms/src/protocol/ant_current_sign.dart';

void main() {
  // The app takes positive current as charging. That is measured on a JK and
  // assumed on an ANT, whose captures are all of idle packs. The frame's own
  // state byte is the check.
  group('the sign of an ANT current, against its own state', () {
    test('charging with a clearly negative current, three frames running, '
        'is a reversed sign, said once', () {
      final c = AntCurrentSign();
      expect(c.observe(batteryState: antStateCharge, current: -6), isFalse);
      expect(c.observe(batteryState: antStateCharge, current: -6), isFalse);
      expect(c.inverted, isFalse);
      expect(c.observe(batteryState: antStateCharge, current: -6), isTrue);
      expect(c.inverted, isTrue);
      // Said once, and then it stays decided.
      expect(c.observe(batteryState: antStateCharge, current: -6), isFalse);
      expect(c.observe(batteryState: antStateCharge, current: 6), isFalse);
      expect(c.inverted, isTrue);
    });

    test('discharging with a positive current is the same finding', () {
      final c = AntCurrentSign();
      for (var i = 0; i < 3; i++) {
        c.observe(batteryState: antStateDischarge, current: 12);
      }
      expect(c.inverted, isTrue);
    });

    test('a state and a current that agree settle it the other way', () {
      final c = AntCurrentSign();
      for (var i = 0; i < 3; i++) {
        c.observe(batteryState: antStateDischarge, current: -12);
      }
      expect(c.decided, isTrue);
      expect(c.inverted, isFalse);
      // A later disagreement is the two not being sampled together, not a
      // change of convention.
      for (var i = 0; i < 5; i++) {
        c.observe(batteryState: antStateCharge, current: -12);
      }
      expect(c.inverted, isFalse);
    });

    test('one contradicting frame between agreeing ones decides nothing', () {
      // The moment a charger is plugged in is when the state and the current
      // can briefly disagree.
      final c = AntCurrentSign();
      c.observe(batteryState: antStateCharge, current: -6);
      c.observe(batteryState: antStateCharge, current: -6);
      c.observe(batteryState: antStateCharge, current: 6);
      c.observe(batteryState: antStateCharge, current: -6);
      expect(c.decided, isFalse);
    });

    test('idle, standby and small currents say nothing', () {
      final c = AntCurrentSign();
      for (var i = 0; i < 10; i++) {
        c.observe(batteryState: 0x01, current: -20); // idle
        c.observe(batteryState: 0x04, current: -20); // standby
        c.observe(batteryState: antStateCharge, current: -0.3);
      }
      expect(c.decided, isFalse);
    });
  });
}
