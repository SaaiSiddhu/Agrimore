import 'package:agrimore_services/agrimore_services.dart' show PendingGoogleIdentity;
import 'package:firebase_auth/firebase_auth.dart' show GoogleAuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seller/providers/seller_auth_provider.dart';
import 'package:seller/screens/auth/email_sign_in_screen.dart';
import 'package:seller/screens/auth/seller_sign_in_screen.dart';

import '../support/seller_fixtures.dart';
import 'visual_harness.dart';

/// Boards 16-01 and 16-02: sign-in, Google mobile verification, email, OTP.
void main() {
  setUpAll(loadSellerFonts);
  const phone = '+919876543210';
  final cases = <(String, Widget, SellerAuthProvider Function(), Brightness, Size)>[
    ('auth_signin_light', const SellerSignInScreen(), SellerAuthProvider.preview, Brightness.light, const Size(390, 900)),
    ('auth_signin_dark', const SellerSignInScreen(), SellerAuthProvider.preview, Brightness.dark, const Size(390, 900)),
    ('auth_signin_desktop', const SellerSignInScreen(), SellerAuthProvider.preview, Brightness.light, const Size(1280, 800)),
    (
      'auth_google_verify',
      const SellerSignInScreen(),
      () => SellerAuthProvider.preview(
            pendingGoogle: PendingGoogleIdentity(
              credential: GoogleAuthProvider.credential(idToken: 'test-token'),
              idToken: 'test-token',
              email: 'seller@example.com',
            ),
          ),
      Brightness.light,
      const Size(390, 900),
    ),
    ('auth_email', const EmailSignInScreen(), SellerAuthProvider.preview, Brightness.light, const Size(390, 844)),
    ('auth_otp_light', const SellerSignInScreen(), () => SellerAuthProvider.preview(pendingPhone: phone), Brightness.light, const Size(390, 700)),
    (
      'auth_otp_wrong_dark',
      const SellerSignInScreen(),
      () => SellerAuthProvider.preview(pendingPhone: phone, error: SellerAuthError.invalidCode),
      Brightness.dark,
      const Size(390, 700),
    ),
  ];
  for (final (name, screen, auth, b, size) in cases) {
    testWidgets(name, (tester) async {
      await pumpSellerApp(tester, screen, auth: auth(), brightness: b, size: size);
      expect(tester.takeException(), isNull);
      await qaCapture(tester, name);
    });
  }
}
