import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/metrics/advice_engine.dart';
import 'package:jk_bms/src/metrics/pack_health_report.dart';
import 'package:jk_bms/src/metrics/range_estimator.dart';
import 'package:jk_bms/src/model/bms_snapshot.dart';
import 'package:jk_bms/src/model/bms_warning.dart';
import 'package:jk_bms/src/model/jk_settings.dart';
import 'package:jk_bms/src/protocol/protocol_variant.dart';

BmsSnapshot snap({
  List<double>? cells,
  double soc = 78,
  double remainingAh = 35.1,
  List<double> temperatures = const [25, 24],
  double mosfetTemp = 28,
  int cycles = 63,
  double cycleCapacityAh = 2843.5,
  double soh = 97,
}) {
  final v = cells ?? List.filled(20, 3.90);
  return BmsSnapshot(
    timestamp: DateTime.utc(2026, 1, 1),
    variant: JkProtocolVariant.jk02_24s,
    frameCounter: 1,
    cellVoltages: v,
    cellResistances: List.filled(20, 0.0025),
    enabledCellMask: 0xFFFFF,
    packVoltage: v.reduce((a, b) => a + b),
    current: -20,
    temperatures: temperatures,
    temperatureSensorMask: 7,
    mosfetTemp: mosfetTemp,
    soc: soc,
    soh: soh,
    remainingCapacityAh: remainingAh,
    nominalCapacityAh: 45,
    cycleCount: cycles,
    cycleCapacityAh: cycleCapacityAh,
    balancingAction: 0,
    balanceCurrent: 0,
    chargeMosfetOn: true,
    dischargeMosfetOn: true,
    balancerActive: false,
    heatingOn: false,
    warnings: BmsWarnings.none,
    wireResistanceWarningMask: 0,
    heatingCurrent: 0,
    totalRuntimeSeconds: 3600,
  );
}

JkSettings settings({
  double cellOvp = 4.2,
  double balanceStart = 3.4,
  bool balancerOn = true,
}) =>
    JkSettings(
      receivedAt: DateTime.utc(2026, 1, 1),
      smartSleepVoltage: 0,
      cellUvp: 2.8,
      cellUvpRecovery: 3.0,
      cellOvp: cellOvp,
      cellOvpRecovery: cellOvp - 0.1,
      balanceTriggerVoltage: 0.01,
      soc100Voltage: 0,
      soc0Voltage: 0,
      cellRequestChargeVoltage: 0,
      cellRequestFloatVoltage: 0,
      powerOffVoltage: 2.7,
      maxChargeCurrent: 20,
      chargeOcpDelaySeconds: 30,
      chargeOcpRecoverySeconds: 60,
      maxDischargeCurrent: 120,
      dischargeOcpDelaySeconds: 30,
      dischargeOcpRecoverySeconds: 60,
      scpRecoverySeconds: 60,
      maxBalanceCurrent: 1,
      chargeOtp: 55,
      chargeOtpRecovery: 45,
      dischargeOtp: 65,
      dischargeOtpRecovery: 55,
      chargeUtp: 0,
      chargeUtpRecovery: 5,
      mosfetOtp: 90,
      mosfetOtpRecovery: 70,
      cellCount: 20,
      chargeSwitchOn: true,
      dischargeSwitchOn: true,
      balancerSwitchOn: balancerOn,
      nominalCapacityAh: 45,
      scpDelayMicroseconds: 1500,
      balanceStartVoltage: balanceStart,
      connectionWireResistances: const [],
    );

List<Advice> run({
  BmsSnapshot? snapshot,
  JkSettings? config,
  double? restingDelta,
  double? loadedDelta,
  Map<int, int> weakCellCounts = const {},
  bool balancerEverSeen = true,
  int capacityTestCount = 1,
  RangeEstimator? estimator,
  double usableWh = 0,
  double grossWh = 0,
  double catalogueAh = 45,
  bool degradationMeasurable = false,
}) {
  final s = snapshot ?? snap();
  return const AdviceEngine().evaluate(
    snapshot: s,
    report: PackHealthReport.from(
      snapshot: s,
      settings: config,
      catalogueCapacityAh: catalogueAh,
    ),
    estimator: estimator ?? (RangeEstimator()..addSegment(wh: 3000, km: 100)),
    settings: config,
    restingDelta: restingDelta,
    loadedDelta: loadedDelta,
    weakCellCounts: weakCellCounts,
    balancerEverSeen: balancerEverSeen,
    capacityTestCount: capacityTestCount,
    degradationMeasurable: degradationMeasurable,
    usableWh: usableWh,
    grossWh: grossWh,
  );
}

bool has(List<Advice> advice, AdviceCode code) =>
    advice.any((a) => a.code == code);

