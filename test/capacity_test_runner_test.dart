import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/metrics/capacity_endpoints.dart';
import 'package:jk_bms/src/metrics/capacity_test_runner.dart';
import 'package:jk_bms/src/model/bms_snapshot.dart';
import 'package:jk_bms/src/model/bms_warning.dart';
import 'package:jk_bms/src/protocol/bms_brand.dart';
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
    brand: BmsBrand.jk,
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

    test('accepts a full pack by its cells, not by its percentage', () {
      final r = CapacityTestRunner();
      // 99 % on the counter with the cells half way up is not full: opening
      // there is what made the old test hand back the configured capacity.
      expect(
        r.blockedBy(snap(t0, soc: 99, cellVolts: 3.9)),
        CapacityTestBlock.notFull,
      );
      // Coulomb counter drifted low, but the cells say full. That is the case
      // this test exists to settle, so it must not be blocked by it.
      expect(r.blockedBy(snap(t0, soc: 80, cellVolts: 4.18)), isNull);
    });

    test('a charger still pushing bulk current is not full yet', () {
      final r = CapacityTestRunner();
      expect(
        r.blockedBy(snap(t0, current: 8, cellVolts: 4.16)),
        CapacityTestBlock.notFull,
      );
      expect(r.blockedBy(snap(t0, current: 1.2, cellVolts: 4.18)), isNull);
    });

    test('with no full mark for the pack, it says so rather than guess', () {
      final r = CapacityTestRunner(
        endpoints: const CapacityEndpoints(
          fullCellVolts: null,
          cutoffCellVolts: 3.0,
        ),
      );
      expect(
        r.blockedBy(snap(t0, cellVolts: 4.18)),
        CapacityTestBlock.noFullMark,
      );
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

    test('bridges a dropped connection on the BMS counter, and counts it', () {
      final r = CapacityTestRunner()
        ..begin(snapshot: snap(t0), catalogueAh: 45, rowId: 1)
        ..addSnapshot(snap(t0.add(const Duration(seconds: 5))));

      final before = r.measuredAh;
      // Half an hour of silence, then readings resume, with the BMS having
      // counted 10 Ah out in the meantime (100 % to 77.8 % of 45 Ah).
      r.addSnapshot(
        snap(t0.add(const Duration(minutes: 30)), soc: 100 - 10 / 45 * 100),
      );

      // The gap is what the BMS counted, not half an hour at 20 A and not
      // nothing either, and the half hour is on the record.
      expect(r.measuredAh - before, closeTo(10, 0.01));
      expect(r.gapSeconds, closeTo(1795, 1));
      expect(r.chargedDuringRun, isFalse);
    });

    test('a rise across a gap is a charge it did not see', () {
      final r = CapacityTestRunner()
        ..begin(
          snapshot: snap(t0, soc: 60, cellVolts: 3.8),
          catalogueAh: 45,
          rowId: 1,
        )
        ..addSnapshot(snap(t0.add(const Duration(minutes: 90)), soc: 90));
      expect(r.chargedDuringRun, isTrue);
    });

    test('ends when the BMS opens the discharge MOSFET near the cutoff', () {
      final r = CapacityTestRunner()
        ..begin(snapshot: snap(t0), catalogueAh: 45, rowId: 1);

      expect(
        r.addSnapshot(snap(t0.add(const Duration(seconds: 5)))),
        isFalse,
      );
      expect(
        r.addSnapshot(
          snap(
            t0.add(const Duration(seconds: 10)),
            dischargeOn: false,
            cellVolts: 3.15,
          ),
        ),
        isTrue,
      );
      expect(r.endReason, CapacityEndReason.bmsCutoff);
    });

    test('an over-current trip on a charged pack is not the cutoff', () {
      final r = CapacityTestRunner()
        ..begin(snapshot: snap(t0), catalogueAh: 45, rowId: 1);
      expect(
        r.addSnapshot(
          snap(
            t0.add(const Duration(seconds: 5)),
            dischargeOn: false,
            cellVolts: 3.95,
          ),
        ),
        isFalse,
      );
    });

    test('ends when the lowest cell reaches the cutoff', () {
      final r = CapacityTestRunner()
        ..begin(snapshot: snap(t0), catalogueAh: 45, rowId: 1);
      expect(
        r.addSnapshot(
          snap(t0.add(const Duration(seconds: 5)), soc: 40, cellVolts: 3.04),
        ),
        isTrue,
      );
      expect(r.endReason, CapacityEndReason.cellCutoff);
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

    test('does not end at 3 % on the percentage with the cells well up', () {
      // The old floor. The percentage is remaining over the configured
      // capacity, so stopping on it measured the configuration.
      final r = CapacityTestRunner()
        ..begin(snapshot: snap(t0), catalogueAh: 45, rowId: 1);
      expect(
        r.addSnapshot(
          snap(t0.add(const Duration(seconds: 5)), soc: 2, cellVolts: 3.4),
        ),
        isFalse,
      );
      expect(r.isRunning, isTrue);
    });

    test('finishing by hand is a partial', () {
      final r = CapacityTestRunner()
        ..begin(snapshot: snap(t0), catalogueAh: 45, rowId: 1)
        ..addSnapshot(snap(t0.add(const Duration(seconds: 5))))
        ..finish(reason: CapacityEndReason.stoppedEarly);
      expect(r.endReason, CapacityEndReason.stoppedEarly);
      expect(r.isRunning, isFalse);
    });

    test('a closed run does not close twice', () {
      final r = CapacityTestRunner()
        ..begin(snapshot: snap(t0), catalogueAh: 45, rowId: 1);
      expect(
        r.addSnapshot(snap(t0.add(const Duration(seconds: 5)), cellVolts: 3)),
        isTrue,
      );
      final ah = r.measuredAh;
      expect(
        r.addSnapshot(snap(t0.add(const Duration(seconds: 10)), cellVolts: 3)),
        isFalse,
      );
      expect(r.measuredAh, ah);
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

    test('a resumed run bridges the time the app was closed', () {
      // The app was killed with 12.5 Ah counted and the pack at 72 %. When it
      // comes back the pack is at 50 %: 9.9 Ah drawn with nobody watching.
      // That used to vanish, because the run restarted from nothing.
      final r = CapacityTestRunner()
        ..resume(
          rowId: 7,
          startedAt: t0,
          ah: 12.5,
          wh: 940,
          startSoc: 100,
          startPackVoltage: 83,
          catalogueAh: 45,
          gapSeconds: 30,
          lastSeen: CapacityBridgePoint(
            at: t0.add(const Duration(minutes: 40)),
            remainingAh: 45 * 0.72,
            packVoltage: 78,
            soc: 72,
          ),
        );
      r.addSnapshot(
        snap(t0.add(const Duration(minutes: 70)), soc: 50, cellVolts: 3.7),
      );

      expect(r.measuredAh, closeTo(12.5 + 45 * 0.22, 0.01));
      // The half hour it was closed counts against trusting the result.
      expect(r.gapSeconds, 30 + 30 * 60);
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
