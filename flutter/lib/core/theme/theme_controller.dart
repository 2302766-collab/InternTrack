import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeController(this._preferences)
    : _isDarkMode = _preferences.getBool(_preferenceKey) ?? false;

  static const String _preferenceKey = 'is_dark_mode_enabled';

  final SharedPreferences _preferences;
  bool _isDarkMode;

  static Future<ThemeController> create() async {
    final preferences = await SharedPreferences.getInstance();
    return ThemeController(preferences);
  }

  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) {
      return;
    }

    _isDarkMode = value;
    notifyListeners();
    await _preferences.setBool(_preferenceKey, value);
  }
}