void main() {
  group('AdviceEngine', () {
    test('a healthy pack gets no advice at all', () {
      final advice = run(restingDelta: 0.008, loadedDelta: 0.020);
      expect(advice, isEmpty);
    });

    test('a delta present at rest is called capacity, not resistance', () {
      final advice = run(restingDelta: 0.045, loadedDelta: 0.050);
      expect(has(advice, AdviceCode.imbalanceAtRest), isTrue);
      expect(has(advice, AdviceCode.imbalanceUnderLoad), isFalse);
    });

    test('a delta that only appears under load is called resistance', () {
      final advice = run(restingDelta: 0.010, loadedDelta: 0.080);
      expect(has(advice, AdviceCode.imbalanceUnderLoad), isTrue);
      expect(has(advice, AdviceCode.imbalanceAtRest), isFalse);
    });

    test('a very wide resting delta is a problem, not a warning', () {
      final advice = run(restingDelta: 0.080);
      final item =
          advice.firstWhere((a) => a.code == AdviceCode.imbalanceAtRest);
      expect(item.level, AdviceLevel.problem);
    });

    test('names the cell that keeps coming last', () {
      final advice = run(
        weakCellCounts: {7: 180, 3: 15, 12: 5},
      );
      final item =
          advice.firstWhere((a) => a.code == AdviceCode.weakCellDominant);
      expect(item.cellIndex, 7);
      expect(item.value, greaterThan(60));
    });

    test('says nothing about a weak cell when it moves around', () {
      final advice = run(
        weakCellCounts: {1: 30, 2: 28, 3: 31, 4: 29, 5: 30},
      );
      expect(has(advice, AdviceCode.weakCellDominant), isFalse);
    });

    test('says nothing about a weak cell on too few readings', () {
      final advice = run(weakCellCounts: {7: 9});
      expect(has(advice, AdviceCode.weakCellDominant), isFalse);
    });

    test('flags a cycle counter that reads high', () {
      final advice = run(
        snapshot: snap(cycles: 200, cycleCapacityAh: 2025),
      );
      expect(has(advice, AdviceCode.cycleCounterInflated), isTrue);
    });

    test('flags a health figure stuck at a hundred', () {
      final advice = run(snapshot: snap(soh: 100));
      expect(has(advice, AdviceCode.healthFigureDecorative), isTrue);
    });

    test('mentions capacity below the label without calling it a fault', () {
      // 25 Ah remaining at 78% implies about 32 Ah against a 45 Ah label.
      //
      // This used to be raised as a problem, which told riders of a perfectly
      // healthy pack that it was failing. It cannot tell a battery that has
      // degraded from one that was never the advertised size, and with a
      // number printed on a box the second is far more common.
      final advice = run(snapshot: snap(remainingAh: 25, soc: 78));
      final item =
          advice.firstWhere((a) => a.code == AdviceCode.capacityBelowCatalogue);
      expect(item.level, AdviceLevel.info);
    });

    test('drops it once real degradation can be measured', () {
      // By then the honest figure exists, measured against what this battery
      // actually delivered, and comparing to the advert adds nothing.
      final advice = run(
        snapshot: snap(remainingAh: 25, soc: 78),
        degradationMeasurable: true,
      );
      expect(has(advice, AdviceCode.capacityBelowCatalogue), isFalse);
    });

    test('nags about a capacity test only until one is done', () {
      expect(
        has(run(capacityTestCount: 0), AdviceCode.noCapacityTestYet),
        isTrue,
      );
      expect(
        has(run(capacityTestCount: 1), AdviceCode.noCapacityTestYet),
        isFalse,
      );
    });

    test('flags heat, and escalates when it is serious', () {
      final warm = run(snapshot: snap(temperatures: const [48, 46]));
      expect(
        warm.firstWhere((a) => a.code == AdviceCode.runningHot).level,
        AdviceLevel.watch,
      );

      final hot = run(snapshot: snap(temperatures: const [58, 56]));
      expect(
        hot.firstWhere((a) => a.code == AdviceCode.runningHot).level,
        AdviceLevel.problem,
      );
    });

    test('flags a balancer that has never run and cannot', () {
      final cells = List.filled(20, 3.90);
      cells[6] = 3.84;
      final advice = run(
        snapshot: snap(cells: cells),
        // Start voltage sits above where these cells ever get.
        config: settings(balanceStart: 4.0),
        balancerEverSeen: false,
      );
      expect(has(advice, AdviceCode.balancerNeverSeen), isTrue);
    });

    test('says nothing about the balancer once it has been seen working', () {
      final cells = List.filled(20, 3.90);
      cells[6] = 3.84;
      final advice = run(
        snapshot: snap(cells: cells),
        config: settings(balanceStart: 4.0),
        balancerEverSeen: true,
      );
      expect(has(advice, AdviceCode.balancerNeverSeen), isFalse);
    });

    test('flags an overvoltage limit set high for NMC', () {
      expect(
        has(run(config: settings(cellOvp: 4.3)),
            AdviceCode.overvoltageSetHigh),
        isTrue,
      );
      expect(
        has(run(config: settings(cellOvp: 4.2)),
            AdviceCode.overvoltageSetHigh),
        isFalse,
      );
    });

    test('admits the range figure is young', () {
      final advice = run(estimator: RangeEstimator());
      expect(has(advice, AdviceCode.rangeStillLearning), isTrue);
    });

    test('prices the imbalance in range', () {
      final advice = run(usableWh: 2000, grossWh: 2800);
      expect(has(advice, AdviceCode.imbalanceCostingRange), isTrue);
    });

    test('says nothing about stranded energy on a balanced pack', () {
      final advice = run(usableWh: 2750, grossWh: 2800);
      expect(has(advice, AdviceCode.imbalanceCostingRange), isFalse);
    });

    test('puts the loudest advice first', () {
      final advice = run(
        snapshot: snap(temperatures: const [58, 56], soh: 100),
        capacityTestCount: 0,
        restingDelta: 0.090,
      );
      expect(advice.first.level, AdviceLevel.problem);
      expect(advice.last.level, AdviceLevel.info);
    });
  });
}
