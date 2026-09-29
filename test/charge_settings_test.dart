import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/metrics/charge_session.dart';

import 'fixtures/captured_frames.dart';
import 'support/fakes.dart';

void main() {
  group("the rider's thresholds reach the charge alerts", () {
    final service = BmsService(transport: FakeLink());

    void apply({double? temp, double? delta}) => service.applySettings(
      haptics: false,
      rawFrames: false,
      alertTempWarn: temp,
      alertDeltaWarn: delta,
    );

    test('lower brings the charging alert earlier', () {
      apply(temp: 40, delta: 0.030);
      expect(service.chargeAlerts.hotWarn, 40);
      expect(service.chargeAlerts.spreadWarn, 0.030);
    });

    test('a low-charge threshold saved under the critical level is lifted', () {
      // The slider used to reach 5, where low charge can never trip.
      service.applySettings(
        haptics: false,
        rawFrames: false,
        alertLowChargeWarn: 5,
      );
      expect(service.alerts.lowChargeWarn, 8);
    });

    test('higher never takes charging past its own limits', () {
      // They used to be fixed whatever the sliders said; they must not now
      // follow a rider who raised the riding threshold into charging hot.
      apply(temp: 60, delta: 0.150);
      expect(service.chargeAlerts.hotWarn, 45);
      expect(service.chargeAlerts.spreadWarn, 0.060);
    });
  });

  group('the last charge', () {
    late FakeLink link;
    late AppDatabase db;
    late BmsRepository repo;
    late BmsService service;

    setUp(() async {
      link = FakeLink();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = BmsRepository(database: db);
      service = BmsService(transport: link, locationFactory: StubLocation.new)
        ..repository = repo;
      await service.connect('AA:BB', name: 'KevinJK');
      await link.deliver(deviceInfoFrames[1]);
      await link.deliver(cellInfo24s[0]);
      await pumpEventQueue();
    });

    tearDown(() async {
      await service.dispose();
      await repo.dispose();
      await db.close();
    });

    test('is read back from the pack after a restart', () async {
      // Memory only, it was gone after a restart and the card said no charge
      // had ever been recorded.
      final report = ChargeReport(
        startedAt: DateTime.utc(2026, 9, 1, 22),
        endedAt: DateTime.utc(2026, 9, 2, 2),
        startSoc: 30,
        endSoc: 100,
        ahIn: 31.5,
        whIn: 2400,
        peakCurrent: 10,
        maxTemperature: null,
        deltaAtStart: 0.008,
        deltaAtTop: 0.02,
        worstDeltaHigh: 0.03,
        weakCellAtTop: 7,
        strongCellAtTop: 14,
        balancerWorkedSeconds: 60,
        reachedTop: true,
      );
      final id = service.activeDeviceId!;
      await repo.saveLastChargeReport(id, report.toJson());
      await service.refreshActiveDevice();

      final back = service.lastChargeReport;
      expect(back, isNotNull);
      expect(back!.ahIn, 31.5);
      expect(back.startedAt, report.startedAt);
    });
  });
}
