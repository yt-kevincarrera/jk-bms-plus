import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/inspection/inspection_result.dart';

/// A stored run, as small as the table will take.
InspectionsCompanion row({
  required DateTime at,
  String bmsId = 'AA:BB',
  String serial = 'SN-1',
  int weakCell = 7,
  double weakSag = 0.30,
  String light = 'problem',
}) {
  final result = InspectionResult(
    at: at,
    cells: [
      for (var i = 1; i <= 4; i++)
        CellInspection(
          index: i,
          restVolts: 3.9,
          heavySagVolts: i == weakCell ? weakSag : 0.08,
          recovered: true,
        ),
    ],
    restDeltaVolts: 0.015,
    restCurrentAmps: 0.2,
    peakDischargeAmps: 38,
    currentStepAmps: 37,
    medianHeavySagVolts: 0.08,
    faultsSeen: const [],
    caveats: const [],
    reported: ReportedFigures(
      model: 'JK',
      serialNumber: serial,
      softwareVersion: '11.26',
    ),
    durationSeconds: 90,
    readings: 120,
  );
  return InspectionsCompanion.insert(
    at: at,
    bmsId: bmsId,
    serialNumber: Value(serial),
    light: light,
    resultJson: jsonEncode(result.toJson()),
    samplesJson: '[]',
  );
}

void main() {
  late AppDatabase db;
  late BmsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = BmsRepository(database: db, flushInterval: const Duration(days: 1));
  });

  tearDown(() async {
    await repo.dispose();
  });

  final april = DateTime.utc(2026, 4, 1);
  final may = DateTime.utc(2026, 5, 1);
  final june = DateTime.utc(2026, 6, 1);

  test('the runs on one pack come back oldest first', () async {
    await db.insertInspection(row(at: may));
    await db.insertInspection(row(at: april));
    await db.insertInspection(row(at: june));
    await db.insertInspection(row(at: may, bmsId: 'CC:DD', serial: 'OTHER'));

    final mine = await repo.pastInspections(bmsId: 'AA:BB');
    // Drift hands dates back in local time; the instant is what matters.
    expect(mine.map((p) => p.at.toUtc()), [april, may, june]);
    expect(mine.first.result.cells, hasLength(4));
  });

  test('the same pack on a new address is found by its serial', () async {
    await db.insertInspection(row(at: april, bmsId: 'OLD', serial: 'SN-9'));

    final byAddress = await repo.pastInspections(bmsId: 'NEW');
    expect(byAddress, isEmpty);

    final bySerial = await repo.pastInspections(
      bmsId: 'NEW',
      serialNumber: 'SN-9',
    );
    expect(bySerial, hasLength(1));
  });

  test('an empty serial does not merge two anonymous packs', () async {
    await db.insertInspection(row(at: april, bmsId: 'AA:BB', serial: ''));
    await db.insertInspection(row(at: may, bmsId: 'CC:DD', serial: ''));

    final mine = await repo.pastInspections(bmsId: 'AA:BB', serialNumber: '');
    expect(mine, hasLength(1));
    expect(mine.single.at.toUtc(), april);
  });

  test('rereading a saved run only sees what came before it', () async {
    await db.insertInspection(row(at: april));
    final mayId = await db.insertInspection(row(at: may));
    await db.insertInspection(row(at: june));

    final asOfMay = await repo.pastInspections(
      bmsId: 'AA:BB',
      before: may,
      excludeId: mayId,
    );
    expect(asOfMay.map((p) => p.at.toUtc()), [april]);
  });

  test('a row nothing can read is skipped rather than fatal', () async {
    await db.insertInspection(row(at: april));
    await db.insertInspection(
      InspectionsCompanion.insert(
        at: may,
        bmsId: 'AA:BB',
        light: 'watch',
        resultJson: 'not json at all',
        samplesJson: '[]',
      ),
    );

    final mine = await repo.pastInspections(bmsId: 'AA:BB');
    expect(mine.map((p) => p.at.toUtc()), [april]);
  });

  test('the counts say which packs have been looked at before', () async {
    await db.insertInspection(row(at: april));
    await db.insertInspection(row(at: may));
    await db.insertInspection(row(at: june, bmsId: 'CC:DD', serial: 'OTHER'));

    final counts = await repo.inspectionCountsByPack();
    expect(counts['AA:BB'], 2);
    expect(counts['CC:DD'], 1);
    expect(counts['EE:FF'], isNull);
  });
}
