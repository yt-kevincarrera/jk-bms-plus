import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/simulator/ant_frame_builder.dart';
import 'package:jk_bms/src/ble/simulator/simulated_link.dart';
import 'package:jk_bms/src/ble/simulator/simulated_pack.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/model/ant_settings.dart';
import 'package:jk_bms/src/model/bms_snapshot.dart';
import 'package:jk_bms/src/protocol/ant_constants.dart';
import 'package:jk_bms/src/protocol/ant_current_sign.dart';
import 'package:jk_bms/src/protocol/ant_frame.dart';
import 'package:jk_bms/src/protocol/ant_frame_assembler.dart';
import 'package:jk_bms/src/protocol/ant_parser.dart';
import 'package:jk_bms/src/protocol/bms_brand.dart';

/// Feeds [frame] to a fresh assembler 20 bytes at a time, as BLE does.
List<AntFrame> assemble(List<int> frame) {
  final a = AntFrameAssembler();
  final out = <AntFrame>[];
  for (var i = 0; i < frame.length; i += 20) {
    out.addAll(a.addChunk(frame.sublist(i, (i + 20).clamp(0, frame.length))));
  }
  return out;
}

void main() {
  const builder = AntFrameBuilder();
  const parser = AntParser();

  group('AntFrameBuilder', () {
    AntStatus build({required double current, int probes = 2}) {
      final frames = assemble(
        builder.status(
          cellVoltages: List.filled(20, 3.9),
          temperatures: List.filled(probes, 25.0),
          mosfetTemp: 27,
          balancerTemp: 28,
          packVoltage: 78,
          current: current,
          soc: 78,
          soh: 97,
          chargeMosfetOn: true,
          dischargeMosfetOn: true,
          balancerCode: 0,
          balancingCellMask: 0,
          nominalCapacityAh: 45,
          remainingCapacityAh: 35.1,
          totalDischargedAh: 2823.5,
          totalChargedAh: 2863.5,
          runtimeSeconds: 14400,
          dischargingSeconds: 4320,
          chargingSeconds: 2880,
        ),
      );
      expect(frames, hasLength(1), reason: 'CRC and length must be right');
      return parser.parseStatus(frames.single);
    }

    test('a status frame survives the real assembler, CRC and parser', () {
      final st = build(current: -30);
      final s = st.snapshot;
      expect(s.brand, BmsBrand.ant);
      expect(s.cellCount, 20);
      expect(s.packVoltage, closeTo(78, 1e-9));
      expect(s.current, closeTo(-30, 1e-9));
      expect(s.soc, 78);
      expect(s.nominalCapacityAh, closeTo(45, 1e-6));
      expect(s.remainingCapacityAh, closeTo(35.1, 1e-6));
      expect(s.cycleCapacityAh, closeTo(2843.5, 1e-3));
      expect(st.batteryState, antStateDischarge);
      expect(st.totalChargedAh, closeTo(2863.5, 1e-9));
      expect(antBatteryTypeOf(st.batteryTypeCode), AntBatteryType.ternary);
    });

    test('charging goes on the wire negative, as a real ANT sends it', () {
      final frame = builder.status(
        cellVoltages: List.filled(20, 3.9),
        temperatures: const [25, 25],
        mosfetTemp: 27,
        balancerTemp: 28,
        packVoltage: 78,
        current: 12,
        soc: 50,
        soh: 100,
        chargeMosfetOn: true,
        dischargeMosfetOn: false,
        balancerCode: 0,
        balancingCellMask: 0,
        nominalCapacityAh: 45,
        remainingCapacityAh: 22.5,
        totalDischargedAh: 100,
        totalChargedAh: 110,
        runtimeSeconds: 1,
        dischargingSeconds: 0,
        chargingSeconds: 0,
      );
      // 20 cells and 2 probes: o = 44, the current field at 84.
      final raw = (frame[84] | (frame[85] << 8)).toSigned(16);
      expect(raw, -120);
      expect(frame[7], antStateCharge);
      final st = parser.parseStatus(assemble(frame).single);
      expect(st.snapshot.current, closeTo(12, 1e-9));
      // And the service's own cross-check of sign against state agrees, so
      // nothing gets reversed.
      final sign = AntCurrentSign();
      for (var i = 0; i < 5; i++) {
        expect(
          sign.observe(
            batteryState: st.batteryState,
            current: st.snapshot.current,
          ),
          isFalse,
        );
      }
      expect(sign.decided, isTrue);
      expect(sign.inverted, isFalse);
    });

    test('device info and a settings reply read back', () {
      final info = parser.parseDeviceInfo(
        assemble(builder.deviceInfo(model: 'DEMO20S', software: 'DEMO-SIM'))
            .single,
      );
      expect(info.model, 'DEMO20S');
      expect(info.softwareVersion, 'DEMO-SIM');
      final reply = assemble(
        builder.settingReply(AntSetting.cellUvp, 2.8),
      ).single;
      final (setting, value) = parser.parseSetting(reply)!;
      expect(setting, AntSetting.cellUvp);
      expect(value, closeTo(2.8, 1e-9));
    });
  });

  group('the simulated ANT', () {
    final sim = SimulatedLink(
      tickInterval: const Duration(hours: 1),
      scenario: DemoScenario.antCharging,
    );
    tearDownAll(sim.dispose);

    test('answers the app\'s status and device info requests', () {
      final status = sim.antReplyTo(antStatusRequest)!;
      expect(assemble(status).single.isStatus, isTrue);
      final info = sim.antReplyTo(antDeviceInfoRequest)!;
      expect(assemble(info).single.isDeviceInfo, isTrue);
    });

    test('answers every settings read the script makes', () {
      for (final s in AntSetting.values) {
        final reply = sim.antReplyTo(antReadRequest(s.address, 2))!;
        final (setting, value) = parser.parseSetting(assemble(reply).single)!;
        expect(setting, s);
        expect(value, closeTo(SimulatedLink.antSettingValues[s]!, 1e-6));
      }
    });

    test('ignores a bad CRC, a write and anything else', () {
      final bad = List<int>.from(antStatusRequest)..[6] ^= 0xFF;
      expect(sim.antReplyTo(bad), isNull);
      // Function 0x51, the reference's register write, built with a good
      // CRC: still no answer, and nothing about the pack changes.
      final write = [0x7E, 0xA1, 0x51, 0x00, 0x00, 0x00];
      expect(sim.antReplyTo([...write, 0, 0, 0xAA, 0x55]), isNull);
      expect(sim.antReplyTo(const [0xAA, 0x55, 0x90, 0xEB]), isNull);
    });

    test('is an ANT, on the charger', () {
      expect(sim.brand, BmsBrand.ant);
      expect(DemoScenario.antCharging.behaviour, DemoScenario.charging);
      expect(DemoScenario.riding.brand, BmsBrand.jk);
    });
  });

  group('demo mode end to end', () {
    test('an ANT scenario reads through the ANT pipeline, settings too',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = BmsRepository(database: db);
      final service = BmsService()..repository = repo;
      addTearDown(() async {
        await service.dispose();
        await repo.dispose();
        await db.close();
      });
      final snapshots = <BmsSnapshot>[];
      service.snapshots.listen(snapshots.add);

      await service.enterDemoMode(scenario: DemoScenario.antCharging);
      // Long enough for the pack to start charging, the poll after it and
      // the first settings read (every other tick once device info is in).
      await Future<void>.delayed(const Duration(milliseconds: 4500));

      expect(service.isDemo, isTrue);
      expect(service.brand, BmsBrand.ant);
      // Its own pack row, apart from the JK demo's.
      expect(service.activeDeviceId, BmsService.demoAntDeviceId);
      expect(service.activeDevice?.brand, BmsBrand.ant.stored);
      expect(service.demoScenario, DemoScenario.antCharging);
      expect(service.lastDeviceInfo?.model, 'DEMO20S');
      expect(snapshots, isNotEmpty);
      final s = snapshots.last;
      expect(s.brand, BmsBrand.ant);
      expect(s.cellCount, 20);
      // Charging reads positive, through the real sign handling.
      expect(s.current, greaterThan(0));
      expect(service.stats.badChecksum, 0);
      // No JK settings frame: an ANT's come as register reads, and the first
      // one has been asked and answered.
      expect(service.lastSettings, isNull);
      expect(service.lastAntSettings?.cellOvp, closeTo(4.2, 1e-9));
      expect(service.packConfig, isNotNull);
    });

    test('switching between a JK and an ANT scenario changes the pack',
        () async {
      final service = BmsService();
      addTearDown(service.dispose);
      await service.enterDemoMode(scenario: DemoScenario.riding);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(service.brand, BmsBrand.jk);
      expect(service.lastSettings, isNotNull);

      service.demoScenario = DemoScenario.antRiding;
      await Future<void>.delayed(const Duration(milliseconds: 900));
      expect(service.brand, BmsBrand.ant);
      expect(service.lastSnapshot?.brand, BmsBrand.ant);
      expect(service.lastSettings, isNull);

      // Within a brand it is the same pack doing something else.
      service.demoScenario = DemoScenario.antCharging;
      expect(service.demoScenario, DemoScenario.antCharging);
    });
  });
}
