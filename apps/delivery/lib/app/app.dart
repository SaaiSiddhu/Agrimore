// lib/app/app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/pending_approval_screen.dart';
import '../screens/home/dashboard_screen.dart';
import '../offers/offer_coordinator.dart';
import '../offers/offer_launch.dart';

import 'package:agrimore_ui/agrimore_ui.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: deliveryNavigatorKey,
      title: 'Agrimore Delivery',
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
      home: const _DeliverySplashWrapper(),
    );
  }
}

class _DeliverySplashWrapper extends StatelessWidget {
  const _DeliverySplashWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return PremiumSplashScreen(
      appName: 'Agrimore Delivery',
      tagline: 'Delivery Partner',
      logoPath: 'packages/agrimore_ui/assets/icons/delivery_logo.png',
      animationType: SplashAnimationType.delivery,
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
    return Consumer<DeliveryAuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Fully authenticated and approved delivery partner
        // Phase DLV-2B: the coordinator listens for this rider's offers and
        // rings / opens the incoming-offer screen above the dashboard.
        if (authProvider.isAuthenticated && authProvider.isDeliveryPartner) {
          return OfferCoordinator(
            key: ValueKey(authProvider.user!.uid),
            riderId: authProvider.user!.uid,
            child: const DashboardScreen(),
          );
        }

        // Signed in, but onboarding status does not allow work: pending,
        // rejected or suspended (Phase DLV-1B — previously matched the word
        // 'pending' in an error string, so every state read as pending).
        if (authProvider.isBlocked) {
          return const DeliveryPendingApprovalScreen();
        }

        // Not logged in
        return const LoginScreen();
      },
    );
  }
}
