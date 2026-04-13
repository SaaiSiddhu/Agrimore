// lib/helpers/ad_helper.dart
import 'dart:io';

class AdHelper {
  // ========================================
  // BANNER AD UNITS
  // ========================================

  /// Main Banner Ad Unit (Shop Screen - Bottom Navigation)
  /// Used in: main shop screen, home screen, auth screen
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-4374614015135326/9177975881';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-4374614015135326/9177975881';
    }
    throw UnsupportedError('Unsupported platform');
  }

  /// Checkout Banner Ad Unit (Checkout Screen - Below Address Section)
  /// Used in: checkout_screen.dart
  static String get checkoutBannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-4374614015135326/9177975881'; // Use same ID or create new one
    } else if (Platform.isIOS) {
      return 'ca-app-pub-4374614015135326/9177975881'; // Use same ID or create new one
    }
    throw UnsupportedError('Unsupported platform');
  }

  /// Profile Banner Ad Unit (Profile Screen - After Logout Button)
  /// Used in: profile_screen.dart
  static String get profileBannerBottomAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-4374614015135326/2789920683';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-4374614015135326/2789920683';
    }
    throw UnsupportedError('Unsupported platform');
  }

  // ========================================
  // NATIVE ADVANCED AD UNITS
  // ========================================

  /// Native Advanced Ad (Product Lists, Feed Items)
  /// Used in: product lists, feed items
  static String get nativeAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-4374614015135326/8925026144';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-4374614015135326/8925026144';
    }
    throw UnsupportedError('Unsupported platform');
  }

  // ========================================
  // REWARDED AD UNITS (Test IDs for now)
  // ========================================

  /// Rewarded Ads (For rewards, bonuses, etc.)
  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917'; // Test ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313'; // Test ID
    }
    throw UnsupportedError('Unsupported platform');
  }

  // ========================================
  // INTERSTITIAL AD UNITS (Optional - Add if needed)
  // ========================================

  /// Interstitial Ad Unit (Full screen ads between screens)
  /// Uncomment and add real IDs when you create interstitial ad units
  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712'; // Test ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910'; // Test ID
    }
    throw UnsupportedError('Unsupported platform');
  }
}