import 'package:flutter/material.dart';
import '../auth/auth_guard.dart';
import '../user/main_screen.dart';

/// Instant root screen: bypasses duplicated Flutter splash animation
/// so the app immediately renders the Home screen after native startup.
class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const AuthGuard(child: MainScreen(initialIndex: 0));
  }
}
