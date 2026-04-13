import 'package:flutter/material.dart';
import '../services/shared_preferences_service.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadThemeMode();
  }

  // Load theme mode from storage
  Future<void> _loadThemeMode() async {
    _isDarkMode = SharedPreferencesService.isDarkMode();
    notifyListeners();
  }

  // Toggle theme mode
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await SharedPreferencesService.setThemeMode(_isDarkMode);
    notifyListeners();
  }

  // Set theme mode
  Future<void> setThemeMode(bool isDark) async {
    _isDarkMode = isDark;
    await SharedPreferencesService.setThemeMode(isDark);
    notifyListeners();
  }

  // Get theme mode
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;
}
