// lib/app/app.dart
//
// Delivery Partner root application on the owned burnt-orange Delivery Design
// System (`D-SELLER-OWN-DS`) with ARB localisation, appearance persistence,
// and a session gate that binds rider data to one signed-in rider at a time.
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../auth/auth_copy.dart';
import '../design_system/design_system.dart';
import '../l10n/app_localizations.dart';
import '../offers/offer_coordinator.dart';
import '../offers/offer_launch.dart';
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../providers/order_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/pending_approval_screen.dart';
import '../screens/auth/rider_registration_screen.dart';
import 'delivery_shell.dart';

class App extends StatefulWidget {
  const App({super.key, this.appearance});

  final DeliveryAppearanceController? appearance;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final DeliveryAppearanceController _appearance =
      widget.appearance ?? DeliveryAppearanceController();

  @override
  Widget build(BuildContext context) {
    return DeliveryAppearanceScope(
      controller: _appearance,
      child: ListenableBuilder(
        listenable: _appearance,
        builder: (context, _) {
          return MaterialApp(
            navigatorKey: deliveryNavigatorKey,
            onGenerateTitle: (context) => AppLocalizations.of(context).appName,
            debugShowCheckedModeBanner: false,
            theme: DeliveryTheme.light(),
            darkTheme: DeliveryTheme.dark(),
            themeMode: _appearance.mode,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const RiderSessionGate(),
          );
        },
      ),
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
    final working = _auth.isAuthenticated && _auth.isDeliveryPartner
        ? _auth.user!.uid
        : null;
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
      // opens the incoming-offer screen above whichever tab is showing.
      // DLVNAV1: moved from wrapping DashboardScreen alone to wrapping the
      // whole shell, so an offer interrupts safely from any tab.
      return OfferCoordinator(
        key: ValueKey(auth.user!.uid),
        riderId: auth.user!.uid,
        child: const DeliveryShell(),
      );
    }
    if (auth.isBlocked) return const DeliveryPendingApprovalScreen();
    // DLV-A1: signed in, no rider record yet — finish registering.
    if (auth.needsRegistration) return const RiderRegistrationScreen();
    if (auth.profileUnavailable) return const _AccountUnavailable();
    return const LoginScreen();
  }
}

class _LoadingAccount extends StatelessWidget {
  const _LoadingAccount();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: Center(
        child: Semantics(
          label: l.loadingAccount,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DeliveryBrandMark(size: DeliverySize.avatarXl),
              const SizedBox(height: DeliverySpace.lg),
              DeliveryLoadingState(label: l.loadingAccount),
            ],
          ),
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
    final c = context.colors;
    final t = context.text;
    final auth = context.read<DeliveryAuthProvider>();
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(DeliverySpace.page),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: DeliverySize.formMaxWidth,
              ),
              child: DeliveryCard(
                padding: const EdgeInsets.all(DeliverySpace.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: DeliverySize.avatarXl,
                        height: DeliverySize.avatarXl,
                        decoration: BoxDecoration(
                          color: c.warning.container,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          DeliveryIcons.offline,
                          size: DeliveryIconSize.xl,
                          color: c.warning.icon,
                        ),
                      ),
                    ),
                    const SizedBox(height: DeliverySpace.lg),
                    Text(
                      l10n.sessionLoadFailedTitle,
                      textAlign: TextAlign.center,
                      style: t.headlineMedium.copyWith(color: c.textPrimary),
                    ),
                    const SizedBox(height: DeliverySpace.sm),
                    Text(
                      authProblemText(l10n, RiderAuthProblem.profileUnavailable),
                      textAlign: TextAlign.center,
                      style: t.bodyMedium.copyWith(color: c.textSecondary),
                    ),
                    const SizedBox(height: DeliverySpace.xxl),
                    DeliveryButton.primary(
                      label: l10n.actionRetry,
                      icon: DeliveryIcons.refresh,
                      onPressed: auth.retryProfile,
                    ),
                    const SizedBox(height: DeliverySpace.sm),
                    DeliveryButton.secondary(
                      label: l10n.actionSignOut,
                      icon: DeliveryIcons.logout,
                      onPressed: auth.signOut,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
