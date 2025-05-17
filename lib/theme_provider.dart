// In a new file, e.g., lib/theme_provider.dart
import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart'; // Uncomment for persistence

// const String _themePrefKey = 'appThemeMode'; // For shared_preferences

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system; // Default to system theme

  ThemeNotifier() {
    // _loadThemeMode(); // Uncomment for persistence
  }

  ThemeMode get currentThemeMode => _themeMode;

  // Call this method to toggle between light and dark mode.
  // For a more advanced cycle (Light -> Dark -> System), you can expand this.
  void toggleTheme(bool isCurrentlyDark) {
    _themeMode = isCurrentlyDark ? ThemeMode.light : ThemeMode.dark;
    // _saveThemeMode(_themeMode); // Uncomment for persistence
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    // _saveThemeMode(mode); // Uncomment for persistence
    notifyListeners();
  }

  /* Uncomment for persistence with shared_preferences
  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themePrefKey);
    if (themeIndex != null && themeIndex >= 0 && themeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeIndex];
    }
    notifyListeners(); // Notify even if it's the default, to ensure initial setup
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themePrefKey, mode.index);
  }
  */
}
