import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../landing/landing_screen.dart';

/// AuthGuard wraps protected screens and ensures user is authenticated.
/// On web, it shows a seamless loading screen while auth state is being determined.
class AuthGuard extends StatelessWidget {
  final Widget child;
  
  const AuthGuard({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // On mobile, trust the flow - no guard needed
    if (!kIsWeb) {
      return child;
    }
    
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        // ✅ Show minimal loading screen while initializing (matches HTML loading screen)
        if (auth.isInitializing) {
          return const _MinimalLoadingScreen();
        }
        
        // ✅ User is logged in - show the protected content
        if (auth.isLoggedIn) {
          return child;
        }
        
        // ❌ User is NOT logged in - show landing screen
        return const LandingScreen();
      },
    );
  }
}

/// Minimal loading screen that matches the HTML loading screen
/// for seamless visual transition
class _MinimalLoadingScreen extends StatelessWidget {
  const _MinimalLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
          ),
        ),
      ),
    );
  }
}
