import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'app_settings.dart';
import 'ble/proximity_watcher.dart';
import 'bms_service.dart';
import 'data/repository.dart';
import 'ui/connect_screen.dart';
import 'ui/locale_controller.dart';
import 'ui/theme.dart';
import 'update/app_version.dart';
import 'update/update_service.dart';

import 'package:package_info_plus/package_info_plus.dart';

/// Root of the app.
///
/// [BmsService] is created once here and handed down. There is deliberately no
/// factory, no per-screen instance and no service locator that could hand out a
/// second one: the BMS accepts a single BLE connection, so a second service
/// would fight the first for the channel.
class JkBmsApp extends StatefulWidget {
  const JkBmsApp({super.key});

  @override
  State<JkBmsApp> createState() => _JkBmsAppState();
}

class _JkBmsAppState extends State<JkBmsApp> {
  late final BmsService _service = BmsService();
  final LocaleController _locale = LocaleController();
  final BmsRepository _repository = BmsRepository();
  final ProximityWatcher _proximity = ProximityWatcher();
  final AppSettings _settings = AppSettings();

  /// Seeded with 0.0.0 until the platform reports the real one, so a failed
  /// lookup can never make a stale build look newer than what is published.
  final UpdateService _updates =
      UpdateService(currentVersion: const AppVersion(0, 0, 0));

  @override
  void initState() {
    super.initState();
    _locale.load();
    _service.repository = _repository;
    _service.notifications.ensureInitialised(
      channelName: 'Trip recording',
      channelDescription:
          'Keeps a trip recording with the screen off or another app open.',
    );
    // Cheap, and better done at every start than when the phone is already
    // full: raw frames are the biggest thing this app writes.
    _repository.pruneRawFrames();
    _proximity.load();
    _loadSettings();
    _loadVersion();
  }

  /// Reads the version Android has installed, which is the only figure that
  /// can be compared against a published release.
  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final parsed = AppVersion.tryParse(info.version);
      if (parsed != null && mounted) {
        setState(() => _updates.currentVersion = parsed);
      }
    } on Object catch (_) {
      // Leaves 0.0.0, which shows every release as newer. Visibly wrong beats
      // silently claiming to be up to date.
    }
  }

  @override
  void dispose() {

    _service.dispose();
    _repository.dispose();
    _proximity.dispose();
    _settings.dispose();
    _updates.dispose();
    _locale.dispose();
    super.dispose();
  }

  /// Settings live in preferences and are pushed into the service, so nothing
  /// below the UI has to know where they came from.
  Future<void> _loadSettings() async {
    await _settings.load();
    _updates.token = _settings.updateToken;
    _service.applySettings(
      haptics: _settings.hapticAlerts,
      rawFrames: _settings.recordRawFrames,
    );

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _locale,
      builder: (context, _) => MaterialApp(
        title: 'JK BMS +',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        // Spanish unless the rider says otherwise. `locale: null` hands the
        // choice back to the phone.
        locale: _locale.locale,
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        localeResolutionCallback: (deviceLocale, supported) {
          if (_locale.locale != null) return _locale.locale;
          for (final l in supported) {
            if (l.languageCode == deviceLocale?.languageCode) return l;
          }
          return const Locale('es');
        },
        home: ConnectScreen(
          service: _service,
          localeController: _locale,
          proximity: _proximity,
          settings: _settings,
          updateService: _updates,
        ),
      ),
    );
  }
}
