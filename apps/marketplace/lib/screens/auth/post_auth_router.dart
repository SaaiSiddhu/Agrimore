// ============================================================
//  Phase 16, Workstream 6 — shared post-authentication routing decision
// ============================================================
//
// Both otp_verification_screen.dart (when notifications are already primed
// on this device) and enable_notifications_screen.dart (when they aren't)
// are exit points that used to jump straight to onboardingAddress/main.
// Both now go through this single decision instead, so the
// profile-completion gate can't be bypassed by whichever exit point a given
// session happens to take.
//
// This is a SECOND checkpoint alongside auth_wrapper.dart's cold-start
// gate, not a replacement for it — see auth_wrapper.dart's header comment
// for why both are needed (this one covers the immediate post-verification
// transition, which never passes through AuthWrapper's widget tree at all
// since it's a pushNamedAndRemoveUntil that clears the whole stack).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/routes.dart';
import '../../providers/auth_provider.dart';

class PostAuthRouter {
  PostAuthRouter._();

  static void routeAfterAuth(
    BuildContext context, {
    required String phone,
    required bool isNewUser,
  }) {
    final authProvider = context.read<AuthProvider>();
    final needsProfile = authProvider.needsProfileCompletion;

    final destination = needsProfile
        ? AppRoutes.completeProfile
        : (isNewUser ? AppRoutes.onboardingAddress : AppRoutes.main);

    Navigator.of(context).pushNamedAndRemoveUntil(
      destination,
      (route) => false,
      arguments: needsProfile ? {'phone': phone} : null,
    );
  }
}
