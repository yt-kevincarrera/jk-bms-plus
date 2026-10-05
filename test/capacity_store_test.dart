import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/metrics/capacity_cycle_detector.dart';
import 'package:jk_bms/src/metrics/capacity_endpoints.dart';

void main() {
  late AppDatabase db;
  late BmsRepository repo;
  final t0 = DateTime.utc(2026, 9, 1, 8);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = BmsRepository(database: db, flushInterval: const Duration(days: 1));
  });

  tearDown(() async => db.close());

  DetectedCycle cycle(double ah) => DetectedCycle(
    startedAt: t0,
    endedAt: t0.add(const Duration(hours: 2)),
    startSoc: 100,
    endSoc: 0,
    startPackVoltage: 83,
    endPackVoltage: 61,
    measuredAh: ah,
    measuredWh: ah * 72,
    gapSeconds: 0,
  );

  Future<int> storedRun({required bool automatic}) => db.insertCapacityTest(
    CapacityTestsCompanion.insert(
      startedAt: t0.add(const Duration(seconds: 30)),
      endedAt: Value(t0.add(const Duration(hours: 2))),
      startSoc: 97,
      endSoc: 3,
      startPackVoltage: 83,
      endPackVoltage: 64,
      measuredAh: 37.6,
      measuredWh: 2700,
      completed: const Value(true),
      automatic: Value(automatic),
      endReason: const Value('legacy'),
      deviceId: const Value('JK:01'),
    ),
  );

  test('a detected cycle is recorded with what closed it', () async {
    expect(await repo.recordDetectedCycle('JK:01', cycle(43), 45), isTrue);
    final stored = (await repo.capacityTests('JK:01')).single;
    expect(stored.endReason, CapacityEndReason.cellCutoff.name);
    expect(stored.isTrustworthy, isTrue);
    // And a rescan of the same discharge adds nothing.
    expect(await repo.recordDetectedCycle('JK:01', cycle(43), 45), isFalse);
  });

  test('an old detection is re-measured from its readings', () async {
    // The old detector's 97 % to 3 % count, 0.94 of a 40 Ah setting. The
    // same discharge scanned with the cells as the endpoints replaces it,
    // rather than being refused as a duplicate and leaving it standing.
    await storedRun(automatic: true);
    expect(await repo.recordDetectedCycle('JK:01', cycle(43), 45), isTrue);
    final stored = (await repo.capacityTests('JK:01')).single;
    expect(stored.measuredAh, 43);
    expect(stored.endReason, CapacityEndReason.cellCutoff.name);
  });

  test('a run somebody stood over is never rewritten', () async {
    await storedRun(automatic: false);
    expect(await repo.recordDetectedCycle('JK:01', cycle(43), 45), isFalse);
    final stored = (await repo.capacityTests('JK:01')).single;
    expect(stored.measuredAh, 37.6);
  });

  test('a manual run is filed under the pack it was run on', () async {
    repo.activeDeviceId = 'JK:01';
    await repo.beginCapacityTest(
      startedAt: t0,
      startSoc: 100,
      startPackVoltage: 83,
      catalogueAh: 45,
    );
    // Found again, which is what resuming it after a restart needs.
    expect(await repo.unfinishedCapacityTest('JK:01'), isNotNull);
    expect((await db.orphanCounts())['capacityTests'], 0);
  });

  test('a finished manual run keeps its gap, its charge and its reason', () async {
    repo.activeDeviceId = 'JK:01';
    final id = await repo.beginCapacityTest(
      startedAt: t0,
      startSoc: 100,
      startPackVoltage: 83,
      catalogueAh: 45,
    );
    await repo.finishCapacityTest(
      id,
      endedAt: t0.add(const Duration(hours: 3)),
      endSoc: 20,
      endPackVoltage: 70,
      measuredAh: 30,
      measuredWh: 2200,
      endReason: CapacityEndReason.stoppedEarly,
      gapSeconds: 900,
      chargedDuringRun: true,
    );
    final stored = (await repo.capacityTests('JK:01')).single;
    expect(stored.gapSeconds, 900);
    expect(stored.chargedDuringRun, isTrue);
    expect(stored.endReason, 'stoppedEarly');
    expect(stored.isTrustworthy, isFalse);
  });
}
