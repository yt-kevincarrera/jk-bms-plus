import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a new installation follows the system', () async {
    final settings = AppSettings();
    await settings.load();
    expect(settings.appearance, AppAppearance.system);
  });

  test('an explicit appearance survives restarting settings', () async {
    final settings = AppSettings();
    for (final choice in AppAppearance.values) {
      await settings.setAppearance(choice);
      final restored = AppSettings();
      await restored.load();
      expect(restored.appearance, choice);
    }
  });

  test('unknown persisted choices fall back to the system', () async {
    SharedPreferences.setMockInitialValues({'app_appearance': 'unknown'});
    final settings = AppSettings();
    await settings.load();
    expect(settings.appearance, AppAppearance.system);
  });

  test('backup restores appearance and older backups leave it alone', () async {
    final original = AppSettings();
    await original.setAppearance(AppAppearance.light);
    final restored = AppSettings();
    await restored.restoreBackup(original.toBackup());
    expect(restored.appearance, AppAppearance.light);
    await restored.restoreBackup({'hapticAlerts': false});
    await restored.restoreBackup({'appearance': 'unknown'});
    expect(restored.appearance, AppAppearance.light);
    expect(restored.hapticAlerts, isFalse);
  });
}
