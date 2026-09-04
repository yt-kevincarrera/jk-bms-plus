import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/metrics/ride_alerts.dart';
import 'package:jk_bms/src/model/bms_snapshot.dart';
import 'package:jk_bms/src/model/bms_warning.dart';
import 'package:jk_bms/src/protocol/protocol_variant.dart';

BmsSnapshot snap(
  DateTime at, {
  double soc = 80,
  double delta = 0.010,
  double temp = 25,
  double minCell = 3.9,
  double current = -20,
  BmsWarnings warnings = BmsWarnings.none,
}) {
  final cells = List.filled(20, minCell + delta);
  cells[0] = minCell;
  return BmsSnapshot(
    timestamp: at,
    variant: JkProtocolVariant.jk02_24s,
    frameCounter: 1,
    cellVoltages: cells,
    cellResistances: List.filled(20, 0.0025),
    enabledCellMask: 0xFFFFF,
    packVoltage: cells.reduce((a, b) => a + b),
    current: current,
    temperatures: [temp, temp - 1],
    temperatureSensorMask: 7,
    mosfetTemp: temp,
    soc: soc,
    soh: 97,
    remainingCapacityAh: 45 * soc / 100,
    nominalCapacityAh: 45,
    cycleCount: 60,
    cycleCapacityAh: 2700,
    balancingAction: 0,
    balanceCurrent: 0,
    chargeMosfetOn: true,
    dischargeMosfetOn: true,
    balancerActive: false,
    heatingOn: false,
    warnings: warnings,
    wireResistanceWarningMask: 0,
    heatingCurrent: 0,
    totalRuntimeSeconds: 3600,
  );
}

