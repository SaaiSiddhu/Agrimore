// lib/screens/home/dashboard_screen.dart
//
// Phase 18 — Delivery Partner Dashboard on the burnt-orange Delivery Design
// System (`D-SELLER-OWN-DS`). Preserves all server online-state sync,
// location disclosures, offer alerts, active-order cards, earnings streams,
// inbox badge, SOS sheet, and sign-out confirmation.
import 'package:agrimore_core/agrimore_core.dart' show OrderModel;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../account/rider_account.dart';
import '../../design_system/design_system.dart';
import '../../inbox/rider_inbox.dart';
import '../../l10n/app_localizations.dart';
import '../../location/location_disclosure.dart';
import '../../location/location_policy.dart';
import '../../money/rider_money.dart';
import '../../offers/offer_alerts.dart';
import '../../offers/offer_launch.dart';
import '../../offers/offer_platform.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/offer_provider.dart';
import '../../providers/order_provider.dart';
import '../../safety/emergency_sheet.dart';
import '../history/rider_history_screen.dart';
import '../inbox/inbox_screen.dart';
import '../money/money_screen.dart';
import '../orders/active_order_screen.dart';
import '../profile/rider_profile_screen.dart';
import 'active_work_states.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final RiderInboxSource _inbox = FirestoreRiderInbox();
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _initializeProviders();
  }

  // Phase DLV-3A: the toggle follows the server's delivery_partners.isOnline
  // (resume after the app was closed while online; stop when the server
  // takes a silent rider offline), and the active order sets the location
  // cadence and live-point target.
  DeliveryAuthProvider? _auth;
  DeliveryOrderProvider? _orders;
  bool _syncedFromServer = false;
  bool? _lastServerOnline;
  bool _toggling = false;

  void _initializeProviders() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<DeliveryAuthProvider>();
      final orderProvider = context.read<DeliveryOrderProvider>();
      _auth = auth..addListener(_onServerState);
      _orders = orderProvider..addListener(_onActiveOrder);
      _onServerState();
      _onActiveOrder();
    });
  }

  @override
  void dispose() {
    _auth?.removeListener(_onServerState);
    _orders?.removeListener(_onActiveOrder);
    super.dispose();
  }

  void _onActiveOrder() {
    if (!mounted) return;
    context.read<LocationProvider>().setActiveOrders(
          _orders?.activeOrders.map((o) => o.id).toList() ?? const [],
        );
  }

  void _onServerState() {
    final auth = _auth;
    if (!mounted || auth == null || auth.user == null) return;
    final server = auth.partnerOnline;
    if (server == null) return;
    final previous = _lastServerOnline;
    _lastServerOnline = server;
    if (!_syncedFromServer) {
      _syncedFromServer = true;
      if (server && !_isOnline) _resumeOnline();
      return;
    }
    if (!server && previous == true && _isOnline && !_toggling) {
      context.read<LocationProvider>().stopTracking();
      setState(() => _isOnline = false);
      final message = serverOfflineMessage(
        AppLocalizations.of(context),
        auth.offlineReason,
      );
      if (message != null) {
        showDeliveryToast(
          context,
          message: message,
          tone: DeliveryBannerTone.danger,
        );
      }
    }
  }

  /// The server still has this rider online (the app was closed or killed
  /// while online): pick tracking back up without prompting, or go offline
  /// if it cannot run.
  Future<void> _resumeOnline() async {
    final auth = _auth;
    if (auth?.user == null) return;
    final uid = auth!.user!.uid;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      late final AppLifecycleListener listener;
      listener = AppLifecycleListener(
        onResume: () {
          listener.dispose();
          if (mounted && !_isOnline) _resumeOnline();
        },
      );
      return;
    }
    final location = context.read<LocationProvider>();
    if (await location.nativeServiceRunning()) {
      debugPrint('Resume online: native service already running');
      location.attachToRunningService(uid);
      if (mounted) setState(() => _isOnline = true);
      return;
    }
    final disclosed = await locationDisclosureAccepted();
    final canTrack = await location.canTrackWithoutPrompt();
    debugPrint(
      'Resume online: blocked=${auth.isBlocked} '
      'disclosed=$disclosed canTrack=$canTrack',
    );
    if (auth.isBlocked || !disclosed || !canTrack) {
      await location.setOnlineStatus(uid, false);
      return;
    }
    final result = await location.startTracking(uid);
    debugPrint('Resume online: ${result.name}');
    if (!mounted) return;
    if (result == GoOnlineResult.started) {
      setState(() => _isOnline = true);
    } else {
      await location.setOnlineStatus(uid, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PopScope(
      canPop: !_isOnline,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!await OfferPlatform.moveToBackground()) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildOnlineToggle(),
              Expanded(
                child: Consumer<DeliveryOrderProvider>(
                  builder: (context, orderProvider, _) {
                    final work = orderProvider.work;
                    final Widget body;
                    if (!work.loaded) {
                      body = const ActiveWorkLoading();
                    } else if (work.hasMultiple) {
                      body = MultipleActiveOrders(
                        orders: work.orders,
                        onOpen: _openOrder,
                      );
                    } else if (work.single != null) {
                      body = _buildActiveOrderCard(work.single!);
                    } else if (work.error != null) {
                      body = ActiveWorkError(
                        error: work.error!,
                        onRetry: orderProvider.retry,
                      );
                    } else {
                      body = _buildDashboardContent();
                    }
                    return Column(
                      children: [
                        if (work.loaded &&
                            (work.fromCache || work.error != null) &&
                            work.orders.isNotEmpty)
                          const StaleDataBanner(),
                        Expanded(child: body),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Consumer<DeliveryAuthProvider>(
      builder: (context, auth, _) {
        final l = AppLocalizations.of(context);
        final c = context.colors;
        final t = context.text;
        final initials = auth.user?.initials;
        final first = auth.user?.firstName;
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            DeliverySpace.md,
            DeliverySpace.lg,
            DeliverySpace.sm,
            DeliverySpace.lg,
          ),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('open-profile'),
                tooltip: l.profileOpen,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RiderProfileScreen(),
                  ),
                ),
                icon: CircleAvatar(
                  radius: DeliverySize.avatarMd / 2,
                  backgroundColor: c.brandSubtle,
                  child: initials == null || initials.isEmpty
                      ? Icon(DeliveryIcons.user, color: c.brand)
                      : Text(
                          initials,
                          style: t.titleSmall.copyWith(color: c.brand),
                        ),
                ),
              ),
              const SizedBox(width: DeliverySpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      first == null || first.isEmpty
                          ? l.dashGreetingNoName
                          : l.dashGreeting(first),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleMedium.copyWith(color: c.textPrimary),
                    ),
                    Text(
                      _isOnline ? l.dashReady : l.dashOfflineShort,
                      style: t.bodySmall.copyWith(
                        color: _isOnline ? c.onlineFg : c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (auth.user != null)
                InboxButton(riderId: auth.user!.uid, source: _inbox),
              IconButton(
                onPressed: () => showEmergencySheet(context),
                icon: Icon(DeliveryIcons.emergency, color: c.danger.icon),
                tooltip: l.emergencyTitle,
              ),
              IconButton(
                onPressed: _confirmSignOut,
                icon: Icon(DeliveryIcons.logout, color: c.textSecondary),
                tooltip: l.dashSignOutTooltip,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOnlineToggle() {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DeliverySpace.page),
      child: DeliveryOnlineSwitch(
        isOnline: _isOnline,
        isLoading: _toggling,
        onlineTitle: l.dashOnline,
        offlineTitle: l.dashOffline,
        onlineSubtitle: l.dashReady,
        offlineSubtitle: l.dashOfflineShort,
        onChanged: _toggleOnline,
      ),
    );
  }

  Widget _buildDashboardContent() {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(DeliverySpace.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildEarningsCard(),
          const SizedBox(height: DeliverySpace.xl),
          _moneyStats(
            (week, today, cash) => Consumer<DeliveryOrderProvider>(
              builder: (context, orderProvider, _) => Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: l.dashStatToday,
                          value: orderProvider.todayDelivered?.toString() ??
                              l.todayDeliveredUnknown,
                          icon: DeliveryIcons.invoice,
                        ),
                      ),
                      const SizedBox(width: DeliverySpace.md),
                      Expanded(
                        child: _StatCard(
                          label: l.dashStatWeek,
                          value: week,
                          icon: DeliveryIcons.calendar,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DeliverySpace.md),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: l.dashStatEarnedToday,
                          value: today,
                          icon: DeliveryIcons.wallet,
                          highlight: true,
                        ),
                      ),
                      const SizedBox(width: DeliverySpace.md),
                      Expanded(
                        child: _StatCard(
                          label: l.dashStatCash,
                          value: cash,
                          icon: DeliveryIcons.rupee,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: DeliverySpace.md),
          _ActionCard(
            title: l.dashMoneyTitle,
            subtitle: l.dashMoneySubtitle,
            icon: DeliveryIcons.wallet,
            onTap: _openMoney,
          ),
          const SizedBox(height: DeliverySpace.xxl),
          Text(
            l.dashQuickActions,
            style: t.titleMedium.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: DeliverySpace.md),
          Consumer<OfferProvider>(
            builder: (context, offers, _) {
              final current = offers.current;
              return _ActionCard(
                title: current != null
                    ? l.dashOfferTitle
                    : _isOnline
                        ? l.dashWaitingTitle
                        : l.dashGoOnlineTitle,
                subtitle: current != null
                    ? l.dashOfferSubtitle
                    : _isOnline
                        ? l.dashWaitingSubtitle
                        : l.dashGoOnlineSubtitle,
                icon: DeliveryIcons.bell,
                badgeCount: offers.offers.length,
                onTap: current == null
                    ? null
                    : () => OfferLaunch.request(current.orderId),
              );
            },
          ),
          const SizedBox(height: DeliverySpace.md),
          _ActionCard(
            title: l.historyActionTitle,
            subtitle: l.historyActionSubtitle,
            icon: DeliveryIcons.history,
            onTap: _showDeliveryHistory,
          ),
        ],
      ),
    );
  }

  // ── Phase DLV-4B: money from the server (rider_earnings / rider_accounts) ──

  RiderMoneyService? _money;
  Stream<List<RiderEarning>>? _earningsStream;
  Stream<RiderAccount>? _accountStream;

  RiderMoneyService? get _moneyService {
    final uid = context.read<DeliveryAuthProvider>().user?.uid;
    if (uid == null) return null;
    if (_money?.riderId != uid) {
      _money = RiderMoneyService(uid);
      _earningsStream = _money!.unsettledEarnings().asBroadcastStream();
      _accountStream = _money!.account().asBroadcastStream();
    }
    return _money;
  }

  void _openMoney() {
    final uid = _auth?.user?.uid;
    if (uid == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MoneyScreen(riderId: uid)),
    );
  }

  /// Builds [child] with this week's pay, today's pay and cash held, formatted.
  Widget _moneyStats(
    Widget Function(String week, String today, String cash) child,
  ) {
    final l = AppLocalizations.of(context);
    if (_moneyService == null) {
      return child(
        l.todayDeliveredUnknown,
        l.todayDeliveredUnknown,
        l.todayDeliveredUnknown,
      );
    }
    return StreamBuilder<List<RiderEarning>>(
      stream: _earningsStream,
      builder: (context, earnings) => StreamBuilder<RiderAccount>(
        stream: _accountStream,
        builder: (context, account) {
          final list = earnings.data;
          final week = list == null
              ? l.moneyAmountLoading
              : rupees(sumRupees(list.map((e) => e.total)));
          final today = list == null
              ? l.moneyAmountLoading
              : rupees(earnedSince(list, istDayStart(DateTime.now())));
          final cash = account.data == null
              ? l.moneyAmountLoading
              : rupees(account.data!.cashHeld);
          return child(week, today, cash);
        },
      ),
    );
  }

  Widget _buildEarningsCard() {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    final on = c.onBrand;
    return _moneyStats(
      (week, today, _) => Material(
        color: c.brand,
        borderRadius: DeliveryRadius.rMd,
        child: InkWell(
          onTap: _openMoney,
          borderRadius: DeliveryRadius.rMd,
          child: Padding(
            padding: const EdgeInsets.all(DeliverySpace.lg),
            child: Row(
              children: [
                Icon(DeliveryIcons.rupee, color: on, size: DeliveryIconSize.xl),
                const SizedBox(width: DeliverySpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.dashEarnedWeek,
                        style: t.labelMedium.copyWith(color: on),
                      ),
                      const SizedBox(height: DeliverySpace.xxs),
                      Text(
                        week,
                        style: t.headlineSmall.copyWith(color: on),
                      ),
                      Text(
                        l.dashEarnedTodayLine(today),
                        style: t.bodySmall.copyWith(color: on),
                      ),
                    ],
                  ),
                ),
                Icon(DeliveryIcons.chevronRight, color: on),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveOrderCard(OrderModel order) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DeliverySpace.page),
        child: DeliveryCard(
          variant: DeliveryCardVariant.brand,
          padding: const EdgeInsets.all(DeliverySpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: DeliverySize.avatarLg,
                    height: DeliverySize.avatarLg,
                    decoration: BoxDecoration(
                      color: c.brand,
                      borderRadius: DeliveryRadius.rMd,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      DeliveryIcons.rider,
                      color: c.onBrand,
                      size: DeliveryIconSize.lg,
                    ),
                  ),
                  const SizedBox(width: DeliverySpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.dashActiveTitle,
                          style: t.titleMedium.copyWith(color: c.textPrimary),
                        ),
                        Text(
                          l.offerOrderNumber(order.orderNumber),
                          style: t.bodySmall.copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DeliverySpace.xl),
              DeliveryButton.primary(
                label: l.dashViewDetails,
                icon: DeliveryIcons.chevronRight,
                onPressed: () => _openOrder(order),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openOrder(OrderModel order) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ActiveOrderScreen(order: order)),
    );
  }

  void _showDeliveryHistory() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RiderHistoryScreen()),
    );
  }

  void _toggleOnline(bool value) async {
    if (_toggling) return;
    HapticFeedback.lightImpact();
    final auth = context.read<DeliveryAuthProvider>();
    final location = context.read<LocationProvider>();
    final uid = auth.user?.uid;
    if (uid == null) return;

    _toggling = true;
    setState(() => _isOnline = value);
    try {
      if (value) {
        if (!await ensureLocationDisclosure(context)) {
          if (mounted) setState(() => _isOnline = false);
          return;
        }
        if (!mounted) return;
        await ensureOfferAlertPermissions(context);
        var result = await location.ensurePermission();
        var backgroundAllowed = true;
        if (result == GoOnlineResult.started) {
          if (!mounted) return;
          backgroundAllowed = await ensureBackgroundLocation(context);
          if (!mounted) return;
          await maybeShowBatteryGuide(context);
          await location.setOnlineStatus(uid, true);
          result = await location.startTracking(uid);
          if (result != GoOnlineResult.started) {
            await location.setOnlineStatus(uid, false);
          }
        }
        if (!mounted) return;
        final l = AppLocalizations.of(context);
        if (result == GoOnlineResult.started && !backgroundAllowed) {
          showDeliveryToast(context, message: l.backgroundLocationReminder);
        }
        if (result != GoOnlineResult.started) {
          setState(() => _isOnline = false);
          final message = result.message(l);
          if (message != null) {
            if (result.needsSettings) {
              final open = await showDeliveryConfirmDialog(
                context: context,
                icon: DeliveryIcons.locationOff,
                title: l.goOnlineBlockedTitle,
                body: message,
                confirmLabel: l.actionOpenSettings,
                cancelLabel: l.actionNotNow,
              );
              if (open) {
                await (result == GoOnlineResult.servicesOff
                    ? Geolocator.openLocationSettings()
                    : Geolocator.openAppSettings());
              }
            } else {
              showDeliveryToast(
                context,
                message: message,
                tone: DeliveryBannerTone.danger,
              );
            }
          }
          return;
        }
      } else {
        location.stopTracking();
        await location.setOnlineStatus(uid, false);
      }
    } finally {
      _toggling = false;
    }
  }

  Future<void> _confirmSignOut() async {
    final l = AppLocalizations.of(context);
    final ok = await showDeliveryConfirmDialog(
      context: context,
      title: l.dashSignOutTitle,
      body: l.dashSignOutBody,
      confirmLabel: l.actionSignOut,
      cancelLabel: l.cancel,
    );
    if (ok && mounted) await riderSignOut(context);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });
  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return DeliveryCard(
      variant: highlight
          ? DeliveryCardVariant.brand
          : DeliveryCardVariant.standard,
      padding: const EdgeInsets.all(DeliverySpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: highlight ? c.brand : c.textSecondary,
            size: DeliveryIconSize.md,
          ),
          const SizedBox(height: DeliverySpace.md),
          Text(
            value,
            style: t.titleLarge.copyWith(
              color: highlight ? c.brand : c.textPrimary,
            ),
          ),
          Text(
            label,
            style: t.bodySmall.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.badgeCount = 0,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return DeliveryCard(
      onTap: onTap,
      padding: const EdgeInsets.all(DeliverySpace.lg),
      child: Row(
        children: [
          Badge.count(
            isLabelVisible: badgeCount > 0,
            count: badgeCount,
            child: Container(
              width: DeliverySize.avatarMd,
              height: DeliverySize.avatarMd,
              decoration: BoxDecoration(
                color: c.brandSubtle,
                borderRadius: DeliveryRadius.rSm,
              ),
              child: Icon(icon, color: c.brand),
            ),
          ),
          const SizedBox(width: DeliverySpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.titleSmall.copyWith(color: c.textPrimary),
                ),
                Text(
                  subtitle,
                  style: t.bodySmall.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(DeliveryIcons.chevronRight, color: c.textSecondary),
        ],
      ),
    );
  }
}
