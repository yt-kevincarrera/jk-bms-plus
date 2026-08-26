import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/metrics/capacity_test_runner.dart';
import 'package:jk_bms/src/model/bms_snapshot.dart';
import 'package:jk_bms/src/model/bms_warning.dart';
import 'package:jk_bms/src/protocol/protocol_variant.dart';

BmsSnapshot snap(
  DateTime at, {
  double current = -20,
  double soc = 100,
  double cellVolts = 4.15,
  bool dischargeOn = true,
  BmsWarnings warnings = BmsWarnings.none,
}) {
  final cells = List.filled(20, cellVolts);
  return BmsSnapshot(
    timestamp: at,
    variant: JkProtocolVariant.jk02_24s,
    frameCounter: 1,
    cellVoltages: cells,
    cellResistances: List.filled(20, 0.0025),
    enabledCellMask: 0xFFFFF,
    packVoltage: cellVolts * 20,
    current: current,
    temperatures: const [25, 24],
    temperatureSensorMask: 7,
    mosfetTemp: 28,
    soc: soc,
    soh: 97,
    remainingCapacityAh: 45 * soc / 100,
    nominalCapacityAh: 45,
    cycleCount: 60,
    cycleCapacityAh: 2700,
    balancingAction: 0,
    balanceCurrent: 0,
    chargeMosfetOn: true,
    dischargeMosfetOn: dischargeOn,
    balancerActive: false,
    heatingOn: false,
    warnings: warnings,
    wireResistanceWarningMask: 0,
    heatingCurrent: 0,
    totalRuntimeSeconds: 3600,
  );
}

