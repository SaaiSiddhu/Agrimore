// lib/app/app.dart
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/seller_auth_provider.dart';
import '../providers/seller_settings_provider.dart';
import '../screens/auth/account_restricted_screen.dart';
import '../screens/auth/application_status_screen.dart';
import '../screens/auth/seller_sign_in_screen.dart';
import '../screens/auth/widgets/auth_brand_panel.dart';
import '../screens/onboarding/application_screen.dart';
import '../screens/onboarding/apply_intro_screen.dart';
import '../screens/shell/seller_shell.dart';

/// AgriMore Seller — Workspace theme, seller (teal) brand (ADR-S02/S03).
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: WorkspaceTheme.build(WorkspaceBrand.seller, Brightness.light),
      darkTheme: WorkspaceTheme.build(WorkspaceBrand.seller, Brightness.dark),
      themeMode: context.watch<SellerSettingsProvider>().themeMode,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
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
      duration: WsMotion.standard,
      switchInCurve: WsMotion.curveEnter,
      switchOutCurve: WsMotion.curveExit,
      child: KeyedSubtree(
        key: ValueKey(access),
        child: switch (access) {
          SellerAccess.loading => const _LoadingAccount(),
          SellerAccess.signedOut => const SellerSignInScreen(),
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

class _LoadingAccount extends StatelessWidget {
  const _LoadingAccount();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: Semantics(
          label: l10n.loadingAccount,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AuthWordmark(),
              SizedBox(height: WsSpace.s24),
              SizedBox(
                width: WsSize.railWidthExpanded / 2,
                child: LinearProgressIndicator(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
