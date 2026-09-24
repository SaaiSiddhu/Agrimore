// lib/app/app.dart
//
// Phase DLV-C1 — the delivery app on the shared Workspace theme (delivery
// brand: the app's existing green) with ARB localisation, and a session gate
// that binds rider data to exactly one signed-in rider.
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../auth/auth_copy.dart';
import '../l10n/app_localizations.dart';
import '../offers/offer_coordinator.dart';
import '../offers/offer_launch.dart';
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../providers/order_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/pending_approval_screen.dart';
import '../screens/home/dashboard_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: deliveryNavigatorKey,
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: WorkspaceTheme.build(WorkspaceBrand.delivery, Brightness.light),
      darkTheme: WorkspaceTheme.build(WorkspaceBrand.delivery, Brightness.dark),
      themeMode: ThemeMode.system,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _DeliverySplashWrapper(),
    );
  }
}

class _DeliverySplashWrapper extends StatelessWidget {
  const _DeliverySplashWrapper();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PremiumSplashScreen(
      appName: l10n.appName,
      tagline: l10n.splashTagline,
      logoPath: 'packages/agrimore_ui/assets/icons/delivery_logo.png',
      animationType: SplashAnimationType.delivery,
      onNavigation: (ctx) async {
        if (!ctx.mounted) return;
        Navigator.of(ctx).pushReplacement(
          MaterialPageRoute(builder: (_) => const RiderSessionGate()),
        );
      },
    );
  }
}

/// Routes on the auth state and keeps rider-scoped state bound to the rider
/// who may work right now. On every change of that rider — sign-out, account
/// switch, suspension — the previous rider's orders, offer launch requests,
/// offer notifications and location tracking are dropped.
class RiderSessionGate extends StatefulWidget {
  const RiderSessionGate({super.key});

  @override
  State<RiderSessionGate> createState() => _RiderSessionGateState();
}

class _RiderSessionGateState extends State<RiderSessionGate> {
  late final DeliveryAuthProvider _auth;
  String? _boundUid;

  @override
  void initState() {
    super.initState();
    _auth = context.read<DeliveryAuthProvider>()..addListener(_sync);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    _auth.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (!mounted) return;
    final working = _auth.isAuthenticated && _auth.isDeliveryPartner ? _auth.user!.uid : null;
    if (working == _boundUid) return;
    final ended = _boundUid != null;
    _boundUid = working;
    context.read<DeliveryOrderProvider>().bind(working);
    if (ended) {
      // Screens opened in that session (history, an active order, an offer)
      // belong to it: close them, back to this gate.
      deliveryNavigatorKey.currentState?.popUntil((route) => route.isFirst);
      OfferLaunch.clear();
      context.read<LocationProvider>().stopTracking();
      FlutterLocalNotificationsPlugin().cancelAll().catchError((Object e) {
        debugPrint('Notification cleanup skipped: $e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<DeliveryAuthProvider>();
    if (auth.isLoading) return const _LoadingAccount();
    if (auth.isAuthenticated && auth.isDeliveryPartner) {
      // Phase DLV-2B: the coordinator listens for this rider's offers and
      // opens the incoming-offer screen above the dashboard.
      return OfferCoordinator(
        key: ValueKey(auth.user!.uid),
        riderId: auth.user!.uid,
        child: const DashboardScreen(),
      );
    }
    if (auth.isBlocked) return const DeliveryPendingApprovalScreen();
    if (auth.profileUnavailable) return const _AccountUnavailable();
    return const LoginScreen();
  }
}

class _LoadingAccount extends StatelessWidget {
  const _LoadingAccount();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          label: AppLocalizations.of(context).loadingAccount,
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }
}

/// Signed in, but the profile could not be read (offline, or the read
/// failed): never treated as "no account".
class _AccountUnavailable extends StatelessWidget {
  const _AccountUnavailable();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final auth = context.read<DeliveryAuthProvider>();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(WsSpace.page),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(AgIcons.offline, size: WsIconSize.empty, color: t.textTertiary),
              const SizedBox(height: WsSpace.s16),
              Text(l10n.sessionLoadFailedTitle,
                  textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: WsSpace.s8),
              Text(authProblemText(l10n, RiderAuthProblem.profileUnavailable),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: t.textSecondary)),
              const SizedBox(height: WsSpace.s24),
              FilledButton(onPressed: auth.retryProfile, child: Text(l10n.actionRetry)),
              const SizedBox(height: WsSpace.s8),
              OutlinedButton(onPressed: auth.signOut, child: Text(l10n.actionSignOut)),
            ],
          ),
        ),
      ),
    );
  }
}