void main() {
  final t0 = DateTime.utc(2026, 1, 1, 8);

  group('CapacityTestRunner', () {
    test('refuses to start on a pack that is not full', () {
      final r = CapacityTestRunner();
      expect(
        r.blockedBy(snap(t0, soc: 60, cellVolts: 3.8)),
        CapacityTestBlock.notFull,
      );
      expect(r.blockedBy(null), CapacityTestBlock.noReadings);
    });

    test('accepts a full pack by charge or by cell voltage', () {
      final r = CapacityTestRunner();
      expect(r.blockedBy(snap(t0, soc: 99, cellVolts: 3.9)), isNull);
      // Coulomb counter drifted low, but the cells say full. That is the case
      // this test exists to settle, so it must not be blocked by it.
      expect(r.blockedBy(snap(t0, soc: 80, cellVolts: 4.18)), isNull);
    });

    test('counts amp-hours out of the pack', () {
      final r = CapacityTestRunner()
        ..begin(snapshot: snap(t0), catalogueAh: 45, rowId: 1);

      // 20 A for one hour, fed a second at a time would be slow; step in
      // 10-second slices for an hour instead.
      var at = t0;
      for (var i = 0; i < 360; i++) {
        at = at.add(const Duration(seconds: 10));
        r.addSnapshot(snap(at, current: -20, soc: 100 - i / 360 * 40));
      }

      expect(r.measuredAh, closeTo(20, 0.1));
      expect(r.measuredWh, greaterThan(0));
    });

    test('does not integrate across a dropped connection', () {
      final r = CapacityTestRunner()
        ..begin(snapshot: snap(t0), catalogueAh: 45, rowId: 1)
        ..addSnapshot(snap(t0.add(const Duration(seconds: 5))));

      final before = r.measuredAh;
      // Half an hour of silence, then readings resume.
      r.addSnapshot(snap(t0.add(const Duration(minutes: 30))));

      // The gap contributes nothing rather than half an hour at 20 A.
      expect(r.measuredAh, closeTo(before, 0.001));
    });

    test('ends when the BMS opens the discharge MOSFET', () {
      final r = CapacityTestRunner()
        ..begin(snapshot: snap(t0), catalogueAh: 45, rowId: 1);

      expect(
        r.addSnapshot(snap(t0.add(const Duration(seconds: 5)))),
        isFalse,
      );
      expect(
        r.addSnapshot(
          snap(t0.add(const Duration(seconds: 10)), dischargeOn: false),
        ),
        isTrue,
      );
    });

    test('ends on an undervoltage warning', () {
      final r = CapacityTestRunner()
        ..begin(snapshot: snap(t0), catalogueAh: 45, rowId: 1);

      final done = r.addSnapshot(
        snap(
          t0.add(const Duration(seconds: 5)),
          warnings: BmsWarnings.fromBitmask(
            1 << BmsWarning.cellUndervoltage.bit,
          ),
        ),
      );
      expect(done, isTrue);
    });

    test('ends when charge reaches the floor', () {
      final r = CapacityTestRunner()
        ..begin(snapshot: snap(t0), catalogueAh: 45, rowId: 1);
      expect(
        r.addSnapshot(snap(t0.add(const Duration(seconds: 5)), soc: 2)),
        isTrue,
      );
    });

    test('notices when the pack was charged part way through', () {
      final r = CapacityTestRunner()
        ..begin(snapshot: snap(t0), catalogueAh: 45, rowId: 1);
      expect(r.chargedDuringRun, isFalse);

      r.addSnapshot(snap(t0.add(const Duration(seconds: 5)), current: -20));
      r.addSnapshot(snap(t0.add(const Duration(seconds: 10)), current: 15));
      r.addSnapshot(snap(t0.add(const Duration(seconds: 15)), current: 15));

      expect(r.chargedDuringRun, isTrue);
    });

    test('charging does not subtract from the total drawn', () {
      final r = CapacityTestRunner()
        ..begin(snapshot: snap(t0), catalogueAh: 45, rowId: 1);
      var at = t0;
      for (var i = 0; i < 60; i++) {
        at = at.add(const Duration(seconds: 10));
        r.addSnapshot(snap(at, current: -20));
      }
      final drawn = r.measuredAh;

      for (var i = 0; i < 60; i++) {
        at = at.add(const Duration(seconds: 10));
        r.addSnapshot(snap(at, current: 20));
      }
      expect(r.measuredAh, closeTo(drawn, 0.05));
    });

    test('compares the result against the catalogue figure', () {
      final r = CapacityTestRunner()
        ..begin(snapshot: snap(t0), catalogueAh: 45, rowId: 1);
      var at = t0;
      // Two hours at 18 A is 36 Ah out of a pack sold as 45.
      for (var i = 0; i < 720; i++) {
        at = at.add(const Duration(seconds: 10));
        r.addSnapshot(snap(at, current: -18, soc: 100 - i / 720 * 97));
      }

      expect(r.measuredAh, closeTo(36, 0.2));
      expect(r.fractionOfCatalogue, closeTo(0.8, 0.01));
    });

    test('resumes a run that was interrupted', () {
      final r = CapacityTestRunner()
        ..resume(
          rowId: 7,
          startedAt: t0,
          ah: 12.5,
          wh: 940,
          startSoc: 100,
          startPackVoltage: 83,
          catalogueAh: 45,
        );

      expect(r.state, CapacityTestState.measuring);
      expect(r.measuredAh, 12.5);
      expect(r.rowId, 7);

      var at = t0.add(const Duration(hours: 1));
      for (var i = 0; i < 60; i++) {
        at = at.add(const Duration(seconds: 10));
        r.addSnapshot(snap(at, current: -20, soc: 60));
      }
      expect(r.measuredAh, greaterThan(12.5));
    });

    test('aborting clears everything', () {
      final r = CapacityTestRunner()
        ..begin(snapshot: snap(t0), catalogueAh: 45, rowId: 1)
        ..addSnapshot(snap(t0.add(const Duration(seconds: 10))))
        ..abort();

      expect(r.state, CapacityTestState.idle);
      expect(r.measuredAh, 0);
      expect(r.isRunning, isFalse);
    });

    test('ignores readings when nothing is running', () {
      final r = CapacityTestRunner();
      expect(r.addSnapshot(snap(t0)), isFalse);
      expect(r.measuredAh, 0);
    });
  });
}
