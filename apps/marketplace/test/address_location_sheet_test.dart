import 'dart:async';
import 'package:agrimore_marketplace/providers/address_provider.dart';
import 'package:agrimore_marketplace/providers/auth_provider.dart';
import 'package:agrimore_marketplace/providers/theme_provider.dart';
import 'package:agrimore_marketplace/screens/user/home/widgets/address_bottom_sheet.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart'
    hide AuthProvider;
// ignore: depend_on_referenced_packages
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:geocoding_platform_interface/geocoding_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'foundation_edit_profile_form_test.dart' show FormAuth, FormTheme;

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

class Geo extends GeolocatorPlatform {
  final position = Completer<Position?>();
  int checks = 0;
  @override
  Future<bool> isLocationServiceEnabled() async {
    checks++;
    return true;
  }

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) =>
      position.future;
}

class Places extends GeocodingPlatform {
  @override
  Future<List<Placemark>> placemarkFromCoordinates(
          double latitude, double longitude) async =>
      [
        const Placemark(
            street: 'Fixture street',
            locality: 'Fixture city',
            administrativeArea: 'Fixture state',
            postalCode: '600001',
            subLocality: 'Fixture area')
      ];
}

class Addresses extends ChangeNotifier implements AddressProvider {
  Addresses({bool nearby = false})
      : rows = nearby
            ? [
                AddressModel(
                    id: 'near',
                    userId: 'owner_a',
                    name: 'Fixture',
                    phone: '9000000000',
                    addressLine1: 'Fixture',
                    addressLine2: 'Fixture area',
                    city: 'Fixture city',
                    state: 'Fixture state',
                    zipcode: '600001',
                    latitude: 10,
                    longitude: 20)
              ]
            : [];
  final List<AddressModel> rows;
  final added = Completer<String?>(), primary = Completer<bool>();
  int adds = 0, defaults = 0;
  @override
  List<AddressModel> get addresses => rows;
  @override
  void loadAddresses() {}
  @override
  Future<String?> addAddress(AddressModel row) {
    adds++;
    return added.future;
  }

  @override
  Future<bool> setDefaultAddress(String id) {
    defaults++;
    return primary.future;
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
  Position position() => Position(
      longitude: 20,
      latitude: 10,
      timestamp: DateTime.utc(2026),
      accuracy: 1,
      altitude: 0,
      altitudeAccuracy: 1,
      heading: 0,
      headingAccuracy: 1,
      speed: 0,
      speedAccuracy: 1);
  Future<void> mount(
      WidgetTester tester, FormAuth auth, Addresses addresses, Geo geo) async {
    sdk.form = auth;
    GeolocatorPlatform.instance = geo;
    GeocodingPlatform.instance = Places();
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
          ChangeNotifierProvider<ThemeProvider>.value(value: FormTheme(false)),
          ChangeNotifierProvider<AddressProvider>.value(value: addresses)
        ],
        child: MaterialApp(
            navigatorKey: nav,
            home: const Scaffold(body: Text('Base fixture')))));
    nav.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: AddressBottomSheet())));
    await tester.pumpAndSettle();
  }

  Future<void> start(WidgetTester tester) async {
    await tester.tap(find.text('Use current location'));
    await tester.pump();
  }

  for (final nearby in [false, true]) {
    testWidgets('refused GPS save nearby=$nearby keeps sheet open',
        (tester) async {
      final auth = FormAuth(), a = Addresses(nearby: nearby), geo = Geo();
      await mount(tester, auth, a, geo);
      await start(tester);
      geo.position.complete(position());
      await tester.pump();
      await tester.pump();
      if (nearby) {
        a.primary.complete(false);
      } else {
        a.added.complete(null);
      }
      await tester.pumpAndSettle();
      expect(nearby ? a.defaults : a.adds, 1);
      expect(find.byType(AddressBottomSheet), findsOneWidget);
      expect(find.textContaining('Could not save'), findsOneWidget);
    });
    testWidgets('confirmed GPS save nearby=$nearby closes sheet',
        (tester) async {
      final auth = FormAuth(), a = Addresses(nearby: nearby), geo = Geo();
      await mount(tester, auth, a, geo);
      await start(tester);
      geo.position.complete(position());
      await tester.pump();
      await tester.pump();
      if (nearby) {
        a.primary.complete(true);
      } else {
        a.added.complete('created');
      }
      await tester.pumpAndSettle();
      expect(nearby ? a.defaults : a.adds, 1);
      expect(find.text('Base fixture'), findsOneWidget);
    });
  }
  for (final uid in <String?>['owner_b', null, 'owner_a']) {
    testWidgets('changed session $uid during location lookup never saves',
        (tester) async {
      final auth = FormAuth(), a = Addresses(), geo = Geo();
      await mount(tester, auth, a, geo);
      await start(tester);
      auth.change(uid);
      geo.position.complete(position());
      await tester.pumpAndSettle();
      expect(a.adds, 0);
      expect(a.defaults, 0);
      expect(find.byType(AddressBottomSheet), findsOneWidget);
    });
  }
  testWidgets('changed session during GPS save cannot close next session',
      (tester) async {
    final auth = FormAuth(), a = Addresses(), geo = Geo();
    await mount(tester, auth, a, geo);
    await start(tester);
    geo.position.complete(position());
    await tester.pump();
    await tester.pump();
    expect(a.adds, 1);
    auth.change('owner_b');
    a.added.complete('old');
    await tester.pumpAndSettle();
    expect(find.byType(AddressBottomSheet), findsOneWidget);
  });
  testWidgets('duplicate GPS action dispatches only one lookup',
      (tester) async {
    final auth = FormAuth(), a = Addresses(), geo = Geo();
    await mount(tester, auth, a, geo);
    await start(tester);
    await start(tester);
    expect(geo.checks, 1);
    geo.position.complete(position());
    await tester.pump();
    await tester.pump();
    a.added.complete('created');
    await tester.pumpAndSettle();
    expect(a.adds, 1);
  });
  testWidgets('refused saved-address selection remains open', (tester) async {
    final auth = FormAuth(), a = Addresses(nearby: true), geo = Geo();
    await mount(tester, auth, a, geo);
    await tester.tap(find.textContaining('Fixture, Fixture city'));
    await tester.pump();
    expect(a.defaults, 1);
    a.primary.complete(false);
    await tester.pumpAndSettle();
    expect(find.byType(AddressBottomSheet), findsOneWidget);
  });
  testWidgets('confirmed saved-address selection closes sheet', (tester) async {
    final auth = FormAuth(), a = Addresses(nearby: true), geo = Geo();
    await mount(tester, auth, a, geo);
    await tester.tap(find.textContaining('Fixture, Fixture city'));
    await tester.pump();
    a.primary.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Base fixture'), findsOneWidget);
  });
}
