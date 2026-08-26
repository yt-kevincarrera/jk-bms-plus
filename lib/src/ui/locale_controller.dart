import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which language the app shows.
///
/// Spanish is the default because that is what the person riding the bike
/// reads; [LanguageChoice.system] is offered for anyone who would rather follow
/// the phone.
enum LanguageChoice {
  spanish('es'),
  english('en'),
  system(null);

  const LanguageChoice(this.code);
  final String? code;

  Locale? get locale => code == null ? null : Locale(code!);

  static LanguageChoice fromCode(String? code) => switch (code) {
        'en' => LanguageChoice.english,
        'es' => LanguageChoice.spanish,
        _ => LanguageChoice.system,
      };
}

/// Holds the language choice and remembers it across restarts.
class LocaleController extends ChangeNotifier {
  static const _prefsKey = 'language_choice';

  LanguageChoice _choice = LanguageChoice.spanish;
  LanguageChoice get choice => _choice;

  Locale? get locale => _choice.locale;

  /// Loads the stored choice. Defaults to Spanish when nothing is stored, which
  /// is also what a fresh install gets.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      if (stored != null) {
        _choice = LanguageChoice.values.firstWhere(
          (c) => c.name == stored,
          orElse: () => LanguageChoice.spanish,
        );
        notifyListeners();
      }
    } on Exception catch (_) {
      // A missing or unreadable preference store is not worth failing over;
      // the default is perfectly usable.
    }
  }

  Future<void> set(LanguageChoice choice) async {
    if (choice == _choice) return;
    _choice = choice;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, choice.name);
    } on Exception catch (_) {
      // Same: the app still works this session, it just forgets next time.
    }
  }
}
