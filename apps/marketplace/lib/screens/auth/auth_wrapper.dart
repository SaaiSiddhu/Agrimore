// ============================================================
//  AUTH WRAPPER — decides where the user lands on app open
//  OLD USERS  → already logged-in, complete profile → Home (no flicker)
//  INCOMPLETE → logged-in, profile not complete      → Complete Profile
//  NEW USERS  → not logged-in                        → Login screen
// ============================================================
//
// Phase 16, Workstream 6: this is the AUTHORITATIVE profile-completion
// gate for cold app starts / app restarts — including a restart that
// happens mid-completion (kill the app on the CompleteProfileScreen, reopen
// it: Firebase still has a session, but profileCompleted is still false,
// so this widget routes back to CompleteProfileScreen rather than Home).
//
// This is a SECOND checkpoint, not the only one — see post_auth_router.dart
// for the other (the immediate post-OTP-verification transition, which
// never passes through this widget's build() at all, since it's a
// pushNamedAndRemoveUntil that clears AuthWrapper off the stack entirely).
//
// The other two gates in this codebase are deliberately NOT made
// profile-completion-aware, and that is a considered decision, not an
// oversight: auth_guard.dart is a no-op passthrough on mobile (the
// platform this app is actually shipped on) and only gates web; auth_gate.
// dart wraps individual FEATURE screens reached via deep navigation from
// inside MainScreen — by the time any such screen is reachable, the user
// has already passed this gate, so by construction their profile is
// already complete. Adding profile-completion checks to either would be
// redundant, not incorrect, and risks a fourth divergent gate
// implementation — deliberately avoided.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/address_provider.dart';
import '../../providers/seller_provider.dart';
import '../user/main_screen.dart';
import 'login_screen.dart';
import 'complete_profile_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Address loading is handled in build() when auth state is determined
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        // ── Still checking Firebase session (very brief) ──
        if (auth.isInitializing) {
          return const _SplashLoader();
        }

        // ── LOGGED-IN, PROFILE INCOMPLETE: app restarted mid-completion
        // (or the immediate post-OTP redirect was somehow skipped) →
        // back to Complete Profile, never Home ──
        if (auth.isLoggedIn && auth.needsProfileCompletion) {
          final phone = auth.currentUser?.phone ?? '';
          return CompleteProfileScreen(phone: phone);
        }

        // ── OLD USER: session persisted, profile complete → straight to Home ──
        if (auth.isLoggedIn) {
          // Ensure address provider is loaded
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.read<AddressProvider>().loadAddresses();
              context.read<SellerProvider>().checkSellerStatus();
            }
          });
          return const MainScreen(initialIndex: 0);
        }

        // ── NEW / LOGGED-OUT USER → Login ──
        return const LoginScreen();
      },
    );
  }
}

// ── Unbranded loader shown only during the very brief Firebase check ──
class _SplashLoader extends StatelessWidget {
  const _SplashLoader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
