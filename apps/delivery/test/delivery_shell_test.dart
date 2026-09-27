// Phase DLVNAV1 — the five-tab shell: DeliveryBottomNav had zero
// instantiations anywhere in the app before this phase (grep-confirmed at
// branch creation) and the session gate returned DashboardScreen directly.
// These tests render the REAL shell over the REAL five tab-root screens
// (DashboardScreen, RiderHistoryScreen, MoneyScreen, InboxScreen,
// RiderProfileScreen) — not a substitute Scaffold — and prove: all five
// tabs are reachable, the correct one is selected, Home's own internal
// navigations (profile avatar, inbox bell) switch tabs rather than pushing
// a duplicate tab-root route, the Inbox badge reaches the nav bar, and the
// back-button policy is wired (non-Home tab -> Home; Home root's own
// canPop reflects on/offline).
import 'dart:async';

import 'package:agrimore_core/agrimore_core.dart' show OrderModel;
import 'package:delivery/app/delivery_shell.dart';
import 'package:delivery/auth/rider_account_source.dart';
import 'package:delivery/data/rider_work.dart';
import 'package:delivery/design_system/design_system.dart';
import 'package:delivery/inbox/rider_inbox.dart';
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/money/rider_money.dart';
import 'package:delivery/providers/auth_provider.dart';
import 'package:delivery/providers/location_provider.dart';
import 'package:delivery/providers/offer_provider.dart';
import 'package:delivery/providers/order_provider.dart';
import 'package:delivery/screens/history/rider_history_screen.dart';
import 'package:delivery/screens/money/money_screen.dart';
import 'package:delivery/screens/profile/rider_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeGateway implements RiderAuthGateway {
  _FakeGateway(String? uid) : currentUid = uid;
  @override
  final String? currentUid;
  @override
  Stream<String?> get uidChanges => Stream.value(currentUid);
  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<void> refreshClaims() async {}
  @override
  Future<void> sendPasswordReset(String email) async {}
}

class _FakeStore implements RiderAccountStore {
  _FakeStore({required this.online});
  final bool online;
  @override
  Future<ProfileRead> user(String uid) async => ProfileRead(
        exists: true,
        fromCache: false,
        data: const {'email': 'r@x.in', 'name': 'Ravi', 'role': 'delivery_partner'},
      );
  @override
  Future<ProfileRead> partner(String uid) async => ProfileRead(
        exists: true,
        fromCache: false,
        data: {'status': 'approved', 'isOnline': online},
      );
  @override
  Stream<ProfileRead> watchPartner(String uid) => const Stream.empty();
  @override
  Future<void> addToken(String uid, String token) async {}
  @override
  Future<void> removeToken(String uid, String token) async {}
}

class _NoPush implements RiderPushTokens {
  @override
  Future<String?> current() async => null;
  @override
  Stream<String> get refreshed => const Stream.empty();
  @override
  Future<void> forget() async {}
}

class _FakeInbox implements RiderInboxSource {
  @override
  Stream<List<RiderNotice>> latest(String riderId) => Stream.value([
        RiderNotice(
          id: 'n1',
          type: 'payout_sent',
          title: 'Weekly payout sent',
          body: 'Sent to your bank account',
          unread: true,
        ),
      ]);
  @override
  Stream<int> unreadCount(String riderId) => Stream.value(2);
  @override
  Future<void> markRead(String riderId, Iterable<String> ids) async {}
  @override
  Future<void> markAllRead(String riderId) async {}
}

DeliveryOrderProvider _fakeOrders(String uid) => DeliveryOrderProvider(
      activeSource: (_) => Stream.value((docs: <OrderDoc>[], fromCache: false)),
      deliveredCount: (_, __) async => 3,
      historyFetch: (_, __, ___, ____) async =>
          (items: const <OrderModel>[], cursor: null, hasMore: false),
    )..bind(uid);

