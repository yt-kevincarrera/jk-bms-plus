import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/metrics/pack_summary.dart';
import 'package:jk_bms/src/metrics/range_estimator.dart';

void main() {
  final at = DateTime.utc(2026, 10, 21, 12);
  final estimator = RangeEstimator(learnedWhPerKm: 20, learnedKm: 60);

  Device device({
    double catalogue = 45,
    bool fromBms = false,
    String chemistry = 'nmc',
  }) => Device(
    id: 'AA:BB',
    name: 'KevinJK',
    serialNumber: '',
    model: '',
    catalogueCapacityAh: catalogue,
    catalogueFromBms: fromBms,
    chemistry: chemistry,
    firstSeenAt: at,
    lastSeenAt: at,
    demo: false,
  );

  Snapshot reading({
    required DateTime time,
    double soc = 100,
    double remainingAh = 40,
    String deviceId = 'AA:BB',
    double cell = 4.18,
  }) => Snapshot(
    id: 1,
    deviceId: deviceId,
    timestamp: time,
    packVoltage: cell * 20,
    current: 0,
    soc: soc,
    remainingAh: remainingAh,
    cycleCapacityAh: 2000,
    deltaVolts: 0,
    minCellVoltage: cell,
    maxCellVoltage: cell,
    warningsMask: 0,
    balancerActive: false,
    cellVoltagesJson: encodeCellVoltages(List.filled(20, cell)),
  );

  CapacityTest measurement(double ah, {int gapSeconds = 0}) => CapacityTest(
    id: 1,
    deviceId: 'AA:BB',
    startedAt: at.subtract(const Duration(days: 3)),
    endedAt: at.subtract(const Duration(days: 2)),
    startSoc: 100,
    endSoc: 3,
    startPackVoltage: 84,
    endPackVoltage: 60,
    measuredAh: ah,
    measuredWh: ah * 72,
    completed: true,
    automatic: false,
    gapSeconds: gapSeconds,
    endReason: 'cellCutoff',
    chargedDuringRun: false,
    note: '',
  );

  Trip trip() => Trip(
    id: 1,
    deviceId: 'AA:BB',
    startedAt: at.subtract(const Duration(days: 1)),
    endedAt: at.subtract(const Duration(hours: 23)),
    distanceKm: 10,
    movingSeconds: 1800,
    totalSeconds: 1800,
    maxSpeedKmh: 40,
    energyOutWh: 200,
    energyInWh: 0,
    startSoc: 90,
    endSoc: 70,
    minPackVoltage: 70,
    maxPackVoltage: 82,
    maxDischargeCurrent: 30,
    maxDeltaVolts: 0.01,
    climbM: 0,
    descentM: 0,
    note: '',
    demo: false,
    summarySeen: true,
  );

  final history = [
    reading(
      time: at.subtract(const Duration(hours: 2)),
      soc: 60,
      remainingAh: 24,
    ),
    reading(time: at),
  ];

  test('a full saved reading recovers the recent BMS scale, not the advert', () {
    final pack = device();
    expect(
      PackSummary.configuredCapacityFromHistory(
        device: pack,
        readings: history,
      ),
      40,
    );
    final range = PackSummary.rangeOutlookFrom(
      device: pack,
      readings: history,
      estimator: estimator,
    );
    expect(range.fullFromBmsConfig, isTrue);
    expect(range.fullFromMeasuredCapacity, isFalse);
    expect(range.nowKm, closeTo(149.28, 1e-9));
    expect(range.fullKm, closeTo(range.nowKm!, 1e-9));
    final summary = PackSummary.from(
      device: pack,
      readings: history,
      trips: [trip()],
      tests: [],
    );
    expect(summary.rangeKm, closeTo(range.fullKm!, 1e-9));
    expect(
      summary.impliedCapacityAh,
      isNull,
      reason:
          'range calibration does not change the health/cycle capacity calculation',
    );
  });

  test('a trustworthy measurement wins in both saved-pack and comparison', () {
    final pack = device();
    final range = PackSummary.rangeOutlookFrom(
      device: pack,
      readings: history,
      estimator: estimator,
      measuredCapacityAh: 38,
    );
    final summary = PackSummary.from(
      device: pack,
      readings: history,
      trips: [trip()],
      tests: [measurement(38), measurement(44, gapSeconds: 1000)],
    );
    expect(range.fullFromMeasuredCapacity, isTrue);
    expect(range.fullFromBmsConfig, isFalse);
    expect(range.nowKm, closeTo(range.fullKm!, 1e-9));
    expect(summary.bestMeasuredAh, 38);
    expect(summary.rangeKm, closeTo(141.816, 1e-9));
    expect(summary.rangeKm, closeTo(range.fullKm!, 1e-9));
  });

  test('a capacity explicitly borrowed from the BMS remains a BMS source', () {
    final range = PackSummary.rangeOutlookFrom(
      device: device(catalogue: 40, fromBms: true),
      readings: [history.last],
      estimator: estimator,
    );
    expect(range.fullFromBmsConfig, isTrue);
    expect(range.nowKm, closeTo(range.fullKm!, 1e-9));
  });

  test(
    'without nominal evidence the sales claim is only a labelled fallback',
    () {
      final pack = device();
      expect(
        PackSummary.configuredCapacityFromHistory(
          device: pack,
          readings: [history.last],
        ),
        isNull,
      );
      final range = PackSummary.rangeOutlookFrom(
        device: pack,
        readings: [history.last],
        estimator: estimator,
      );
      expect(range.fullFromBmsConfig, isFalse);
      expect(range.fullFromMeasuredCapacity, isFalse);
      expect(range.fullKm, closeTo(167.94, 1e-9));
      expect(range.nowKm, lessThan(149.28));
    },
  );

  test(
    'old or another pack\'s counter cannot masquerade as recent nominal',
    () {
      for (final evidence in [
        reading(
          time: at.subtract(const Duration(days: 2)),
          soc: 60,
          remainingAh: 24,
        ),
        reading(
          time: at.subtract(const Duration(minutes: 1)),
          deviceId: 'OTHER',
          soc: 60,
          remainingAh: 24,
        ),
      ]) {
        final readings = [evidence, history.last];
        final range = PackSummary.rangeOutlookFrom(
          device: device(),
          readings: readings,
          estimator: estimator,
        );
        expect(range.fullFromBmsConfig, isFalse);
        expect(range.fullKm, closeTo(167.94, 1e-9));
      }
    },
  );

  test(
    'a useful last reading still supplies nominal outside the loaded window',
    () {
      final latest = reading(time: at, soc: 60, remainingAh: 24);
      expect(
        PackSummary.configuredCapacityFromHistory(
          device: device(),
          readings: [],
          latestReading: latest,
        ),
        40,
      );
    },
  );

  test(
    'unknown chemistry explains the missing full prediction offline too',
    () {
      final pack = device(catalogue: 40, fromBms: true, chemistry: 'unknown');
      final readings = [reading(time: at, cell: 3.4)];
      final range = PackSummary.rangeOutlookFrom(
        device: pack,
        readings: readings,
        estimator: estimator,
      );
      final summary = PackSummary.from(
        device: pack,
        readings: readings,
        trips: [trip()],
        tests: [],
      );
      expect(range.nowKm, isNotNull);
      expect(range.fullKm, isNull);
      expect(range.fullNeedsChemistry, isTrue);
      expect(summary.rangeKm, isNull);
    },
  );
}
