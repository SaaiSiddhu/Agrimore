// Exercises the real service through Firebase and Razorpay platform channels.
// Neither channel reaches a backend, device SDK or payment provider.
@TestOn('vm')
library;

import 'dart:async';

import 'package:agrimore_marketplace/services/razorpay_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  const functionsChannel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call',
    StandardMessageCodec(),
  );
  const sdkChannel = MethodChannel('razorpay_flutter');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Map<String, dynamic> serverResponse;
  late List<Map<dynamic, dynamic>> requests;
  late List<Map<dynamic, dynamic>> sdkOptions;
  late List<String> failures;
  late Completer<Map<dynamic, dynamic>> opened;
  late RazorpayService service;

  setUpAll(() async => Firebase.initializeApp());
  setUp(() {
    serverResponse = {
      'success': true,
      'orderId': 'order_foundation_mobile',
      'keyId': 'rzp_test_foundation_fixture',
      'amount': 59999,
      'currency': 'INR',
    };
    requests = [];
    sdkOptions = [];
    failures = [];
    opened = Completer<Map<dynamic, dynamic>>();
    messenger.setMockDecodedMessageHandler<Object?>(functionsChannel,
        (message) async {
      final call = (message! as List).single as Map;
      expect(call['functionName'], 'createRazorpayOrder');
      requests.add(call['parameters'] as Map);
      return [serverResponse];
    });
    messenger.setMockMethodCallHandler(sdkChannel, (call) async {
      if (call.method == 'resync') return null;
      expect(call.method, 'open');
      final options = call.arguments as Map;
      sdkOptions.add(options);
      if (!opened.isCompleted) opened.complete(options);
      return {
        'type': 0,
        'data': {
          'razorpay_payment_id': 'pay_foundation_mobile',
          'razorpay_order_id': options['order_id'],
          'razorpay_signature': 'fixture_signature',
        },
      };
    });
    service = RazorpayService();
    service.initialize(onSuccess: (_, __, ___) {}, onFailure: failures.add);
  });
  tearDown(() {
    service.dispose();
    messenger.setMockDecodedMessageHandler<Object?>(functionsChannel, null);
    messenger.setMockMethodCallHandler(sdkChannel, null);
  });

  Future<void> checkout() => service.openCheckout(
        amount: 599.99,
        userName: 'Fixture Customer',
        userEmail: 'fixture@example.invalid',
        userPhone: '',
      );

  test('goods purpose is sent to the real callable transport', () async {
    await checkout();
    await opened.future.timeout(const Duration(seconds: 2));
    expect(requests.single['purpose'], 'goods_checkout');
  });
  test('disposing during provider response prevents late native checkout',
      () async {
    final entered = Completer<void>(), release = Completer<void>();
    messenger.setMockDecodedMessageHandler<Object?>(functionsChannel,
        (message) async {
      entered.complete();
      await release.future;
      return [serverResponse];
    });
    final pending = checkout();
    await entered.future;
    service.dispose();
    release.complete();
    await pending;
    await Future<void>.delayed(Duration.zero);
    expect(sdkOptions, isEmpty);
    expect(failures, isEmpty);
  });
  test('durable order-created hook finishes before native SDK opens', () async {
    final entered = Completer<void>(), release = Completer<void>();
    final pending = service.openCheckout(
      amount: 599.99,
      userName: '',
      userEmail: '',
      userPhone: '',
      onOrderCreated: (order) async {
        expect(order.orderId, 'order_foundation_mobile');
        expect(order.amountPaise, 59999);
        expect(order.keyId, 'rzp_test_foundation_fixture');
        entered.complete();
        await release.future;
      },
    );
    await entered.future;
    expect(sdkOptions, isEmpty);
    release.complete();
    await pending;
    expect((await opened.future)['amount'], 59999);
    expect(requests, hasLength(1));
  });
  test('failed order-created hook never opens SDK or emits payment success',
      () async {
    bool success = false;
    service.initialize(
        onSuccess: (_, __, ___) {
          success = true;
        },
        onFailure: failures.add);
    await service.openCheckout(
      amount: 599.99,
      userName: '',
      userEmail: '',
      userPhone: '',
      onOrderCreated: (_) async {
        throw StateError('Synthetic persistence failure');
      },
    );
    expect(sdkOptions, isEmpty);
    expect(success, false);
    expect(failures, hasLength(1));
  });
  test('malformed server order cannot reach persistence hook', () async {
    bool hook = false;
    serverResponse['amount'] = 59999.5;
    await service.openCheckout(
      amount: 599.99,
      userName: '',
      userEmail: '',
      userPhone: '',
      onOrderCreated: (_) async {
        hook = true;
      },
    );
    expect(hook, false);
    expect(sdkOptions, isEmpty);
    expect(failures, hasLength(1));
  });
  test('disposing during persistence hook suppresses late native SDK open',
      () async {
    final entered = Completer<void>(), release = Completer<void>();
    final pending = service.openCheckout(
      amount: 599.99,
      userName: '',
      userEmail: '',
      userPhone: '',
      onOrderCreated: (_) async {
        entered.complete();
        await release.future;
      },
    );
    await entered.future;
    service.dispose();
    release.complete();
    await pending;
    expect(sdkOptions, isEmpty);
    expect(failures, isEmpty);
  });
  test('sandbox success waits for persistence hook instead of bypassing it',
      () async {
    final entered = Completer<void>(), release = Completer<void>();
    bool success = false;
    serverResponse['isTestMode'] = true;
    service.initialize(
        onSuccess: (_, __, ___) {
          success = true;
        },
        onFailure: failures.add);
    final pending = service.openCheckout(
      amount: 599.99,
      userName: '',
      userEmail: '',
      userPhone: '',
      onOrderCreated: (_) async {
        entered.complete();
        await release.future;
      },
    );
    await entered.future;
    expect(success, false);
    release.complete();
    await pending;
    expect(success, true);
    expect(sdkOptions, isEmpty);
    expect(failures, isEmpty);
  });
  test('59999 server paise reaches the native SDK without losing a paise',
      () async {
    await checkout();
    final options = await opened.future.timeout(const Duration(seconds: 2));
    expect(options['amount'], 59999);
    expect(options['order_id'], 'order_foundation_mobile');
  });
  test('wallet top-up declares wallet intent and preserves success callback',
      () async {
    final callback = Completer<List<String?>>();
    service.initialize(
      onSuccess: (payment, order, signature) =>
          callback.complete([payment, order, signature]),
      onFailure: failures.add,
    );
    await service.openCheckout(
      amount: 599.99,
      purpose: CheckoutPaymentPurpose.walletTopup,
      userName: '',
      userEmail: '',
      userPhone: '',
    );
    expect(await callback.future.timeout(const Duration(seconds: 2)), [
      'pay_foundation_mobile',
      'order_foundation_mobile',
      'fixture_signature'
    ]);
    expect(requests.single['purpose'], 'wallet_topup');
    expect(sdkOptions.single['amount'], 59999);
  });
  test('integral JSON double minor units remain exact', () async {
    serverResponse['amount'] = 59999.0;
    await checkout();
    expect((await opened.future.timeout(const Duration(seconds: 2)))['amount'],
        59999);
  });
  test(
      'SDK amount comes from server order instead of the requested rupee amount',
      () async {
    serverResponse['amount'] = 12345;
    await checkout();
    expect((await opened.future.timeout(const Duration(seconds: 2)))['amount'],
        12345);
  });
  test('29 paise survives a rupee value whose float multiplication is below 29',
      () async {
    serverResponse['amount'] = 29;
    await service.openCheckout(
        amount: 0.29, userName: '', userEmail: '', userPhone: '');
    expect((await opened.future.timeout(const Duration(seconds: 2)))['amount'],
        29);
  });
  for (final entry in <MapEntry<String, dynamic>>[
    const MapEntry('amount', null),
    const MapEntry('amount', 59999.5),
    const MapEntry('amount', -1),
    const MapEntry('amount', double.nan),
    const MapEntry('amount', double.infinity),
    const MapEntry('amount', 9007199254740992),
    const MapEntry('currency', null),
    const MapEntry('currency', 'USD'),
    const MapEntry('orderId', 'bad/path'),
    const MapEntry('keyId', 'invalid'),
  ]) {
    test(
        'invalid server ${entry.key}:${entry.value} cannot open native checkout',
        () async {
      serverResponse[entry.key] = entry.value;
      await checkout();
      await Future<void>.delayed(Duration.zero);
      expect(sdkOptions, isEmpty);
      expect(failures, hasLength(1));
    });
  }
}
