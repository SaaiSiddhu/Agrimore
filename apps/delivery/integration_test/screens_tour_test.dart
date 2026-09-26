import 'dart:async';
import 'dart:typed_data';

import 'package:agrimore_core/agrimore_core.dart' show OrderModel;
import 'package:delivery/account/rider_account.dart';
import 'package:delivery/auth/rider_account_source.dart';
import 'package:delivery/data/rider_work.dart';
import 'package:delivery/delivery/delivery_problems.dart';
import 'package:delivery/design_system/design_system.dart';
import 'package:delivery/inbox/rider_inbox.dart';
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/money/rider_money.dart';
import 'package:delivery/offers/delivery_offer.dart';
import 'package:delivery/providers/auth_provider.dart';
import 'package:delivery/providers/location_provider.dart';
import 'package:delivery/providers/offer_provider.dart';
import 'package:delivery/providers/order_provider.dart';
import 'package:delivery/registration/rider_application.dart';
import 'package:delivery/safety/emergency_sheet.dart';
import 'package:delivery/screens/auth/login_screen.dart';
import 'package:delivery/screens/auth/pending_approval_screen.dart';
import 'package:delivery/screens/auth/rider_registration_screen.dart';
import 'package:delivery/screens/home/active_work_states.dart';
import 'package:delivery/screens/home/dashboard_screen.dart';
import 'package:delivery/screens/inbox/inbox_screen.dart';
import 'package:delivery/screens/money/statement_screen.dart';
import 'package:delivery/screens/offers/incoming_offer_screen.dart';
import 'package:delivery/screens/orders/active_order_screen.dart';
import 'package:delivery/screens/orders/delivery_problem_panel.dart';
import 'package:delivery/screens/profile/rider_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TourAuth implements RiderAuthGateway {
  _TourAuth();
  final String uid = 'r-tour';

  @override
  Stream<String?> get uidChanges => Stream.value(uid);
  @override
  String? get currentUid => uid;
  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<void> refreshClaims() async {}
  @override
  Future<void> sendPasswordReset(String email) async {}
}

class _TourStore implements RiderAccountStore {
  _TourStore({this.status = 'approved', this.reason});
  final String status;
  final String? reason;

  Map<String, dynamic> get _partnerDoc => {
    'name': 'Ravi Kumar',
    'email': 'ravi.rider@agrimore.in',
    'phone': '9876543210',
    'altPhone': '9123456789',
    'address': '12, Koodal Nagar Main Road',
    'city': 'Madurai',
    'pincode': '625018',
    'vehicleType': 'motorcycle',
    'vehicleNumber': 'TN58AB1234',
    'licenseNumber': 'TN5820200001234',
    'aadhaarNumber': '234567890123',
    'status': status,
    'isApproved': status == 'approved',
    'isActive': status == 'approved',
    'isOnline': true,
    'rating': 4.8,
    'totalDeliveries': 148,
    'totalEarnings': 14250.0,
    if (reason != null) 'rejectionReason': reason,
    'kycDocuments': {
      'aadhaarFront': 'kyc/aadhaar_front.jpg',
      'aadhaarBack': 'kyc/aadhaar_back.jpg',
      'selfie': 'kyc/selfie.jpg',
      'license': 'kyc/license.jpg',
    },
    'bankDetails': {
      'payoutMethod': 'upi',
      'upiId': 'ravi@okaxis',
      'accountHolderName': 'Ravi Kumar',
      'bankName': 'State Bank of India',
      'accountNumber': '123456784821',
      'ifsc': 'SBIN0001234',
    },
  };

  @override
  Future<ProfileRead> user(String uid) async => const ProfileRead(
    exists: true,
    fromCache: false,
    data: {'role': 'delivery_partner', 'name': 'Ravi Kumar'},
  );

  @override
  Future<ProfileRead> partner(String uid) async => ProfileRead(
    exists: true,
    fromCache: false,
    data: _partnerDoc,
  );

