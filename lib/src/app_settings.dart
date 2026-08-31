import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The handful of things about this particular pack and rider that the app
/// cannot work out for itself.
///
/// Kept out of the code because the moment someone else's pack is involved,
/// a constant compiled into the binary becomes a lie about their battery.
class AppSettings extends ChangeNotifier {
  static const _hapticKey = 'haptic_alerts';
  static const _rawFramesKey = 'record_raw_frames';
  static const _updateTokenKey = 'github_update_token';
  // Key bumped: timestamps written before the version race was fixed record a
  // check that compared against 0.0.0, and honouring one would keep the wrong
  // answer alive for a day.
  static const _lastCheckKey = 'update_last_checked_at_v2';
  static const _dismissedKey = 'update_dismissed_version';
  static const _chargeTargetKey = 'charge_target_soc';
  static const _chargeWatchKey = 'charge_watch_enabled';
  static const _mutedKey = 'muted_alerts';
  static const _autoTripKey = 'auto_trip_enabled';



  /// A GitHub token, only for checking and fetching updates.
  ///
  /// Needed only while the repository is private: GitHub will not serve a
  /// private release to an anonymous request. Typed in by the rider and kept
  /// here rather than compiled into the app, because a token inside an APK is
  /// a token handed to anyone who gets the APK. It is sent to api.github.com
  /// and nowhere else.
  String updateToken = '';

  /// When the app last asked GitHub whether there is a newer build.
  ///
  /// Used to keep the quiet check to once a day. This is the only thing this
  /// app does on the network without being asked, and it is one request that
  /// sends nothing about the pack, the rides or where you are.
  DateTime? lastUpdateCheck;

  /// A version the rider has already waved away, so the banner stays gone
  /// until there is a newer one. Dismissing is an answer, not a snooze.
  String dismissedUpdateVersion = '';

  /// Charge level to announce, or null for only telling you when it is done.
  ///
  /// Defaults to 80: the top of the range is where calendar ageing happens,
  /// and a rider who does not need the whole pack tomorrow is better off
  /// stopping there. The app suggests it rather than enforcing it.
  double? chargeTargetSoc = 80;

  /// Whether to hold the Bluetooth link open while the pack charges.
  ///
  /// Off by default. It costs phone battery for as long as a charge lasts, and
  /// that is a trade nobody should be opted into: the alerts still work with
  /// the app open, this is only for reaching you with it closed.
  bool chargeWatchEnabled = false;

  /// Whether rides open and close themselves.
  ///
  /// On by default, unlike the charge watch. The whole reason it exists is not
  /// having to remember, and a feature that solves forgetting only once you
  /// remember to switch it on solves nothing.
  bool autoTripEnabled = true;

  /// Alerts the rider has switched off, by name.
  ///
  /// Individually rather than all at once. Somebody who does not care that the
  /// charger runs warm still wants to know the charge finished, and an app
  /// whose only option is silence gets silenced entirely.
  Set<String> mutedAlerts = <String>{};

  bool isMuted(String alert) => mutedAlerts.contains(alert);

  /// Whether the phone buzzes when something crosses a line.


  bool hapticAlerts = true;

  /// Whether the 300-byte frames are kept. On by default and worth leaving on:
  /// it is what makes a wrongly-decoded byte offset recoverable rather than
  /// months of history lost.
  bool recordRawFrames = true;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      hapticAlerts = prefs.getBool(_hapticKey) ?? true;
      recordRawFrames = prefs.getBool(_rawFramesKey) ?? true;
      updateToken = prefs.getString(_updateTokenKey) ?? '';
      final at = prefs.getInt(_lastCheckKey);
      lastUpdateCheck =
          at == null ? null : DateTime.fromMillisecondsSinceEpoch(at, isUtc: true);
      dismissedUpdateVersion = prefs.getString(_dismissedKey) ?? '';
      // A stored -1 means the rider turned it off, which is different from
      // never having chosen.
      final target = prefs.getDouble(_chargeTargetKey);
      chargeTargetSoc = target == null ? 80 : (target < 0 ? null : target);
      chargeWatchEnabled = prefs.getBool(_chargeWatchKey) ?? false;
      mutedAlerts = (prefs.getStringList(_mutedKey) ?? const []).toSet();
      autoTripEnabled = prefs.getBool(_autoTripKey) ?? true;
      notifyListeners();
    } on Exception catch (_) {
      // Defaults are usable; a broken preference store is not worth failing on.
    }
  }


  Future<void> setUpdateToken(String value) async {
    updateToken = value.trim();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_updateTokenKey, updateToken);
    } on Exception catch (_) {
      // The token is a convenience; failing to keep it just means retyping.
    }
  }

  Future<void> markUpdateChecked(DateTime at) async {
    lastUpdateCheck = at;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastCheckKey, at.millisecondsSinceEpoch);
    } on Exception catch (_) {
      // Worst case it checks again sooner than it needed to.
    }
  }

  Future<void> dismissUpdate(String version) async {
    dismissedUpdateVersion = version;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dismissedKey, version);
    } on Exception catch (_) {
      // The banner comes back next launch, which is a tolerable failure.
    }
  }

  Future<void> setChargeTarget(double? soc) async {
    chargeTargetSoc = soc;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_chargeTargetKey, soc ?? -1);
    } on Exception catch (_) {
      // Kept for this session at least.
    }
  }

  Future<void> setChargeWatch(bool value) async {
    chargeWatchEnabled = value;
    notifyListeners();
    await _writeBool(_chargeWatchKey, value);
  }

  Future<void> setAlertMuted(String alert, bool muted) async {
    if (muted) {
      mutedAlerts.add(alert);
    } else {
      mutedAlerts.remove(alert);
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_mutedKey, mutedAlerts.toList());
    } on Exception catch (_) {
      // Silenced for this session at least.
    }
  }

  Future<void> setAutoTrip(bool value) async {
    autoTripEnabled = value;
    notifyListeners();
    await _writeBool(_autoTripKey, value);
  }

  Future<void> setHapticAlerts(bool value) async {



    hapticAlerts = value;
    notifyListeners();
    await _writeBool(_hapticKey, value);
  }

  Future<void> setRecordRawFrames(bool value) async {
    recordRawFrames = value;
    notifyListeners();
    await _writeBool(_rawFramesKey, value);
  }

  Future<void> _writeBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } on Exception catch (_) {
      // Same.
    }
  }
}
