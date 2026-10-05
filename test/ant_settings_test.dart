import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/metrics/advice_engine.dart';
import 'package:jk_bms/src/metrics/ride_alerts.dart';
import 'package:jk_bms/src/model/ant_settings.dart';
import 'package:jk_bms/src/pack/chemistry.dart';
import 'package:jk_bms/src/pack/config_audit.dart';
import 'package:jk_bms/src/pack/pack_config.dart';
import 'package:jk_bms/src/protocol/ant_constants.dart';
import 'package:jk_bms/src/protocol/ant_crc.dart';
import 'package:jk_bms/src/protocol/ant_frame.dart';
import 'package:jk_bms/src/protocol/ant_frame_assembler.dart';
import 'package:jk_bms/src/protocol/ant_parser.dart';

import 'fixtures/ant_frames.dart';
import 'support/fakes.dart';

/// A settings reply for [s] carrying [raw], with a good CRC. Synthetic: the
/// reference has one real reply, [antSettingCellOvpReply]; the rest are
/// built to its exact shape.
Uint8List settingReply(AntSetting s, int raw) {
  final f = [
    0x7E, 0xA1, 0x12, s.address & 0xFF, s.address >> 8, 0x02, //
    raw & 0xFF, raw >> 8,
  ];
  final crc = antCrc16(f, 1, f.length);
  return Uint8List.fromList([...f, crc & 0xFF, crc >> 8, 0xAA, 0x55]);
}

