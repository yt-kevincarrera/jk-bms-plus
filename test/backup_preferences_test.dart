import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/app_settings.dart';
import 'package:jk_bms/src/data/backup.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the rider\'s settings travel in the backup and come back', () async {
    // A new phone used to start with every threshold, muted alert and
    // charge target back at its default, while the intro promised the
    // backup brought everything back.
    final before = AppSettings();
    await before.setAlertThresholds(delta: 0.07, temperature: 50);
    await before.setChargeTarget(null);
    await before.setAlertMuted('cellSpread', true);
    await before.setAutoTrip(false);
    await before.setScreenAwake(ScreenAwake.always);
    await before.setUpdateToken('ghp_secret');

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final dir = await Directory.systemTemp.createTemp('jk-prefs');
    addTearDown(() => dir.delete(recursive: true));
    final file = await BackupCodec(db).export(
      into: dir,
      preferences: before.toBackup(),
    );
    // A credential never leaves in a file meant to be shared.
    expect(await file.readAsString(), isNot(contains('ghp_secret')));

    SharedPreferences.setMockInitialValues({});
    final fresh = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(fresh.close);
    final result = await BackupCodec(fresh).import(file);
    final after = AppSettings();
    await after.restoreBackup(result.preferences!);

    expect(after.alertDeltaWarn, 0.07);
    expect(after.alertTempWarn, 50);
    expect(after.chargeTargetSoc, isNull);
    expect(after.isMuted('cellSpread'), isTrue);
    expect(after.autoTripEnabled, isFalse);
    expect(after.screenAwake, ScreenAwake.always);
    expect(after.updateToken, '');
  });

  test('a backup from before settings travelled restores none', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final dir = await Directory.systemTemp.createTemp('jk-prefs');
    addTearDown(() => dir.delete(recursive: true));
    final file = await BackupCodec(db).export(into: dir);
    final result = await BackupCodec(db).import(file);
    expect(result.preferences, isNull);
  });
}
