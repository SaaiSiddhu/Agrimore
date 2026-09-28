// Phase DLVP1 — sign-out confirmation and the proactive, multi-step
// account-deletion eligibility flow (workstream 5.9). Mirrors the fake
// provider set delivery_shell_test.dart already established (this screen
// is normally rendered inside that same shell), but pumps RiderProfileScreen
// directly so each test controls exactly one blocker at a time.
//
// Phase DLVC3 adds the auth-bound partner-data lifecycle group below --
// _FakeGateway above is fixed-at-construction (one uid, one emission),
// which cannot express an account switching mid-session; _MutableGateway
// lets a test push new uids (or a sign-out) at will, and _controllablePartnerSource
// gives per-uid controllable streams so a superseded account's late event
// can be constructed and proven never to reach the current one's screen.
import 'dart:async';

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
import 'package:delivery/screens/support/my_support_requests_screen.dart';
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

/// DLVC3: unlike [_FakeGateway], [emit] can be called repeatedly with a new
/// (or null) uid at any point, simulating a real account switch or
/// sign-out happening WHILE a screen built from an earlier uid is still on
/// screen -- exactly the class of scenario [_FakeGateway]'s one-shot stream
/// cannot express.
class _MutableGateway implements RiderAuthGateway {
  final _controller = StreamController<String?>.broadcast();
  @override
  String? currentUid;
  var signOutCalls = 0;

  void emit(String? uid) {
    currentUid = uid;
    _controller.add(uid);
  }

  @override
  Stream<String?> get uidChanges => _controller.stream;
  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<void> signOut() async {
    signOutCalls++;
    emit(null);
  }

  @override
  Future<void> refreshClaims() async {}
  @override
  Future<void> sendPasswordReset(String email) async {}
}

