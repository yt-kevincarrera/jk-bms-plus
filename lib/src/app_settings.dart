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



  /// A GitHub token, only for checking and fetching updates.
  ///
  /// Needed only while the repository is private: GitHub will not serve a
  /// private release to an anonymous request. Typed in by the rider and kept
  /// here rather than compiled into the app, because a token inside an APK is
  /// a token handed to anyone who gets the APK. It is sent to api.github.com
  /// and nowhere else.
  String updateToken = '';

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
