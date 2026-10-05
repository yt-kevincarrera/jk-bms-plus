import 'package:drift/drift.dart' show Value;
import 'package:jk_bms/src/data/database.dart';

/// One stored reading, with only the parts a history test cares about.
///
/// Delta, min and max are worked out from [cells], so a row cannot disagree
/// with its own cell list.
SnapshotsCompanion storedReading({
  required String deviceId,
  required DateTime at,
  required List<double> cells,
  double current = 0,
  double soc = 60,
  int warningsMask = 0,
  int? tripId,
}) {
  final low = cells.reduce((a, b) => a < b ? a : b);
  final high = cells.reduce((a, b) => a > b ? a : b);
  return SnapshotsCompanion.insert(
    timestamp: at,
    tripId: Value(tripId),
    deviceId: Value(deviceId),
    packVoltage: cells.reduce((a, b) => a + b),
    current: current,
    soc: soc,
    soh: const Value(100.0),
    remainingAh: 24,
    deltaVolts: high - low,
    minCellVoltage: low,
    maxCellVoltage: high,
    warningsMask: warningsMask,
    balancerActive: false,
    cellVoltagesJson: encodeCellVoltages(cells),
  );
}

/// Twenty cells at [level], with the given ones moved by the given volts.
List<double> cellsAt(double level, [Map<int, double> offsets = const {}]) => [
  for (var i = 1; i <= 20; i++) level + (offsets[i] ?? 0),
];