  @override
  Stream<ProfileRead> watchPartner(String uid) => Stream.value(
    ProfileRead(exists: true, fromCache: false, data: _partnerDoc),
  );

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
      body: '₹2,480.00 credited to UPI ravi@okaxis for week 2026-W38.',
      unread: true,
      createdAt: DateTime(2026, 9, 24, 9, 15),
    ),
    RiderNotice(
      id: 'n2',
      type: 'cod_settled',
      title: 'COD cash settlement verified',
      body: '₹920.00 cash deposit confirmed by Madurai hub.',
      unread: false,
      createdAt: DateTime(2026, 9, 23, 18, 40),
    ),
    RiderNotice(
      id: 'n3',
      type: 'payout_change_approved',
      title: 'Payout details updated',
      body: 'Your UPI ID ravi@okaxis is active for upcoming weekly settlements.',
      unread: false,
      createdAt: DateTime(2026, 9, 22, 11, 0),
    ),
  ];

  @override
  Stream<List<RiderNotice>> latest(String riderId) => Stream.value(items);
  @override
  Stream<int> unreadCount(String riderId) => Stream.value(1);
  @override
  Future<void> markRead(String riderId, Iterable<String> ids) async {}
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

OrderModel _sampleOrder({String status = 'arrived_at_store'}) =>
    OrderModel.fromMap({
      'orderNumber': 'AGM-1042',
      'userId': 'cust-1',
      'userName': 'Meenakshi Sundaram',
      'userPhone': '+91 98421 55120',
      'sellerId': 'sel-1',
      'deliveryPartnerId': 'r-tour',
      'orderStatus': status,
      'status': 'processing',
      'paymentMethod': 'cod',
      'paymentStatus': 'pending',
      'subtotal': 420.0,
      'deliveryFee': 48.0,
      'total': 468.0,
      'deliveryEarning': 54.0,
      // DLV-Q1 fix: OrderModel.fromMap only reads 'deliveryAddress' (matching
      // createOrder.ts) and AddressModel.fromMap only reads 'addressLine1'
      // (not 'street') — the previous 'shippingAddress'/'street' keys here
      // silently produced an empty AddressModel, so this fixture's Customer
      // card and Delivery address section screenshotted misleadingly blank
      // ("Delivery address: India" — the model's country-only default).
      'deliveryAddress': {
        'name': 'Meenakshi Sundaram',
        'phone': '+91 98421 55120',
        'addressLine1': '44, West Masi Street, Near Temple Tower',
        'city': 'Madurai',
        'state': 'Tamil Nadu',
        'pincode': '625001',
      },
      'items': [
        {
          'productId': 'p1',
          'productName': 'Organic Madurai Malli & Country Tomatoes',
          'price': 210.0,
          'quantity': 2,
          'unit': 'kg',
        },
      ],
    }, 'ord-1042');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  var converted = false;

  Future<void> shot(
    WidgetTester tester,
    String name,
    Widget screen, {
    Brightness brightness = Brightness.light,
    double scale = 1.0,
    String partnerStatus = 'approved',
    String? rejectionReason,
    Future<void> Function(WidgetTester tester)? before,
  }) async {
    final auth = DeliveryAuthProvider(
      gateway: _TourAuth(),
      store: _TourStore(status: partnerStatus, reason: rejectionReason),
      pushTokens: _NoPush(),
    );
    final offer = DeliveryOffer(
      orderId: 'o1',
      orderNumber: 'AGM-1042',
      expiresAt: DateTime.now().add(const Duration(seconds: 26)),
      pickupDistanceKm: 1.4,
      pickupArea: 'Mattuthavani Hub · 625007',
      dropPincode: '625001',
      dropDistanceKm: 3.8,
      itemCount: 3,
      codAmount: 468,
      estimatedPay: 54,
    );
    final offerProvider = _FakeOfferProvider([offer]);
    final appearance = DeliveryAppearanceController();

    await tester.pumpWidget(
      DeliveryAppearanceScope(
        controller: appearance,
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<DeliveryAuthProvider>.value(value: auth),
            ChangeNotifierProvider<OfferProvider>.value(value: offerProvider),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: DeliveryTheme.of(brightness),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, home) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: home!,
            ),
            home: screen,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    if (!converted) {
      await binding.convertFlutterSurfaceToImage();
      converted = true;
    }
    if (before != null) {
      await before(tester);
    }
    await tester.pump(const Duration(milliseconds: 200));
    await binding.takeScreenshot(name);
  }

  testWidgets('AgriMore Delivery Partner complete visual QA tour', (tester) async {
    // 0. DashboardScreen itself -- never screenshotted before (shot 13's
    // "active work and route" scaffold hand-assembles the same widgets in a
    // bespoke Scaffold, not the real production screen). Deliberately FIRST,
    // before any shot that opens a modal bottom sheet: a leftover open sheet
    // from an earlier shot was observed bleeding through pumpWidget's tree
    // replacement into this one when placed later in the sequence -- a
    // test-harness ordering issue, not a DashboardScreen defect (confirmed by
    // moving it here). bind() with injectable fakes so no real Firestore call
    // is needed for the order provider; DashboardScreen's own hardcoded
    // FirestoreRiderInbox for the inbox badge is now also injectable
    // (DLV-S1) so this touches no Firebase at all.
    DeliveryOrderProvider fakeOrders() => DeliveryOrderProvider(
          activeSource: (_) => Stream.value((docs: <OrderDoc>[], fromCache: false)),
          deliveredCount: (_, __) async => 8,
          historyFetch: (_, __, ___, ____) async =>
              (items: const <OrderModel>[], cursor: null, hasMore: false),
        )..bind('r-tour');

    // LocationProvider's constructor reads FirebaseFirestore.instance eagerly
    // (a real Firebase app is always live by then in production, via
    // main.dart's init order) -- it must be lazy (create:, not .value) here
    // so it is never actually constructed unless DashboardScreen reads it,
    // which only happens from interaction handlers, not initial build.
    Widget dashboardFixture() => MultiProvider(
          providers: [
            ChangeNotifierProvider<DeliveryOrderProvider>.value(value: fakeOrders()),
            ChangeNotifierProvider<LocationProvider>(create: (_) => LocationProvider()),
          ],
          child: DashboardScreen(
            inboxSource: _FakeInbox(),
            earningsSource: (_) => Stream.value(const <RiderEarning>[]),
            accountSource: (_) => Stream.value(
              RiderAccount.fromMap(const {'cashHeld': 0}),
            ),
          ),
        );

    await shot(tester, '00_dashboard_waiting_light', dashboardFixture());
    await shot(
      tester,
      '00b_dashboard_waiting_dark',
      dashboardFixture(),
      brightness: Brightness.dark,
    );

    // 1. Login Light, Dark & 200% Text Scale
    await shot(tester, '01_login_light', const LoginScreen());
    await shot(
      tester,
      '02_login_dark',
      const LoginScreen(),
      brightness: Brightness.dark,
    );
    await shot(
      tester,
      '03_login_text200',
      const LoginScreen(),
      scale: 2.0,
    );

    // 2. Rider Registration Wizard (Light & Dark)
    await shot(
      tester,
      '04_registration_step1_light',
      RiderRegistrationScreen(service: RegistrationService(_FakeReg())),
    );
    await shot(
      tester,
      '05_registration_step1_dark',
      RiderRegistrationScreen(service: RegistrationService(_FakeReg())),
      brightness: Brightness.dark,
    );

    // 3. Pending Approval & Rejected Status Screens
    await shot(
      tester,
      '06_pending_approval_light',
      DeliveryPendingApprovalScreen(backend: _FakeAccountBackend()),
      partnerStatus: 'pending',
    );
    await shot(
      tester,
      '07_pending_approval_rejected_dark',
      DeliveryPendingApprovalScreen(backend: _FakeAccountBackend()),
      brightness: Brightness.dark,
      partnerStatus: 'rejected',
      rejectionReason:
          'Driving licence photo was blurry — please re-upload a clear front & back photo.',
    );

    // 4. Incoming Offer Screen (Light, Dark & 200% Text Scale)
    await shot(
      tester,
      '08_incoming_offer_light',
      const IncomingOfferScreen(orderId: 'o1'),
    );
    await shot(
      tester,
      '09_incoming_offer_dark',
      const IncomingOfferScreen(orderId: 'o1'),
      brightness: Brightness.dark,
    );
    await shot(
      tester,
      '10_incoming_offer_text200',
      const IncomingOfferScreen(orderId: 'o1'),
      scale: 2.0,
    );

    // 5. Active Order Workspace — Pickup Leg (Light) & Dropoff Leg (Dark)
    await shot(
      tester,
      '11_active_order_pickup_light',
      ActiveOrderScreen(order: _sampleOrder(status: 'arrived_at_store')),
    );
    await shot(
      tester,
      '12_active_order_dropoff_dark',
      ActiveOrderScreen(order: _sampleOrder(status: 'out_for_delivery')),
      brightness: Brightness.dark,
    );

    // 5b. Delivery-code verification sheet — DLV-Q1: proves the 6-digit
    // fix (DeliveryOtpField previously defaulted to 4 while the server
    // issues 6-digit codes; the field could never be completed enough to
    // submit). Reached by tapping the real "Complete delivery" button
    // exposed at the out_for_delivery step — no network call is made
    // before the sheet opens.
    Future<void> openVerifySheet(WidgetTester t) async {
      await t.ensureVisible(find.text('Complete delivery'));
      await t.pumpAndSettle();
      await t.tap(find.text('Complete delivery'), warnIfMissed: false);
      await t.pumpAndSettle();
    }

    // Best-effort: these two shots exist to visually prove the DLV-Q1
    // 6-digit fix. A hiccup opening the sheet must never abort the rest of
    // this tour (shots 13-23 below), so failures are logged, not thrown.
    await shot(
      tester,
      '24_verify_code_sheet_empty_light',
      ActiveOrderScreen(order: _sampleOrder(status: 'out_for_delivery')),
      before: (t) async {
        try {
          await openVerifySheet(t);
        } catch (e) {
          debugPrint('24_verify_code_sheet_empty_light: sheet not opened: $e');
        }
      },
    );
    await shot(
      tester,
      '25_verify_code_sheet_filled_dark',
      ActiveOrderScreen(order: _sampleOrder(status: 'out_for_delivery')),
      brightness: Brightness.dark,
      before: (t) async {
        try {
          await openVerifySheet(t);
          await t.enterText(find.byType(TextField), '482910');
          await t.pump();
        } catch (e) {
          debugPrint('25_verify_code_sheet_filled_dark: sheet not opened: $e');
        }
      },
    );

    // 5c. DLV-R1: the active-delivery Help sheet (phase 20 image 07,
    // "support-access") -- the Help icon lives in the AppBar, always
    // tappable regardless of scroll position, so this is not best-effort.
    await shot(
      tester,
      '26_help_sheet_light',
      ActiveOrderScreen(order: _sampleOrder(status: 'out_for_delivery')),
      before: (t) async {
        await t.tap(find.byTooltip('Help'));
        await t.pumpAndSettle();
      },
    );

    // 6. Active Work States, Route Header & Multiple Orders Showcase
    await shot(
      tester,
      '13_active_work_and_route_light',
      Scaffold(
        appBar: const DeliveryAppBar(
          title: Text('Active Route & Work States'),
          subtitle: 'Madurai Hub • Live GPS',
        ),
        body: ListView(
          padding: const EdgeInsets.all(DeliverySpace.page),
          children: [
            const DeliveryMapHeader(
              pickupLabel: 'Kaveri Fresh Produce Hub, Mattuthavani',
              dropLabel: 'Meenakshi Sundaram • 625001',
              distanceLabel: '9 min • 2.6 km',
            ),
            const SizedBox(height: DeliverySpace.lg),
            MultipleActiveOrders(
              orders: [
                _sampleOrder(status: 'picked_up'),
                _sampleOrder(status: 'delivery_accepted'),
              ],
              onOpen: (_) {},
            ),
            const SizedBox(height: DeliverySpace.lg),
            ActiveWorkError(
              error: RiderDataError.offline,
              onRetry: () {},
            ),
          ],
        ),
      ),
    );

    // 7. Delivery Problem Report Sheet & Emergency SOS Sheet
    await shot(
      tester,
      '14_problem_panel_light',
      Scaffold(
        appBar: const DeliveryAppBar(
          title: Text('Delivery Problem Resolution'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(DeliverySpace.page),
          child: ProblemReportSheet(
            orderId: 'ord-1042',
            backend: _FakeProblemBackend(),
            fix: () async => {'lat': 9.9252, 'lng': 78.1198},
          ),
        ),
      ),
    );
    await shot(
      tester,
      '15_emergency_sheet_dark',
      Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(DeliverySpace.page),
            child: EmergencySheet(
              supportPhone: '+91 98765 43210',
              launcher: (_) async => true,
              reporter: (_) async => 'inc-101',
              fix: () async => {'lat': 9.9252, 'lng': 78.1198},
            ),
          ),
        ),
      ),
      brightness: Brightness.dark,
    );

    // 8. Weekly Statement & Payout Ledger (Light, Dark & 200% Text Scale)
    final samplePayout = RiderPayout.fromMap('p1', {
      'weekKey': '2026-W38',
      'orderCount': 42,
      'earnedPaise': 267000,
      'nettedPaise': 19000,
      'amountPaise': 248000,
      'cashHeldAfterPaise': 0,
      'status': 'paid',
      'paymentReference': 'AXISCN094827164',
      'paidTo': {'method': 'upi', 'upiId': 'ravi@okaxis'},
    });
    final sampleEntries = [
      RiderEarning(
        orderId: 'o1',
        orderNumber: 'AGM-1042',
        total: 60.0,
        basePay: 48.0,
        createdAt: DateTime(2026, 9, 21, 14, 30),
      ),
      RiderEarning(
        orderId: 'o2',
        orderNumber: 'AGM-1039',
        total: 55.0,
        basePay: 45.0,
        createdAt: DateTime(2026, 9, 20, 19, 10),
      ),
      RiderEarning(
        orderId: 'o3',
        orderNumber: 'AGM-1034',
        total: 68.0,
        basePay: 50.0,
        createdAt: DateTime(2026, 9, 19, 11, 45),
      ),
    ];
    await shot(
      tester,
      '16_statement_light',
      StatementScreen(
        payout: samplePayout,
        load: (_) async => StatementPage(sampleEntries, null, false),
      ),
    );
    await shot(
      tester,
      '17_statement_dark',
      StatementScreen(
        payout: samplePayout,
        load: (_) async => StatementPage(sampleEntries, null, false),
      ),
      brightness: Brightness.dark,
    );
    await shot(
      tester,
      '18_statement_text200',
      StatementScreen(
        payout: samplePayout,
        load: (_) async => StatementPage(sampleEntries, null, false),
      ),
      scale: 2.0,
    );

    // 9. Rider Inbox & Notifications (Light & Dark)
    await shot(
      tester,
      '19_inbox_light',
      InboxScreen(riderId: 'r-tour', source: _FakeInbox()),
    );
    await shot(
      tester,
      '20_inbox_dark',
      InboxScreen(riderId: 'r-tour', source: _FakeInbox()),
      brightness: Brightness.dark,
    );

    // 10. Rider Profile, Appearance Switcher, Vehicle & Support (Light & Dark)
    await shot(
      tester,
      '21_profile_light',
      RiderProfileScreen(
        backend: _FakeAccountBackend(),
        partnerData: _TourStore()._partnerDoc,
      ),
    );
    await shot(
      tester,
      '22_profile_dark',
      RiderProfileScreen(
        backend: _FakeAccountBackend(),
        partnerData: _TourStore()._partnerDoc,
      ),
      brightness: Brightness.dark,
    );

    // 11. Contact Edit Sheet (Light)
    await shot(
      tester,
      '23_contact_edit_light',
      Scaffold(
        appBar: const DeliveryAppBar(title: Text('Edit Rider Contact')),
        body: SingleChildScrollView(
          child: ContactEditSheet(
            initial: const {
              'altPhone': '9123456789',
              'address': '12, Koodal Nagar Main Road',
              'city': 'Madurai',
              'pincode': '625018',
            },
            backend: _FakeAccountBackend(),
          ),
        ),
      ),
    );

  });
}
