// Phase DLVP1 — sign-out confirmation and the proactive, multi-step
// account-deletion eligibility flow (workstream 5.9). Mirrors the fake
// provider set delivery_shell_test.dart already established (this screen
// is normally rendered inside that same shell), but pumps RiderProfileScreen
// directly so each test controls exactly one blocker at a time.
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:delivery/account/rider_account.dart';
import 'package:delivery/auth/rider_account_source.dart';
import 'package:delivery/data/rider_work.dart';
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/money/rider_money.dart';
import 'package:delivery/providers/auth_provider.dart';
import 'package:delivery/providers/location_provider.dart';
import 'package:delivery/providers/order_provider.dart';
import 'package:delivery/screens/money/money_screen.dart';
import 'package:delivery/screens/orders/active_order_screen.dart';
import 'package:delivery/screens/profile/rider_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeGateway implements RiderAuthGateway {
  _FakeGateway(this.currentUid);
  @override
  final String? currentUid;
  var signOutCalls = 0;
  @override
  Stream<String?> get uidChanges => Stream.value(currentUid);
  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<void> signOut() async => signOutCalls++;
  @override
  Future<void> refreshClaims() async {}
  @override
  Future<void> sendPasswordReset(String email) async {}
}

class _FakeStore implements RiderAccountStore {
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
        data: const {'status': 'approved', 'isOnline': false},
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

class FakeAccountBackend implements RiderAccountBackend {
  var deleteCalls = 0;
  Object? deleteError;
  @override
  Future<void> updateContact(Map<String, dynamic> contact) async {}
  @override
  Future<void> deleteAccount() async {
    deleteCalls++;
    if (deleteError != null) throw deleteError!;
  }
}

DeliveryOrderProvider fakeOrders(String uid, {List<OrderDoc> active = const []}) =>
    DeliveryOrderProvider(
      activeSource: (_) => Stream.value((docs: active, fromCache: false)),
      deliveredCount: (_, __) async => 0,
      historyFetch: (_, __, ___, ____) async =>
          (items: const <OrderModel>[], cursor: null, hasMore: false),
    )..bind(uid);

Future<DeliveryAuthProvider> authedProvider(WidgetTester t, {RiderAuthGateway? gateway}) async {
  final auth = DeliveryAuthProvider(
    gateway: gateway ?? _FakeGateway('r1'),
    store: _FakeStore(),
    pushTokens: _NoPush(),
  );
  await t.pump();
  await t.pump();
  expect(auth.isAuthenticated, isTrue, reason: 'fixture must reach an approved, signed-in rider');
  return auth;
}

Widget host(
  DeliveryAuthProvider auth,
  Widget child, {
  List<OrderDoc> activeOrders = const [],
}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider<DeliveryAuthProvider>.value(value: auth),
        ChangeNotifierProvider<DeliveryOrderProvider>.value(
          value: fakeOrders('r1', active: activeOrders),
        ),
        ChangeNotifierProvider<LocationProvider>(create: (_) => LocationProvider()),
      ],
      child: MaterialApp(
        theme: WorkspaceTheme.build(WorkspaceBrand.delivery, Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

OrderDoc activeOrder(String id) => (
      id: id,
      data: {
        'orderNumber': 'AGM-$id',
        'orderStatus': 'out_for_delivery',
        'total': 200,
        'deliveryPartnerId': 'r1',
      },
    );

void main() {
  group('sign-out confirmation (DLVP1)', () {
    testWidgets('shows a confirmation dialog; cancelling does not sign out', (t) async {
      final gateway = _FakeGateway('r1');
      final auth = await authedProvider(t, gateway: gateway);
      await t.pumpWidget(host(
        auth,
        RiderProfileScreen(
          backend: FakeAccountBackend(),
          partnerData: const {'name': 'Ravi'},
        ),
      ));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.byKey(const ValueKey('sign-out')), 400);
      await t.ensureVisible(find.byKey(const ValueKey('sign-out')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('sign-out')));
      await t.pumpAndSettle();
      expect(find.text('Sign out of this device?'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(gateway.signOutCalls, 0);
    });

    testWidgets('confirming signs out', (t) async {
      final gateway = _FakeGateway('r1');
      final auth = await authedProvider(t, gateway: gateway);
      await t.pumpWidget(host(
        auth,
        RiderProfileScreen(
          backend: FakeAccountBackend(),
          partnerData: const {'name': 'Ravi'},
        ),
      ));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.byKey(const ValueKey('sign-out')), 400);
      await t.ensureVisible(find.byKey(const ValueKey('sign-out')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('sign-out')));
      await t.pumpAndSettle();
      await t.tap(find.text('Sign out').last);
      await t.pumpAndSettle();
      expect(gateway.signOutCalls, 1);
    });
  });

  group('account deletion eligibility (DLVP1)', () {
    testWidgets('an active order blocks deletion with a distinct message, not the generic confirm', (t) async {
      final auth = await authedProvider(t);
      await t.pumpWidget(host(
        auth,
        RiderProfileScreen(
          backend: FakeAccountBackend(),
          partnerData: const {'name': 'Ravi'},
          accountSource: (_) => Stream.value(RiderAccount.fromMap(const {})),
        ),
        activeOrders: [activeOrder('9')],
      ));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.byKey(const ValueKey('delete-account')), 400);
      await t.ensureVisible(find.byKey(const ValueKey('delete-account')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('delete-account')));
      await t.pumpAndSettle();
      expect(
        find.text('You still have an order assigned. Deliver it or ask Agrimore to reassign it first.'),
        findsOneWidget,
      );
      expect(find.text('Delete your account?'), findsNothing);
      await t.tap(find.text('View delivery'));
      await t.pumpAndSettle();
      expect(find.byType(ActiveOrderScreen), findsOneWidget);
    });

    testWidgets('held cash blocks deletion and links to Earnings', (t) async {
      final auth = await authedProvider(t);
      await t.pumpWidget(host(
        auth,
        RiderProfileScreen(
          backend: FakeAccountBackend(),
          partnerData: const {'name': 'Ravi'},
          accountSource: (_) => Stream.value(RiderAccount.fromMap(const {'cashHeld': 620})),
        ),
      ));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.byKey(const ValueKey('delete-account')), 400);
      await t.ensureVisible(find.byKey(const ValueKey('delete-account')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('delete-account')));
      await t.pumpAndSettle();
      expect(
        find.text("You still hold customers' cash. Deposit it with Agrimore first."),
        findsOneWidget,
      );
      await t.tap(find.text('View earnings'));
      await t.pumpAndSettle();
      expect(find.byType(MoneyScreen), findsOneWidget);
    });

    testWidgets('unsettled earnings block deletion with a distinct message from held cash', (t) async {
      final auth = await authedProvider(t);
      await t.pumpWidget(host(
        auth,
        RiderProfileScreen(
          backend: FakeAccountBackend(),
          partnerData: const {'name': 'Ravi'},
          accountSource: (_) =>
              Stream.value(RiderAccount.fromMap(const {'earningsUnsettled': 80})),
        ),
      ));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.byKey(const ValueKey('delete-account')), 400);
      await t.ensureVisible(find.byKey(const ValueKey('delete-account')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('delete-account')));
      await t.pumpAndSettle();
      expect(
        find.text('Agrimore still owes you delivery pay. Wait until your statement is paid.'),
        findsOneWidget,
      );
    });

    testWidgets('nothing blocking: the real confirm-and-delete flow runs, signs out on success', (t) async {
      final gateway = _FakeGateway('r1');
      final backend = FakeAccountBackend();
      final auth = await authedProvider(t, gateway: gateway);
      await t.pumpWidget(host(
        auth,
        RiderProfileScreen(
          backend: backend,
          partnerData: const {'name': 'Ravi'},
          accountSource: (_) => Stream.value(RiderAccount.fromMap(const {})),
        ),
      ));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.byKey(const ValueKey('delete-account')), 400);
      await t.ensureVisible(find.byKey(const ValueKey('delete-account')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('delete-account')));
      await t.pumpAndSettle();
      expect(find.text('Delete your account?'), findsOneWidget);
      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();
      expect(backend.deleteCalls, 1);
      expect(gateway.signOutCalls, 1);
    });
  });
}
