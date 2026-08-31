import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final now = DateTime.utc(2026, 1, 1);
    for (final id in ['AA:BB', 'CC:DD']) {
      await db.upsertDevice(
        DevicesCompanion.insert(id: id, firstSeenAt: now, lastSeenAt: now),
      );
    }
  });

  tearDown(() async => db.close());

  /// [count] readings a second apart, starting [daysAgo] days back.
  Future<void> seed({
    required String deviceId,
    required int daysAgo,
    required int count,
    Duration step = const Duration(seconds: 1),
    double soc = 80,
  }) async {
    final start = DateTime.now().toUtc().subtract(Duration(days: daysAgo));
    await db.insertSnapshots([
      for (var i = 0; i < count; i++)
        SnapshotsCompanion.insert(
          deviceId: Value(deviceId),
          timestamp: start.add(step * i),
          packVoltage: 78,
          current: -10,
          soc: soc,
          soh: 97,
          remainingAh: 30,
          cycleCount: 60,
          cycleCapacityAh: const Value(2000),
          deltaVolts: 0.01,
          minCellVoltage: 3.89,
          maxCellVoltage: 3.9,
          maxTemperature: 25,
          warningsMask: 0,
          balancerActive: false,
          cellVoltagesJson: '[3.9]',
        ),
    ]);
  }

  group('thinning old readings', () {
    test('keeps one per minute once they are past the window', () async {
      // Ten minutes of 1 Hz readings from six months ago: 600 rows in, about
      // ten out. Buckets are absolute minutes rather than relative to the
      // data, so ten minutes of readings can straddle eleven of them.
      await seed(deviceId: 'AA:BB', daysAgo: 180, count: 600);
      expect(await db.snapshotCountFor('AA:BB'), 600);

      await db.compactSnapshots();

      final kept = await db.snapshotCountFor('AA:BB');
      expect(kept, greaterThanOrEqualTo(10));
      expect(kept, lessThanOrEqualTo(11));
    });

    test('leaves recent readings at full resolution', () async {
      // The last month is what the live screens and a running capacity test
      // read, and thinning it would blunt both.
      await seed(deviceId: 'AA:BB', daysAgo: 2, count: 600);
      await db.compactSnapshots();
      expect(await db.snapshotCountFor('AA:BB'), 600);
    });

    test('what survives is a reading that really happened', () async {
      // An averaged row would be a measurement nobody took, sitting in the
      // same table as real ones.
      await seed(deviceId: 'AA:BB', daysAgo: 180, count: 120, soc: 63);
      await db.compactSnapshots();

      final kept = await db.allSnapshotsForBackup();
      expect(kept, isNotEmpty);
      expect(kept.every((s) => s.soc == 63), isTrue);
    });

    test('two packs read in the same minute both survive', () async {
      // Grouping by bucket alone would collapse them into one.
      await seed(deviceId: 'AA:BB', daysAgo: 180, count: 120);
      await seed(deviceId: 'CC:DD', daysAgo: 180, count: 120);

      await db.compactSnapshots();

      // The point is that neither pack was thinned away by the other, not the
      // exact bucket count.
      final a = await db.snapshotCountFor('AA:BB');
      final b = await db.snapshotCountFor('CC:DD');
      expect(a, b);
      expect(a, greaterThanOrEqualTo(2));
      expect(a, lessThan(120));
    });

    test('running it twice changes nothing the second time', () async {
      await seed(deviceId: 'AA:BB', daysAgo: 180, count: 600);
      await db.compactSnapshots();
      final after = await db.snapshotCountFor('AA:BB');

      await db.compactSnapshots();
      expect(await db.snapshotCountFor('AA:BB'), after);
    });

    test('an empty table is not a problem', () async {
      expect(await db.compactSnapshots(), 0);
    });

    test('the span of the history is preserved', () async {
      // Thinning must not eat the oldest reading: the offline summary reports
      // how far back the history goes from exactly that row.
      await seed(deviceId: 'AA:BB', daysAgo: 180, count: 600);
      final firstBefore = await db.firstSnapshotAt('AA:BB');

      await db.compactSnapshots();
      final firstAfter = await db.firstSnapshotAt('AA:BB');

      // Within one bucket of where it was, and still roughly six months back.
      expect(
        firstAfter!.difference(firstBefore!).inSeconds.abs(),
        lessThanOrEqualTo(60),
      );
    });
  });

  group('asking about a pack without reading its history', () {
    test('counts without loading', () async {
      await seed(deviceId: 'AA:BB', daysAgo: 1, count: 50);
      await seed(deviceId: 'CC:DD', daysAgo: 1, count: 7);
      expect(await db.snapshotCountFor('AA:BB'), 50);
      expect(await db.snapshotCountFor('CC:DD'), 7);
    });

    test('finds the newest and oldest', () async {
      await seed(deviceId: 'AA:BB', daysAgo: 3, count: 10);
      final first = await db.firstSnapshotAt('AA:BB');
      final last = await db.lastSnapshotFor('AA:BB');
      expect(first!.isBefore(last!.timestamp), isTrue);
    });

    test('says nothing for a pack with no readings', () async {
      expect(await db.snapshotCountFor('CC:DD'), 0);
      expect(await db.firstSnapshotAt('CC:DD'), isNull);
      expect(await db.lastSnapshotFor('CC:DD'), isNull);
    });
  });
}
