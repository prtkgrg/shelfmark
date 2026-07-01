import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.dark);
  static const _key = 'theme_mode';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    mode.value = switch (raw) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
  }

  static Future<void> setMode(ThemeMode newMode) async {
    mode.value = newMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, newMode.name);
  }
}