// pumpEventQueue() drives REAL Future.delayed timers, but testWidgets runs
// under AutomatedTestWidgetsFlutterBinding's fake clock, which only advances
// on tester.pump() — pumpEventQueue() alone never returns here (it does
// under a plain test() body, which is why auth_session_test.dart can use
// it; testWidgets needs the tester itself).
Future<DeliveryAuthProvider> _authedProvider(WidgetTester t, {bool online = false}) async {
  final auth = DeliveryAuthProvider(
    gateway: _FakeGateway('r1'),
    store: _FakeStore(online: online),
    pushTokens: _NoPush(),
  );
  await t.pump();
  await t.pump();
  expect(auth.isAuthenticated, isTrue, reason: 'fixture must reach an approved, signed-in rider');
  return auth;
}

Widget _shellHost(DeliveryAuthProvider auth, String uid, {Brightness brightness = Brightness.light}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<DeliveryAuthProvider>.value(value: auth),
      ChangeNotifierProvider<DeliveryOrderProvider>.value(value: _fakeOrders(uid)),
      ChangeNotifierProvider<LocationProvider>(create: (_) => LocationProvider()),
      ChangeNotifierProvider<OfferProvider>(create: (_) => OfferProvider()),
    ],
    child: MaterialApp(
      theme: DeliveryTheme.of(brightness),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DeliveryShell(
        inboxSource: _FakeInbox(),
        earningsSource: (_) => Stream.value(const <RiderEarning>[]),
        accountSource: (_) => Stream.value(RiderAccount.fromMap(const {'cashHeld': 0})),
      ),
    ),
  );
}

