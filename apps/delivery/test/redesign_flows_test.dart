import 'dart:async';
import 'dart:typed_data';

import 'package:delivery/account/rider_account.dart';
import 'package:delivery/auth/rider_account_source.dart';
import 'package:delivery/delivery/delivery_problems.dart';
import 'package:delivery/design_system/design_system.dart';
import 'package:delivery/inbox/rider_inbox.dart';
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/money/rider_money.dart';
import 'package:delivery/offers/delivery_offer.dart';
import 'package:delivery/providers/auth_provider.dart';
import 'package:delivery/providers/offer_provider.dart';
import 'package:delivery/registration/registration_draft.dart';
import 'package:delivery/registration/rider_application.dart';
import 'package:delivery/safety/emergency_sheet.dart';
import 'package:delivery/screens/auth/login_screen.dart';
import 'package:delivery/screens/auth/rider_registration_screen.dart';
import 'package:delivery/screens/inbox/inbox_screen.dart';
import 'package:delivery/screens/money/statement_screen.dart';
import 'package:delivery/screens/offers/incoming_offer_screen.dart';
import 'package:delivery/screens/orders/delivery_problem_panel.dart';
import 'package:delivery/screens/profile/rider_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoAuth implements RiderAuthGateway {
  @override
  Stream<String?> get uidChanges => Stream.value(null);
  @override
  String? get currentUid => null;
  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<void> refreshClaims() async {}
  @override
  Future<void> sendPasswordReset(String email) async {}
}

class _NoStore implements RiderAccountStore {
  @override
  Future<ProfileRead> user(String uid) async =>
      const ProfileRead(exists: false, fromCache: false);
  @override
  Future<ProfileRead> partner(String uid) async =>
      const ProfileRead(exists: false, fromCache: false);
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

/// DLVID4: none of these responsive-layout checks exercise draft recovery --
/// keeps the screen from touching real secure storage.
class _NoDraftStore implements RegistrationDraftStore {
  @override
  Future<RegistrationDraft?> load(String key) async => null;
  @override
  Future<void> save(String key, RegistrationDraft draft) async {}
  @override
  Future<void> clear(String key) async {}
}

class _FakeReg implements RegistrationBackend {
  @override
  String? get currentUid => null;
  @override
  Future<String> createAccount(String email, String password) async => 'u1';
  @override
  Future<void> uploadPhoto(
    String path,
    Uint8List bytes,
    String contentType,
  ) async {}
  @override
  Future<void> submit(Map<String, dynamic> payload) async {}
}

class _FakeAccountBackend implements RiderAccountBackend {
  @override
  Future<void> updateContact(Map<String, dynamic> contact) async {}
  @override
  Future<void> deleteAccount() async {}
}

class _FakeOfferProvider extends OfferProvider {
  _FakeOfferProvider(this._list);
  final List<DeliveryOffer> _list;

  @override
  List<DeliveryOffer> get offers => _list;
  @override
  DeliveryOffer? get current => _list.isEmpty ? null : _list.first;
  @override
  DeliveryOffer? byOrderId(String orderId) {
    for (final o in _list) {
      if (o.orderId == orderId) return o;
    }
    return null;
  }

  @override
  Future<OfferActionResult> accept(String orderId) async =>
      const OfferActionResult.success();
  @override
  Future<OfferActionResult> decline(String orderId, {String? reason}) async =>
      const OfferActionResult.success();
}

class _FakeInbox implements RiderInboxSource {
  final List<RiderNotice> items = [
    RiderNotice(
      id: 'n1',
      type: 'payout_sent',
      title: 'Weekly payout sent',
      body: '₹1,000.50 sent to bank account ending 7890',
      unread: true,
      createdAt: DateTime(2026, 9, 24, 9),
    ),
  ];

