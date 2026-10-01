@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_marketplace/services/checkout_recovery_service.dart';
import 'package:agrimore_marketplace/services/payment_checkout_order.dart';
import 'package:agrimore_marketplace/screens/user/checkout/widgets/saved_checkout_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
// Official cached platform interfaces are used only by isolated test fixtures.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:agrimore_marketplace/providers/cart_provider.dart';
import 'package:agrimore_marketplace/providers/coupon_provider.dart';
import 'package:agrimore_marketplace/providers/theme_provider.dart';
import 'package:agrimore_marketplace/providers/market_mode_provider.dart';
import 'package:agrimore_marketplace/providers/address_provider.dart';
import 'package:agrimore_marketplace/providers/product_provider.dart';
import 'package:agrimore_marketplace/screens/user/cart/mobile_cart_screen.dart';
import 'package:agrimore_marketplace/screens/user/checkout/payment_method_screen.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'foundation_mobile_checkout_confirmation_test.dart' show MemoryStore;

class _Auth extends FirebaseAuthPlatform {
  late final UserPlatform fixture = _User(this);
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) {
    return this;
  }

  @override
  FirebaseAuthPlatform setInitialValues(
          {PigeonUserDetails? currentUser, String? languageCode}) =>
      this;
  @override
  UserPlatform? get currentUser => fixture;
}

class _Factor extends MultiFactorPlatform {
  _Factor(super.auth);
}

class _User extends UserPlatform {
  _User(FirebaseAuthPlatform auth)
      : super(
            auth,
            _Factor(auth),
            PigeonUserDetails(
                userInfo: PigeonUserInfo(
                    uid: 'fixture_owner',
                    isAnonymous: false,
                    isEmailVerified: true,
                    email: 'fixture@example.invalid'),
                providerData: []));
}

class _EmptyCart extends CartProvider {
  @override
  void loadCart() {}
}

class _Addresses extends AddressProvider {
  @override
  void loadAddresses() {}
}

