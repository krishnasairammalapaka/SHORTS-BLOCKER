import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  ThemeController._();

  static final ThemeController instance = ThemeController._();
  static const _prefKey = 'theme_mode_dark';

  final ValueNotifier<ThemeMode> mode = ValueNotifier<ThemeMode>(ThemeMode.light);

  bool get isDark => mode.value == ThemeMode.dark;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_prefKey) ?? false;
    mode.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> setDarkMode(bool enabled) async {
    if (mode.value == (enabled ? ThemeMode.dark : ThemeMode.light)) {
      return;
    }
    mode.value = enabled ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
  }
}
