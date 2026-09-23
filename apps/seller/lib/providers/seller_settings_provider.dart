import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// M-11 device preferences (SELLER-ACCOUNT-1b). Theme is per device, so it
/// lives in shared_preferences, not Firestore.
class SellerSettingsProvider extends ChangeNotifier {
  SellerSettingsProvider({SharedPreferences? prefs}) : _prefs = prefs {
    _themeMode = _decode(_prefs?.getString(_themeKey));
  }

  static const String _themeKey = 'seller.themeMode';
  SharedPreferences? _prefs;
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  static ThemeMode _decode(String? v) => switch (v) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  /// Loads the stored preference once shared_preferences is available.
  Future<void> load() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      _themeMode = _decode(_prefs!.getString(_themeKey));
      notifyListeners();
    } catch (e) {
      debugPrint('Settings load failed: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(_themeKey, mode.name);
    } catch (e) {
      debugPrint('Settings save failed: $e');
    }
  }
}
