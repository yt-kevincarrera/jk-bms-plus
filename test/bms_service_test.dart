import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/simulator/jk_frame_builder.dart';
import 'package:jk_bms/src/ble/bms_link.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/model/bms_snapshot.dart';
import 'package:jk_bms/src/protocol/jk_frame.dart';
import 'package:jk_bms/src/protocol/jk_parser.dart';
import 'package:jk_bms/src/protocol/protocol_variant.dart';

import 'fixtures/captured_frames.dart';

/// A transport that replays captured bytes instead of talking to a radio.
class FakeLink implements BmsLink {
  final _bytes = StreamController<List<int>>.broadcast();
  final _state = StreamController<BleLinkState>.broadcast();
  final _errors = StreamController<BleLinkError>.broadcast();

  bool connected = false;
  bool disposed = false;

  @override
  Stream<List<int>> get bytes => _bytes.stream;
  @override
  Stream<BleLinkState> get state => _state.stream;
  @override
  Stream<BleLinkError> get errors => _errors.stream;
  @override
  int? negotiatedMtu = 244;

  @override
  Stream<List<DiscoveredBms>> scan() => const Stream.empty();

  @override
  LinkHealth get health => LinkHealth.unknown;

  @override
  Future<void> connect(String deviceId) async => connected = true;

  @override
  Future<void> disconnect() async => connected = false;

  @override
  Future<void> dispose() async {
    disposed = true;
    await _bytes.close();
    await _state.close();
    await _errors.close();
  }

  /// Delivers a frame the way BLE does before MTU negotiation: 20 bytes at a
  /// time.
  Future<void> deliver(Uint8List frame, {int chunk = 20}) async {
    for (var i = 0; i < frame.length; i += chunk) {
      _bytes.add(frame.sublist(i, (i + chunk).clamp(0, frame.length)));
    }
    await pumpEventQueue();
  }
}

/// A parser whose cell info always fails, standing in for a firmware whose
/// frames this app gets wrong.
class BrokenCellInfoParser extends JkParser {
  const BrokenCellInfoParser();

  @override
  BmsSnapshot parseCellInfo(JkFrame frame, JkProtocolVariant variant) {
    throw StateError('offset 300 is past the end of a 300-byte frame');
  }
}