  @override
  Stream<List<RiderNotice>> latest(String riderId) => Stream.value(items);
  @override
  Stream<int> unreadCount(String riderId) => Stream.value(1);
  @override
  Future<void> markRead(String riderId, Iterable<String> ids) async {}
  @override
  Future<void> markAllRead(String riderId) async {}
}

class _FakeProblemBackend implements DeliveryProblemBackend {
  @override
  Future<String> report(Map<String, dynamic> payload) async => 'ex1';
  @override
  Future<void> uploadProof(
    String orderId,
    Uint8List bytes,
    String contentType,
  ) async {}
  @override
  Future<void> attachProof(String orderId) async {}
}

Widget _host(
  Widget child, {
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  Size size = const Size(390, 844),
  DeliveryAppearanceController? appearance,
}) {
  final controller = appearance ?? DeliveryAppearanceController();
  return DeliveryAppearanceScope(
    controller: controller,
    child: ChangeNotifierProvider<DeliveryAuthProvider>(
      create: (_) => DeliveryAuthProvider(
        gateway: _NoAuth(),
        store: _NoStore(),
        pushTokens: _NoPush(),
      ),
      child: MaterialApp(
        theme: DeliveryTheme.of(brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, home) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: home!,
        ),
        home: child,
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    group('Redesigned Screens in ${brightness.name} mode (Phases 15–32)', () {
      testWidgets(
        'LoginScreen renders hero, brand lockup, and 200% text scale cleanly on small phone (360x640)',
        (t) async {
          t.view.physicalSize = const Size(360, 640);
          t.view.devicePixelRatio = 1.0;
          addTearDown(t.view.reset);

          await t.pumpWidget(_host(
            const LoginScreen(),
            brightness: brightness,
            textScale: 2.0,
            size: const Size(360, 640),
          ));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          expect(find.byType(DeliveryLogo), findsOneWidget);
          expect(find.byType(DeliveryHeroIllustration), findsOneWidget);
        },
      );

      testWidgets(
        'RiderRegistrationScreen renders 5-step wizard on large phone (412x915) and tablet (800x1280)',
        (t) async {
          for (final viewport in [const Size(412, 915), const Size(800, 1280)]) {
            t.view.physicalSize = viewport;
            t.view.devicePixelRatio = 1.0;

            await t.pumpWidget(_host(
              RiderRegistrationScreen(
                service: RegistrationService(_FakeReg()),
                draftStore: _NoDraftStore(),
              ),
              brightness: brightness,
              size: viewport,
            ));
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
            expect(find.byType(DeliveryStepIndicator), findsOneWidget);
          }
          addTearDown(t.view.reset);
        },
      );

      testWidgets('IncomingOfferScreen renders SLA countdown ring, payout hero, and route timeline', (t) async {
        final offer = DeliveryOffer(
          orderId: 'o1',
          orderNumber: 'ORD-501',
          expiresAt: DateTime.now().add(const Duration(seconds: 24)),
          pickupDistanceKm: 1.4,
          pickupArea: 'Madurai · 625001',
          dropPincode: '625002',
          dropDistanceKm: 3.2,
          itemCount: 4,
          codAmount: 450,
          estimatedPay: 52,
        );
        final provider = _FakeOfferProvider([offer]);
        await t.pumpWidget(
          ChangeNotifierProvider<OfferProvider>.value(
            value: provider,
            child: _host(
              const IncomingOfferScreen(orderId: 'o1'),
              brightness: brightness,
            ),
          ),
        );
        await t.pump();
        expect(t.takeException(), isNull);
        expect(find.byType(DeliveryCountdownRing), findsOneWidget);
        expect(find.text('Collect ₹450 in cash'), findsOneWidget);
      });

      testWidgets('StatementScreen renders formula, reference, and empty/loaded states', (t) async {
        final payout = RiderPayout.fromMap('p1', {
          'weekKey': '2026-W38',
          'orderCount': 24,
          'earnedPaise': 142050,
          'nettedPaise': 42000,
          'amountPaise': 100050,
          'cashHeldAfterPaise': 0,
          'status': 'paid',
          'paymentReference': 'UTR998877',
          'paidTo': {'method': 'bank', 'accountLast4': '7890'},
        });
        await t.pumpWidget(_host(
          StatementScreen(
            payout: payout,
            load: (_) async => const StatementPage([], null, false),
          ),
          brightness: brightness,
          textScale: 1.5,
        ));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.text('− ₹420.00'), findsOneWidget);
      });

      testWidgets('ProblemReportSheet and EmergencySheet render cleanly', (t) async {
        await t.pumpWidget(_host(
          Scaffold(
            body: ProblemReportSheet(
              orderId: 'o1',
              backend: _FakeProblemBackend(),
              fix: () async => {'lat': 9.9, 'lng': 78.1},
            ),
          ),
          brightness: brightness,
        ));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);

        await t.pumpWidget(_host(
          Scaffold(
            body: EmergencySheet(
              launcher: (_) async => true,
              supportPhone: '+91 98765 43210',
              reporter: (_) async => 'inc1',
              fix: () async => {'lat': 9.9, 'lng': 78.1},
            ),
          ),
          brightness: brightness,
        ));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      });

      testWidgets('InboxScreen and ContactEditSheet render cleanly at 200% text scale', (t) async {
        await t.pumpWidget(_host(
          InboxScreen(riderId: 'r1', source: _FakeInbox()),
          brightness: brightness,
          textScale: 2.0,
        ));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.text('Weekly payout sent'), findsOneWidget);

        await t.pumpWidget(_host(
          Scaffold(
            body: ContactEditSheet(
              initial: const {
                'altPhone': '9123456789',
                'address': '14 Gandhi Nagar',
                'city': 'Madurai',
                'pincode': '625020',
              },
              backend: _FakeAccountBackend(),
            ),
          ),
          brightness: brightness,
          textScale: 1.5,
        ));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      });
    });
  }
}
