@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:agrimore_marketplace/providers/wallet_provider.dart';
import 'package:agrimore_marketplace/providers/theme_provider.dart';
import 'package:agrimore_marketplace/screens/user/wallet/add_money_screen.dart';
import 'package:agrimore_marketplace/services/wallet_topup_recovery_service.dart';
import 'package:agrimore_marketplace/services/payment_checkout_order.dart';
import 'package:firebase_core/firebase_core.dart';
// Cached official platform interfaces for local fixtures.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'
    as fs;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'foundation_mobile_checkout_confirmation_test.dart' show MemoryStore;

class _Auth extends FirebaseAuthPlatform {
  String? uid = 'fixture_owner';
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) {
    return this;
  }

  @override
  FirebaseAuthPlatform setInitialValues(
          {PigeonUserDetails? currentUser, String? languageCode}) =>
      this;
  @override
  Stream<UserPlatform?> authStateChanges() => const Stream.empty();

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const functions = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call',
      StandardMessageCodec());
  const documents = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceGet',
      fs.FirebaseFirestoreHostApi.codec);
  const sdk = MethodChannel('razorpay_flutter');
  late _Auth auth;
  late List<Map> calls, opens;
  late List<fs.DocumentReferenceRequest> reads;
  late Map<String, Object?>? walletData;
  late bool readFails;
  late Future<void> Function()? beforeWalletReply;
  final receipt = {
    'success': true,
    'amount': 100.0,
    'alreadyCredited': false,
    'bonusCoins': 5,
    'balanceAfter': 110.0,
    'coinsAfter': 8
  };
  final gateway = {
    'success': true,
    'orderId': 'order_fixture',
    'keyId': 'rzp_test_fixture',
    'amount': 10000,
    'currency': 'INR'
  };
  setUpAll(() async {
    await Firebase.initializeApp();
    auth = _Auth();
    FirebaseAuthPlatform.instance = auth;
    const snapshots = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceSnapshot',
        fs.FirebaseFirestoreHostApi.codec);
    messenger.setMockDecodedMessageHandler<Object?>(
        snapshots, (_) async => ['fixture_wallet_listener']);
    messenger.setMockMethodCallHandler(
        const MethodChannel(
            'plugins.flutter.io/firebase_firestore/document/fixture_wallet_listener'),
        (_) async => null);
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesService.init();
    for (final family in ['Roboto', 'NotoSans']) {
      await (FontLoader(family)
            ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf')))
          .load();
    }
  });
  setUp(() {
    auth.uid = 'fixture_owner';
    calls = [];
    opens = [];
    reads = [];
    readFails = false;
    beforeWalletReply = null;
    walletData = {
      'userId': 'fixture_owner',
      'balance': 110.0,
      'coins': 8,
      'lifetimeEarnings': 100.0
    };
    messenger.setMockDecodedMessageHandler<Object?>(documents, (message) async {
      final request = (message! as List)[1] as fs.DocumentReferenceRequest;
      if (request.path.startsWith('wallets/')) {
        reads.add(request);
        await beforeWalletReply?.call();
        if (readFails) return ['unavailable', 'fixture', null];
        return [
          fs.PigeonDocumentSnapshot(
              path: request.path,
              data: walletData,
              metadata: fs.PigeonSnapshotMetadata(
                  hasPendingWrites: false, isFromCache: false))
        ];
      }
      return [
        fs.PigeonDocumentSnapshot(
            path: request.path,
            data: null,
            metadata: fs.PigeonSnapshotMetadata(
                hasPendingWrites: false, isFromCache: false))
      ];
    });
    messenger.setMockDecodedMessageHandler<Object?>(functions, (message) async {
      final call = (message! as List).single as Map;
      calls.add(call);
      return [
        call['functionName'] == 'createRazorpayOrder'
            ? gateway
            : call['functionName'] == 'recoverWalletTopupPayment'
                ? {
                    'success': true,
                    'verified': true,
                    'outcome': 'captured',
                    'orderId': 'order_fixture',
                    'paymentId': 'pay_fixture',
                    'amountPaise': 10000,
                    'currency': 'INR'
                  }
                : receipt
      ];
    });
    messenger.setMockMethodCallHandler(sdk, (call) async {
      if (call.method == 'resync') return null;
      final options = call.arguments as Map;
      opens.add(options);
      return {
        'type': 0,
        'data': {
          'razorpay_payment_id': 'pay_fixture',
          'razorpay_order_id': options['order_id'],
          'razorpay_signature': 'fixture_signature'
        }
      };
    });
  });
  tearDown(() {
    messenger.setMockDecodedMessageHandler<Object?>(documents, null);
    messenger.setMockDecodedMessageHandler<Object?>(functions, null);
    messenger.setMockMethodCallHandler(sdk, null);
  });
  Future<WalletTopupRecoveryService> prepare(
      MemoryStore store, String stage) async {
    final journal =
        WalletTopupRecoveryService(store: store, currentUserId: () => auth.uid);
    var p = await journal.prepare(100);
    if (stage != 'draft') {
      p = await journal.attachGateway(
          p.ownerId, p.requestId, PaymentCheckoutOrder.fromResponse(gateway));
    }
    if (stage == 'ready' || stage == 'completed') {
      p = await journal.recordPayment(p.ownerId, p.requestId,
          paymentId: 'pay_fixture',
          orderId: 'order_fixture',
          signature: 'fixture_signature');
    }
    if (stage == 'completed') {
      store.value = jsonEncode(
          {...p.toMap(), 'stage': 'completed', 'confirmation': receipt});
    }
    return journal;
  }

  Future<void> drain(WidgetTester tester) async {
    await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> mount(WidgetTester tester, WalletTopupRecoveryService journal,
      {bool dark = false, GlobalKey? key, WalletProvider? provider}) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final theme = ThemeProvider();
    await theme.setThemeMode(dark);
    final wallet = provider ?? WalletProvider();
    addTearDown(theme.dispose);
    addTearDown(wallet.dispose);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<WalletProvider>.value(value: wallet),
          ChangeNotifierProvider<ThemeProvider>.value(value: theme)
        ],
        child: MaterialApp(
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            home: RepaintBoundary(
                key: key, child: AddMoneyScreen(topupRecovery: journal)))));
    await drain(tester);
  }

  for (final dark in [false, true]) {
    for (final stage in ['draft', 'awaiting_payment', 'ready', 'completed']) {
      testWidgets(
          'actual wallet $stage ${dark ? 'dark' : 'light'} restores without fresh charge',
          (tester) async {
        final store = MemoryStore();
        final journal = await prepare(store, stage);
        final key = GlobalKey();
        await mount(tester, journal, dark: dark, key: key);
        expect(find.text('Saved top-up'), findsOneWidget);
        expect(
            find.text(stage == 'draft' ? 'Review amount' : 'Continue top-up'),
            findsOneWidget);
        expect(
            tester
                .widget<ElevatedButton>(
                    find.widgetWithText(ElevatedButton, 'Proceed to Pay'))
                .onPressed,
            isNull);
        expect(calls, isEmpty);
        expect(opens, isEmpty);
        final output = Platform.environment['AGRIMORE_UI_CAPTURE'];
        if (output != null) {
          await tester.runAsync(() async {
            final boundary = key.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes =
                (await image.toByteData(format: ui.ImageByteFormat.png))!;
            await Directory(output).create(recursive: true);
            await File('$output/wallet-$stage-${dark ? 'dark' : 'light'}.png')
                .writeAsBytes(bytes.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }
  testWidgets(
      'completed receipt refreshes server wallet before acknowledgement and stays visible',
      (tester) async {
    final store = MemoryStore();
    final journal = await prepare(store, 'completed');
    final wallet = WalletProvider();
    await mount(tester, journal, provider: wallet);
    await tester.tap(find.text('Continue top-up'));
    await drain(tester);
    expect(reads.single.path, 'wallets/fixture_owner');
    expect(reads.single.source, fs.Source.server);
    expect(calls, isEmpty);
    expect(opens, isEmpty);
    expect(store.value, isNull);
    expect(find.text('Top-up confirmed'), findsOneWidget);
    expect(find.text('₹100.00 added to your wallet'), findsOneWidget);
    expect(find.text('5 bonus coins'), findsOneWidget);
    expect(wallet.balance, 110);
  });
  testWidgets(
      'wallet server failure keeps confirmation and retries refresh without payment RPC',
      (tester) async {
    final store = MemoryStore();
    final journal = await prepare(store, 'completed');
    readFails = true;
    await mount(tester, journal);
    await tester.tap(find.text('Continue top-up'));
    await drain(tester);
    expect((await journal.pending())!.stage, 'completed');
    expect(find.text('Top-up confirmed'), findsNothing);
    expect(find.textContaining('needs attention'), findsWidgets);
    readFails = false;
    await tester.tap(find.text('Continue top-up'));
    await drain(tester);
    expect(store.value, isNull);
    expect(reads.length, 2);
    expect(calls, isEmpty);
    expect(opens, isEmpty);
  });
  testWidgets(
      'attempted top-up recovers captured original payment with empty amount input',
      (tester) async {
    final store = MemoryStore();
    final journal = await prepare(store, 'awaiting_payment');
    await mount(tester, journal);
    await tester.tap(find.text('Continue top-up'));
    await drain(tester);
    expect(find.text('Top-up confirmed'), findsOneWidget);
    expect(calls.last['parameters']['amount'], 100);
    expect(opens, isEmpty);
    expect(calls.any((c) => c['functionName'] == 'createRazorpayOrder'), false);
  });
  testWidgets('explicit draft review removes only unpaid draft',
      (tester) async {
    final store = MemoryStore();
    final journal = await prepare(store, 'draft');
    await mount(tester, journal);
    await tester.tap(find.text('Review amount'));
    await tester.pumpAndSettle();
    expect(store.value, isNotNull);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Review amount').last);
    await drain(tester);
    expect(store.value, isNull);
    expect(calls, isEmpty);
    expect(opens, isEmpty);
  });
  testWidgets(
      'session changes during server wallet reply preserve confirmation without old account UI',
      (tester) async {
    final store = MemoryStore();
    final journal = await prepare(store, 'completed');
    beforeWalletReply = () async {
      auth.uid = 'other_owner';
    };
    await mount(tester, journal);
    await tester.tap(find.text('Continue top-up'));
    await drain(tester);
    expect(store.value, isNotNull);
    expect(find.text('Top-up confirmed'), findsNothing);
    expect(calls, isEmpty);
  });
  testWidgets(
      'closed screen during server wallet reply retains receipt for reopening',
      (tester) async {
    final store = MemoryStore();
    final journal = await prepare(store, 'completed');
    final reply = Completer<void>();
    beforeWalletReply = () => reply.future;
    await mount(tester, journal);
    await tester.tap(find.text('Continue top-up'));
    await drain(tester);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    reply.complete();
    await drain(tester);
    expect(store.value, isNotNull);
    expect(calls, isEmpty);
  });
  test('wallet refresh refuses another owner before any server read', () async {
    final wallet = WalletProvider();
    await expectLater(
        wallet.refreshWalletForOwner('other_owner'), throwsStateError);
    expect(reads, isEmpty);
    expect(wallet.balance, 0);
    await Future<void>.delayed(Duration.zero);
    wallet.dispose();
  });
  test('wallet refresh cannot publish old owner balance after awaited reply',
      () async {
    final wallet = WalletProvider();
    beforeWalletReply = () async {
      auth.uid = 'other_owner';
    };
    await expectLater(
        wallet.refreshWalletForOwner('fixture_owner'), throwsStateError);
    expect(wallet.balance, 0);
    expect(reads.single.source, fs.Source.server);
    await Future<void>.delayed(Duration.zero);
    wallet.dispose();
  });
  for (final bad in [
    null,
    {'userId': 'other_owner', 'balance': 110.0},
    {'userId': 'fixture_owner', 'balance': double.nan}
  ]) {
    test(
        'owned wallet refresh refuses missing, mismatched or nonfinite server wallet $bad',
        () async {
      walletData = bad;
      final wallet = WalletProvider();
      await expectLater(
          wallet.refreshWalletForOwner('fixture_owner'), throwsStateError);
      expect(wallet.balance, 0);
      wallet.dispose();
      expect(calls, isEmpty);
    });
  }
  testWidgets(
      'fresh native payment freezes original amount despite editing the input',
      (tester) async {
    final store = MemoryStore();
    final journal =
        WalletTopupRecoveryService(store: store, currentUserId: () => auth.uid);
    await mount(tester, journal);
    await tester.enterText(find.byType(TextField), '100');
    await tester.pump();
    await tester.tap(find.text('Proceed to Pay'));
    await tester.enterText(find.byType(TextField), '200');
    await drain(tester);
    expect(opens.single['amount'], 10000);
    expect(calls.last['parameters']['amount'], 100);
    expect(find.text('₹100.00 added to your wallet'), findsOneWidget);
  });
}