class _Products extends ProductProvider {
  @override
  Future<void> loadProducts(
      {String? categoryId,
      bool forceRefresh = false,
      String? location,
      int? limit}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  setUpAll(() async {
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _Auth();
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesService.init();
    for (final family in ['Roboto', 'NotoSans']) {
      await (FontLoader(family)
            ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf')))
          .load();
    }
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'razorpay_flutter',
      'com.llfbandit.record/messages',
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events'
    ]) {
      messenger.setMockMethodCallHandler(
          MethodChannel(name), (_) async => null);
    }
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers'), (call) async {
      final args = call.arguments;
      if (call.method == 'create' && args is Map) {
        messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/${args['playerId']}'),
            (_) async => null);
      }
      return null;
    });
  });
  for (final dark in [false, true]) {
    for (final stage in ['draft', 'awaiting_payment', 'ready', 'completed']) {
      testWidgets(
          '$stage recovery card ${dark ? 'dark' : 'light'} at phone width',
          (tester) async {
        tester.view.physicalSize = const Size(360, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = MemoryStore();
        final journal = CheckoutRecoveryService(
            store: store, currentUserId: () => 'fixture_owner');
        var request = await journal.prepare({
          'items': [
            {'productId': 'fixture_product', 'quantity': 1}
          ],
          'paymentMethod': 'razorpay',
          'orderMode': 'B2C',
          'deliveryAddress': {'name': 'Fixture'}
        });
        if (stage != 'draft') {
          request = await journal.attachGateway(
              request.ownerId,
              request.requestId,
              PaymentCheckoutOrder.fromResponse({
                'success': true,
                'orderId': 'order_fixture',
                'keyId': 'rzp_test_fixture_key',
                'amount': 1000,
                'currency': 'INR'
              }));
        }
        if (stage == 'ready' || stage == 'completed') {
          request = await journal.recordPayment(
              request.ownerId, request.requestId,
              paymentId: 'pay_fixture',
              orderId: 'order_fixture',
              signature: 'fixture_signature');
        }
        if (stage == 'completed') {
          store.value = jsonEncode({
            ...request.toMap(),
            'stage': 'completed',
            'orders': [
              {
                'orderId': 'fixture_order',
                'orderNumber': 'ORD-FIXTURE',
                'sellerId': 'fixture_seller',
                'total': 10.0
              }
            ]
          });
          request = (await journal.pending())!;
        }
        final key = GlobalKey();
        var taps = 0;
        await tester.pumpWidget(MaterialApp(
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            home: RepaintBoundary(
                key: key,
                child: Scaffold(
                    body: Column(children: [
                  SavedCheckoutCard(
                      request: request,
                      isBusy: false,
                      onContinue: () {
                        taps++;
                      }),
                ])))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Saved checkout'), findsOneWidget);
        expect(find.textContaining('Payment successful'), findsNothing);
        final text = stage == 'draft' ? 'Review cart' : 'Continue checkout';
        await tester.tap(find.text(text));
        expect(taps, 1);
        await tester.pumpAndSettle();
        final output = Platform.environment['AGRIMORE_UI_CAPTURE'];
        if (output != null) {
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject() as RenderRepaintBoundary;
            final capture = await boundary.toImage(pixelRatio: 1);
            final bytes =
                (await capture.toByteData(format: ui.ImageByteFormat.png))!;
            await Directory(output).create(recursive: true);
            await File(
                    '$output/saved-checkout-$stage-${dark ? 'dark' : 'light'}.png')
                .writeAsBytes(bytes.buffer.asUint8List());
            capture.dispose();
          });
        }
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: SavedCheckoutCard(
                    request: request,
                    isBusy: true,
                    onContinue: () {
                      taps++;
                    }))));
        expect(
            tester
                .widget<ElevatedButton>(find.byType(ElevatedButton))
                .onPressed,
            isNull);
      });
    }
  }
  for (final cartScreen in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets(
          'actual ${cartScreen ? 'empty cart' : 'payment'} screen restores saved checkout ${dark ? 'dark' : 'light'}',
          (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = MemoryStore();
        final journal = CheckoutRecoveryService(
            store: store, currentUserId: () => 'fixture_owner');
        final draft = await journal.prepare({
          'items': [
            {'productId': 'fixture_product', 'quantity': 1}
          ],
          'paymentMethod': 'razorpay',
          'orderMode': 'B2C',
          'deliveryAddress': {'name': 'Fixture', 'phone': ''}
        });
        await journal.attachGateway(
            draft.ownerId,
            draft.requestId,
            PaymentCheckoutOrder.fromResponse({
              'success': true,
              'orderId': 'order_fixture',
              'keyId': 'rzp_test_fixture',
              'amount': 1000,
              'currency': 'INR'
            }));
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final calls = <String>[];
        const functions = BasicMessageChannel<Object?>(
            'dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call',
            StandardMessageCodec());
        messenger.setMockDecodedMessageHandler<Object?>(functions,
            (message) async {
          calls
              .add(((message as List).single as Map)['functionName'] as String);
          return ['unavailable', 'fixture', null];
        });
        final theme = ThemeProvider();
        await theme.setThemeMode(dark);
        final key = GlobalKey();
        final address = AddressModel(
            id: 'fixture_address',
            userId: 'fixture_owner',
            name: 'Fixture',
            phone: '',
            addressLine1: 'Fixture street',
            addressLine2: '',
            city: 'Fixture city',
            state: 'Fixture state',
            zipcode: '000000');
        await tester.pumpWidget(MultiProvider(
            providers: [
              ChangeNotifierProvider<CartProvider>(create: (_) => _EmptyCart()),
              ChangeNotifierProvider<CouponProvider>(
                  create: (_) => CouponProvider()),
              ChangeNotifierProvider<ThemeProvider>.value(value: theme),
              ChangeNotifierProvider<MarketModeProvider>(
                  create: (_) => MarketModeProvider()),
              ChangeNotifierProvider<AddressProvider>(
                  create: (_) => _Addresses()),
              ChangeNotifierProvider<ProductProvider>(
                  create: (_) => _Products()),
            ],
            child: MaterialApp(
                theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
                home: RepaintBoundary(
                    key: key,
                    child: cartScreen
                        ? MobileCartScreen(checkoutRecovery: journal)
                        : PaymentMethodScreen(
                            selectedAddress: address,
                            total: 10,
                            checkoutRecovery: journal)))));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        expect(find.text('Saved checkout'), findsOneWidget);
        final output = Platform.environment['AGRIMORE_UI_CAPTURE'];
        if (output != null) {
          await tester.runAsync(() async {
            final capture = await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
            final bytes =
                (await capture.toByteData(format: ui.ImageByteFormat.png))!;
            await File(
                    '$output/actual-${cartScreen ? 'empty-cart' : 'payment'}-${dark ? 'dark' : 'light'}.png')
                .writeAsBytes(bytes.buffer.asUint8List());
            capture.dispose();
          });
        }
        await tester.tap(find.text('Continue checkout'));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
        expect(calls, ['recoverCheckoutPayment']);
        expect(find.text('Saved checkout'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        theme.dispose();
      });
    }
  }
}
