import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'app_settings.dart';
import 'ble/proximity_watcher.dart';
import 'bms_service.dart';
import 'data/repository.dart';
import 'license/entitlements.dart';
import 'license/license_controller.dart';
import 'ui/license_scope.dart';
import 'ui/connect_screen.dart';
import 'ui/locale_controller.dart';
import 'ui/theme.dart';
import 'platform/pack_widget.dart';
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

  /// What this phone has paid for. One instance, handed down through
  /// [LicenseScope]; loaded before the settings so a preference the licence
  /// does not cover is never pushed into the service.
  final LicenseController _license = LicenseController();

  /// Seeded with 0.0.0 until the platform reports the real one, so a failed
  /// lookup can never make a stale build look newer than what is published.
  final UpdateService _updates = UpdateService();

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
    _repository.compactSnapshots();
    // Every pack, at startup, because the saved-pack screen reads history with
    // no radio involved and was showing figures the app already knew how to
    // mend. Finds nothing after the first pass.
    _repairOldRides();
    _proximity.load();
    _loadSettings();
    _loadVersion();
  }

  /// Measures again the rides recorded before the integration bug was fixed.
  Future<void> _repairOldRides() async {
    final report = await _repository.repairAllTripEnergy();
    // Only a redraw, so a screen already open picks up the mended figures
    // rather than waiting to be reopened.
    if (report.didAnything && mounted) setState(() {});
  }

  /// Reads the version Android has installed, which is the only figure that
  /// can be compared against a published release.
  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final parsed = AppVersion.tryParse(info.version);
      if (parsed != null && mounted) {
        setState(() => _updates.version = parsed);
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
    _license.dispose();
    _updates.dispose();
    _locale.dispose();
    super.dispose();
  }

  /// Settings live in preferences and are pushed into the service, so nothing
  /// below the UI has to know where they came from.
  Future<void> _loadSettings() async {
    await _license.load();
    await _settings.load();
    _updates.token = _settings.updateToken;
    // Holding the link open for a closed app is Pro. The preference is kept
    // as the rider set it, so it comes back the day a key is activated, but
    // the service only hears about it when the licence covers it.
    final watchCharge =
        _settings.chargeWatchEnabled &&
        _license.entitlements.allows(Feature.backgroundAlerts);
    _service.applySettings(
      haptics: _settings.hapticAlerts,
      rawFrames: _settings.recordRawFrames,
      chargeTargetSoc: _settings.chargeTargetSoc,
      watchCharge: watchCharge,
      autoTrip: _settings.autoTripEnabled,
      watchLink: _settings.linkWatchEnabled,
      muted: _settings.mutedAlerts,
    );

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LicenseScope(
      controller: _license,
      child: ListenableBuilder(
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
          home: Builder(
            builder: (context) {
              // The widget's age line is written in the app's language, so the
              // strings are handed down once the localisations exist.
              final t = AppL10n.of(context);
              _service.widgetStrings = PackWidgetStrings(
                justNow: t.widgetJustNow,
                minutesAgo: (n) => t.widgetMinutes('$n'),
                hoursAgo: (n) => t.widgetHours('$n'),
                daysAgo: (n) => t.widgetDays('$n'),
              );
              _service.chargeWatchTitle = t.chargeWatchNotifTitle;
              _service.chargeWatchText = (s) => s == null
                  ? ''
                  : t.chargeWatchNotifText(
                      s.soc.toStringAsFixed(0),
                      s.packVoltage.toStringAsFixed(1),
                      s.current.toStringAsFixed(1),
                    );
              // The notification for merely being connected. Its whole job is to
              // let the screen sleep without the readings stopping, so it shows
              // the reading rather than saying the app is running.
              // Set here rather than only when a ride is started by hand. An
              // auto-started trip got the English default and an empty body, and
              // with the screen off that notification is the only thing the
              // rider can see of a ride in progress.
              _service.notificationTitle = t.tripNotificationTitle;
              _service.notificationText = (trip, snapshot) {
                final consumption = trip.whPerKm;
                return [
                  '${trip.speedKmh.toStringAsFixed(0)} km/h',
                  '${trip.distanceKm.toStringAsFixed(2)} km',
                  if (snapshot != null) '${snapshot.soc.toStringAsFixed(0)} %',
                  if (consumption != null)
                    '${consumption.toStringAsFixed(0)} Wh/km',
                ].join('  ·  ');
              };
              _service.downloadTitle = t.downloadNotifTitle;
              _service.downloadText = (pct) => t.downloadNotifText('$pct');
              // The update service does not know about foreground services and
              // should not: it reports, and the one object that owns the service
              // decides.
              _updates.onDownloadProgress = _service.reportDownloadProgress;
              _service.linkWatchTitle = t.linkWatchNotifTitle;
              _service.linkWatchText = (s) => s == null
                  ? t.linkWatchNotifWaiting
                  : t.linkWatchNotifText(
                      s.soc.toStringAsFixed(0),
                      s.packVoltage.toStringAsFixed(1),
                      s.current.toStringAsFixed(1),
                    );
              return ConnectScreen(
                service: _service,
                localeController: _locale,
                proximity: _proximity,
                settings: _settings,
                updateService: _updates,
              );
            },
          ),
        ),
      ),
    );
  }
}
