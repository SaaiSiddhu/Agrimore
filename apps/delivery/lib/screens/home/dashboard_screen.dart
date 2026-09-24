// lib/screens/home/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/location_provider.dart';
import '../orders/active_order_screen.dart';
import '../money/money_screen.dart';
import '../../money/rider_money.dart';
import '../../safety/emergency_sheet.dart';
import '../../l10n/app_localizations.dart';
import '../history/rider_history_screen.dart';
import '../inbox/inbox_screen.dart';
import '../../inbox/rider_inbox.dart';
import '../profile/rider_profile_screen.dart';
import '../../account/rider_account.dart';
import 'active_work_states.dart';
import '../../offers/offer_alerts.dart';
import '../../offers/offer_launch.dart';
import '../../offers/offer_platform.dart';
import '../../providers/offer_provider.dart';
import '../../location/location_disclosure.dart';
import '../../location/location_policy.dart';
import 'package:geolocator/geolocator.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

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
      // DLV-C1: the session gate (app/app.dart) binds the order provider.
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
        _orders?.activeOrders.map((o) => o.id).toList() ?? const []);
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
      final message = serverOfflineMessage(AppLocalizations.of(context), auth.offlineReason);
      if (message != null) WsToast.show(context, message, tone: WsToastTone.error);
    }
  }

  /// The server still has this rider online (the app was closed or killed
  /// while online): pick tracking back up without prompting, or go offline
  /// if it cannot run.
  Future<void> _resumeOnline() async {
    final auth = _auth;
    if (auth?.user == null) return;
    final uid = auth!.user!.uid;
    // Android 12+ refuses to start a location foreground service from the
    // background (seen on the device run when the rider left the app during
    // start-up): wait until the app is on screen.
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      late final AppLifecycleListener listener;
      listener = AppLifecycleListener(onResume: () {
        listener.dispose();
        if (mounted && !_isOnline) _resumeOnline();
      });
      return;
    }
    final location = context.read<LocationProvider>();
    // Phase DLV-3A2: the native service may have kept sending while the app
    // was swiped away — attach to it rather than restarting.
    if (await location.nativeServiceRunning()) {
      debugPrint('Resume online: native service already running');
      location.attachToRunningService(uid);
      if (mounted) setState(() => _isOnline = true);
      return;
    }
    final disclosed = await locationDisclosureAccepted();
    final canTrack = await location.canTrackWithoutPrompt();
    debugPrint('Resume online: blocked=${auth.isBlocked} '
        'disclosed=$disclosed canTrack=$canTrack');
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
    // Phase DLV-3A: while online, Back here keeps the app running in the
    // background (as WhatsApp does) — closing the activity would end the
    // location stream. Offline, Back closes the app as before.
    return PopScope(
      canPop: !_isOnline,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!await OfferPlatform.moveToBackground()) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
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
                      body = MultipleActiveOrders(orders: work.orders, onOpen: _openOrder);
                    } else if (work.single != null) {
                      body = _buildActiveOrderCard(work.single!);
                    } else if (work.error != null) {
                      body = ActiveWorkError(error: work.error!, onRetry: orderProvider.retry);
                    } else {
                      body = _buildDashboardContent();
                    }
                    return Column(
                      children: [
                        if (work.loaded && (work.fromCache || work.error != null) && work.orders.isNotEmpty)
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
        final t = context.ws;
        final text = Theme.of(context).textTheme;
        final initials = auth.user?.initials;
        final first = auth.user?.firstName;
        return Padding(
          padding: const EdgeInsets.fromLTRB(WsSpace.s12, WsSpace.s16, WsSpace.s8, WsSpace.s16),
          child: Row(
            children: [
              // DLV-A2: the avatar opens the rider's profile.
              IconButton(
                key: const ValueKey('open-profile'),
                tooltip: l.profileOpen,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const RiderProfileScreen()),
                ),
                icon: CircleAvatar(
                  radius: WsSize.avatarMd / 2,
                  backgroundColor: t.primarySubtle,
                  child: initials == null || initials.isEmpty
                      ? Icon(AgIcons.user, color: t.primary)
                      : Text(initials, style: text.titleSmall?.copyWith(color: t.primary)),
                ),
              ),
              const SizedBox(width: WsSpace.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(first == null || first.isEmpty ? l.dashGreetingNoName : l.dashGreeting(first),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium),
                    Text(_isOnline ? l.dashReady : l.dashOfflineShort,
                        style: text.bodySmall?.copyWith(color: t.textSecondary)),
                  ],
                ),
              ),
              // DLV-N1: the inbox — pushes a phone missed, statements, payments.
              if (auth.user != null) InboxButton(riderId: auth.user!.uid, source: _inbox),
              // Phase DLV-S1: this used to show "SOS Alert Sent! Live
              // location shared with authorities and admin." and send
              // nothing. It now opens a sheet that only hands off to the
              // phone dialer (112, Agrimore support) and says so.
              IconButton(
                onPressed: () => showEmergencySheet(context),
                icon: Icon(AgIcons.emergency, color: t.errorFg),
                tooltip: l.emergencyTitle,
              ),
              IconButton(
                onPressed: _confirmSignOut,
                icon: const Icon(AgIcons.logOut),
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
    final t = context.ws;
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: WsSpace.page),
      padding: const EdgeInsets.fromLTRB(WsSpace.s16, WsSpace.s8, WsSpace.s8, WsSpace.s8),
      decoration: BoxDecoration(
        color: _isOnline ? t.successBg : t.surfaceSunken,
        borderRadius: BorderRadius.circular(WsRadius.card),
        border: Border.all(color: _isOnline ? t.successFg : t.divider, width: WsSize.hairline),
      ),
      child: Row(
        children: [
          Icon(_isOnline ? AgIcons.success : AgIcons.stepPending,
              size: WsIconSize.supporting, color: _isOnline ? t.successFg : t.textTertiary),
          const SizedBox(width: WsSpace.s12),
          Expanded(child: Text(_isOnline ? l.dashOnline : l.dashOffline, style: text.titleSmall)),
          Switch(value: _isOnline, onChanged: _toggleOnline),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    final l = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(WsSpace.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Phase DLV-4B: what the server says this rider earned (DLV-4A),
          // replacing a hard-coded "₹4.75 / km, Min ₹15" card and a "Daily
          // Challenge ₹150 bonus" that nothing in the system ever paid.
          _buildEarningsCard(),
          const SizedBox(height: WsSpace.s20),

          // Deliveries from the order stream; money from the server's records.
          _moneyStats(
            (week, today, cash) => Consumer<DeliveryOrderProvider>(
              builder: (context, orderProvider, _) => Column(
                children: [
                  Row(children: [
                    Expanded(
                      child: _StatCard(
                        label: l.dashStatToday,
                        value: orderProvider.todayDelivered?.toString() ?? l.todayDeliveredUnknown,
                        icon: AgIcons.invoice,
                      ),
                    ),
                    const SizedBox(width: WsSpace.s12),
                    Expanded(child: _StatCard(label: l.dashStatWeek, value: week, icon: AgIcons.calendar)),
                  ]),
                  const SizedBox(height: WsSpace.s12),
                  Row(children: [
                    Expanded(
                      child: _StatCard(
                          label: l.dashStatEarnedToday, value: today, icon: AgIcons.wallet, highlight: true),
                    ),
                    const SizedBox(width: WsSpace.s12),
                    Expanded(child: _StatCard(label: l.dashStatCash, value: cash, icon: AgIcons.rupee)),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: WsSpace.s12),
          _ActionCard(
            title: l.dashMoneyTitle,
            subtitle: l.dashMoneySubtitle,
            icon: AgIcons.wallet,
            onTap: _openMoney,
          ),
          const SizedBox(height: WsSpace.s24),
          Text(l.dashQuickActions, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: WsSpace.s12),

          // Phase DLV-2B (D-DLV-LIST): no platform-wide order list any more —
          // orders are offered to this rider and ring when they arrive.
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
                icon: AgIcons.bell,
                badgeCount: offers.offers.length,
                onTap: current == null ? null : () => OfferLaunch.request(current.orderId),
              );
            },
          ),
          const SizedBox(height: WsSpace.s12),
          _ActionCard(
            title: l.historyActionTitle,
            subtitle: l.historyActionSubtitle,
            icon: AgIcons.history,
            onTap: _showDeliveryHistory,
          ),
          // Phase DLV-S1: "Demand Heat Map" and "Smart Route Optimization"
          // were placeholders with nothing behind them — removed until real
          // data exists.
        ],
      ),
    );
  }

  // ── Phase DLV-4B: money from the server (rider_earnings / rider_accounts) ──

  RiderMoneyService? _money;
  Stream<List<RiderEarning>>? _earningsStream;
  Stream<RiderAccount>? _accountStream;

  RiderMoneyService? get _moneyService {
    // DLV-A2: read the provider here, not the field set in a post-frame
    // callback — nothing rebuilt the money section after that callback once
    // DLV-C1 bound the order provider before the dashboard existed, so a
    // rider with no order changes saw "–" for pay and cash indefinitely.
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => MoneyScreen(riderId: uid)));
  }

  /// Builds [child] with this week's pay, today's pay and cash held, formatted.
  Widget _moneyStats(Widget Function(String week, String today, String cash) child) {
    final l = AppLocalizations.of(context);
    if (_moneyService == null) {
      return child(l.todayDeliveredUnknown, l.todayDeliveredUnknown, l.todayDeliveredUnknown);
    }
    return StreamBuilder<List<RiderEarning>>(
      stream: _earningsStream,
      builder: (context, earnings) => StreamBuilder<RiderAccount>(
        stream: _accountStream,
        builder: (context, account) {
          final list = earnings.data;
          final week = list == null ? l.moneyAmountLoading : rupees(sumRupees(list.map((e) => e.total)));
          final today = list == null ? l.moneyAmountLoading : rupees(earnedSince(list, istDayStart(DateTime.now())));
          final cash = account.data == null ? l.moneyAmountLoading : rupees(account.data!.cashHeld);
          return child(week, today, cash);
        },
      ),
    );
  }

  Widget _buildEarningsCard() {
    final l = AppLocalizations.of(context);
    final t = context.ws;
    final text = Theme.of(context).textTheme;
    final on = t.onPrimary;
    return _moneyStats(
      (week, today, _) => Material(
        color: t.primary,
        borderRadius: BorderRadius.circular(WsRadius.card),
        child: InkWell(
          onTap: _openMoney,
          borderRadius: BorderRadius.circular(WsRadius.card),
          child: Padding(
            padding: const EdgeInsets.all(WsSpace.s16),
            child: Row(
              children: [
                Icon(AgIcons.rupee, color: on, size: WsIconSize.feature),
                const SizedBox(width: WsSpace.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.dashEarnedWeek, style: text.labelMedium?.copyWith(color: on)),
                      const SizedBox(height: WsSpace.s4),
                      Text(week, style: text.headlineSmall?.copyWith(color: on)),
                      Text(l.dashEarnedTodayLine(today), style: text.bodySmall?.copyWith(color: on)),
                    ],
                  ),
                ),
                Icon(AgIcons.chevronRight, color: on),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveOrderCard(OrderModel order) {
    final l = AppLocalizations.of(context);
    final t = context.ws;
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.all(WsSpace.page),
      padding: const EdgeInsets.all(WsSpace.s20),
      decoration: BoxDecoration(color: t.primarySubtle, borderRadius: BorderRadius.circular(WsRadius.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(AgIcons.rider, color: t.primary, size: WsIconSize.feature),
              const SizedBox(width: WsSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.dashActiveTitle, style: text.titleMedium),
                    Text(l.offerOrderNumber(order.orderNumber),
                        style: text.bodySmall?.copyWith(color: t.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: WsSpace.s20),
          FilledButton(onPressed: () => _openOrder(order), child: Text(l.dashViewDetails)),
        ],
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
        // Phase DLV-3A: Play's prominent disclosure comes before the
        // location prompt; without location the rider cannot go online.
        if (!await ensureLocationDisclosure(context)) {
          if (mounted) setState(() => _isOnline = false);
          return;
        }
        if (!mounted) return;
        // Phase DLV-2B: notifications, and full-screen alerts on Android 14+,
        // so offers can ring. Asked once; never blocks going online.
        await ensureOfferAlertPermissions(context);
        // Phase DLV-3A2: while-in-use first, then (D-DLV-BGLOC-ALWAYS) the
        // explained 'Allow all the time' step and (D-DLV-BATTERY) the
        // one-time battery guide. Neither of the last two blocks going online.
        var result = await location.ensurePermission();
        var backgroundAllowed = true;
        if (result == GoOnlineResult.started) {
          if (!mounted) return;
          backgroundAllowed = await ensureBackgroundLocation(context);
          if (!mounted) return;
          await maybeShowBatteryGuide(context);
          // Online on the server BEFORE the native service starts: it stops
          // itself whenever the server says offline.
          await location.setOnlineStatus(uid, true);
          result = await location.startTracking(uid);
          if (result != GoOnlineResult.started) {
            await location.setOnlineStatus(uid, false);
          }
        }
        if (!mounted) return;
        final l = AppLocalizations.of(context);
        if (result == GoOnlineResult.started && !backgroundAllowed) {
          WsToast.show(context, l.backgroundLocationReminder);
        }
        if (result != GoOnlineResult.started) {
          setState(() => _isOnline = false);
          final message = result.message(l);
          if (message != null) {
            if (result.needsSettings) {
              // The fix is a phone setting: ask, then open it.
              final open = await wsConfirm(
                context,
                icon: AgIcons.locationOff,
                title: l.goOnlineBlockedTitle,
                message: message,
                confirmLabel: l.actionOpenSettings,
                cancelLabel: l.actionNotNow,
              );
              if (open) {
                await (result == GoOnlineResult.servicesOff
                    ? Geolocator.openLocationSettings()
                    : Geolocator.openAppSettings());
              }
            } else {
              WsToast.show(context, message, tone: WsToastTone.error);
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
    final ok = await wsConfirm(
      context,
      title: l.dashSignOutTitle,
      message: l.dashSignOutBody,
      confirmLabel: l.actionSignOut,
      cancelLabel: l.cancel,
    );
    // DLV-3A: offline first (account/rider_account.dart).
    if (ok && mounted) await riderSignOut(context);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, this.highlight = false});
  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final t = context.ws;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(WsSpace.s16),
      decoration: BoxDecoration(
        color: highlight ? t.primarySubtle : t.surface,
        borderRadius: BorderRadius.circular(WsRadius.card),
        border: Border.all(color: highlight ? t.primary : t.divider, width: WsSize.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: highlight ? t.primary : t.textSecondary),
          const SizedBox(height: WsSpace.s12),
          Text(value, style: text.titleLarge?.copyWith(color: highlight ? t.primary : t.textPrimary)),
          Text(label, style: text.bodySmall?.copyWith(color: t.textSecondary)),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.title, required this.subtitle, required this.icon, this.onTap, this.badgeCount = 0});
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final t = context.ws;
    final text = Theme.of(context).textTheme;
    return Material(
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WsRadius.card),
        side: BorderSide(color: t.divider, width: WsSize.hairline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WsRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(WsSpace.s16),
          child: Row(
            children: [
              Badge.count(
                isLabelVisible: badgeCount > 0,
                count: badgeCount,
                child: Container(
                  width: WsSize.avatarMd,
                  height: WsSize.avatarMd,
                  decoration: BoxDecoration(color: t.primarySubtle, borderRadius: BorderRadius.circular(WsRadius.small)),
                  child: Icon(icon, color: t.primary),
                ),
              ),
              const SizedBox(width: WsSpace.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleSmall),
                    Text(subtitle, style: text.bodySmall?.copyWith(color: t.textSecondary)),
                  ],
                ),
              ),
              if (onTap != null) Icon(AgIcons.chevronRight, color: t.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
