import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Canonical outline icon set for AgriMore Sales Associate.
///
/// Maps the 20 canonical Lucide outline icons defined in the
/// "Icon system" canonical reference board (assets/Canonical/Icon system.png).
///
/// Touch targets: minimum 48×48 px container with centered 24px icon.
/// Standard sizes:
/// - Supporting: 16 px ([SaTokens.iconSupporting])
/// - Controls: 20 px ([SaTokens.iconControl])
/// - Navigation: 24 px ([SaTokens.iconNav])
abstract final class SaIcons {
  SaIcons._();

  /// Phone outline icon (contact, phone auth).
  static const IconData phone = LucideIcons.phone;

  /// Mail outline icon (email auth, correspondence).
  static const IconData mail = LucideIcons.mail;

  /// Lock / Keyhole outline icon (passwords, secure auth).
  static const IconData lockKeyhole = LucideIcons.lock;

  /// Eye outline icon (password visible).
  static const IconData eye = LucideIcons.eye;

  /// Eye-off outline icon (password hidden).
  static const IconData eyeOff = LucideIcons.eyeOff;

  /// Arrow-left outline icon (app bar back navigation).
  static const IconData arrowLeft = LucideIcons.arrowLeft;

  /// X outline icon (close, clear, dismiss).
  static const IconData x = LucideIcons.x;

  /// Info outline icon (informational banners, tooltips).
  static const IconData info = LucideIcons.info;

  /// Circle-check outline icon (success states, verified).
  static const IconData circleCheck = LucideIcons.checkCircle;

  /// Triangle-alert outline icon (warnings).
  static const IconData triangleAlert = LucideIcons.alertTriangle;

  /// Circle-alert outline icon (validation errors, alerts).
  static const IconData circleAlert = LucideIcons.alertCircle;

  /// Rotate-ccw outline icon (retry, refresh, resend OTP).
  static const IconData rotateCcw = LucideIcons.rotateCcw;

  /// Headphones outline icon (support, help).
  static const IconData headphones = LucideIcons.headphones;

  /// Log-out outline icon (sign out).
  static const IconData logOut = LucideIcons.logOut;

  /// Wallet outline icon (commissions, payouts).
  static const IconData wallet = LucideIcons.wallet;

  /// Shopping-bag outline icon (orders, catalog).
  static const IconData shoppingBag = LucideIcons.shoppingBag;

  /// User outline icon (profile, account).
  static const IconData user = LucideIcons.user;

  /// Bell outline icon (notifications).
  static const IconData bell = LucideIcons.bell;

  /// Copy outline icon (copy associate code, referral links).
  static const IconData copy = LucideIcons.copy;

  /// Share2 outline icon (share code, share app).
  static const IconData share2 = LucideIcons.share2;
}