void main() {
  final t0 = DateTime.utc(2026, 1, 1, 9);
  const cutoff = 3.0;

  List<RideAlert> feed(RideAlerts a, BmsSnapshot s) =>
      a.evaluate(s, cutoffVoltagePerCell: cutoff);

  List<RideAlert> feedWithLimits(
    RideAlerts a,
    BmsSnapshot s, {
    double? discharge,
    double? charge,
  }) => a.evaluate(
    s,
    cutoffVoltagePerCell: cutoff,
    dischargeLimitAmps: discharge,
    chargeLimitAmps: charge,
  );

  group('close to the current the BMS allows', () {
    test('a pull near the configured discharge limit is called out', () {
      final a = RideAlerts();
      final firing = feedWithLimits(a, snap(t0, current: -97), discharge: 100);
      expect(firing, contains(RideAlert.nearCurrentLimit));
    });

    test('a comfortable pull says nothing', () {
      final a = RideAlerts();
      expect(
        feedWithLimits(a, snap(t0, current: -40), discharge: 100),
        isEmpty,
      );
    });

    test('it clears once the current comes properly back down', () {
      final a = RideAlerts();
      feedWithLimits(a, snap(t0, current: -97), discharge: 100);
      expect(a.active, contains(RideAlert.nearCurrentLimit));

      // Still high enough to be inside the clearing band: no chatter.
      feedWithLimits(
        a,
        snap(t0.add(const Duration(seconds: 5)), current: -90),
        discharge: 100,
      );
      expect(a.active, contains(RideAlert.nearCurrentLimit));

      feedWithLimits(
        a,
        snap(t0.add(const Duration(seconds: 10)), current: -50),
        discharge: 100,
      );
      expect(a.active, isNot(contains(RideAlert.nearCurrentLimit)));
    });

    test(
      'charging is judged against the charge limit, not the discharge one',
      () {
        final a = RideAlerts();
        // Twenty amps in is nowhere near a hundred-amp discharge limit, and
        // everything near a twenty-amp charge limit.
        expect(
          feedWithLimits(
            a,
            snap(t0, current: 19.5),
            discharge: 100,
            charge: 20,
          ),
          contains(RideAlert.nearCurrentLimit),
        );
      },
    );

    test('with no configured limit it stays quiet', () {
      final a = RideAlerts();
      expect(feedWithLimits(a, snap(t0, current: -200)), isEmpty);
    });
  });

  group('thresholds the rider moved', () {
    test('a raised spread threshold stops the alert firing', () {
      final a = RideAlerts()
        ..deltaWarn = 0.200
        ..deltaClear = 0.160;
      expect(feed(a, snap(t0, delta: 0.150)), isEmpty);
    });

    test('a lowered one makes it fire where it would not have', () {
      final a = RideAlerts()
        ..deltaWarn = 0.040
        ..deltaClear = 0.030;
      expect(feed(a, snap(t0, delta: 0.050)), contains(RideAlert.cellSpread));
    });

    test('a raised temperature threshold is respected', () {
      final a = RideAlerts()
        ..tempWarn = 70
        ..tempClear = 65;
      expect(feed(a, snap(t0, temp: 60)), isEmpty);
    });
  });

  group('RideAlerts', () {
    test('a healthy pack says nothing', () {
      final a = RideAlerts();
      expect(feed(a, snap(t0)), isEmpty);
      expect(a.active, isEmpty);
    });

    test('fires once on a wide spread, not on every reading', () {
      final a = RideAlerts();
      expect(feed(a, snap(t0, delta: 0.130)), contains(RideAlert.cellSpread));
      // Same condition a second later: already said.
      expect(
        feed(a, snap(t0.add(const Duration(seconds: 1)), delta: 0.135)),
        isEmpty,
      );
      expect(a.active, contains(RideAlert.cellSpread));
    });

    test('does not chatter around the threshold', () {
      final a = RideAlerts();
      feed(a, snap(t0, delta: 0.130));

      // Falls back just under the trip point but not past the clear point.
      feed(a, snap(t0.add(const Duration(seconds: 1)), delta: 0.095));
      // Rises again: must not fire a second time, because it never cleared.
      expect(
        feed(a, snap(t0.add(const Duration(seconds: 2)), delta: 0.130)),
        isEmpty,
      );
    });

    test('clears properly and can fire again later', () {
      final a = RideAlerts();
      feed(a, snap(t0, delta: 0.130));

      feed(a, snap(t0.add(const Duration(seconds: 1)), delta: 0.050));
      expect(a.active, isEmpty);

      // Well past the minimum gap, and back over the line.
      expect(
        feed(a, snap(t0.add(const Duration(minutes: 5)), delta: 0.130)),
        contains(RideAlert.cellSpread),
      );
    });

    test('will not repeat inside the minimum gap even after clearing', () {
      final a = RideAlerts();
      feed(a, snap(t0, delta: 0.130));
      feed(a, snap(t0.add(const Duration(seconds: 5)), delta: 0.050));

      expect(
        feed(a, snap(t0.add(const Duration(seconds: 20)), delta: 0.130)),
        isEmpty,
      );
    });

    test('fires on heat', () {
      final a = RideAlerts();
      expect(feed(a, snap(t0, temp: 58)), contains(RideAlert.temperature));
    });

    test('fires on a BMS fault', () {
      final a = RideAlerts();
      final alerts = feed(
        a,
        snap(
          t0,
          warnings: BmsWarnings.fromBitmask(
            1 << BmsWarning.dischargeOvercurrent.bit,
          ),
        ),
      );
      expect(alerts, contains(RideAlert.bmsFault));
    });

    test('separates low charge from nearly empty', () {
      final low = RideAlerts();
      expect(feed(low, snap(t0, soc: 12)), contains(RideAlert.lowCharge));
      expect(feed(low, snap(t0, soc: 12)), isEmpty);

      final critical = RideAlerts();
      final alerts = feed(critical, snap(t0, soc: 5));
      expect(alerts, contains(RideAlert.criticalCharge));
      // At 5% it is critical, not merely low: one message, not two.
      expect(alerts, isNot(contains(RideAlert.lowCharge)));
    });

    test('warns on a cell near cutoff even at a comfortable charge', () {
      final a = RideAlerts();
      // The charge reading says there is plenty left, but one cell is nearly
      // at the floor. That cell is what will stop the bike.
      final alerts = feed(a, snap(t0, soc: 45, minCell: 3.05));
      expect(alerts, contains(RideAlert.cellNearCutoff));
      expect(alerts, isNot(contains(RideAlert.lowCharge)));
    });

    test('marks the serious ones as critical', () {
      expect(RideAlert.criticalCharge.isCritical, isTrue);
      expect(RideAlert.cellNearCutoff.isCritical, isTrue);
      expect(RideAlert.bmsFault.isCritical, isTrue);
      expect(RideAlert.lowCharge.isCritical, isFalse);
      expect(RideAlert.cellSpread.isCritical, isFalse);
    });

    test('reset forgets everything', () {
      final a = RideAlerts();
      feed(a, snap(t0, delta: 0.130));
      a.reset();
      expect(a.active, isEmpty);
      expect(
        feed(a, snap(t0.add(const Duration(seconds: 1)), delta: 0.130)),
        contains(RideAlert.cellSpread),
      );
    });
  });
}
