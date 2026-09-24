// lib/screens/home/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/location_provider.dart';
import '../orders/active_order_screen.dart';
import '../money/money_screen.dart';
import '../../money/rider_money.dart';
import '../../safety/emergency_sheet.dart';
import '../../l10n/app_localizations.dart';
import '../history/rider_history_screen.dart';
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
      final message = serverOfflineMessage(auth.offlineReason);
      if (message != null) SnackbarHelper.showWarning(context, message);
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
              // Header
              _buildHeader(colorScheme),

              // Online Toggle
              _buildOnlineToggle(colorScheme),

              // Active Order or Dashboard
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
                      body = _buildActiveOrderCard(work.single!, colorScheme);
                    } else if (work.error != null) {
                      body = ActiveWorkError(
                        error: work.error!,
                        onRetry: orderProvider.retry,
                      );
                    } else {
                      body = _buildDashboardContent(colorScheme);
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

  Widget _buildHeader(ColorScheme colorScheme) {
    return Consumer<DeliveryAuthProvider>(
      builder: (context, auth, _) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // DLV-A2: the avatar opens the rider's profile.
              IconButton(
                key: const ValueKey('open-profile'),
                tooltip: AppLocalizations.of(context).profileOpen,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const RiderProfileScreen()),
                ),
                icon: CircleAvatar(
                  radius: 24,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    auth.user?.initials ?? 'DP',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${auth.user?.firstName ?? 'Partner'}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      _isOnline ? 'Ready to deliver' : 'Offline',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Phase DLV-S1: this used to show "SOS Alert Sent! Live
              // location shared with authorities and admin." and send
              // nothing. It now opens a sheet that only hands off to the
              // phone dialer (112, Agrimore support) and says so.
              IconButton(
                onPressed: () => showEmergencySheet(context),
                icon: const Icon(Icons.sos_rounded, color: Colors.red),
                tooltip: 'Emergency help',
              ),
              IconButton(
                onPressed: () => _showLogoutDialog(),
                icon: Icon(Icons.logout_rounded),
                tooltip: 'Logout',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOnlineToggle(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _isOnline
            ? colorScheme.primary
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            _isOnline ? Icons.circle : Icons.circle_outlined,
            size: 12,
            color: _isOnline ? Colors.white : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isOnline ? 'You are Online' : 'You are Offline',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _isOnline ? Colors.white : colorScheme.onSurface,
              ),
            ),
          ),
          Switch(
            value: _isOnline,
            onChanged: (value) => _toggleOnline(value),
            activeColor: Colors.white,
            activeTrackColor: Colors.white.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phase DLV-4B: what the server says this rider earned (DLV-4A),
          // replacing a hard-coded "₹4.75 / km, Min ₹15" card and a "Daily
          // Challenge ₹150 bonus" that nothing in the system ever paid.
          _buildEarningsCard(),
          const SizedBox(height: 20),

          // Stats Row — deliveries from the order stream; money from the
          // server's records (DLV-4B).
          _moneyStats(
            (week, today, cash) => Consumer<DeliveryOrderProvider>(
              builder: (context, orderProvider, _) => Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Today',
                          orderProvider.todayDelivered?.toString() ??
                              AppLocalizations.of(context).todayDeliveredUnknown,
                          Icons.receipt_long_rounded,
                          colorScheme,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'This week',
                          week,
                          Icons.date_range_rounded,
                          colorScheme,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Earned today',
                          today,
                          Icons.account_balance_wallet_rounded,
                          colorScheme,
                          isHighlight: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Cash with you',
                          cash,
                          Icons.payments_rounded,
                          colorScheme,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          _buildActionCard(
            'Earnings & payouts',
            'Pay per delivery, cash with you, Monday statements',
            Icons.account_balance_wallet_rounded,
            colorScheme,
            onTap: _openMoney,
          ),

          const SizedBox(height: 24),

          // Quick Actions
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),

          // Phase DLV-2B (D-DLV-LIST): no platform-wide order list any more —
          // orders are offered to this rider and ring when they arrive.
          Consumer<OfferProvider>(
            builder: (context, offers, _) {
              final current = offers.current;
              return _buildActionCard(
                current != null
                    ? 'Order offered to you'
                    : _isOnline
                        ? 'Waiting for orders'
                        : 'Go online to get orders',
                current != null
                    ? 'Tap to see it before it expires'
                    : _isOnline
                        ? 'New orders near you will ring on this phone'
                        : 'Orders are only offered while you are online',
                Icons.notifications_active_rounded,
                colorScheme,
                badgeCount: offers.offers.length,
                onTap: current == null
                    ? null
                    : () => OfferLaunch.request(current.orderId),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            AppLocalizations.of(context).historyActionTitle,
            AppLocalizations.of(context).historyActionSubtitle,
            Icons.history_rounded,
            colorScheme,
            onTap: () {
              _showDeliveryHistory();
            },
          ),
          // Phase DLV-S1: "Demand Heat Map" and "Smart Route Optimization"
          // were placeholders ("Heat Map loading...", "Calculating best
          // route...") with nothing behind them — removed until real data
          // exists.
        ],
      ),
    );
  }

  // ── Phase DLV-4B: money from the server (rider_earnings / rider_accounts) ──

  RiderMoneyService? _money;
  Stream<List<RiderEarning>>? _earningsStream;
  Stream<RiderAccount>? _accountStream;

  RiderMoneyService? get _moneyService {
    final uid = _auth?.user?.uid;
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
    if (_moneyService == null) return child('–', '–', '–');
    return StreamBuilder<List<RiderEarning>>(
      stream: _earningsStream,
      builder: (context, earnings) => StreamBuilder<RiderAccount>(
        stream: _accountStream,
        builder: (context, account) {
          final list = earnings.data;
          final week = list == null ? '…' : rupees(list.fold(0.0, (s, e) => s + e.total));
          final today = list == null ? '…' : rupees(earnedSince(list, istDayStart(DateTime.now())));
          final cash = account.data == null ? '…' : rupees(account.data!.cashHeld);
          return child(week, today, cash);
        },
      ),
    );
  }

  Widget _buildEarningsCard() {
    return _moneyStats(
      (week, today, _) => InkWell(
        onTap: _openMoney,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade400, Colors.green.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.currency_rupee_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Earned this week',
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(week, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                    Text('Today $today · paid every Monday',
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    ColorScheme colorScheme, {
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isHighlight
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlight
              ? colorScheme.primary.withOpacity(0.3)
              : colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: isHighlight
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            size: 28,
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isHighlight ? colorScheme.primary : colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    ColorScheme colorScheme, {
    VoidCallback? onTap,
    int badgeCount = 0,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: colorScheme.primary),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveOrderCard(OrderModel order, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.delivery_dining_rounded,
                color: colorScheme.primary,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active Delivery',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      'Order #${order.orderNumber}',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ActiveOrderScreen(order: order),
              ),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text('View Details'),
          ),
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
        if (result == GoOnlineResult.started && !backgroundAllowed) {
          SnackbarHelper.showWarning(context, backgroundLocationReminder);
        }
        if (result != GoOnlineResult.started) {
          setState(() => _isOnline = false);
          final message = result.message;
          if (message != null) {
            if (result.needsSettings) {
              SnackbarHelper.showWithAction(
                context,
                message,
                'Settings',
                () => result == GoOnlineResult.servicesOff
                    ? Geolocator.openLocationSettings()
                    : Geolocator.openAppSettings(),
              );
            } else {
              SnackbarHelper.showError(context, message);
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

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              // DLV-3A: offline first (account/rider_account.dart).
              await riderSignOut(this.context);
            },
            child: Text('Logout'),
          ),
        ],
      ),
    );
  }
}
