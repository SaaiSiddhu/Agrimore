// lib/app/app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/pending_approval_screen.dart';
import '../screens/auth/suspended_screen.dart';
import '../screens/shell/employee_shell_screen.dart';

// Phase 21, Workstream 1: shared with NotificationService (see main.dart)
// so a tapped notification has a real BuildContext to navigate from —
// mirrors apps/marketplace/lib/app/app.dart:16's identical top-level
// declaration exactly.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Agrimore Sales Associate',
      debugShowCheckedModeBanner: false,
      // Phase 21, Workstream 1: this app has no routes: map and no
      // onGenerateRoute anywhere — every screen transition is a direct
      // Navigator.push(MaterialPageRoute(...)) call. The shared
      // NotificationService.handleNotificationNavigation exclusively calls
      // Navigator.pushNamed(...), which — with no routes/onGenerateRoute to
      // resolve it and no onUnknownRoute either — throws a FlutterError
      // during route resolution rather than a catchable rejected Future.
      // Without this, wiring navigatorKey above would turn a silently
      // no-op notification tap into a visible crash. _AuthGate is already
      // the single source of truth for "what should be showing right now"
      // (shell/suspended/pending/login, based on live auth state), so
      // routing every unresolved pushNamed here is correct for any
      // possible current state, not just a generic fallback.
      onUnknownRoute: (settings) =>
          MaterialPageRoute(builder: (_) => const _AuthGate()),
      theme: SalesAssociateTheme.lightTheme,
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: SaTokens.primary,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const _AuthGate(),
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
            backgroundColor: SaTokens.pageBackground,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Fully authenticated and approved employee -> 4-tab shell
        if (authProvider.isAuthenticated && authProvider.isEmployee) {
          return const EmployeeShellScreen();
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
