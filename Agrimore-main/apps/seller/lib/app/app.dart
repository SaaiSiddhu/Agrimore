// lib/app/app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/seller_auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/pending_approval_screen.dart';
import '../screens/shell/seller_shell.dart';

import 'package:agrimore_ui/agrimore_ui.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agrimore Seller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A365D), // Professional Navy Blue
          secondary: const Color(0xFFF59E0B), // Amber Accent
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Color(0xFF1A365D),
          foregroundColor: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2B6CB0), // Lighter Blue for Dark Mode
          secondary: const Color(0xFFFBBF24), // Amber Accent
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const _SellerSplashWrapper(),
    );
  }
}

class _SellerSplashWrapper extends StatelessWidget {
  const _SellerSplashWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return PremiumSplashScreen(
      appName: 'Agrimore Seller',
      tagline: 'Seller Dashboard',
      logoPath: 'packages/agrimore_ui/assets/icons/seller_logo.png',
      animationType: SplashAnimationType.seller,
      onNavigation: (ctx) async {
        if (!ctx.mounted) return;
        Navigator.of(ctx).pushReplacement(
          MaterialPageRoute(builder: (_) => const _AuthGate()),
        );
      },
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SellerAuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        // Fully authenticated and approved seller → show shell with bottom nav
        if (authProvider.isAuthenticated) {
          return const SellerShell();
        }
        
        // Seller is logged in but pending approval
        if (authProvider.isPendingApproval) {
          return const PendingApprovalScreen();
        }
        
        // Not logged in or not a seller
        return const LoginScreen();
      },
    );
  }
}
