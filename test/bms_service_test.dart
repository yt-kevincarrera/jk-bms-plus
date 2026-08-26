import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/bms_link.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/model/bms_snapshot.dart';
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

void main() {
  late FakeLink link;
  late BmsService service;

  setUp(() {
    link = FakeLink();
    service = BmsService(transport: link);
  });

  tearDown(() async => service.dispose());

  test('does not decode cell info before the variant is known', () async {
    final snapshots = <BmsSnapshot>[];
    final problems = <String>[];
    service.snapshots.listen(snapshots.add);
    service.problems.listen(problems.add);

    await link.deliver(cellInfo24s[0]);

    // A held-back frame is the correct outcome. Decoding it with a guessed
    // variant would produce wrong voltages instead of an obvious gap.
    expect(snapshots, isEmpty);
    expect(service.variant, isNull);
    expect(problems.single, contains('variant is not known'));
    expect(service.stats.accepted, 1, reason: 'the frame itself was valid');
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
    await link.deliver(cellInfo24s[1]);

    expect(snapshots, hasLength(1));
    expect(snapshots.single.frameCounter, 0x8D);
  });
}
