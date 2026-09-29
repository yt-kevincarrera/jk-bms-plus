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

    test('full is the top cell up and a minute of tapered current', () {
      final a = ChargeAlerts(targetSoc: null);
      final top = List.filled(20, 4.17);
      final t0 = DateTime.utc(2026, 1, 1, 3);
      List<ChargeAlert> at(int seconds, double amps, {List<double>? cells}) =>
          a.evaluate(
            buildSnapshot(
              timestamp: t0.add(Duration(seconds: seconds)),
              soc: 99,
              current: amps,
              cells: cells ?? top,
            ),
            fullCellVolts: 4.15,
            capacityAh: 45,
          );

      // 99 % with amps still going in is not finished.
      expect(at(0, 8), isEmpty);
      // Tapered, but only just: one reading is not a finished charge.
      expect(at(10, 1.5), isEmpty);
      expect(at(40, 1.2), isEmpty);
      expect(at(71, 0.9), contains(ChargeAlert.chargeComplete));
    });

    test('pulling the plug at 97 % is not the charge finishing', () {
      // The old rule was 97 % and under 0.3 A on one reading, which is what
      // a plug coming out looks like: bulk current straight to nothing.
      final a = ChargeAlerts(targetSoc: null);
      final t0 = DateTime.utc(2026, 1, 1, 3);
      final cells = List.filled(20, 4.10);
      for (var i = 0; i < 10; i++) {
        expect(
          a.evaluate(
            buildSnapshot(
              timestamp: t0.add(Duration(seconds: i * 10)),
              soc: 97,
              current: i < 5 ? 6 : 0,
              cells: cells,
            ),
            fullCellVolts: 4.15,
            capacityAh: 45,
          ),
          isNot(contains(ChargeAlert.chargeComplete)),
        );
      }
      expect(a.isCharging, isFalse);
    });

    test('a tapered tail with the cells short of full is not finished', () {
      // A weak charger that trickles at 1 A all the way: the current says
      // "tapered" from the start, and the cells are what say it is not done.
      final a = ChargeAlerts(targetSoc: null);
      final t0 = DateTime.utc(2026, 1, 1, 3);
      a.evaluate(buildSnapshot(timestamp: t0, soc: 60, current: 1.5));
      for (var i = 1; i < 20; i++) {
        expect(
          a.evaluate(
            buildSnapshot(
              timestamp: t0.add(Duration(seconds: i * 10)),
              soc: 99,
              current: 1.2,
              cells: List.filled(20, 3.95),
            ),
            fullCellVolts: 4.15,
            capacityAh: 45,
          ),
          isNot(contains(ChargeAlert.chargeComplete)),
        );
      }
    });

    test('a target up where the counter runs ahead is the completion alert', () {
      // 97 and above used to be announced by nothing at all.
      final a = ChargeAlerts(targetSoc: 99);
      final t0 = DateTime.utc(2026, 1, 1, 3);
      final raised = <ChargeAlert>[];
      for (var i = 0; i < 10; i++) {
        raised.addAll(
          a.evaluate(
            buildSnapshot(
              timestamp: t0.add(Duration(seconds: i * 10)),
              soc: 99.5,
              current: i == 0 ? 5 : 1,
              cells: List.filled(20, 4.18),
            ),
            fullCellVolts: 4.15,
            capacityAh: 45,
          ),
        );
      }
      expect(raised, [ChargeAlert.chargeComplete]);
    });

    test('the rider can bring the heat alert earlier, not later', () {
      final a = ChargeAlerts()..hotWarn = 40;
      expect(
        a.evaluate(
          buildSnapshot(soc: 70, current: 12, temperatures: [41.0, 30.0]),
        ),
        contains(ChargeAlert.hotWhileCharging),
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

    test('a warm MOSFET next to cool cells is no reason to unplug', () {
      // The alert is about the cells charging hot. A switch at 50 C is
      // ordinary, and the cells here are at 25.
      final a = ChargeAlerts();
      final alerts = a.evaluate(
        buildSnapshot(
          soc: 70,
          current: 12,
          temperatures: [25.0, 24.0],
          mosfetTemp: 50,
        ),
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