void main() {
  late FakeLink link;
  late BmsService service;

  setUp(() {
    link = FakeLink();
    service = BmsService(transport: link);
  });

  tearDown(() async => service.dispose());

  test('decodes cell info that arrives before any device info', () async {
    // This used to be held back: with no device info there was no version
    // string, so there was no framing, so the reading was refused. Refusing was
    // right while a guess was the only alternative. It is not the only
    // alternative any more -- the frame is read with each framing and the one
    // that describes a real battery is kept, which is evidence rather than a
    // guess.
    final snapshots = <BmsSnapshot>[];
    service.snapshots.listen(snapshots.add);

    await link.deliver(cellInfo24s[0]);

    expect(service.variant, JkProtocolVariant.jk02_24s);
    expect(service.variantProved, isTrue);
    expect(snapshots, hasLength(1));
    expect(snapshots.single.packVoltage, closeTo(53.251, 1e-9));
    expect(service.stats.accepted, 1, reason: 'the frame itself was valid');
  });

  test('a frame no framing can read is still held back', () async {
    // The guarantee that survives: nothing is decoded on a guess. When the
    // frame cannot settle it either, the reading is refused and said, and the
    // System tab is where a rider chooses.
    final snapshots = <BmsSnapshot>[];
    final problems = <String>[];
    service.snapshots.listen(snapshots.add);
    service.problems.listen(problems.add);

    final rubbish = Uint8List.fromList(cellInfo24s[0]);
    for (var i = 6; i < 260; i++) {
      rubbish[i] = 0xFF;
    }
    var sum = 0;
    for (var i = 0; i < rubbish.length - 1; i++) {
      sum = (sum + rubbish[i]) & 0xFF;
    }
    rubbish[rubbish.length - 1] = sum;

    await link.deliver(rubbish);

    expect(snapshots, isEmpty);
    expect(service.variant, isNull);
    expect(service.heldBackFrames, 1);
    expect(problems.join(' '), contains('could not tell them apart'));
  });

  test('decodes cell info once device info has set the variant', () async {
    final snapshots = <BmsSnapshot>[];
    service.snapshots.listen(snapshots.add);

    await link.deliver(deviceInfoFrames[1]); // JK-B2A24S15P, sw 10.07
    expect(service.variant, JkProtocolVariant.jk02_24s);

    await link.deliver(cellInfo24s[0]);

    expect(snapshots, hasLength(1));
    expect(snapshots.single.cellCount, 16);
    expect(snapshots.single.packVoltage, closeTo(53.251, 1e-9));
    expect(service.lastSnapshot, same(snapshots.single));
  });

  test('a manual variant override wins over auto-detection', () async {
    service.overrideVariant(JkProtocolVariant.jk02_32s);
    await link.deliver(deviceInfoFrames[1]); // would auto-detect as 24S

    expect(service.variant, JkProtocolVariant.jk02_32s);

    service.overrideVariant(null);
    expect(service.variant, JkProtocolVariant.jk02_24s);
  });

  test('warns when auto-detection was not confident', () async {
    final problems = <String>[];
    service.problems.listen(problems.add);

    await link.deliver(deviceInfoFrames[1]);

    expect(problems.single, contains('Assuming jk02_24s'));
  });

  test('stays silent when auto-detection was confident', () async {
    final problems = <String>[];
    service.problems.listen(problems.add);

    await link.deliver(deviceInfoFrames[2]); // sw 14.20 -> JK02_32S

    expect(service.variant, JkProtocolVariant.jk02_32s);
    expect(problems, isEmpty);
  });

  test('a stream of frames yields one snapshot each', () async {
    final snapshots = <BmsSnapshot>[];
    service.snapshots.listen(snapshots.add);

    await link.deliver(deviceInfoFrames[1]);
    for (final f in cellInfo24s) {
      await link.deliver(f);
    }

    expect(snapshots, hasLength(cellInfo24s.length));
    expect(
      snapshots.map((s) => s.frameCounter),
      [0x8C, 0x8D, 0x8E, 0x91, 0x92, 0x93],
    );
  });

  test('corrupt frames are counted and skipped, the link keeps working',
      () async {
    final snapshots = <BmsSnapshot>[];
    service.snapshots.listen(snapshots.add);

    await link.deliver(deviceInfoFrames[1]);

    final corrupt = Uint8List.fromList(cellInfo24s[0]);
    corrupt[50] ^= 0xFF;
    await link.deliver(corrupt);
    expect(snapshots, isEmpty);
    expect(service.stats.badChecksum, 1);

    await link.deliver(cellInfo24s[1]);
    expect(snapshots, hasLength(1));
  });

  test('publishes frame statistics as bytes arrive', () async {
    final stats = <int>[];
    service.frameStats.listen((s) => stats.add(s.accepted));

    await link.deliver(deviceInfoFrames[1]);

    expect(stats, isNotEmpty);
    expect(stats.last, 1);
    expect(service.negotiatedMtu, 244);
  });

  test('decodes a settings frame into the settings stream', () async {
    final settings = [];
    service.settings.listen(settings.add);

    await link.deliver(deviceInfoFrames[1]);
    await link.deliver(settingsJk02_24s);

    expect(settings, hasLength(1));
    expect(service.lastSettings, isNotNull);
    expect(service.lastSettings!.cellOvp, closeTo(4.3, 1e-9));
  });

  test('reports an unsupported record type instead of silently dropping it',
      () async {
    final problems = <String>[];
    service.problems.listen(problems.add);

    // Record type 0x07 does not exist. Rebuild the checksum so the frame is
    // structurally valid and only the type is unknown.
    final odd = Uint8List.fromList(cellInfo24s[0]);
    odd[4] = 0x07;
    var sum = 0;
    for (var i = 0; i < odd.length - 1; i++) {
      sum = (sum + odd[i]) & 0xFF;
    }
    odd[odd.length - 1] = sum;

    await link.deliver(odd);

    expect(problems.single, contains('0x07'));
    expect(service.stats.unsupportedType, 1);
  });

  test('disconnect clears the assembler so half a frame is not carried over',
      () async {
    final snapshots = <BmsSnapshot>[];
    service.snapshots.listen(snapshots.add);

    await link.deliver(deviceInfoFrames[1]);
    await link.deliver(cellInfo24s[0].sublist(0, 120));
    await service.disconnect();
    // The pack names its protocol again, because a disconnect now forgets the
    // pack rather than only dropping the radio, and this is the order the real
    // sequence has: the transport asks for device info first on every attach.
    await link.deliver(deviceInfoFrames[1]);
    await link.deliver(cellInfo24s[1]);

    // One reading, and it is the second frame rather than a splice of the
    // truncated first one and the second.
    expect(snapshots, hasLength(1));
    expect(snapshots.single.frameCounter, 0x8D);
  });

  test('a cell info frame that will not decode is said, not swallowed', () async {
    // _handleCellInfo is not awaited by its caller, so a throw from the parser
    // used to vanish: no notice, no reading, and every tab waiting for the
    // first reading indefinitely. The rider saw exactly that.
    await service.dispose();
    link = FakeLink();
    service = BmsService(transport: link, parser: const BrokenCellInfoParser());
    final problems = <String>[];
    service.problems.listen(problems.add);
    await service.connect('pack');

    await link.deliver(deviceInfoFrames[0]);
    await link.deliver(cellInfo24s[0]);
    await link.deliver(cellInfo24s[1]);

    expect(service.deviceInfoFrames, 1);
    expect(service.cellInfoFrames, 2);
    expect(service.decodeFailures, 2);
    expect(service.snapshotsEmitted, 0);
    expect(
      problems.where((p) => p.contains('Could not decode cell info')),
      hasLength(2),
    );
    expect(service.recentProblems.first, contains('offset 300'));
  });

  group('settling the framing by reading a frame', () {
    // The framing used to be worked out from the firmware version string
    // alone. A version the regex cannot read left the app with none, and every
    // reading held back forever; a version implying the wrong one produced
    // numbers no battery could produce, silently. Both are answerable from the
    // frame, because the wrong framing does not read slightly wrong.

    test('a version the app cannot read no longer holds every reading back',
        () async {
      const builder = JkFrameBuilder();
      final problems = <String>[];
      final snapshots = <BmsSnapshot>[];
      service.problems.listen(problems.add);
      service.snapshots.listen(snapshots.add);

      // A leading letter is all it takes: the major version is read with
      // ^\s*(\d+), so "V11.05" yields nothing.
      await link.deliver(
        builder.deviceInfo(
          counter: 1,
          model: 'JK-BD6A24S10P',
          hardwareVersion: 'V11.XW',
          softwareVersion: 'V11.05',
          uptimeSeconds: 1000,
          powerOnCount: 5,
          deviceName: 'KevinJK',
          devicePasscode: '1234',
          manufacturingDate: '240101',
          serialNumber: 'SN123',
        ),
      );
      expect(service.variant, isNull, reason: 'the version says nothing');

      await link.deliver(cellInfo24s[0]);

      expect(service.variant, JkProtocolVariant.jk02_24s);
      expect(service.variantProved, isTrue);
      expect(snapshots, hasLength(1));
      expect(service.heldBackFrames, 0);
      expect(
        problems.join(' '),
        contains('read a reading with each and kept the one'),
      );
    });

    test('a version implying the wrong framing is overruled by the frame',
        () async {
      // Real data on both sides: this device info capture reports software
      // 14.20, which the version rule calls 32-cell confidently, and these are
      // the 24-cell captures from the rider's own pack.
      final problems = <String>[];
      final snapshots = <BmsSnapshot>[];
      service.problems.listen(problems.add);
      service.snapshots.listen(snapshots.add);

      await link.deliver(deviceInfoFrames[2]);
      expect(service.variant, JkProtocolVariant.jk02_32s);

      await link.deliver(cellInfo24s[0]);

      expect(service.variant, JkProtocolVariant.jk02_24s);
      expect(service.variantCorrections, 1);
      // And the reading that triggered the correction is the corrected one,
      // not the impossible one.
      expect(snapshots.single.packVoltage, closeTo(53.251, 1e-9));
      expect(snapshots.single.cellCount, 16);
      expect(problems.join(' '), contains('no battery could produce'));
    });

    test('a framing the rider picked by hand is never overruled', () async {
      // Their choice, and the System tab is where they made it. Second-
      // guessing it would make the picker useless.
      final problems = <String>[];
      service.problems.listen(problems.add);
      // The forced framing decodes into impossible numbers, which fire a
      // critical alert; the buzz behind it needs a platform this test has not
      // got, and is not what is being judged here.
      service.hapticAlerts = false;
      service.overrideVariant(JkProtocolVariant.jk02_32s);

      await link.deliver(deviceInfoFrames[1]);
      await link.deliver(cellInfo24s[0]);

      expect(service.variant, JkProtocolVariant.jk02_32s);
      expect(service.variantCorrections, 0);
      expect(problems.join(' '), isNot(contains('no battery could produce')));
    });

    test('a pack the version rule got right costs no correction', () async {
      await link.deliver(deviceInfoFrames[1]); // 10.07 -> 24-cell
      for (final f in cellInfo24s) {
        await link.deliver(f);
      }

      expect(service.variant, JkProtocolVariant.jk02_24s);
      expect(service.variantCorrections, 0);
      expect(service.snapshotsEmitted, cellInfo24s.length);
    });

    test('clearing a hand-picked framing lets the frame speak again',
        () async {
      service.hapticAlerts = false;
      service.overrideVariant(JkProtocolVariant.jk02_32s);
      await link.deliver(deviceInfoFrames[2]);
      await link.deliver(cellInfo24s[0]);
      expect(service.variantCorrections, 0);

      service.overrideVariant(null);
      await link.deliver(cellInfo24s[1]);

      expect(service.variant, JkProtocolVariant.jk02_24s);
      expect(service.variantCorrections, 1);
    });
  });
}
