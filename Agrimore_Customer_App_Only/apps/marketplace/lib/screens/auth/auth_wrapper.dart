import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../user/main_screen.dart';
import '../landing/landing_screen.dart';
import '../splash/splash_screen.dart';
import 'login_screen.dart';

/// AuthWrapper - FAST START VERSION
/// Goes directly to MainScreen without any loading screen.
/// Auth state is handled reactively by MainScreen itself.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        // ✅ NO LOADING SCREEN - Go directly to content
        // The MainScreen/LoginScreen will handle auth state reactively
        
        if (kIsWeb) {
          // Web: Show MainScreen if logged in, LandingScreen if not
          // During initialization, show MainScreen (it has its own loading)
          if (auth.isLoggedIn) {
            return const MainScreen(initialIndex: 0);
          }
          return const LandingScreen();
        }
        
        // Mobile: "Fast Start" - Instant Launch
        // We bypass the Flutter SplashScreen to match Android's instant-open feel.
        // Data loading is handled safely in MainScreen/MobileHomeScreen using 
        // addPostFrameCallback to prevent build-phase crashes.
        return const MainScreen(initialIndex: 0);
      },
    );
  }
}
