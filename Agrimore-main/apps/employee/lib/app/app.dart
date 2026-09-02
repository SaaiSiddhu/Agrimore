// lib/app/app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/pending_approval_screen.dart';
import '../screens/auth/suspended_screen.dart';
import '../screens/home/dashboard_screen.dart';

import 'package:agrimore_ui/agrimore_ui.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agrimore Sales Associate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2D7D3C),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4DB85F),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const _EmployeeSplashWrapper(),
    );
  }
}

class _EmployeeSplashWrapper extends StatelessWidget {
  const _EmployeeSplashWrapper();

  @override
  Widget build(BuildContext context) {
    return PremiumSplashScreen(
      appName: 'Agrimore',
      tagline: 'Sales Associate',
      // No employee-specific package icon exists yet (agrimore_ui only ships
      // customer/seller/delivery/admin logos) — reusing admin_logo.png as the
      // closest fit since employees are internal staff, not customer-facing
      // like sellers. Adding a dedicated asset would touch packages/agrimore_ui,
      // out of this phase's scope.
      logoPath: 'packages/agrimore_ui/assets/icons/admin_logo.png',
      animationType: SplashAnimationType.admin,
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
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return Consumer<EmployeeAuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Fully authenticated and approved employee
        if (authProvider.isAuthenticated && authProvider.isEmployee) {
          return const DashboardScreen();
        }

        // Phase 16C, Workstream 5: checked BEFORE the pending branch below
        // — a suspended associate's error message must never match the
        // pending branch's own .contains('pending') check.
        if (authProvider.user != null &&
            authProvider.error != null &&
            authProvider.error!.contains('suspended')) {
          return const SuspendedScreen();
        }

        // Employee logged in but pending approval or has error
        if (authProvider.user != null &&
            authProvider.error != null &&
            authProvider.error!.contains('pending')) {
          return const EmployeePendingApprovalScreen();
        }

        // Not logged in
        return const LoginScreen();
      },
    );
  }
}
