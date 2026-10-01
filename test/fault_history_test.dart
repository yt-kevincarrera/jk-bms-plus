import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/model/bms_warning.dart';

import 'support/stored_readings.dart';

/// The warning mask has been stored with every reading since the first
/// version, and only the backup and the CSV ever read it.
void main() {
  late AppDatabase db;
  late BmsRepository repo;
  final t0 = DateTime.utc(2026, 9, 20, 10);
  final uvp = 1 << BmsWarning.cellUndervoltage.bit;
  final ocp = 1 << BmsWarning.dischargeOvercurrent.bit;
  final full = 1 << BmsWarning.batteryFullyCharged.bit;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = BmsRepository(database: db);
  });

  tearDown(() async {
    await repo.dispose();
    await db.close();
  });

  /// Readings every [step] from [from] for [count], all with [mask].
  List<SnapshotsCompanion> run(
    DateTime from,
    int count,
    int mask, {
    Duration step = const Duration(seconds: 1),
    double current = -30,
    String device = 'A',
  }) => [
    for (var i = 0; i < count; i++)
      storedReading(
        deviceId: device,
        at: from.add(step * i),
        cells: cellsAt(3.40, {7: -0.200}),
        current: current,
        soc: 12,
        warningsMask: mask,
      ),
  ];

  test(
    'one episode per stretch, with its readings, length and context',
    () async {
      await db.insertSnapshots([
        ...run(t0, 10, 0),
        ...run(t0.add(const Duration(seconds: 10)), 5, uvp),
        ...run(t0.add(const Duration(seconds: 15)), 10, 0),
      ]);
      final eps = await repo.faultHistory('A');
      expect(eps, hasLength(1));
      final e = eps.single;
      expect(e.warning, BmsWarning.cellUndervoltage);
      expect(e.start, t0.add(const Duration(seconds: 10)));
      expect(e.end, t0.add(const Duration(seconds: 14)));
      expect(e.readings, 5);
      expect(e.duration, const Duration(seconds: 4));
      expect(e.ongoing, isFalse);
      expect(e.unobservedGap, isFalse);
      expect(e.current, -30);
      expect(e.soc, 12);
      expect(e.minCellVoltage, closeTo(3.2, 1e-9));
      expect(e.maxCellVoltage, closeTo(3.4, 1e-9));
    },
  );

  test('a flicker inside half a minute is one episode', () async {
    await db.insertSnapshots([
      ...run(t0, 3, uvp),
      ...run(t0.add(const Duration(seconds: 3)), 20, 0),
      ...run(t0.add(const Duration(seconds: 23)), 3, uvp),
      // And then away for a minute: a second episode.
      ...run(t0.add(const Duration(seconds: 26)), 60, 0),
      ...run(t0.add(const Duration(seconds: 86)), 2, uvp),
      ...run(t0.add(const Duration(seconds: 88)), 2, 0),
    ]);
    final eps = await repo.faultHistory('A');
    expect(eps, hasLength(2));
    // Newest first.
    expect(eps.first.start, t0.add(const Duration(seconds: 86)));
    expect(eps.last.start, t0);
    expect(eps.last.end, t0.add(const Duration(seconds: 25)));
    expect(eps.last.readings, 6);
  });

  test('a link gap ends nothing, and a long one is marked', () async {
    await db.insertSnapshots([
      ...run(t0, 5, ocp),
      // Ten minutes of nothing, then the same fault still there.
      ...run(t0.add(const Duration(minutes: 10)), 5, ocp),
      ...run(t0.add(const Duration(minutes: 11)), 5, 0),
    ]);
    final eps = await repo.faultHistory('A');
    expect(eps, hasLength(1));
    expect(eps.single.readings, 10);
    expect(eps.single.unobservedGap, isTrue);
    expect(eps.single.end, t0.add(const Duration(minutes: 10, seconds: 4)));
  });

  test('a short gap is not marked', () async {
    await db.insertSnapshots([
      ...run(t0, 5, ocp),
      ...run(t0.add(const Duration(minutes: 2)), 5, ocp),
      ...run(t0.add(const Duration(minutes: 3)), 5, 0),
    ]);
    final eps = await repo.faultHistory('A');
    expect(eps.single.unobservedGap, isFalse);
  });

  test('two bits at once are two episodes, each its own length', () async {
    await db.insertSnapshots([
      ...run(t0, 4, uvp | ocp),
      ...run(t0.add(const Duration(seconds: 4)), 4, uvp),
      ...run(t0.add(const Duration(seconds: 8)), 4, 0),
    ]);
    final eps = await repo.faultHistory('A');
    final byBit = {for (final e in eps) e.warning: e};
    expect(byBit[BmsWarning.dischargeOvercurrent]!.readings, 4);
    expect(byBit[BmsWarning.cellUndervoltage]!.readings, 8);
  });

  test(
    'a fault still held in the newest reading is said to be ongoing',
    () async {
      await db.insertSnapshots([
        ...run(t0, 3, 0),
        ...run(t0.add(const Duration(seconds: 3)), 7, ocp),
      ]);
      final e = (await repo.faultHistory('A')).single;
      expect(e.ongoing, isTrue);
      expect(e.readings, 7);
      expect(e.end, t0.add(const Duration(seconds: 9)));
    },
  );

  test(
    '"fully charged" is not a fault, and another pack is not this one',
    () async {
      await db.insertSnapshots([
        ...run(t0, 5, full),
        ...run(t0, 5, uvp, device: 'B'),
      ]);
      expect(await repo.faultHistory('A'), isEmpty);
      expect(await repo.faultHistory('B'), hasLength(1));
    },
  );

  test('a bit the reference has no name for is kept, by number', () async {
    await db.insertSnapshots([
      ...run(t0, 2, 1 << 30),
      ...run(t0.add(const Duration(seconds: 2)), 2, 0),
    ]);
    final e = (await repo.faultHistory('A')).single;
    expect(e.bit, 30);
    expect(e.warning, isNull);
  });
}
