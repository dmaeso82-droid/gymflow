import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GymFlowThemePreference { system, light, dark }

class ThemeController {
  static const String _storageKey = 'gymflow_theme_preference';
  static final ValueNotifier<GymFlowThemePreference> preference =
      ValueNotifier<GymFlowThemePreference>(GymFlowThemePreference.system);

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);
    preference.value = _fromStorage(stored);
  }

  static ThemeMode get themeMode {
    switch (preference.value) {
      case GymFlowThemePreference.light:
        return ThemeMode.light;
      case GymFlowThemePreference.dark:
        return ThemeMode.dark;
      case GymFlowThemePreference.system:
        return ThemeMode.system;
    }
  }

  static Future<void> setPreference(GymFlowThemePreference value) async {
    preference.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, value.name);
  }

  static GymFlowThemePreference _fromStorage(String? value) {
    for (final option in GymFlowThemePreference.values) {
      if (option.name == value) return option;
    }
    return GymFlowThemePreference.system;
  }
}



