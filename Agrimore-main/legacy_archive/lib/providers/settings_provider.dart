import 'package:flutter/material.dart';
import '../services/shared_preferences_service.dart';

class SettingsProvider with ChangeNotifier {
  bool _notificationsEnabled = true;
  bool _pushNotificationsEnabled = true;
  bool _emailNotificationsEnabled = true;
  bool _smsNotificationsEnabled = false;
  bool _orderUpdatesEnabled = true;
  bool _promotionalNotificationsEnabled = true;
  bool _biometricEnabled = false;
  String _language = 'English';
  String _currency = 'INR';

  // Getters
  bool get notificationsEnabled => _notificationsEnabled;
  bool get pushNotificationsEnabled => _pushNotificationsEnabled;
  bool get emailNotificationsEnabled => _emailNotificationsEnabled;
  bool get smsNotificationsEnabled => _smsNotificationsEnabled;
  bool get orderUpdatesEnabled => _orderUpdatesEnabled;
  bool get promotionalNotificationsEnabled => _promotionalNotificationsEnabled;
  bool get biometricEnabled => _biometricEnabled;
  String get language => _language;
  String get currency => _currency;

  SettingsProvider() {
    _loadSettings();
  }

  // Load settings from storage
  Future<void> _loadSettings() async {
    _notificationsEnabled = 
        SharedPreferencesService.getBool('notifications_enabled') ?? true;
    _pushNotificationsEnabled = 
        SharedPreferencesService.getBool('push_notifications_enabled') ?? true;
    _emailNotificationsEnabled = 
        SharedPreferencesService.getBool('email_notifications_enabled') ?? true;
    _smsNotificationsEnabled = 
        SharedPreferencesService.getBool('sms_notifications_enabled') ?? false;
    _orderUpdatesEnabled = 
        SharedPreferencesService.getBool('order_updates_enabled') ?? true;
    _promotionalNotificationsEnabled = 
        SharedPreferencesService.getBool('promotional_notifications_enabled') ?? true;
    _biometricEnabled = 
        SharedPreferencesService.getBool('biometric_enabled') ?? false;
    _language = 
        SharedPreferencesService.getString('language') ?? 'English';
    _currency = 
        SharedPreferencesService.getString('currency') ?? 'INR';
    
    notifyListeners();
  }

  // Toggle notifications
  Future<void> toggleNotifications(bool value) async {
    _notificationsEnabled = value;
    await SharedPreferencesService.setBool('notifications_enabled', value);
    
    // If disabling all notifications, disable sub-options too
    if (!value) {
      await togglePushNotifications(false);
      await toggleEmailNotifications(false);
      await toggleSmsNotifications(false);
    }
    
    notifyListeners();
  }

  // Toggle push notifications
  Future<void> togglePushNotifications(bool value) async {
    _pushNotificationsEnabled = value;
    await SharedPreferencesService.setBool('push_notifications_enabled', value);
    notifyListeners();
  }

  // Toggle email notifications
  Future<void> toggleEmailNotifications(bool value) async {
    _emailNotificationsEnabled = value;
    await SharedPreferencesService.setBool('email_notifications_enabled', value);
    notifyListeners();
  }

  // Toggle SMS notifications
  Future<void> toggleSmsNotifications(bool value) async {
    _smsNotificationsEnabled = value;
    await SharedPreferencesService.setBool('sms_notifications_enabled', value);
    notifyListeners();
  }

  // Toggle order updates
  Future<void> toggleOrderUpdates(bool value) async {
    _orderUpdatesEnabled = value;
    await SharedPreferencesService.setBool('order_updates_enabled', value);
    notifyListeners();
  }

  // Toggle promotional notifications
  Future<void> togglePromotionalNotifications(bool value) async {
    _promotionalNotificationsEnabled = value;
    await SharedPreferencesService.setBool('promotional_notifications_enabled', value);
    notifyListeners();
  }

  // Toggle biometric authentication
  Future<void> toggleBiometric(bool value) async {
    _biometricEnabled = value;
    await SharedPreferencesService.setBool('biometric_enabled', value);
    notifyListeners();
  }

  // Change language
  Future<void> changeLanguage(String language) async {
    _language = language;
    await SharedPreferencesService.setString('language', language);
    notifyListeners();
  }

  // Change currency
  Future<void> changeCurrency(String currency) async {
    _currency = currency;
    await SharedPreferencesService.setString('currency', currency);
    notifyListeners();
  }

  // Reset all settings to default
  Future<void> resetToDefaults() async {
    await toggleNotifications(true);
    await togglePushNotifications(true);
    await toggleEmailNotifications(true);
    await toggleSmsNotifications(false);
    await toggleOrderUpdates(true);
    await togglePromotionalNotifications(true);
    await toggleBiometric(false);
    await changeLanguage('English');
    await changeCurrency('INR');
  }

  // Get notification summary
  String get notificationSummary {
    if (!_notificationsEnabled) return 'All notifications disabled';
    
    final List<String> enabled = [];
    if (_pushNotificationsEnabled) enabled.add('Push');
    if (_emailNotificationsEnabled) enabled.add('Email');
    if (_smsNotificationsEnabled) enabled.add('SMS');
    
    if (enabled.isEmpty) return 'No notification channels enabled';
    return enabled.join(', ') + ' enabled';
  }
}
