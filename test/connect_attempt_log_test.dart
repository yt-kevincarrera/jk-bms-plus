import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/l10n/app_localizations.dart';
import 'package:jk_bms/src/ble/ble_transport.dart';
import 'package:jk_bms/src/ble/connect_recovery.dart';
import 'package:jk_bms/src/ble/switchable_link.dart';
import 'package:jk_bms/src/bms_service.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/data/link_event.dart';
import 'package:jk_bms/src/data/repository.dart';
import 'package:jk_bms/src/ui/widgets/bluetooth_stuck_card.dart';

import 'support/fake_radio.dart';
import 'support/fakes.dart';

void main() {
  // The other half of the morning report: every attempt the recovery sees
  // has to reach the backup, without a retry loop filling the database, and
  // the rider has to be told what to try once the phone looks stuck.

  const id = 'C8:47:80:00:00:09';
  const gatt147 = 'FlutterBluePlusException | connect | android-code: 147 | '
      'GATT_CONNECTION_TIMEOUT';

  late DateTime now;
  late FakeRecoveryRadio radio;
  late ConnectRecovery recovery;
  late AppDatabase db;
  late BmsRepository repo;
  late BmsService service;

  setUp(() {
    now = DateTime(2026, 10, 1, 7, 30);
    radio = FakeRecoveryRadio();
    recovery = ConnectRecovery(
      radio: radio,
      adverts: AdvertBook(),
      now: () => now,
      releasePause: const Duration(milliseconds: 1),
    );
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = BmsRepository(database: db);
    service = BmsService(
      transport: SwitchableLink(real: BleTransport(recovery: recovery)),
      locationFactory: StubLocation.new,
    )..repository = repo;
  });

  tearDown(() async {
    await service.dispose();
    await repo.dispose();
    await db.close();
  });

  Future<void> failOnce() async {
    final a = recovery.begin(id);
    await recovery.prepare(a, stillWanted: () => true);
    now = now.add(const Duration(seconds: 2));
    recovery.failed(a, gatt147);
  }

  Future<List<LinkEvent>> rows(LinkEventKind kind) async {
    await pumpEventQueue();
    return (await repo.recentLinkEvents())
        .where((e) => e.kind == kind.name)
        .toList();
  }

  test('each attempt is one row, with what the app could see', () async {
    await failOnce();
    final written = await rows(LinkEventKind.connectAttempt);
    expect(written, hasLength(1));
    expect(written.single.deviceId, id);
    expect(written.single.detail, contains('#1 failed'));
    expect(written.single.detail, contains('android-code: 147'));
    expect(written.single.detail, contains('system connected'));
    expect(service.recentAttempts.single.detail, written.single.detail);
  });

  test('thirty rows an hour, and the next row says how many were skipped',
      () async {
    for (var i = 0; i < 35; i++) {
      await failOnce();
    }
    expect(await rows(LinkEventKind.connectAttempt), hasLength(30));
    // The console keeps the latest few whatever the budget did.
    expect(service.recentAttempts, hasLength(8));
    expect(service.recentAttempts.first.number, 35);

    now = now.add(const Duration(hours: 1));
    await failOnce();
    final latest = (await rows(LinkEventKind.connectAttempt)).first;
    expect(latest.detail, contains('5 attempt(s) before this one not written'));
  });

  test('the phone looking stuck, what was tried, and the recovery are each '
      'written down', () async {
    for (var i = 0; i < 4; i++) {
      await failOnce();
    }
    expect(service.bluetoothLooksStuck, isTrue);
    expect(await rows(LinkEventKind.bluetoothLooksStuck), hasLength(1));

    await service.resetBluetooth();
    expect(radio.log, contains('resetAll'));
    expect(service.bluetoothLooksStuck, isFalse);
    final remedy = await rows(LinkEventKind.bluetoothRemedy);
    expect(remedy.single.detail, startsWith('inAppReset'));

    final a = recovery.begin(id);
    await recovery.prepare(a, stillWanted: () => true);
    recovery.linkUp(a);
    recovery.connected(a);
    await Future<void>.delayed(const Duration(milliseconds: 2100));
    final back = await rows(LinkEventKind.bluetoothRecovered);
    expect(back.single.detail, contains('inAppReset'));
  });

  test('demo mode is never stuck', () async {
    for (var i = 0; i < 4; i++) {
      await failOnce();
    }
    await service.enterDemoMode();
    expect(service.bluetoothLooksStuck, isFalse);
    await service.exitDemoMode();
  });

  testWidgets('the stuck card offers the four steps in order, and the reset '
      'first', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BluetoothStuckCard(onReset: () => pressed++),
          ),
        ),
      ),
    );
    expect(find.text('El Bluetooth del teléfono parece atascado'), findsOne);
    final reset = find.text('Reiniciar la conexión Bluetooth de la app');
    final forceStop = find.textContaining('Forzar detención');
    final scanning = find.textContaining('Búsqueda de Bluetooth');
    final restart = find.textContaining('reinicia el teléfono');
    for (final f in [reset, forceStop, scanning, restart]) {
      expect(f, findsOne);
    }
    final ys = [
      for (final f in [reset, forceStop, scanning, restart])
        tester.getTopLeft(f).dy,
    ];
    expect(ys, orderedEquals([...ys]..sort()));
    expect(find.textContaining('qué paso lo arregló'), findsOne);

    await tester.tap(reset);
    expect(pressed, 1);
  });

  testWidgets('the reset button cannot be pressed twice', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BluetoothStuckCard(
              onReset: () => pressed++,
              resetting: true,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.textContaining('Restarting'));
    expect(pressed, 0);
  });
}
