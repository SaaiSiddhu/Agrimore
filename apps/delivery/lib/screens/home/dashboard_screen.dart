// lib/screens/home/dashboard_screen.dart
//
// Phase 18, DLVHOME1 — Delivery Partner Home on the AgriMore Delivery Design
// System. DLVHOME1 (2026-09-28, OWNER_DECISION): the main area is now a real
// map (HomeMap) with the compact HomeAppBar above it and every existing
// operational surface -- pending proof, active-work states, earnings, quick
// actions -- reachable through HomeOperationsPanel, an expandable panel
// above the bottom nav. Preserves all server online-state sync, location
// disclosures, offer alerts, active-order cards, earnings streams, inbox
// badge, SOS sheet, and sign-out confirmation exactly as before -- only the
// LAYOUT changed, not one line of the state machine below it.
import 'package:agrimore_core/agrimore_core.dart' show OrderModel;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../delivery/delivery_problems.dart';
import '../../delivery/proof_photo_recovery.dart';
import '../../design_system/design_system.dart';
import '../../inbox/rider_inbox.dart';
import '../../l10n/app_localizations.dart';
import '../../location/location_disclosure.dart';
import '../../location/location_policy.dart';
import '../../money/rider_money.dart';
import '../../offers/offer_alerts.dart';
import '../../offers/offer_launch.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/offer_provider.dart';
import '../../providers/order_provider.dart';
import '../../app/delivery_tab.dart';
import '../history/rider_history_screen.dart';
import '../inbox/inbox_screen.dart';
import '../money/money_screen.dart';
import '../orders/active_order_screen.dart';
import 'active_work_states.dart';
import 'home_app_bar.dart';
import 'home_map.dart';
import 'home_operations_panel.dart';
import 'pending_proof_banner.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.inboxSource,
    this.earningsSource,
    this.accountSource,
    this.onOpenTab,
    this.pendingProofStore,
    this.pendingProofBackend,
    this.homeMapBuilder,
  });

  /// Injected in tests.
  final RiderInboxSource? inboxSource;
  final Stream<List<RiderEarning>> Function(String riderId)? earningsSource;
  final Stream<RiderAccount> Function(String riderId)? accountSource;

  /// DLVHOME1: real GoogleMap platform views are not mocked in
  /// `flutter test` (no plugin registered) and hang `pumpAndSettle`
  /// indefinitely -- the same class of seam as `accountSource` above, not a
  /// special case. Null (production) renders the real [HomeMap].
  final WidgetBuilder? homeMapBuilder;

  /// DLVPP1: injected in tests; forwarded to [PendingProofBanner].
  final PendingProofStore? pendingProofStore;
  final DeliveryProblemBackend? pendingProofBackend;

  /// DLVNAV1: when this screen runs as the shell's Home tab, its four
  /// internal destinations (profile, inbox, earnings, deliveries) switch
  /// tabs through this instead of pushing a duplicate tab-root route. Null
  /// when this screen is not inside a shell (standalone, tests): falls back
  /// to the original push behaviour unchanged.
  final void Function(DeliveryTab tab)? onOpenTab;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

/// DLVDASH2: which period the earnings card's own toggle shows.
enum _EarningsPeriod { today, week }

