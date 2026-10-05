import 'dart:async';
import 'package:agrimore_marketplace/providers/address_provider.dart';
import 'package:agrimore_marketplace/providers/auth_provider.dart';
import 'package:agrimore_marketplace/screens/auth/onboarding_address_screen.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart'
    hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'foundation_edit_profile_form_test.dart' show FormAuth;

class _SdkAuth extends FirebaseAuthPlatform {
  _SdkAuth(this.form);
  FormAuth form;
  String? get uid => form.owner;
  int cancelled = 0;
  late StreamController<UserPlatform?> changes;
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) {
    return this;
  }

  @override
  FirebaseAuthPlatform setInitialValues(
          {PigeonUserDetails? currentUser, String? languageCode}) =>
      this;
  @override
  Stream<UserPlatform?> authStateChanges() => changes.stream;
  void switchTo(String? owner) {
    form.change(owner);
    changes.add(currentUser);
  }

  @override
  UserPlatform? get currentUser => uid == null ? null : _User(this, uid!);
}

class _Factor extends MultiFactorPlatform {
  _Factor(super.auth);
}

class _User extends UserPlatform {
  _User(FirebaseAuthPlatform auth, String uid)
      : super(
            auth,
            _Factor(auth),
            PigeonUserDetails(
                userInfo: PigeonUserInfo(
                    uid: uid,
                    isAnonymous: false,
                    isEmailVerified: true,
                    email: 'fixture@example.invalid'),
                providerData: []));
}

class Addresses extends ChangeNotifier implements AddressProvider {
  final reply = Completer<bool>();
  final created = Completer<String?>();
  int updates = 0, adds = 0;
  @override
  List<AddressModel> get addresses => [];
  @override
  Future<bool> updateAddress(String id, Map<String, dynamic> value) {
    updates++;
    return reply.future;
  }

  @override
  Future<String?> addAddress(AddressModel value) {
    adds++;
    return created.future;
  }

  @override
  String? get error => 'PRIVATE_PROVIDER_DETAIL';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  late _SdkAuth sdk;
  setUpAll(() async {
    await Firebase.initializeApp();
    sdk = _SdkAuth(FormAuth());
    FirebaseAuthPlatform.instance = sdk;
  });
  AddressModel row() => AddressModel(
      id: 'existing',
      userId: 'owner_a',
      name: 'Fixture',
      phone: '+919000000000',
      addressLine1: 'Fixture',
      addressLine2: 'Fixture Area',
      city: 'Chennai',
      state: 'Tamil Nadu',
      zipcode: '600001');
  Future<void> mount(WidgetTester tester, FormAuth auth, Addresses addresses,
      {bool create = false, bool onboarding = false}) async {
    sdk.form = auth;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<AddressProvider>.value(value: addresses)
        ],
        child: MaterialApp(
            navigatorKey: nav,
            home: const Scaffold(body: Text('Base fixture')),
            routes: {
              '/main': (_) => const Scaffold(body: Text('Main fixture'))
            })));
    nav.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => OnboardingAddressScreen(
            isOnboarding: onboarding, existingAddress: create ? null : row())));
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester) async {
    final hints = {
      'e.g. Ravi Kumar': 'Fixture',
      '98765 43210': '9000000000',
      'e.g. Door No. 12, Nehru St.': 'Fixture',
      'e.g. Velachery, Anna Nagar': 'Fixture Area',
      'Chennai': 'Chennai',
      '600001': '600001',
      'Tamil Nadu': 'Tamil Nadu'
    };
    for (final item in hints.entries) {
      final finder = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == item.key);
      await tester.enterText(finder, item.value);
    }
  }

  Future<void> submit(WidgetTester tester) async {
    final finder = find.byType(ElevatedButton);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    tester.widget<ElevatedButton>(finder).onPressed!();
    await tester.pump();
    expect(
        find.text('Enter valid 10-digit Indian mobile number'), findsNothing);
  }

  testWidgets('refused edit stays open with generic error', (tester) async {
    final auth = FormAuth(), a = Addresses();
    await mount(tester, auth, a);
    await submit(tester);
    a.reply.complete(false);
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingAddressScreen), findsOneWidget);
    expect(find.textContaining('Could not save'), findsOneWidget);
    expect(find.textContaining('PRIVATE_PROVIDER_DETAIL'), findsNothing);
  });
  testWidgets('refused create never advances onboarding', (tester) async {
    final auth = FormAuth(), a = Addresses();
    await mount(tester, auth, a, create: true, onboarding: true);
    await fill(tester);
    await submit(tester);
    a.created.complete(null);
    await tester.pumpAndSettle();
    expect(a.adds, 1);
    expect(find.text('Main fixture'), findsNothing);
    expect(find.byType(OnboardingAddressScreen), findsOneWidget);
  });
  testWidgets('confirmed edit retains navigation', (tester) async {
    final auth = FormAuth(), a = Addresses();
    await mount(tester, auth, a);
    await submit(tester);
    a.reply.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Base fixture'), findsOneWidget);
  });
  testWidgets('confirmed creation advances onboarding', (tester) async {
    final auth = FormAuth(), a = Addresses();
    await mount(tester, auth, a, create: true, onboarding: true);
    await fill(tester);
    await submit(tester);
    a.created.complete('created');
    await tester.pumpAndSettle();
    expect(find.text('Main fixture'), findsOneWidget);
  });
  for (final uid in <String?>['owner_b', null, 'owner_a']) {
    testWidgets(
        'changed session $uid clears fields and captured save cannot dispatch',
        (tester) async {
      final auth = FormAuth(), a = Addresses();
      await mount(tester, auth, a);
      final callback =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed!;
      final controller =
          tester.widget<TextField>(find.byType(TextField).first).controller!;
      auth.change(uid);
      await tester.pump();
      callback();
      await tester.pump();
      expect(a.updates, 0);
      expect(controller.text, isEmpty);
    });
    testWidgets('changed session $uid suppresses late successful navigation',
        (tester) async {
      final auth = FormAuth(), a = Addresses();
      await mount(tester, auth, a);
      await submit(tester);
      auth.change(uid);
      a.reply.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('Base fixture'), findsNothing);
      expect(find.byType(OnboardingAddressScreen), findsOneWidget);
    });
  }
}
