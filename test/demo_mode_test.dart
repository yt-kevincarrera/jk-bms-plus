import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/simulator/jk_frame_builder.dart';
import 'package:jk_bms/src/ble/simulator/simulated_pack.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/model/bms_snapshot.dart';
import 'package:jk_bms/src/protocol/frame_assembler.dart';
import 'package:jk_bms/src/protocol/jk_checksum.dart';
import 'package:jk_bms/src/protocol/jk_constants.dart';
import 'package:jk_bms/src/protocol/protocol_variant.dart';

void main() {
  const builder = JkFrameBuilder();

  group('JkFrameBuilder', () {
    test('produces frames that pass the real checksum', () {
      final frame = builder.deviceInfo(
        counter: 1,
        model: 'JK-B2A24S20P',
        hardwareVersion: '10.XW',
        softwareVersion: '10.07',
        uptimeSeconds: 1000,
        powerOnCount: 5,
        deviceName: 'JK BMS',
        devicePasscode: '1234',
        manufacturingDate: '240118',
        serialNumber: 'DEMO0000001',
      );

      expect(frame, hasLength(responseFrameSize));
      expect(
        jkChecksum(frame, responseFrameSize - 1),
        frame[responseFrameSize - 1],
      );
    });

    test('a built frame survives the assembler in 20-byte chunks', () {
      final assembler = FrameAssembler();
      final frame = builder.cellInfo(
        counter: 9,
        cellVoltages: List.filled(20, 3.9),
        cellResistances: List.filled(20, 0.0025),
        packVoltage: 78.0,
        current: -12.5,
        temperatures: const [24.5, 23.8],
        mosfetTemp: 27.1,
        soc: 78,
        soh: 97,
        remainingCapacityAh: 35.1,
        nominalCapacityAh: 45,
        cycleCount: 63,
        cycleCapacityAh: 2843.5,
        balancingAction: 0,
        balanceCurrent: 0,
        chargeMosfetOn: true,
        dischargeMosfetOn: true,
        errorBitmask: 0,
        totalRuntimeSeconds: 14400,
      );

      final out = <Object>[];
      for (var i = 0; i < frame.length; i += 20) {
        out.addAll(assembler.addChunk(
          frame.sublist(i, (i + 20).clamp(0, frame.length)),
        ));
      }
      expect(out, hasLength(1));
      expect(assembler.stats.badChecksum, 0);
    });
  });

  group('SimulatedPack', () {
    test('models a 20S pack in a sane voltage band', () {
      final pack = SimulatedPack();
      for (var i = 0; i < 120; i++) {
        pack.tick(const Duration(seconds: 1));
      }

      expect(pack.cellVoltages, hasLength(20));
      for (final v in pack.cellVoltages) {
        expect(v, inInclusiveRange(3.0, 4.25));
      }
      expect(pack.packVoltage, inInclusiveRange(60, 85));
      expect(pack.soc, inInclusiveRange(0, 100));
    });

    test('riding draws current and drains the pack', () {
      final pack = SimulatedPack(scenario: DemoScenario.riding);
      final startSoc = pack.soc;
      for (var i = 0; i < 600; i++) {
        pack.tick(const Duration(seconds: 1));
      }
      expect(pack.current, lessThan(0));
      expect(pack.soc, lessThan(startSoc));
    });

    test('charging pushes current in and fills the pack', () {
      final pack = SimulatedPack(scenario: DemoScenario.charging);
      final startSoc = pack.soc;
      for (var i = 0; i < 600; i++) {
        pack.tick(const Duration(seconds: 1));
      }
      expect(pack.current, greaterThan(0));
      expect(pack.soc, greaterThan(startSoc));
    });

    test('parked draws nothing', () {
      final pack = SimulatedPack(scenario: DemoScenario.idle);
      pack.tick(const Duration(seconds: 1));
      expect(pack.current, 0);
    });

    test('the weak-cell scenario opens the delta and raises a warning', () {
      final healthy = SimulatedPack(scenario: DemoScenario.riding);
      final faulty = SimulatedPack(scenario: DemoScenario.weakCell);
      for (var i = 0; i < 60; i++) {
        healthy.tick(const Duration(seconds: 1));
        faulty.tick(const Duration(seconds: 1));
      }

      double delta(SimulatedPack p) {
        final v = p.cellVoltages;
        return v.reduce((a, b) => a > b ? a : b) -
            v.reduce((a, b) => a < b ? a : b);
      }

      expect(delta(faulty), greaterThan(delta(healthy)));
      expect(faulty.errorBitmask, isNot(0));
      expect(faulty.balancerActive, isTrue);
    });
  });

  group('demo mode end to end', () {
    test('drives the real pipeline and reaches the snapshot stream', () async {
      final service = BmsService();
      addTearDown(service.dispose);

      final snapshots = <BmsSnapshot>[];
      service.snapshots.listen(snapshots.add);

      await service.enterDemoMode(scenario: DemoScenario.riding);
      await Future<void>.delayed(const Duration(milliseconds: 900));

      expect(service.isDemo, isTrue);
      // Detected, not configured: the simulator reports software 10.07 and the
      // detector concludes JK02_24S from that, exactly as it will with the real
      // BMS.
      expect(service.variant, JkProtocolVariant.jk02_24s);

      expect(snapshots, isNotEmpty);
      final s = snapshots.last;
      expect(s.cellCount, 20);
      expect(s.packVoltage, inInclusiveRange(60, 85));
      expect(s.soc, inInclusiveRange(0, 100));
      expect(s.temperatures, hasLength(2));
      expect(s.mosfetTemp, isNotNull);
      expect(service.stats.badChecksum, 0);
      expect(service.history.length, snapshots.length);
    });

    test('reports the simulated settings frame', () async {
      final service = BmsService();
      addTearDown(service.dispose);

      await service.enterDemoMode();
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(service.lastSettings, isNotNull);
      expect(service.lastSettings!.cellCount, 20);
      expect(service.lastSettings!.cellOvp, closeTo(4.2, 1e-9));
      expect(service.lastSettings!.nominalCapacityAh, closeTo(45, 1e-9));
    });

    test('leaving demo mode clears everything decoded from it', () async {
      final service = BmsService();
      addTearDown(service.dispose);

      await service.enterDemoMode();
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(service.lastSnapshot, isNotNull);

      await service.exitDemoMode();

      expect(service.isDemo, isFalse);
      expect(service.lastSnapshot, isNull);
      expect(service.variant, isNull);
      expect(service.history.isEmpty, isTrue);
    });
  });
}
