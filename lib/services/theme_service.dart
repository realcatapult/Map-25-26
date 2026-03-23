import 'package:flutter/material.dart';

class ThemeService {
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(
    ThemeMode.light,
  );

  static bool get isDark => themeMode.value == ThemeMode.dark;

  static void setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
  }
}
