import 'package:jk_bms/src/model/bms_snapshot.dart';
import 'package:jk_bms/src/model/bms_warning.dart';
import 'package:jk_bms/src/protocol/protocol_variant.dart';

/// A plausible reading, with only the parts a test cares about spelled out.
BmsSnapshot buildSnapshot({
  List<double>? cells,
  double soc = 78,
  double remainingAh = 35.1,
  List<double> temperatures = const [25, 24],
  double? mosfetTemp = 28,
  int cycles = 63,
  double cycleCapacityAh = 2843.5,
  double soh = 97,
  double current = -20,
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
    current: current,
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
