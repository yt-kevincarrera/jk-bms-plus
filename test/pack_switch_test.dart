import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/bms_link.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/metrics/trip_energy_repair.dart';
import 'package:jk_bms/src/platform/pack_widget.dart';

import 'fixtures/captured_frames.dart';

class FakeLink implements BmsLink {
  final _bytes = StreamController<List<int>>.broadcast();
  final _state = StreamController<BleLinkState>.broadcast();
  final _errors = StreamController<BleLinkError>.broadcast();

  String? connectedTo;
  int disconnects = 0;

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
  Future<void> connect(String deviceId) async => connectedTo = deviceId;

  @override
  Future<void> disconnect() async {
    disconnects++;
    connectedTo = null;
  }

  @override
  Future<void> dispose() async {
    await _bytes.close();
    await _state.close();
    await _errors.close();
  }

  Future<void> deliver(Uint8List frame, {int chunk = 20}) async {
    for (var i = 0; i < frame.length; i += chunk) {
      _bytes.add(frame.sublist(i, (i + chunk).clamp(0, frame.length)));
    }
    await pumpEventQueue();
  }
}

/// A repository whose history repair never finishes, standing in for a pack
/// with days of stored readings on a phone that takes its time.
class StuckRepairRepository extends BmsRepository {
  StuckRepairRepository({required AppDatabase database})
      : super(database: database);

  bool asked = false;

  @override
  Future<TripRepairReport> repairTripEnergy(
    String deviceId, {
    TripEnergyRepair repairer = const TripEnergyRepair(),
  }) {
    asked = true;
    return Completer<TripRepairReport>().future;
  }
}

void main() {
  late AppDatabase db;
  late FakeLink link;
  late BmsService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    link = FakeLink();
    service = BmsService(transport: link)
      ..repository = BmsRepository(database: db)
      ..widgetStrings = PackWidgetStrings(
        justNow: 'just now',
        minutesAgo: (n) => '$n min',
        hoursAgo: (n) => '$n h',
        daysAgo: (n) => '$n d',
      );
  });

  tearDown(() async {
    await service.dispose();
    await db.close();
  });

  /// One pack, connected and reading.
  Future<void> bring(String id) async {
    await service.connect(id, name: id);
    await link.deliver(deviceInfoFrames[0]);
    await link.deliver(cellInfo24s[0]);
    await pumpEventQueue();
  }

  // Why this exists. The rider switched batteries and the previous one's
  // notification was still standing. The cause was bigger than the
  // notification: disconnecting dropped the radio and forgot to forget the
  // pack. Everything decoded from it survived into the next connection.

  test('a pack that decodes becomes the active one', () async {
    await bring('pack-a');
    expect(service.activeDeviceId, 'pack-a');
    expect(service.lastSnapshot, isNotNull);
    expect(service.variant, isNotNull);
  });

  test('disconnecting forgets the pack, not just the radio', () async {
    await bring('pack-a');
    expect(service.widgetPublisher.lastPublished?.soc, isNot('--'));

    await service.disconnect();

    expect(service.activeDevice, isNull);
    expect(service.activeDeviceId, isNull);
    expect(service.lastSnapshot, isNull);
    expect(service.lastDeviceInfo, isNull);
    expect(service.variant, isNull);
    expect(service.repository!.activeDeviceId, isNull);
    // The home screen widget stops quoting a charge level for a pack nothing
    // is reading.
    expect(service.widgetPublisher.lastPublished, PackWidgetContent.empty);
  });

  test('the device stream says the pack is gone', () async {
    await bring('pack-a');
    final seen = <String?>[];
    final sub = service.deviceStream.listen((d) => seen.add(d?.id));
    await service.disconnect();
    await pumpEventQueue();
    await sub.cancel();
    expect(seen, [null]);
  });

  test('switching packs lets the first one go first', () async {
    await bring('pack-a');
    final before = link.disconnects;

    // The BMS accepts one connection, so the second cannot be asked for while
    // the first is open.
    await service.connect('pack-b', name: 'pack-b');

    expect(link.disconnects, before + 1);
    expect(link.connectedTo, 'pack-b');
  });

  test('and carries nothing of it into the new one', () async {
    await bring('pack-a');
    final aSnapshot = service.lastSnapshot;
    expect(aSnapshot, isNotNull);

    await service.connect('pack-b', name: 'pack-b');

    // Before pack B has said anything, the screens must have nothing to show.
    // They used to open on pack A's reading, under pack B's name, and could
    // decode pack B with pack A's protocol variant.
    expect(service.lastSnapshot, isNull);
    expect(service.variant, isNull);
    expect(service.activeDevice, isNull);
    expect(service.history.length, 0);
  });

  test('the new pack becomes active on its own first reading', () async {
    await bring('pack-a');
    await service.connect('pack-b', name: 'pack-b');
    await link.deliver(deviceInfoFrames[0]);
    await link.deliver(cellInfo24s[0]);
    await pumpEventQueue();

    expect(service.activeDeviceId, 'pack-b');
    expect(service.lastSnapshot, isNotNull);
  });

  test('reconnecting to the same pack does not tear it down', () async {
    await bring('pack-a');
    final before = link.disconnects;
    await service.connect('pack-a', name: 'pack-a');
    expect(link.disconnects, before);
  });

  test('with no radio behind it, nothing is held by the phone', () async {
    // The honest answer for the simulator and for a test: a diagnosis nobody
    // can make must not be invented.
    expect(await service.heldByPhone('pack-a'), isFalse);
  });

  test('a reading does not wait for the pack history to be rebuilt', () async {
    // The rider's own pack sat on "waiting for the first reading" while a
    // battery that arrived that morning connected and showed its data at once.
    // The difference was stored history: everything derived from it was
    // awaited on the first decoded frame, before any reading was allowed
    // through. A pack with no history did all of it instantly.
    await service.dispose();
    link = FakeLink();
    final stuck = StuckRepairRepository(database: db);
    service = BmsService(transport: link)..repository = stuck;

    final snapshots = <double>[];
    service.snapshots.listen((s) => snapshots.add(s.packVoltage));

    await service.connect('pack-a', name: 'pack-a');
    await link.deliver(deviceInfoFrames[0]);
    await link.deliver(cellInfo24s[0]);
    await pumpEventQueue();

    expect(stuck.asked, isTrue, reason: 'the rebuild was started');
    expect(snapshots, hasLength(1), reason: 'and the reading did not wait');
    expect(service.snapshotsEmitted, 1);

    // And the readings after it keep coming.
    await link.deliver(cellInfo24s[1]);
    await pumpEventQueue();
    expect(snapshots, hasLength(2));
  });
}
