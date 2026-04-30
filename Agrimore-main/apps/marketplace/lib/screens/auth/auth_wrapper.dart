// ============================================================
//  AUTH WRAPPER — decides where the user lands on app open
//  OLD USERS  → already logged-in → Home (no flicker)
//  NEW USERS  → not logged-in    → Login screen
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/address_provider.dart';
import '../../providers/seller_provider.dart';
import '../user/main_screen.dart';
import 'login_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // After first frame, trigger address load if user is already logged in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn && !auth.isInitializing) {
        // Load addresses so defaultAddress is ready for home screen
        context.read<AddressProvider>().loadAddresses();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        // ── Still checking Firebase session (very brief) ──
        if (auth.isInitializing) {
          return const _SplashLoader();
        }

        // ── OLD USER: session persisted → straight to Home ──
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

// ── Minimal branded splash shown only during the very brief Firebase check ──
class _SplashLoader extends StatelessWidget {
  const _SplashLoader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A6B3A), // Agrimore green
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/icons/logo_icon.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text('🌱', style: TextStyle(fontSize: 44)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Agrimore',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