void main() {
  group('the read requests', () {
    // Copied from SETTINGS_REGISTER_CASES in syssi/esphome-ant-bms
    // tests/components/ant_bms_ble/frames_settings.h, not built by this app.
    final reference = {
      AntSetting.cellOvp: '7EA102000002' '19A0AA55',
      AntSetting.cellOvpRecovery: '7EA102020002' 'B860AA55',
      AntSetting.cellUvp: '7EA1020C0002' 'D9A3AA55',
      AntSetting.cellUvpRecovery: '7EA1020E0002' '7863AA55',
      AntSetting.chargeOcp: '7EA102680002' '987CAA55',
      AntSetting.chargeOcpDelay: '7EA1026A0002' '39BCAA55',
      AntSetting.dischargeOcp: '7EA1026C0002' 'D9BDAA55',
      AntSetting.dischargeOcpDelay: '7EA1026E0002' '787DAA55',
      AntSetting.shortCircuit: '7EA102740002' '59BAAA55',
      AntSetting.balanceStart: '7EA1028E0002' '798BAA55',
      AntSetting.balanceTrigger: '7EA102900002' '198DAA55',
      AntSetting.balanceCurrent: '7EA102940002' '584CAA55',
      AntSetting.cellCount: '7EA1029A0002' '398FAA55',
      AntSetting.shutdownVoltage: '7EA1029E0002' '784EAA55',
    };

    test('match the reference byte for byte, one per setting', () {
      expect(reference.keys.toSet(), AntSetting.values.toSet());
      for (final s in AntSetting.values) {
        expect(
          antReadRequest(s.address, 2),
          hex(reference[s]!),
          reason: s.name,
        );
      }
      expect(antSettingsReadRequests, [
        for (final s in AntSetting.values) hex(reference[s]!),
      ]);
    });

    test('the device info request is the same read, at 0x026C', () {
      expect(antReadRequest(0x026C, 0x20), antDeviceInfoRequest);
    });
  });

  group('a reply', () {
    test('the reference capture: cell overvoltage, 4.150 V', () {
      final frames = AntFrameAssembler().addChunk(antSettingCellOvpReply);
      expect(frames, hasLength(1));
      final f = frames.single;
      expect(f.isSettingsReply, isTrue);
      expect(f.isDeviceInfo, isFalse);
      final (setting, value) = const AntParser().parseSetting(f)!;
      expect(setting, AntSetting.cellOvp);
      expect(value, closeTo(4.150, 1e-9));
    });

    test('each register at its own scale', () {
      double read(AntSetting s, int raw) {
        final f = AntFrameAssembler().addChunk(settingReply(s, raw)).single;
        return const AntParser().parseSetting(f)!.$2;
      }

      expect(read(AntSetting.cellUvp, 2800), closeTo(2.8, 1e-9));
      expect(read(AntSetting.dischargeOcp, 1500), closeTo(150, 1e-9));
      expect(read(AntSetting.chargeOcpDelay, 3), 3);
      expect(read(AntSetting.balanceCurrent, 120), 120);
    });

    test('an address this app does not read is not a setting', () {
      final f = AntFrame(
        bytes: Uint8List.fromList([
          0x7E, 0xA1, 0x12, 0x84, 0x00, 0x02, 0x14, 0x00, 0, 0, 0xAA, 0x55, //
        ]),
        receivedAt: DateTime.utc(2026, 10, 5),
      );
      expect(const AntParser().parseSetting(f), isNull);
    });
  });

  group('the audit fields', () {
    test('only what was answered, never filled in', () {
      final s = const AntSettings()
          .withValue(AntSetting.cellOvp, 4.2)
          .withValue(AntSetting.dischargeOcp, 150)
          .withValue(AntSetting.balanceCurrent, 120);
      final c = PackConfig.fromAnt(s, nominalCapacityAh: 45);
      expect(c[ConfigField.cellOvp], 4.2);
      expect(c[ConfigField.maxDischargeCurrent], 150);
      expect(c[ConfigField.maxBalanceCurrent], closeTo(0.12, 1e-9));
      expect(c[ConfigField.nominalCapacityAh], 45);
      expect(c[ConfigField.cellUvp], isNull);
      expect(c[ConfigField.chargeOtp], isNull);
      expect(c[ConfigField.dischargeSwitchOn], isNull);
    });

    test('sane voltages on an ANT do not vouch for its temperatures', () {
      final s = const AntSettings()
          .withValue(AntSetting.cellOvp, 4.15)
          .withValue(AntSetting.cellUvp, 3.25);
      final findings = const ConfigAudit().evaluate(
        config: PackConfig.fromAnt(s),
        chemistry: CellChemistry.nmc,
      );
      final codes = findings.map((a) => a.code).toList();
      expect(codes, contains(AdviceCode.configVoltagesLookSane));
      expect(codes, isNot(contains(AdviceCode.configLooksSane)));
    });

    test('a dangerous ANT cutoff is flagged like a JK one', () {
      final s = const AntSettings().withValue(AntSetting.cellOvp, 4.35);
      final findings = const ConfigAudit().evaluate(
        config: PackConfig.fromAnt(s),
        chemistry: CellChemistry.nmc,
      );
      expect(
        findings.map((a) => a.code),
        contains(AdviceCode.configOvpDangerous),
      );
    });
  });

  group('the service', () {
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
      await service.connect('ANT1', name: 'ANT@BLE22AAUB');
      link.announce(BleLinkState.connected);
      await link.deliver(antInfo22ph);
      await link.deliver(antStatus20s4tCharging);
      await pumpEventQueue();
    });

    tearDown(() async {
      await service.dispose();
      await repo.dispose();
      await db.close();
    });

    test('before any answer: nothing configured, the cutoff assumed', () {
      expect(service.lastAntSettings, isNull);
      expect(service.packConfig, isNull);
      expect(service.cutoffIsAssumed, isTrue);
      expect(service.configuredCellOvp, isNull);
    });

    test('answers build up, and the cutoff becomes the BMS own', () async {
      final seen = <AntSettings>[];
      final sub = service.antSettings.listen(seen.add);
      await link.deliver(antSettingCellOvpReply);
      await link.deliver(settingReply(AntSetting.cellUvp, 2900));
      await link.deliver(settingReply(AntSetting.dischargeOcp, 1200));
      await pumpEventQueue();
      await sub.cancel();

      expect(seen, hasLength(3));
      final s = service.lastAntSettings!;
      expect(s.cellOvp, closeTo(4.15, 1e-9));
      expect(s.cellUvp, closeTo(2.9, 1e-9));
      expect(s.dischargeOcp, closeTo(120, 1e-9));
      expect(service.cutoffVoltagePerCell, closeTo(2.9, 1e-9));
      expect(service.cutoffIsAssumed, isFalse);
      expect(service.configuredCellOvp, closeTo(4.15, 1e-9));
      // 4.15 V is not an LFP cutoff, so the energy is priced as NMC.
      expect(service.cutoffChemistry, CellChemistry.nmc);
      final c = service.packConfig!;
      expect(c[ConfigField.maxDischargeCurrent], closeTo(120, 1e-9));
      // The configured capacity from the status frame.
      expect(c[ConfigField.nominalCapacityAh], closeTo(45, 1e-6));
    });

    test("the near-limit alert measures against the ANT's own limit", () async {
      // The capture charges at 5.1 A. Against a 5.3 A charge limit that is
      // past 95 %; before the limit was read there was nothing to compare.
      service.hapticAlerts = false;
      final fired = <RideAlert>[];
      final sub = service.rideAlerts.listen(fired.add);
      await link.deliver(antStatus20s4tCharging);
      await pumpEventQueue();
      expect(fired, isNot(contains(RideAlert.nearCurrentLimit)));
      await link.deliver(settingReply(AntSetting.chargeOcp, 53));
      await link.deliver(antStatus20s4tCharging);
      await pumpEventQueue();
      await sub.cancel();
      expect(fired, contains(RideAlert.nearCurrentLimit));
    });

    test('a reply is not a reading, and nothing is written in answer', () {
      final before = service.lastSnapshot;
      final writes = link.registerWrites.length;
      return link.deliver(antSettingCellOvpReply).then((_) {
        expect(service.lastSnapshot, same(before));
        expect(link.registerWrites.length, writes);
      });
    });
  });
}
