// ============================================================
//  Firebase App Check — Phase 17, Workstream 2
// ============================================================
//
// INTEGRATION + MONITORING ONLY. This activates App Check on every client
// so the App Check console can show what fraction of traffic is verified —
// it does NOT reject anything. No callable in functions/src sets
// `enforceAppCheck: true`, and enforcement is not enabled in the Firebase
// console either. Do not add either without an explicit, separate owner
// decision — see the Phase 17 completion report's rollout runbook.
//
// Why monitoring mode still has value before enforcement: attestation
// happens and is visible in the App Check metrics dashboard immediately,
// which is exactly the signal the owner needs to decide when it's safe to
// flip enforcement on per-service — without it, that decision would be a
// guess. It does not stop an attacker today; it proves the real clients
// attest correctly and measures how much traffic doesn't, so enforcement
// day one doesn't lock out a device type nobody thought to test.
//
// Providers:
//   Android: Play Integrity in release builds, the debug provider in debug
//            builds (gated on kDebugMode) — a debug build must never
//            require a real device attestation.
//   iOS:     App Attest in release, debug provider in debug. NOT verified
//            on this development machine (Xcode command-line tools only,
//            no full Xcode install, no iOS Simulator available here) — the
//            code is written to the documented API shape but its actual
//            behavior on a real iOS build is unconfirmed by this session.
//   Web:     reCAPTCHA v3. The site key is NOT a secret (App Check's own
//            docs: it's meant to be embedded in client code, same as a
//            Firebase web config value) but is still not invented here —
//            see kRecaptchaV3SiteKey below for the exact owner step.
//
// No debug token is hardcoded anywhere in this file or committed to the
// repository. A physical/emulator debug build will print its own
// auto-generated debug token to the device log on first run; the owner
// registers that token in Firebase Console → App Check → Apps → (app) →
// Manage debug tokens. Never commit a debug token to source control.

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

class AppCheckService {
  AppCheckService._();

  // Phase 17, Workstream 2 configuration point: replace with the real
  // reCAPTCHA v3 site key from Firebase Console → App Check → Apps → Web
  // app → reCAPTCHA v3 → register. Not a secret value, but a real key is
  // required for web App Check to activate at all — until replaced, web
  // clients simply won't attest (monitoring mode, so this fails open, not
  // closed).
  static const String kRecaptchaV3SiteKey = 'REPLACE_WITH_RECAPTCHA_V3_SITE_KEY';

  static Future<void> activate() async {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
        webProvider: kIsWeb ? ReCaptchaV3Provider(kRecaptchaV3SiteKey) : null,
      );
    } catch (_) {
      // App Check is a monitoring layer in this phase, not an authorization
      // gate — a failure to activate it (e.g. Play Integrity not yet
      // configured in the Play Console) must never block app startup or
      // any Firebase call. Silently degrading to "unattested" here is safe
      // by design; it will simply show up as unverified traffic in the App
      // Check console, exactly what monitoring mode is for.
    }
  }
}
