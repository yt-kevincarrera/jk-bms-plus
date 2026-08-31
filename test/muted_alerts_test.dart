import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/metrics/charge_alerts.dart';
import 'package:jk_bms/src/metrics/ride_alerts.dart';

import 'fixtures/snapshot_builder.dart';

/// Stands in for the service's filtering: the detectors are left alone and
/// only what reaches the rider is filtered.
List<T> unmuted<T>(List<T> raised, Set<String> muted, String Function(T) name) =>
    [for (final a in raised) if (!muted.contains(name(a))) a];

void main() {
  group('silencing one alert', () {
    test('does not silence the others', () {
      // The whole point of doing this per alert. Somebody who does not care
      // that the charger runs warm still wants to know the charge finished,
      // and an app whose only option is silence gets silenced entirely.
      final alerts = ChargeAlerts(targetSoc: 80);
      final raised = alerts.evaluate(
        buildSnapshot(soc: 85, current: 10, temperatures: [46.0, 30.0]),
      );
      expect(raised, contains(ChargeAlert.targetReached));
      expect(raised, contains(ChargeAlert.hotWhileCharging));

      final heard = unmuted(
        raised,
        {ChargeAlert.hotWhileCharging.name},
        (a) => a.name,
      );
      expect(heard, contains(ChargeAlert.targetReached));
      expect(heard, isNot(contains(ChargeAlert.hotWhileCharging)));
    });

    test('works the same way for riding alerts', () {
      final alerts = RideAlerts();
      final cells = List.filled(20, 3.90);
      cells[6] = 3.70;
      final raised = alerts.evaluate(
        buildSnapshot(cells: cells, temperatures: [58.0]),
        cutoffVoltagePerCell: 3.0,
      );
      expect(raised, contains(RideAlert.temperature));

      final heard =
          unmuted(raised, {RideAlert.temperature.name}, (a) => a.name);
      expect(heard, isNot(contains(RideAlert.temperature)));
      // And whatever else fired is still heard.
      expect(heard.length, raised.length - 1);
    });

    test('leaves the detector itself untouched', () {
      // Muting changes what the app says out loud, never what it knows. The
      // capacity test, the charge report and the stored history all depend on
      // the same evaluation running.
      final alerts = ChargeAlerts(targetSoc: 80);
      final raised = alerts.evaluate(buildSnapshot(soc: 85, current: 10));

      expect(alerts.fired, contains(ChargeAlert.targetReached));
      expect(raised, isNotEmpty);
    });

    test('an empty mute set changes nothing', () {
      final alerts = ChargeAlerts(targetSoc: 80);
      final raised = alerts.evaluate(buildSnapshot(soc: 85, current: 10));
      expect(unmuted(raised, const {}, (a) => a.name), raised);
    });

    test('names are stable enough to store', () {
      // They are written to preferences, so a rename would silently un-mute
      // everything somebody had switched off.
      expect(ChargeAlert.chargeComplete.name, 'chargeComplete');
      expect(RideAlert.criticalCharge.name, 'criticalCharge');
    });
  });
}
