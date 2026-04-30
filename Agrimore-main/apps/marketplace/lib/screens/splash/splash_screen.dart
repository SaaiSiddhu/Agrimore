import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../providers/auth_provider.dart' as app_auth;

class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PremiumSplashScreen(
      appName: 'Agrimore',
      tagline: 'Empowering Agriculture',
      logoPath: 'packages/agrimore_ui/assets/icons/customer_logo.png',
      animationType: SplashAnimationType.customer,
      onNavigation: (ctx) async {
        final authProvider = Provider.of<app_auth.AuthProvider>(ctx, listen: false);
        
        // Wait for auth initialization
        int waitCount = 0;
        while (authProvider.isInitializing && waitCount < 30) {
          await Future.delayed(const Duration(milliseconds: 100));
          waitCount++;
        }

        if (!ctx.mounted) return;

        if (kIsWeb && !authProvider.isLoggedIn) {
          Navigator.of(ctx).pushReplacementNamed('/landing');
        } else {
          Navigator.of(ctx).pushReplacementNamed('/main');
        }
      },
    );
  }
}