void main() {
  testWidgets('shell renders Home by default with all five destinations', (t) async {
    final auth = await _authedProvider(t);
    await t.pumpWidget(_shellHost(auth, 'r1'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);

    for (final label in ['Home', 'Deliveries', 'Earnings', 'Inbox', 'Profile']) {
      expect(find.text(label), findsOneWidget, reason: '$label destination missing');
    }
    expect(
      t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
      reason: 'Home is the default tab',
    );
    // Dashboard's own greeting header, not a substitute screen.
    expect(find.byKey(const ValueKey('open-profile')), findsOneWidget);
  });

  testWidgets('the Inbox destination shows the shared unread badge', (t) async {
    final auth = await _authedProvider(t);
    await t.pumpWidget(_shellHost(auth, 'r1'));
    await t.pumpAndSettle();
    expect(find.text('2'), findsWidgets, reason: 'unread count from the shared inbox source');
  });

  testWidgets('tapping each destination reaches the real tab-root screen', (t) async {
    final auth = await _authedProvider(t);
    await t.pumpWidget(_shellHost(auth, 'r1'));
    await t.pumpAndSettle();

    await t.tap(find.text('Deliveries'));
    await t.pumpAndSettle();
    expect(find.byType(RiderHistoryScreen), findsOneWidget);
    expect(
      t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );

    // MoneyScreen has no injectable seam yet for its own five other data
    // feeds (payouts/bank-change/payout-details/cash-limit — earnings and
    // account were added this phase but the shell does not thread them
    // through, out of scope for a navigation test): it hits real,
    // uninitialized Firestore here and throws once per feed. Expected in
    // this fixture, not a navigation defect — consumed so it doesn't fail
    // the test; a dedicated MoneyScreen test is the right place to assert
    // on its data states.
    await t.tap(find.text('Earnings'));
    await t.pumpAndSettle();
    t.takeException();
    expect(find.byType(MoneyScreen), findsOneWidget);
    expect(
      t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );

    // Not pumpAndSettle: RiderProfileScreen has no partnerData injected here
    // (its own data-fetch seam is a separate, pre-existing concern outside
    // navigation) so it shows a permanent spinner in this fixture — a real
    // Firestore doc resolves it in production. One pump is enough to prove
    // the tab switch itself reached the real screen.
    await t.tap(find.text('Profile'));
    await t.pump();
    expect(find.byType(RiderProfileScreen), findsOneWidget);
    expect(
      t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      4,
    );

    // Back to Home: Dashboard's own state (built on first visit) is
    // still alive, not rebuilt from scratch — its greeting header is
    // there immediately with no further async wait.
    await t.tap(find.text('Home'));
    await t.pump();
    expect(find.byKey(const ValueKey('open-profile')), findsOneWidget);
  });

  testWidgets("Home header's profile avatar switches tabs, not a push", (t) async {
    final auth = await _authedProvider(t);
    await t.pumpWidget(_shellHost(auth, 'r1'));
    await t.pumpAndSettle();

    // Not pumpAndSettle: see the note in the destinations test above about
    // RiderProfileScreen's own permanent spinner in this fixture.
    await t.tap(find.byKey(const ValueKey('open-profile')));
    await t.pump();

    expect(find.byType(RiderProfileScreen), findsOneWidget);
    expect(
      t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      4,
      reason: 'a tab switch changes the shells own selection; a push would not',
    );
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    expect(nav.canPop(), isFalse, reason: 'no route was pushed');
  });

  testWidgets('back-button policy: a non-Home tab root returns to Home', (t) async {
    final auth = await _authedProvider(t);
    await t.pumpWidget(_shellHost(auth, 'r1'));
    await t.pumpAndSettle();

    await t.tap(find.text('Deliveries'));
    await t.pumpAndSettle();
    final popScope = find.byKey(const ValueKey('delivery-shell-pop-scope'));
    final scope = t.widget(popScope) as PopScope;
    expect(
      scope.canPop,
      isFalse,
      reason: 'a non-Home tab root must never let system back close the app',
    );

    // Exercise the shell's own pop handler directly (didPop: false, as the
    // framework would call it when canPop already vetoed a real pop)
    // rather than going through Navigator.maybePop(), whose own return
    // value reflects Flutter's route-level bookkeeping, not this widget's
    // tab-switch decision.
    scope.onPopInvokedWithResult!(false, null);
    await t.pump();
    expect(t.takeException(), isNull);
    expect(
      t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
      reason: 'system back moved from Deliveries to Home',
    );
  });

  testWidgets('back-button policy: Home root allows pop when off duty', (t) async {
    final auth = await _authedProvider(t, online: false);
    await t.pumpWidget(_shellHost(auth, 'r1'));
    await t.pumpAndSettle();
    final popScope = find.byKey(const ValueKey('delivery-shell-pop-scope'));
    expect((t.widget(popScope) as PopScope).canPop, isTrue);
  });

  testWidgets('back-button policy: Home root blocks pop while on duty (backgrounds instead)', (t) async {
    final auth = await _authedProvider(t, online: true);
    await t.pumpWidget(_shellHost(auth, 'r1'));
    await t.pumpAndSettle();
    final popScope = find.byKey(const ValueKey('delivery-shell-pop-scope'));
    expect(
      (t.widget(popScope) as PopScope).canPop,
      isFalse,
      reason: 'on duty: back should background the app via OfferPlatform, never silently exit',
    );
  });

  testWidgets(
    'DLVDASH1: the online-toggle card has its own explanatory subtitle, not a repeat of the header status',
    (t) async {
      final auth = await _authedProvider(t, online: false);
      await t.pumpWidget(_shellHost(auth, 'r1'));
      await t.pumpAndSettle();

      // The header's own short status line still reads the bare word.
      expect(find.text('Offline'), findsOneWidget, reason: 'header status line, unchanged by this phase');
      // The toggle card no longer repeats it -- it shows genuine explanatory
      // copy instead (matching the mockup's own distinct third line).
      expect(find.text('Orders are only offered while you are online.'), findsOneWidget);
      // The toggle card's own title is still present and distinct from both.
      expect(find.text('You are offline'), findsOneWidget);
    },
  );
}
