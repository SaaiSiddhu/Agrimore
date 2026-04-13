import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration helper for accessing .env variables
class EnvConfig {
  // ============================================
  // FIREBASE WEB
  // ============================================
  static String get firebaseWebApiKey => 
      dotenv.env['FIREBASE_WEB_API_KEY'] ?? '';
  static String get firebaseWebAppId => 
      dotenv.env['FIREBASE_WEB_APP_ID'] ?? '';
  static String get firebaseWebMessagingSenderId => 
      dotenv.env['FIREBASE_WEB_MESSAGING_SENDER_ID'] ?? '';
  static String get firebaseWebProjectId => 
      dotenv.env['FIREBASE_WEB_PROJECT_ID'] ?? '';
  static String get firebaseWebAuthDomain => 
      dotenv.env['FIREBASE_WEB_AUTH_DOMAIN'] ?? '';
  static String get firebaseWebStorageBucket => 
      dotenv.env['FIREBASE_WEB_STORAGE_BUCKET'] ?? '';
  static String get firebaseWebMeasurementId => 
      dotenv.env['FIREBASE_WEB_MEASUREMENT_ID'] ?? '';

  // ============================================
  // FIREBASE ANDROID
  // ============================================
  static String get firebaseAndroidApiKey => 
      dotenv.env['FIREBASE_ANDROID_API_KEY'] ?? '';
  static String get firebaseAndroidAppId => 
      dotenv.env['FIREBASE_ANDROID_APP_ID'] ?? '';
  static String get firebaseAndroidMessagingSenderId => 
      dotenv.env['FIREBASE_ANDROID_MESSAGING_SENDER_ID'] ?? '';
  static String get firebaseAndroidProjectId => 
      dotenv.env['FIREBASE_ANDROID_PROJECT_ID'] ?? '';
  static String get firebaseAndroidStorageBucket => 
      dotenv.env['FIREBASE_ANDROID_STORAGE_BUCKET'] ?? '';

  // ============================================
  // FIREBASE IOS
  // ============================================
  static String get firebaseIosApiKey => 
      dotenv.env['FIREBASE_IOS_API_KEY'] ?? '';
  static String get firebaseIosAppId => 
      dotenv.env['FIREBASE_IOS_APP_ID'] ?? '';
  static String get firebaseIosMessagingSenderId => 
      dotenv.env['FIREBASE_IOS_MESSAGING_SENDER_ID'] ?? '';
  static String get firebaseIosProjectId => 
      dotenv.env['FIREBASE_IOS_PROJECT_ID'] ?? '';
  static String get firebaseIosStorageBucket => 
      dotenv.env['FIREBASE_IOS_STORAGE_BUCKET'] ?? '';
  static String get firebaseIosAndroidClientId => 
      dotenv.env['FIREBASE_IOS_ANDROID_CLIENT_ID'] ?? '';
  static String get firebaseIosClientId => 
      dotenv.env['FIREBASE_IOS_IOS_CLIENT_ID'] ?? '';
  static String get firebaseIosBundleId => 
      dotenv.env['FIREBASE_IOS_BUNDLE_ID'] ?? 'com.agrimore.agrimore';

  // ============================================
  // OTHER API KEYS
  // ============================================
  static String get razorpayKeyId => 
      dotenv.env['RAZORPAY_KEY_ID'] ?? '';
  static String get razorpayKeySecret => 
      dotenv.env['RAZORPAY_KEY_SECRET'] ?? '';
  static String get googleMapsApiKey => 
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  static String get geminiApiKey => 
      dotenv.env['GEMINI_API_KEY'] ?? '';

  /// Initialize environment variables - call this before runApp()
  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }
}
