import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/model/bms_snapshot.dart';
import 'package:jk_bms/src/model/bms_warning.dart';
import 'package:jk_bms/src/protocol/bms_brand.dart';
import 'package:jk_bms/src/protocol/variant_prober.dart';

BmsSnapshot antLike() => BmsSnapshot(
      timestamp: DateTime.utc(2026, 9, 28),
      brand: BmsBrand.ant,
      variant: null,
      frameCounter: null,
      cellVoltages: List.filled(16, 3.3),
      cellResistances: null,
      enabledCellMask: null,
      packVoltage: 52.8,
      current: 0.3,
      temperatures: const [20, 21],
      temperatureSensorMask: null,
      mosfetTemp: 22,
      soc: 91,
      soh: 100,
      remainingCapacityAh: 250,
      nominalCapacityAh: 280,
      cycleCount: null,
      cycleCapacityAh: 4862,
      balancingAction: null,
      balanceCurrent: null,
      chargeMosfetOn: true,
      dischargeMosfetOn: true,
      balancerActive: false,
      heatingOn: null,
      warnings: BmsWarnings.none,
      wireResistanceWarningMask: null,
      heatingCurrent: null,
      totalRuntimeSeconds: 100,
    );

void main() {
  test('an ANT reading carries its brand and no JK-only fields', () {
    final j = antLike().toJson();
    expect(j['brand'], 'ant');
    expect(j['variant'], isNull);
    expect(j['cellResistances'], isNull);
    expect(j['cycleCount'], isNull);
  });

  test('plausibility judges a reading with no JK variant', () {
    expect(const Plausibility().reject(antLike()), isEmpty);
  });

  test('balancing inference works without a balancing action', () {
    expect(antLike().inferredBalancingCells, List.filled(16, false));
  });
}
