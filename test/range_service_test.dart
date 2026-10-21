import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/simulator/jk_frame_builder.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';

import 'support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late BmsRepository repo;
  late FakeLink link;
  late BmsService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = BmsRepository(database: db);
    link = FakeLink();
    service = BmsService(transport: link)..repository = repo;
  });
  tearDown(() async {
    await service.dispose();
    await repo.dispose();
    await db.close();
  });

  Future<void> fullPack({
    double cellVolts = 4.18,
    String chemistry = 'nmc',
  }) async {
    await service.connect('range-pack');
    await link.deliver(
      const JkFrameBuilder().cellInfo(
        counter: 1,
        cellVoltages: List.filled(20, cellVolts),
        cellResistances: List.filled(20, .002),
        packVoltage: cellVolts * 20,
        current: 0,
        temperatures: [25, 25],
        mosfetTemp: 25,
        soc: 100,
        soh: 100,
        remainingCapacityAh: 40,
        nominalCapacityAh: 40,
        cycleCount: 100,
        cycleCapacityAh: 4000,
        balancingAction: 0,
        balanceCurrent: 0,
        chargeMosfetOn: true,
        dischargeMosfetOn: true,
        errorBitmask: 0,
        totalRuntimeSeconds: 1000,
      ),
    );
    await repo.setDeviceCatalogue('range-pack', 45);
    await repo.setPackProfile('range-pack', chemistry: chemistry);
    await service.refreshActiveDevice();
    service.rangeEstimator.addSegment(wh: 1200, km: 60);
  }

  test(
    'the home ranges share the BMS capacity despite a larger sales claim',
    () async {
      await fullPack();
      final outlook = service.rangeOutlook;
      expect(outlook.nowKm, closeTo(149.28, .001));
      expect(outlook.fullKm, closeTo(outlook.nowKm!, .001));
      expect(outlook.fullFromBmsConfig, isTrue);
      expect(outlook.fullFromMeasuredCapacity, isFalse);
      expect(
        service.catalogueCapacityAh,
        45,
        reason: 'the advertised capacity remains recorded as entered',
      );
    },
  );

  test(
    'a measured capacity calibrates both ranges without rewriting raw energy',
    () async {
      await fullPack();
      service.bestMeasuredCapacityAh = 38;
      final outlook = service.rangeOutlook;
      expect(outlook.nowKm, closeTo(141.816, .001));
      expect(outlook.fullKm, closeTo(outlook.nowKm!, .001));
      expect(outlook.fullFromMeasuredCapacity, isTrue);
      expect(outlook.fullFromBmsConfig, isFalse);
      expect(
        service.energyOf(service.lastSnapshot!).usableWh,
        closeTo(2985.6, .001),
      );
    },
  );

  test(
    'unknown chemistry explains why no full range can be compared',
    () async {
      await fullPack(cellVolts: 3.4, chemistry: '');
      final outlook = service.rangeOutlook;
      expect(outlook.nowKm, isNotNull);
      expect(outlook.fullKm, isNull);
      expect(outlook.fullNeedsChemistry, isTrue);
    },
  );
}
