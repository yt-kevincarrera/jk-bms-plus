import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/metrics/charge_alerts.dart';

import 'fixtures/snapshot_builder.dart';

void main() {
  group('while a pack is charging', () {
    test('announces the level the rider asked for, once', () {
      final a = ChargeAlerts(targetSoc: 80);

      expect(a.evaluate(buildSnapshot(soc: 60, current: 10)), isEmpty);
      expect(
        a.evaluate(buildSnapshot(soc: 81, current: 10)),
        contains(ChargeAlert.targetReached),
      );
      // Still above 80 a second later. Saying so again is how an alert
      // teaches you to ignore it.
      expect(a.evaluate(buildSnapshot(soc: 83, current: 10)), isEmpty);
    });

    test('says nothing about a target while the pack is discharging', () {
      // Riding down through 80% is not reaching 80%.
      final a = ChargeAlerts(targetSoc: 80);
      expect(a.evaluate(buildSnapshot(soc: 79, current: -20)), isEmpty);
      expect(a.evaluate(buildSnapshot(soc: 60, current: -20)), isEmpty);
    });

    test('a new charge re-arms it', () {
      // Otherwise it announces 80% once and is useless on the second night.
      final a = ChargeAlerts(targetSoc: 80);
      a.evaluate(buildSnapshot(soc: 85, current: 10));
      expect(a.fired, contains(ChargeAlert.targetReached));

      a.evaluate(buildSnapshot(soc: 40, current: -20)); // ridden down
      expect(
        a.evaluate(buildSnapshot(soc: 85, current: 10)),
        contains(ChargeAlert.targetReached),
      );
    });

    test('full means the current has tapered, not just a high percentage', () {
      final a = ChargeAlerts(targetSoc: null);

      // 98% with amps still going in is not finished.
      expect(a.evaluate(buildSnapshot(soc: 98, current: 8)), isEmpty);
      expect(
        a.evaluate(buildSnapshot(soc: 99, current: 0.1)),
        contains(ChargeAlert.chargeComplete),
      );
    });

    test('an idle pack does not announce completion every time it is read', () {
      // Nothing was charging, so nothing finished.
      final a = ChargeAlerts();
      expect(a.evaluate(buildSnapshot(soc: 99, current: 0.0)), isEmpty);
      expect(a.evaluate(buildSnapshot(soc: 99, current: 0.0)), isEmpty);
    });

    test('flags heat, which while charging usually means the charger', () {
      final a = ChargeAlerts();
      expect(
        a.evaluate(
          buildSnapshot(soc: 70, current: 12, temperatures: [46.0, 30.0]),
        ),
        contains(ChargeAlert.hotWhileCharging),
      );
    });

    test('an unconnected probe cannot raise the heat alert', () {
      // -200 C is not a temperature, and a maximum taken over it would be
      // wrong in the other direction anyway.
      final a = ChargeAlerts();
      final alerts = a.evaluate(
        buildSnapshot(soc: 70, current: 12, temperatures: [-200.0, 25.0]),
      );
      expect(alerts, isNot(contains(ChargeAlert.hotWhileCharging)));
    });

    test('flags a spread only up in the steep region', () {
      final a = ChargeAlerts();

      // Same spread low down says little: the curve is flat there.
      final low = List.filled(20, 3.60);
      low[6] = 3.53;
      expect(
        a.evaluate(buildSnapshot(soc: 40, current: 12, cells: low)),
        isNot(contains(ChargeAlert.spreadAtTop)),
      );

      // The same 70 mV at the top is a capacity mismatch talking.
      final high = List.filled(20, 4.12);
      high[6] = 4.05;
      expect(
        a.evaluate(buildSnapshot(soc: 95, current: 4, cells: high)),
        contains(ChargeAlert.spreadAtTop),
      );
    });

    test('reset forgets the charge entirely', () {
      final a = ChargeAlerts(targetSoc: 80);
      a.evaluate(buildSnapshot(soc: 85, current: 10));
      a.reset();
      expect(a.fired, isEmpty);
      expect(a.isCharging, isFalse);
    });
  });
}