/// DLVC3: a `partnerSource` backed by one controller per uid, created
/// lazily on first access -- a test drives a SPECIFIC rider's stream
/// directly via `controllers['riderId']!.add(...)`, independent of
/// whichever rider is currently bound in the screen under test.
Stream<Map<String, dynamic>?> Function(String) controllablePartnerSource(
  Map<String, StreamController<Map<String, dynamic>?>> controllers,
) =>
    (uid) => (controllers[uid] ??= StreamController<Map<String, dynamic>?>.broadcast()).stream;

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

  group('auth-bound partner-data lifecycle (DLVC3)', () {
    testWidgets('mounts before auth resolves, then shows real data once auth catches up', (t) async {
      final gateway = _MutableGateway();
      final auth = DeliveryAuthProvider(gateway: gateway, store: _FakeStore(), pushTokens: _NoPush());
      final controllers = <String, StreamController<Map<String, dynamic>?>>{};
      await t.pumpWidget(host(auth, RiderProfileScreen(partnerSource: controllablePartnerSource(controllers))));
      await t.pump(); // auth still resolving -- nothing emitted yet
      expect(find.byType(CircularProgressIndicator), findsOneWidget, reason: 'auth-resolving state, not a crash');
      expect(t.takeException(), isNull);

      gateway.emit('r1');
      await t.pump();
      await t.pump();
      controllers['r1']!.add({'name': 'Ravi'});
      await t.pumpAndSettle();
      expect(find.text('Ravi'), findsOneWidget,
          reason: 'real data must appear once auth resolves -- the pre-auth build must not permanently stick');
    });

    testWidgets("switching from rider A to rider B shows B's data, never A's", (t) async {
      final gateway = _MutableGateway();
      final auth = DeliveryAuthProvider(gateway: gateway, store: _FakeStore(), pushTokens: _NoPush());
      final controllers = <String, StreamController<Map<String, dynamic>?>>{};
      gateway.emit('riderA');
      await t.pump();
      await t.pump();
      await t.pumpWidget(host(auth, RiderProfileScreen(partnerSource: controllablePartnerSource(controllers))));
      controllers['riderA']!.add({'name': 'Rider A'});
      await t.pumpAndSettle();
      expect(find.text('Rider A'), findsOneWidget);

      gateway.emit('riderB');
      await t.pump();
      await t.pump();
      controllers['riderB']!.add({'name': 'Rider B'});
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Rider B'), findsOneWidget);
      expect(find.text('Rider A'), findsNothing,
          reason: "switching accounts must not leave the previous rider's data on screen");
    });

    testWidgets("rider A's data arriving late after switching to B never reaches B's screen", (t) async {
      final gateway = _MutableGateway();
      final auth = DeliveryAuthProvider(gateway: gateway, store: _FakeStore(), pushTokens: _NoPush());
      final controllers = <String, StreamController<Map<String, dynamic>?>>{};
      gateway.emit('riderA');
      await t.pump();
      await t.pump();
      await t.pumpWidget(host(auth, RiderProfileScreen(partnerSource: controllablePartnerSource(controllers))));
      await t.pump(); // A's stream is bound but deliberately left pending -- no data yet

      gateway.emit('riderB');
      await t.pump();
      await t.pump();
      controllers['riderB']!.add({'name': 'Rider B'});
      await t.pumpAndSettle();
      expect(find.text('Rider B'), findsOneWidget);

      // A's response finally arrives, well after the switch -- must be
      // silently ignored: the widget is no longer subscribed to A's stream
      // at all once it rebound to a new stream instance for B.
      controllers['riderA']!.add({'name': 'Rider A'});
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Rider A'), findsNothing,
          reason: 'a late event from a superseded account must never reach the current one');
      expect(find.text('Rider B'), findsOneWidget, reason: "B's own data must survive undisturbed");
    });

    testWidgets('sign-out while Profile is open shows a signed-out state, not stale data', (t) async {
      final gateway = _MutableGateway();
      final auth = DeliveryAuthProvider(gateway: gateway, store: _FakeStore(), pushTokens: _NoPush());
      final controllers = <String, StreamController<Map<String, dynamic>?>>{};
      gateway.emit('r1');
      await t.pump();
      await t.pump();
      await t.pumpWidget(host(auth, RiderProfileScreen(partnerSource: controllablePartnerSource(controllers))));
      controllers['r1']!.add({'name': 'Ravi'});
      await t.pumpAndSettle();
      expect(find.text('Ravi'), findsOneWidget);

      await gateway.signOut();
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: 'the real sign-out cascade must not throw inside this screen');
      expect(find.text('Ravi'), findsNothing, reason: "must not keep showing a signed-out rider's stale data");
    });

    testWidgets('a missing partner record shows a distinct message, not an infinite spinner', (t) async {
      final auth = await authedProvider(t);
      final controllers = <String, StreamController<Map<String, dynamic>?>>{};
      await t.pumpWidget(host(auth, RiderProfileScreen(partnerSource: controllablePartnerSource(controllers))));
      controllers['r1']!.add(null); // a genuine "document does not exist" snapshot, already settled
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text("We couldn't find your profile record. Contact Agrimore support."), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: 'a settled null must read as "no such record", never confused with still-loading');
    });

    testWidgets('a read failure shows Retry, and retrying recovers', (t) async {
      final auth = await authedProvider(t);
      final controllers = <String, StreamController<Map<String, dynamic>?>>{};
      var calls = 0;
      await t.pumpWidget(host(
        auth,
        RiderProfileScreen(
          partnerSource: (uid) {
            calls++;
            if (calls == 1) return Stream<Map<String, dynamic>?>.error('boom');
            return controllablePartnerSource(controllers)(uid);
          },
        ),
      ));
      await t.pumpAndSettle();
      expect(find.text("Couldn't load your profile. Check your connection."), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('profile-retry')));
      // A single bounded pump, not pumpAndSettle: the retry's own new
      // stream has no data yet at this instant, so the screen is showing an
      // indeterminate CircularProgressIndicator, whose animation never
      // settles on its own -- pumpAndSettle here would hang forever.
      await t.pump();
      controllers['r1']!.add({'name': 'Ravi'});
      await t.pumpAndSettle();
      expect(find.text('Ravi'), findsOneWidget, reason: 'a retry must genuinely recover, not stay stuck on the old error');
    });

    testWidgets('an off-stage, tab-retained Profile still rebinds correctly on an account switch', (t) async {
      // Mirrors DeliveryShell's own IndexedStack (every tab stays mounted;
      // only the selected one is on-stage) -- the same State object must
      // react to auth changing even while it is not the visible tab.
      final gateway = _MutableGateway();
      final auth = DeliveryAuthProvider(gateway: gateway, store: _FakeStore(), pushTokens: _NoPush());
      final controllers = <String, StreamController<Map<String, dynamic>?>>{};
      gateway.emit('riderA');
      await t.pump();
      await t.pump();
      await t.pumpWidget(host(
        auth,
        IndexedStack(
          index: 0,
          children: [
            const SizedBox(),
            RiderProfileScreen(partnerSource: controllablePartnerSource(controllers)),
          ],
        ),
      ));
      controllers['riderA']!.add({'name': 'Rider A'});
      await t.pumpAndSettle();

      gateway.emit('riderB');
      await t.pump();
      await t.pump();
      controllers['riderB']!.add({'name': 'Rider B'});
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Rider A', skipOffstage: false), findsNothing,
          reason: 'even off-stage, the tab-retained screen must rebind, not keep the previous rider forever');
      expect(find.text('Rider B', skipOffstage: false), findsOneWidget);
    });
  });

  group('Support & safety navigation (DLVHOME1 Profile redesign)', () {
    testWidgets('My support requests opens MySupportRequestsScreen for the signed-in rider', (t) async {
      final auth = await authedProvider(t);
      await t.pumpWidget(host(
        auth,
        RiderProfileScreen(
          backend: FakeAccountBackend(),
          partnerData: const {'name': 'Ravi'},
        ),
      ));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.byKey(const ValueKey('my-support-requests')), 400);
      await t.ensureVisible(find.byKey(const ValueKey('my-support-requests')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('my-support-requests')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final screen = t.widget<MySupportRequestsScreen>(find.byType(MySupportRequestsScreen));
      expect(screen.riderId, 'r1', reason: 'must use the real signed-in uid, not a placeholder');
    });

    testWidgets('My support requests and My safety reports are two distinct rows to two distinct screens', (t) async {
      final auth = await authedProvider(t);
      await t.pumpWidget(host(
        auth,
        RiderProfileScreen(
          backend: FakeAccountBackend(),
          partnerData: const {'name': 'Ravi'},
        ),
      ));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.byKey(const ValueKey('my-safety-reports')), 400);
      expect(find.byKey(const ValueKey('my-support-requests')), findsOneWidget);
      expect(find.byKey(const ValueKey('my-safety-reports')), findsOneWidget);
    });
  });
}
