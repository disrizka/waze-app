import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider with ChangeNotifier {
  Locale? _locale;

  // Tetap: default English untuk konsumsi MaterialApp yang butuh non-null
  Locale get locale => _locale ?? const Locale('en');

  // Baru: akses nilai mentah (null = ikut sistem)
  Locale? get localeRaw => _locale;

  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('locale_code');
    if (code != null && code.isNotEmpty) {
      _locale = Locale(code);
    } else {
      _locale = const Locale('en');
    }
    notifyListeners();
  }

  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove('locale_code');
    } else {
      await prefs.setString('locale_code', locale.languageCode);
    }
    notifyListeners();
  }
}
