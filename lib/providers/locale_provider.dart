import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Key for storing the chosen UI language in SharedPreferences.
const _kLocaleKey = 'app_locale_v1';

/// Locales the app ships translations for.
const supportedLocales = [Locale('en'), Locale('ru')];

/// Default UI locale: English.
const _defaultLocale = Locale('en');

/// Holds the user's chosen UI language, persisted to SharedPreferences.
///
/// Loading from SharedPreferences starts in the constructor and falls back
/// to [_defaultLocale] (English) until it completes or if no value was
/// stored yet.
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(_defaultLocale) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kLocaleKey);
    if (code == null) return;
    final match = supportedLocales.firstWhere(
      (l) => l.languageCode == code,
      orElse: () => _defaultLocale,
    );
    state = match;
  }

  Future<void> set(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, locale.languageCode);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});