class _DashboardScreenState extends State<DashboardScreen> {
  late final RiderInboxSource _inbox = widget.inboxSource ?? FirestoreRiderInbox();
  bool _isOnline = false;
  _EarningsPeriod _earningsPeriod = _EarningsPeriod.today;

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
    final auth = context.watch<DeliveryAuthProvider>();
    final uid = auth.user?.uid;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (uid != null)
              HomeAppBar(
                isOnline: _isOnline,
                busy: _toggling,
                onToggle: _toggleOnline,
                riderId: uid,
                inboxSource: _inbox,
                onOpenInbox: () => _openTab(
                  DeliveryTab.inbox,
                  () => InboxScreen(riderId: uid, source: _inbox),
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: widget.homeMapBuilder?.call(context) ?? const HomeMap(),
                  ),
                  Positioned.fill(
                    child: Consumer<DeliveryOrderProvider>(
                      builder: (context, orderProvider, _) {
                        final work = orderProvider.work;
                        // Rider-requested resting shape: collapsed shows
                        // exactly one pinned "headline" widget (the
                        // Today/This week + Earned card when idle; the
                        // active-work summary otherwise) and nothing else.
                        final Widget peek;
                        final List<Widget> secondary;
                        if (!work.loaded) {
                          peek = const SizedBox(
                            height: DeliverySize.workPreviewMedium,
                            child: ActiveWorkLoading(),
                          );
                          secondary = const [];
                        } else if (work.hasMultiple) {
                          peek = SizedBox(
                            height: DeliverySize.workPreviewLarge,
                            child: MultipleActiveOrders(orders: work.orders, onOpen: _openOrder),
                          );
                          secondary = const [];
                        } else if (work.single != null) {
                          peek = SizedBox(
                            height: DeliverySize.workPreviewMedium,
                            child: ActiveOrderSummaryCard(order: work.single!, onOpen: _openOrder),
                          );
                          secondary = const [];
                        } else if (work.error != null) {
                          peek = SizedBox(
                            height: DeliverySize.workPreviewCompact,
                            child: ActiveWorkError(error: work.error!, onRetry: orderProvider.retry),
                          );
                          secondary = const [];
                        } else {
                          peek = _buildEarningsPeek();
                          secondary = _buildExpandedContent();
                        }
                        return HomeOperationsPanel(
                          peek: peek,
                          expanded: [
                            // DLVPP1: never behind a completion modal or any
                            // other screen -- always visible whenever a
                            // delivery still needs its proof photo attached.
                            PendingProofBanner(
                              store: widget.pendingProofStore,
                              backend: widget.pendingProofBackend,
                            ),
                            if (work.loaded && (work.fromCache || work.error != null) && work.orders.isNotEmpty)
                              const StaleDataBanner(),
                            ...secondary,
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// DLVNAV1: switches to [tab] when running inside the shell, else falls
  /// back to pushing [fallback] (the original standalone behaviour).
  void _openTab(DeliveryTab tab, Widget Function() fallback) {
    final go = widget.onOpenTab;
    if (go != null) {
      go(tab);
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => fallback()));
  }

  /// The panel's pinned collapsed content: just the Today/This week toggle
  /// and the Earned card — everything else lives in [_buildExpandedContent],
  /// only reachable by dragging the panel open.
  Widget _buildEarningsPeek() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DeliverySpace.page,
        0,
        DeliverySpace.page,
        DeliverySpace.md,
      ),
      child: _buildEarningsCard(),
    );
  }

  List<Widget> _buildExpandedContent() {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          DeliverySpace.page,
          0,
          DeliverySpace.page,
          DeliverySpace.page,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _moneyStats(
              (_, __, cash) => _StatCard(
                label: l.dashStatCash,
                value: cash,
                icon: DeliveryIcons.rupee,
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
      ),
    ];
  }

  // ── Phase DLV-4B: money from the server (rider_earnings / rider_accounts) ──

  String? _moneyBoundUid;
  Stream<List<RiderEarning>>? _earningsStream;
  Stream<RiderAccount>? _accountStream;

  static Stream<List<RiderEarning>> _defaultEarnings(String uid) =>
      RiderMoneyService(uid).unsettledEarnings();
  static Stream<RiderAccount> _defaultAccount(String uid) =>
      RiderMoneyService(uid).account();

  /// True once bound; false when signed out. Splitting the two streams
  /// (rather than exposing the RiderMoneyService instance) is what makes
  /// this injectable in tests without a live Firestore.
  bool get _moneyBound {
    final uid = context.read<DeliveryAuthProvider>().user?.uid;
    if (uid == null) return false;
    if (_moneyBoundUid != uid) {
      _moneyBoundUid = uid;
      _earningsStream =
          (widget.earningsSource ?? _defaultEarnings)(uid).asBroadcastStream();
      _accountStream =
          (widget.accountSource ?? _defaultAccount)(uid).asBroadcastStream();
    }
    return true;
  }

  void _openMoney() {
    final uid = _auth?.user?.uid;
    if (uid == null) return;
    _openTab(DeliveryTab.earnings, () => MoneyScreen(riderId: uid));
  }

  /// Builds [child] with this week's pay, today's pay and cash held, formatted.
  Widget _moneyStats(
    Widget Function(String week, String today, String cash) child,
  ) {
    final l = AppLocalizations.of(context);
    if (!_moneyBound) {
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
      (week, today, _) => Consumer<DeliveryOrderProvider>(
        builder: (context, orderProvider, _) {
          final amount = _earningsPeriod == _EarningsPeriod.today ? today : week;
          final count = _earningsPeriod == _EarningsPeriod.today
              ? orderProvider.todayDelivered
              : orderProvider.weekDelivered;
          final completedText =
              count == null ? l.todayDeliveredUnknown : l.dashCompletedDeliveries(count);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DeliverySegmented<_EarningsPeriod>(
                selected: _earningsPeriod,
                onSelected: (p) => setState(() => _earningsPeriod = p),
                items: [
                  DeliveryChipItem(
                    value: _EarningsPeriod.today,
                    label: l.dashStatToday,
                    key: const ValueKey('earnings-period-today'),
                  ),
                  DeliveryChipItem(
                    value: _EarningsPeriod.week,
                    label: l.dashStatWeek,
                    key: const ValueKey('earnings-period-week'),
                  ),
                ],
              ),
              const SizedBox(height: DeliverySpace.sm),
              Material(
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
                                l.dashEarnedLabel,
                                style: t.labelMedium.copyWith(color: on),
                              ),
                              const SizedBox(height: DeliverySpace.xxs),
                              Text(
                                amount,
                                style: t.headlineSmall.copyWith(color: on),
                              ),
                              Text(
                                completedText,
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
            ],
          );
        },
      ),
    );
  }

  void _openOrder(OrderModel order) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ActiveOrderScreen(order: order)),
    );
  }

  void _showDeliveryHistory() {
    _openTab(DeliveryTab.deliveries, () => const RiderHistoryScreen());
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
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return DeliveryCard(
      padding: const EdgeInsets.all(DeliverySpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: c.textSecondary,
            size: DeliveryIconSize.md,
          ),
          const SizedBox(height: DeliverySpace.md),
          Text(
            value,
            style: t.titleLarge.copyWith(color: c.textPrimary),
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
