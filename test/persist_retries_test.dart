import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/repository.dart';

import 'fixtures/captured_frames.dart';
import 'support/fakes.dart';

void main() {
  // The rider's report: the link drops mid-ride, the loop spends six minutes
  // failing, and then stops for good. Nothing revives it but a tap on a screen
  // in a pocket, so the rest of the ride records nothing and the ride's
  // watt-hours end at the drop.
  //
  // The decision to stop is right off the bike and wrong on it, so the service
  // tells the loop which situation it is in.

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
    service.dispose();
    await repo.dispose();
    await db.close();
  });

  test('off the bike, the loop is allowed to give up', () {
    expect(link.persisting, isFalse);
  });

  test('a ride starting tells the loop not to give up', () async {
    await service.startTrip();
    expect(link.persisting, isTrue);
  });

  test('and the ride ending hands the decision back', () async {
    await service.startTrip();
    expect(link.persisting, isTrue);

    await service.stopTrip();
    expect(link.persisting, isFalse);
  });

  test('a paused ride still counts as a ride', () async {
    // Pausing to put air in a tyre is not the end of the ride, and the link
    // has the same reason to keep knocking.
    await service.startTrip();
    service.pauseTrip();
    expect(link.persisting, isTrue);
  });
}
