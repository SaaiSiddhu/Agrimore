// lib/app/delivery_shell.dart
//
// Phase DLVNAV1 — the five-tab home for an approved, signed-in rider: Home,
// Deliveries, Earnings, Inbox, Profile (lib/design_system/icons/delivery_
// icons.dart's own "Phase 07" navigation set). Each tab is the real
// production screen, built lazily the first time it is selected and kept
// alive afterward (IndexedStack) so its listeners/streams start once and are
// never restarted by switching tabs — mirroring apps/marketplace/lib/
// screens/user/main_screen.dart's validated `_builtTabs` precedent, rather
// than inventing a new pattern for this app.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../design_system/design_system.dart';
import '../inbox/rider_inbox.dart';
import '../l10n/app_localizations.dart';
import '../money/rider_money.dart';
import '../offers/offer_platform.dart';
import '../providers/auth_provider.dart';
import '../screens/history/rider_history_screen.dart';
import '../screens/home/dashboard_screen.dart';
import '../screens/inbox/inbox_screen.dart';
import '../screens/money/money_screen.dart';
import '../screens/profile/rider_profile_screen.dart';
import 'delivery_tab.dart';

class DeliveryShell extends StatefulWidget {
  const DeliveryShell({
    super.key,
    this.inboxSource,
    this.earningsSource,
    this.accountSource,
    this.homeMapBuilder,
  });

  /// Injected in tests; defaults to the real Firestore-backed source. One
  /// instance is shared by the Home header badge, the bottom nav's own
  /// Inbox badge and the Inbox tab itself, instead of three separate
  /// Firestore listeners for the same unread count.
  final RiderInboxSource? inboxSource;

  /// Passed straight through to the Home tab's DashboardScreen (the same
  /// injectable seam DLV-S1 already added there); repeated here so a shell
  /// test never needs a live Firebase app just to reach the Home tab.
  final Stream<List<RiderEarning>> Function(String riderId)? earningsSource;
  final Stream<RiderAccount> Function(String riderId)? accountSource;

  /// DLVHOME1: forwarded to [DashboardScreen] — see its own doc comment.
  final WidgetBuilder? homeMapBuilder;

  @override
  State<DeliveryShell> createState() => _DeliveryShellState();
}

class _DeliveryShellState extends State<DeliveryShell> {
  late final RiderInboxSource _inbox =
      widget.inboxSource ?? FirestoreRiderInbox();

  DeliveryTab _tab = DeliveryTab.home;

  // Built once per tab, on first visit, and reused as the SAME widget
  // instance on every later shell rebuild (e.g. every unread-count tick).
  // IndexedStack keeps every child mounted regardless of which is showing,
  // so a freshly-CONSTRUCTED widget for every tab on every shell build
  // (identical type, but a new instance) would still make Element.update
  // re-run each tab's build() on every rebuild, defeating half the point of
  // building lazily in the first place. Caching the instance means
  // Flutter's own `identical` short-circuit skips the rebuild entirely for
  // whichever tabs are not the one that actually changed.
  final Map<DeliveryTab, Widget> _tabs = {};

  String? _unreadBoundUid;
  Stream<int>? _unreadStream;

  /// Memoised per uid so a tab switch (a `setState` on this widget) never
  /// recomputes it — calling `_inbox.unreadCount(uid)` inline inside
  /// [build] would otherwise open a fresh Firestore listener on every tab
  /// change, the exact "restarting streams on tab switch" the brief warns
  /// against by name.
  Stream<int> _unreadFor(String uid) {
    if (_unreadBoundUid != uid) {
      _unreadBoundUid = uid;
      _unreadStream = _inbox.unreadCount(uid).asBroadcastStream();
    }
    return _unreadStream!;
  }

  void _goTo(DeliveryTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
  }

  Widget _buildTab(DeliveryTab tab, String uid) => switch (tab) {
        DeliveryTab.home => DashboardScreen(
            inboxSource: _inbox,
            earningsSource: widget.earningsSource,
            accountSource: widget.accountSource,
            homeMapBuilder: widget.homeMapBuilder,
            onOpenTab: _goTo,
          ),
        DeliveryTab.deliveries => const RiderHistoryScreen(),
        DeliveryTab.earnings => MoneyScreen(riderId: uid),
        DeliveryTab.inbox => InboxScreen(
            riderId: uid,
            source: _inbox,
            onOpenTab: _goTo,
          ),
        DeliveryTab.profile => const RiderProfileScreen(),
      };

  Future<void> _handlePop(bool online) async {
    if (_tab != DeliveryTab.home) {
      _goTo(DeliveryTab.home);
      return;
    }
    if (online) {
      if (!await OfferPlatform.moveToBackground()) {
        await SystemNavigator.pop();
      }
    } else {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final auth = context.watch<DeliveryAuthProvider>();
    final uid = auth.user?.uid;
    // The session gate only mounts this widget for an authenticated rider;
    // a null uid here is a transient frame during sign-out, not a state to
    // build a real shell for.
    if (uid == null) return const SizedBox.shrink();
    _tabs[_tab] ??= _buildTab(_tab, uid);
    final online = auth.partnerOnline == true;
    return PopScope(
      // DLVNAV1: a single, shell-owned back-button policy (the server's
      // partnerOnline, not DashboardScreen's own optimistic local flag it
      // used to own this with) — a non-Home tab root goes to Home first;
      // Home itself backgrounds the app while on duty, else exits. Kept as
      // exactly one PopScope so two of them can never AND-veto a pop on a
      // flag that can transiently disagree between them mid-toggle.
      key: const ValueKey('delivery-shell-pop-scope'),
      canPop: _tab == DeliveryTab.home && !online,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handlePop(online);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _tab.index,
          children: [
            for (final t in DeliveryTab.values)
              _tabs[t] ?? const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: StreamBuilder<int>(
          stream: _unreadFor(uid),
          builder: (context, snap) => DeliveryBottomNav(
            currentIndex: _tab.index,
            onTap: (i) => _goTo(DeliveryTab.values[i]),
            destinations: [
              DeliveryNavDestination(
                label: l.navHome,
                icon: DeliveryIcons.home,
              ),
              DeliveryNavDestination(
                label: l.navDeliveries,
                icon: DeliveryIcons.deliveries,
              ),
              DeliveryNavDestination(
                label: l.navEarnings,
                icon: DeliveryIcons.earnings,
              ),
              DeliveryNavDestination(
                label: l.navInbox,
                icon: DeliveryIcons.inbox,
                badgeCount: snap.data ?? 0,
              ),
              DeliveryNavDestination(
                label: l.navProfile,
                icon: DeliveryIcons.profile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
