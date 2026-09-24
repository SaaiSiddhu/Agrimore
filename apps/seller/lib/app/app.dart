import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../design_system/design_system.dart';
import '../l10n/app_localizations.dart';
import '../providers/seller_auth_provider.dart';
import '../providers/seller_settings_provider.dart';
import '../screens/auth/account_restricted_screen.dart';
import '../screens/auth/application_status_screen.dart';
import '../screens/auth/seller_sign_in_screen.dart';
import '../screens/onboarding/application_screen.dart';
import '../screens/onboarding/apply_intro_screen.dart';
import '../screens/shell/seller_shell.dart';
import 'legacy_auth_theme.dart';

/// AgriMore Seller — the seller's own design system (decision D0), light,
/// dark or following the system (persisted per device).
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: SellerTheme.light,
      darkTheme: SellerTheme.dark,
      themeMode: context.watch<SellerSettingsProvider>().themeMode,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // Reduced motion: no ink ripples either (board 24-05); pressed states
      // still show through their overlay colour.
      builder: (context, child) {
        if (!context.reduceMotion) return child!;
        final theme = Theme.of(context);
        return Theme(data: theme.copyWith(splashFactory: NoSplash.splashFactory), child: child!);
      },
      home: const SellerAuthGate(),
    );
  }
}

/// Routes on [SellerAccess] only (ADR §9 "Auth gate states").
class SellerAuthGate extends StatelessWidget {
  const SellerAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final access = context.watch<SellerAuthProvider>().access;
    return AnimatedSwitcher(
      duration: context.motion(SellerMotion.standard),
      switchInCurve: SellerMotion.enter,
      switchOutCurve: SellerMotion.exit,
      child: KeyedSubtree(
        key: ValueKey(access),
        child: switch (access) {
          SellerAccess.loading => const _LoadingAccount(),
          SellerAccess.signedOut => const LegacyAuthTheme(child: SellerSignInScreen()),
          SellerAccess.noApplication => const ApplyIntroScreen(),
          SellerAccess.draft => const ApplicationScreen(),
          SellerAccess.pending => const ApplicationStatusScreen(),
          SellerAccess.rejected => const AccountRestrictedScreen(reason: RestrictionReason.rejected),
          SellerAccess.suspended => const AccountRestrictedScreen(reason: RestrictionReason.suspended),
          SellerAccess.approved => const SellerShell(),
        },
      ),
    );
  }
}

/// "Loading your seller account" — logo and an indeterminate spinner; no
/// invented percentage (board 13).
class _LoadingAccount extends StatelessWidget {
  const _LoadingAccount();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SellerLogo(large: true),
            const SizedBox(height: SellerSpace.s32),
            SellerProgressLabel(label: l10n.loadingAccount),
          ],
        ),
      ),
    );
  }
}
