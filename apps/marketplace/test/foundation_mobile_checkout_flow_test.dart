// Real coordinator, SDK/callable channels and filesystem. No backend/provider IO.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_marketplace/services/checkout_recovery_service.dart';
import 'package:agrimore_marketplace/services/checkout_request_store_file.dart';
import 'package:agrimore_marketplace/services/checkout_request_store.dart';
import 'package:agrimore_marketplace/services/mobile_checkout_flow.dart';
import 'package:agrimore_marketplace/services/payment_checkout_order.dart';
import 'package:firebase_core/firebase_core.dart';
// Official Firebase test harness already resolved in this app.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStore implements CheckoutRequestStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String ownerId) async => values[ownerId];
  @override
  Future<void> write(String ownerId, String value) async {
    values[ownerId] = value;
  }

  @override
  Future<void> remove(String ownerId) async {
    values.remove(ownerId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  const functions = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call',
      StandardMessageCodec());
  const sdk = MethodChannel('razorpay_flutter');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory directory;
  late CheckoutRequestStore store;
  late String? uid;
  late int nowMs;
  late CheckoutRecoveryService journal;
  late MobileCheckoutFlow flow;
  late List<MobileCheckoutFlow> flows;
  late List<Map> requests, sdkOpens;
  late List<PendingCheckoutRequest> confirmations;
  late List<String> errors;
  late Completer<void> confirmed, errorReported;
  late Future<List<Object?>> Function(Map call) transport;
  late Future<Map<String, dynamic>> Function(Map options) sdkResponse;
  final gateway = {
    'success': true,
    'orderId': 'order_flow_fixture',
    'keyId': 'rzp_test_flow_fixture',
    'amount': 10000,
    'currency': 'INR',
  };
  final receiptResponse = {
    'success': true,
    'orders': [
      {
        'orderId': 'fixture_order',
        'orderNumber': 'ORD-FIXTURE',
        'sellerId': 'fixture_seller',
        'total': 100.0
      },
    ],
  };
  final capture = {
    'success': true,
    'verified': true,
    'outcome': 'captured',
    'orderId': gateway['orderId'],
    'paymentId': 'pay_flow_fixture',
    'amountPaise': 10000,
    'currency': 'INR',
  };
  const customer =
      MobileCheckoutCustomer(name: 'Fixture', email: '', phone: '');
  Map<String, dynamic> intent({bool paid = false}) => {
        'items': [
          {'productId': 'fixture_product', 'quantity': 1}
        ],
        'orderMode': 'B2C',
        'paymentMethod': paid ? 'razorpay' : 'cod',
        'deliveryAddress': {'name': 'Fixture'},
        'deliveryCharge': 0,
        'tax': 0,
      };
  MobileCheckoutFlow makeFlow(
      {Future<void> Function(PendingCheckoutRequest, List<CheckoutReceipt>)?
          complete,
      void Function()? changed}) {
    final f = MobileCheckoutFlow(
        journal: journal,
        currentUserId: () => uid,
        nowMs: () => nowMs,
        onChanged: changed ?? () {},
        onError: (message) {
          errors.add(message);
          if (!errorReported.isCompleted) errorReported.complete();
        },
        onConfirmed: complete ??
            (request, receipts) async {
              confirmations.add(request);
              expect(receipts.single.orderId, 'fixture_order');
              if (!confirmed.isCompleted) confirmed.complete();
            });
    flows.add(f);
    return f;
  }

  Future<void> start({bool paid = false}) =>
      flow.start(intent: intent(paid: paid), amount: 100, customer: customer);
  Future<void> awaitConfirmation() =>
      confirmed.future.timeout(const Duration(seconds: 2));
  Future<void> awaitError() =>
      errorReported.future.timeout(const Duration(seconds: 2));
  Future<PendingCheckoutRequest> awaiting() async {
    final request = await journal.prepare(intent(paid: true));
    return journal.attachGateway(request.ownerId, request.requestId,
        PaymentCheckoutOrder.fromResponse(gateway));
  }

  setUpAll(() async => Firebase.initializeApp());
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('agrimore-mobile-flow-');
    store = FileCheckoutRequestStore(directory: () async => directory);
    uid = 'fixture_owner';
    nowMs = DateTime.now().millisecondsSinceEpoch;
    journal = CheckoutRecoveryService(store: store, currentUserId: () => uid);
    requests = [];
    sdkOpens = [];
    confirmations = [];
    errors = [];
    flows = [];
    confirmed = Completer<void>();
    errorReported = Completer<void>();
    transport = (call) async => [
          switch (call['functionName']) {
            'createRazorpayOrder' => gateway,
            'verifyRazorpayPayment' => {'success': true, 'verified': true},
            'recoverCheckoutPayment' => capture,
            _ => receiptResponse,
          }
        ];
    sdkResponse = (options) async => {
          'type': 0,
          'data': {
            'razorpay_payment_id': 'pay_flow_fixture',
            'razorpay_order_id': options['order_id'],
            'razorpay_signature': 'fixture_signature'
          },
        };
    messenger.setMockDecodedMessageHandler<Object?>(functions, (message) async {
      final call = (message! as List).single as Map;
      requests.add(call);
      return transport(call);
    });
    messenger.setMockMethodCallHandler(sdk, (call) async {
      if (call.method == 'resync') return null;
      expect(call.method, 'open');
      final options = call.arguments as Map;
      sdkOpens.add(options);
      final saved = jsonDecode((await store.read('fixture_owner'))!) as Map;
      expect(saved['stage'], 'awaiting_payment');
      expect((saved['gateway'] as Map)['orderId'], options['order_id']);
      return sdkResponse(options);
    });
    flow = makeFlow();
  });
  tearDown(() async {
    for (final f in flows) {
      f.dispose();
    }
    messenger.setMockDecodedMessageHandler<Object?>(functions, null);
    messenger.setMockMethodCallHandler(sdk, null);
    await directory.delete(
        recursive: true); // Only this test's generated folder.
  });

  test('COD confirms the frozen intent and publishes a durable server receipt',
      () async {
    await start();
    await awaitConfirmation();
    expect(requests.map((r) => r['functionName']), ['createOrder']);
    expect(sdkOpens, isEmpty);
    expect(confirmations.single.stage, 'completed');
    expect(requests.single['parameters']['checkoutOwnerId'], 'fixture_owner');
    expect(requests.single['parameters']['checkoutRequestId'],
        confirmations.single.requestId);
    expect(flow.isBusy, false);
    expect(errors, isEmpty);
  });
  test('SDK tuple and proof persist before verification and order creation',
      () async {
    transport = (call) async {
      if (call['functionName'] == 'createRazorpayOrder') return [gateway];
      if (call['functionName'] == 'verifyRazorpayPayment') {
        final saved = jsonDecode((await store.read('fixture_owner'))!) as Map;
        expect(saved['stage'], 'ready');
        expect(saved['payment']['paymentId'], 'pay_flow_fixture');
        return [
          {'verified': true}
        ];
      }
      return [receiptResponse];
    };
    await start(paid: true);
    await awaitConfirmation();
    expect(requests.map((r) => r['functionName']),
        ['createRazorpayOrder', 'verifyRazorpayPayment', 'createOrder']);
    expect(sdkOpens.single['amount'], 10000);
    expect(errors, isEmpty);
  });
  test('caller changes while queued cannot alter the prepared intent',
      () async {
    final payload = intent();
    final pending =
        flow.start(intent: payload, amount: 100, customer: customer);
    (payload['items'] as List).first['quantity'] = 9;
    await pending;
    expect(requests.single['parameters']['items'].first['quantity'], 1);
  });
  test('lost order reply restores same request with no new provider order',
      () async {
    var lostOnce = false;
    transport = (call) async {
      if (call['functionName'] == 'createOrder' && !lostOnce) {
        lostOnce = true;
        return ['unavailable', 'Synthetic lost order reply', null];
      }
      return [receiptResponse];
    };
    await start();
    await awaitError();
    final original = flow.pending!;
    expect(original.stage, 'ready');
    flow.dispose();
    flow = makeFlow();
    await flow.restore();
    await flow.resume(customer: customer);
    await awaitConfirmation();
    expect(confirmations.single.requestId, original.requestId);
    expect(requests.where((r) => r['functionName'] == 'createRazorpayOrder'),
        isEmpty);
    expect(requests.map((r) => r['parameters']['checkoutRequestId']).toSet(),
        {original.requestId});
  });
  test(
      'lost SDK callback recovers capture and fulfils without SDK or signature',
      () async {
    final request = await awaiting();
    await flow.restore();
    await flow.resume(customer: customer);
    await awaitConfirmation();
    expect(sdkOpens, isEmpty);
    expect(requests.map((r) => r['functionName']), [
      'recoverCheckoutPayment',
      'recoverCheckoutPayment',
      'recoverCheckoutPayment',
      'createOrder'
    ]);
    expect(requests.last['parameters'].containsKey('razorpaySignature'), false);
    expect(confirmations.single.requestId, request.requestId);
  });
  test(
      'unconfirmed recovery reopens only the original order then confirms SDK proof',
      () async {
    final request = await awaiting();
    transport = (call) async => [
          switch (call['functionName']) {
            'recoverCheckoutPayment' => {
                'success': true,
                'verified': false,
                'outcome': 'unconfirmed',
                'orderId': gateway['orderId'],
                'keyId': gateway['keyId'],
                'amountPaise': 10000,
                'currency': 'INR'
              },
            'verifyRazorpayPayment' => {'verified': true},
            _ => receiptResponse,
          }
        ];
    await flow.restore();
    await flow.resume(customer: customer);
    await awaitConfirmation();
    expect(sdkOpens.single['order_id'], request.gateway!['orderId']);
    expect(requests.where((r) => r['functionName'] == 'createRazorpayOrder'),
        isEmpty);
  });
  for (final pricingKind in ['delivery', 'credit']) {
    final pricingIdKey =
        pricingKind == 'delivery' ? 'deliveryQuoteId' : 'productCreditHoldId';
    final pricingDeadlineKey = pricingKind == 'delivery'
        ? 'deliveryQuoteExpiresAtMs'
        : 'productCreditHoldExpiresAtMs';
    test(
        '$pricingKind expired quoted unpaid recovery checks capture but never reopens SDK',
        () async {
      final draft = await journal.prepare({
        ...intent(paid: true),
        pricingIdKey: 'fixture_quote',
        pricingDeadlineKey: DateTime.now().millisecondsSinceEpoch - 1,
      });
      final request = await journal.attachGateway(draft.ownerId,
          draft.requestId, PaymentCheckoutOrder.fromResponse(gateway));
      transport = (call) async => [
            {
              'success': true,
              'verified': false,
              'outcome': 'unconfirmed',
              'orderId': gateway['orderId'],
              'keyId': gateway['keyId'],
              'amountPaise': 10000,
              'currency': 'INR',
            }
          ];
      await flow.restore();
      await flow.resume(customer: customer);
      expect(sdkOpens, isEmpty);
      expect(
          requests.map((r) => r['functionName']), ['recoverCheckoutPayment']);
      expect((await journal.pending())!.requestId, request.requestId);
      expect((await journal.pending())!.stage, 'awaiting_payment');
      expect(errors, isNotEmpty);
    });
    for (final expiry in <Object?>[null, 'invalid', 1.5, 9007199254740992]) {
      test(
          '$pricingKind quoted initial payment rejects malformed deadline $expiry before transport',
          () async {
        await flow.start(intent: {
          ...intent(paid: true),
          pricingIdKey: 'fixture_quote',
          pricingDeadlineKey: expiry,
        }, amount: 100, customer: customer);
        expect(requests, isEmpty);
        expect(sdkOpens, isEmpty);
        expect(await journal.pending(), isNull);
        expect(errors, isNotEmpty);
      });
    }
    test(
        '$pricingKind valid quote opens native payment with immutable deadline',
        () async {
      await flow.start(intent: {
        ...intent(paid: true),
        pricingIdKey: 'fixture_quote',
        pricingDeadlineKey: nowMs + 600000,
      }, amount: 100, customer: customer);
      await awaitConfirmation();
      expect(sdkOpens, hasLength(1));
      expect(confirmations.single.intent[pricingDeadlineKey], nowMs + 600000);
    });
    test(
        '$pricingKind deadline reached during capture lookup blocks unpaid reopening',
        () async {
      final draft = await journal.prepare({
        ...intent(paid: true),
        pricingIdKey: 'fixture_quote',
        pricingDeadlineKey: nowMs + 100,
      });
      await journal.attachGateway(draft.ownerId, draft.requestId,
          PaymentCheckoutOrder.fromResponse(gateway));
      transport = (call) async {
        nowMs += 100;
        return [
          {
            'success': true,
            'verified': false,
            'outcome': 'unconfirmed',
            'orderId': gateway['orderId'],
            'keyId': gateway['keyId'],
            'amountPaise': 10000,
            'currency': 'INR',
          }
        ];
      };
      await flow.resume(customer: customer);
      expect(sdkOpens, isEmpty);
      expect(
          requests.map((r) => r['functionName']), ['recoverCheckoutPayment']);
      expect((await journal.pending())!.stage, 'awaiting_payment');
      expect(errors, isNotEmpty);
    });
    test(
        '$pricingKind expired quote still recovers captured payment when server refuses fulfilment',
        () async {
      final draft = await journal.prepare({
        ...intent(paid: true),
        pricingIdKey: 'fixture_quote',
        pricingDeadlineKey: nowMs - 1,
      });
      await journal.attachGateway(draft.ownerId, draft.requestId,
          PaymentCheckoutOrder.fromResponse(gateway));
      transport = (call) async => call['functionName'] == 'createOrder'
          ? ['failed-precondition', 'Synthetic expired quote', null]
          : [capture];
      await flow.resume(customer: customer);
      expect(sdkOpens, isEmpty);
      expect(requests.map((r) => r['functionName']), [
        'recoverCheckoutPayment',
        'recoverCheckoutPayment',
        'recoverCheckoutPayment',
        'createOrder'
      ]);
      final saved = (await journal.pending())!;
      expect(saved.payment!['paymentId'], 'pay_flow_fixture');
      expect(saved.requestId, draft.requestId);
      expect(confirmations, isEmpty);
      expect(errors, isNotEmpty);
    });
    test(
        '$pricingKind deadline reached while creating gateway preserves order without opening SDK',
        () async {
      transport = (call) async {
        nowMs += 100;
        return [gateway];
      };
      await flow.start(intent: {
        ...intent(paid: true),
        pricingIdKey: 'fixture_quote',
        pricingDeadlineKey: nowMs + 100,
      }, amount: 100, customer: customer);
      await awaitError();
      expect(sdkOpens, isEmpty);
      expect(requests.map((r) => r['functionName']), ['createRazorpayOrder']);
      expect(
          (await journal.pending())!.gateway!['orderId'], gateway['orderId']);
      expect(errors, isNotEmpty);
    });
  }
  for (final expiredKind in ['delivery', 'credit']) {
    test('both constraints reject when only $expiredKind has expired',
        () async {
      await flow.start(intent: {
        ...intent(paid: true),
        'deliveryQuoteId': 'fixture_delivery',
        'deliveryQuoteExpiresAtMs':
            nowMs + (expiredKind == 'delivery' ? 0 : 1000),
        'productCreditHoldId': 'fixture_hold',
        'productCreditHoldExpiresAtMs':
            nowMs + (expiredKind == 'credit' ? 0 : 1000),
      }, amount: 100, customer: customer);
      expect(requests, isEmpty);
      expect(sdkOpens, isEmpty);
      expect(await journal.pending(), isNull);
    });
  }
  test('both valid constraints persist without replacing frozen hold',
      () async {
    await flow.start(intent: {
      ...intent(paid: true),
      'deliveryQuoteId': 'fixture_delivery',
      'deliveryQuoteExpiresAtMs': nowMs + 1000,
      'productCreditHoldId': 'fixture_hold',
      'productCreditHoldExpiresAtMs': nowMs + 1800000,
    }, amount: 100, customer: customer);
    await awaitConfirmation();
    expect(sdkOpens, hasLength(1));
    expect(confirmations.single.intent['productCreditHoldId'], 'fixture_hold');
    expect(confirmations.single.intent['productCreditHoldExpiresAtMs'],
        nowMs + 1800000);
  });
  for (final holdId in <Object?>['', 12, 'bad/path']) {
    test('malformed credit hold $holdId cannot initiate payment', () async {
      await flow.start(intent: {
        ...intent(paid: true),
        'productCreditHoldId': holdId,
        'productCreditHoldExpiresAtMs': nowMs + 1800000,
      }, amount: 100, customer: customer);
      expect(requests, isEmpty);
      expect(sdkOpens, isEmpty);
      expect(await journal.pending(), isNull);
    });
  }
  test('unavailable provider lookup preserves attempt and opens no SDK',
      () async {
    final request = await awaiting();
    transport = (_) async => ['unavailable', 'PRIVATE_FIXTURE_ERROR', null];
    await flow.restore();
    await flow.resume(customer: customer);
    await awaitError();
    expect(flow.pending!.toMap(), request.toMap());
    expect(sdkOpens, isEmpty);
    expect(errors.single.contains('PRIVATE_FIXTURE'), false);
    expect(flow.isBusy, false);
  });
  test('native failure preserves the original attempt for later outcome checks',
      () async {
    sdkResponse = (_) async => {
          'type': 1,
          'data': {'code': 2, 'message': 'PRIVATE_FIXTURE_ERROR'}
        };
    await start(paid: true);
    await awaitError();
    expect(flow.pending!.stage, 'awaiting_payment');
    expect(flow.isBusy, false);
    expect(requests.map((r) => r['functionName']), ['createRazorpayOrder']);
    expect(errors.single.contains('PRIVATE_FIXTURE'), false);
  });
  test(
      'a saved paid draft requires review and cannot open a new payment on resume',
      () async {
    final request = await journal.prepare(intent(paid: true));
    await flow.restore();
    await flow.resume(customer: customer);
    await awaitError();
    expect(flow.pending!.requestId, request.requestId);
    expect(requests, isEmpty);
    expect(sdkOpens, isEmpty);
    await flow.discardDraft();
    expect(await journal.pending(), isNull);
  });
  test('an attempted payment cannot be discarded', () async {
    final request = await awaiting();
    await flow.restore();
    await flow.discardDraft();
    await awaitError();
    expect((await journal.pending())!.toMap(), request.toMap());
  });
  test('a completed receipt after restart publishes without financial RPC',
      () async {
    final request = await journal.prepare(intent());
    await journal.confirm(request.ownerId, request.requestId);
    requests.clear();
    await flow.restore();
    await flow.resume(customer: customer);
    await awaitConfirmation();
    expect(requests, isEmpty);
    expect(sdkOpens, isEmpty);
  });
  test(
      'receipt handoff failure preserves completion and allows retry without another order',
      () async {
    var first = true;
    flow.dispose();
    flow = makeFlow(complete: (request, receipts) async {
      if (first) {
        first = false;
        throw StateError('Synthetic display failure');
      }
      confirmations.add(request);
      confirmed.complete();
    });
    await start();
    await awaitError();
    expect(flow.pending!.stage, 'completed');
    await flow.resume(customer: customer);
    await awaitConfirmation();
    expect(requests.map((r) => r['functionName']), ['createOrder']);
  });
  test('acknowledgment clears only a completed owned receipt', () async {
    await start();
    await awaitConfirmation();
    await flow.acknowledge(confirmations.single);
    expect(await journal.pending(), isNull);
    expect(flow.pending, isNull);
  });
  test(
      'account switch during create response cannot publish the previous account receipt',
      () async {
    transport = (_) async {
      uid = 'other-owner';
      return [receiptResponse];
    };
    await start();
    expect(confirmations, isEmpty);
    expect(errors, isEmpty);
    expect(flow.pending, isNull);
    expect(sdkOpens, isEmpty);
    uid = 'fixture_owner';
    nowMs = DateTime.now().millisecondsSinceEpoch;
    expect((await journal.pending())!.stage, 'ready');
  });
  test(
      'disposal during provider creation suppresses persistence hook and late SDK',
      () async {
    transport = (_) async {
      flow.dispose();
      return [gateway];
    };
    await start(paid: true);
    expect(confirmations, isEmpty);
    expect(sdkOpens, isEmpty);
    expect(errors, isEmpty);
    expect((await journal.pending())!.stage, 'draft');
  });
  test(
      'account switch at the persistence UI handoff cannot open the old SDK checkout',
      () async {
    flow.dispose();
    flow = makeFlow(changed: () {
      if (flow.pending?.stage == 'awaiting_payment') uid = 'other-owner';
    });
    await start(paid: true);
    await Future<void>.delayed(Duration.zero);
    expect(sdkOpens, isEmpty);
    expect(confirmations, isEmpty);
    uid = 'fixture_owner';
    nowMs = DateTime.now().millisecondsSinceEpoch;
    expect((await journal.pending())!.stage, 'awaiting_payment');
  });
  test('account switch while loading pending state hides old-account details',
      () async {
    await awaiting();
    await flow.restore();
    uid = 'other-owner';
    expect(flow.pending, isNull);
    expect(flow.isBusy, false);
  });
  testWidgets('closed checkout context cannot open a late payment window',
      (tester) async {
    // Widget tests use a fake clock. Keep persistence in memory here; the
    // remaining flow cases exercise real files under the ordinary test clock.
    flow.dispose();
    store = _MemoryStore();
    journal = CheckoutRecoveryService(store: store, currentUserId: () => uid);
    flow = makeFlow();
    late BuildContext checkoutContext;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      checkoutContext = context;
      return const SizedBox();
    })));
    final entered = Completer<void>(), release = Completer<void>();
    transport = (call) async {
      if (call['functionName'] == 'createRazorpayOrder') {
        entered.complete();
        await release.future;
        return [gateway];
      }
      return [
        call['functionName'] == 'verifyRazorpayPayment'
            ? {'verified': true}
            : receiptResponse
      ];
    };
    final operation = flow.start(
        intent: intent(paid: true),
        amount: 100,
        customer: customer,
        context: checkoutContext);
    await tester.pump();
    expect(entered.isCompleted, true);
    await tester.pumpWidget(const SizedBox());
    release.complete();
    await tester.pump();
    await operation;
    await tester.pump();
    expect(sdkOpens, isEmpty);
    expect(confirmations, isEmpty);
    expect(flow.pending?.stage, 'awaiting_payment');
  });
  test('another foreground flow cannot create a second provider attempt',
      () async {
    final sdkEntered = Completer<void>(),
        releaseSdk = Completer<Map<String, dynamic>>();
    sdkResponse = (_) async {
      if (!sdkEntered.isCompleted) sdkEntered.complete();
      return releaseSdk.future;
    };
    transport = (call) async => [
          switch (call['functionName']) {
            'createRazorpayOrder' => gateway,
            'recoverCheckoutPayment' => {
                'success': true,
                'verified': false,
                'outcome': 'unconfirmed',
                'orderId': gateway['orderId'],
                'keyId': gateway['keyId'],
                'amountPaise': 10000,
                'currency': 'INR',
              },
            _ => receiptResponse,
          }
        ];
    await start(paid: true);
    await sdkEntered.future;
    final other = makeFlow();
    await other.start(
        intent: intent(paid: true), amount: 100, customer: customer);
    await other.resume(customer: customer);
    final created = requests
        .where((r) => r['functionName'] == 'createRazorpayOrder')
        .length;
    final recovered = requests
        .where((r) => r['functionName'] == 'recoverCheckoutPayment')
        .length;
    final opened = sdkOpens.length;
    errorReported = Completer<void>();
    releaseSdk.complete({
      'type': 1,
      'data': {'code': 2, 'message': 'Synthetic dismissal'}
    });
    await awaitError();
    expect(created, 1);
    expect(recovered, 0);
    expect(opened, 1);
  });
  test('rapid repeated start uses one SDK order and one receipt handoff',
      () async {
    await Future.wait([start(paid: true), start(paid: true)]);
    await awaitConfirmation();
    expect(requests.where((r) => r['functionName'] == 'createRazorpayOrder'),
        hasLength(1));
    expect(sdkOpens, hasLength(1));
    expect(confirmations, hasLength(1));
    expect(errors, isEmpty);
  });
  test('Auto-Delivery completion is finished before UI receipt handoff',
      () async {
    final payload = {
      ...intent(),
      'orderType': 'Auto Delivery',
      'autoFrequency': 'Daily'
    };
    transport = (call) async => [
          call['functionName'] == 'ensureCheckoutSubscriptions'
              ? {
                  'success': true,
                  'checkoutRequestId': call['parameters']['checkoutRequestId'],
                  'subscriptionIds': ['a' * 64]
                }
              : receiptResponse
        ];
    await flow.start(intent: payload, amount: 100, customer: customer);
    await awaitConfirmation();
    expect(requests.map((r) => r['functionName']),
        ['createOrder', 'ensureCheckoutSubscriptions']);
  });

  group('receipt display and cart preservation', () {
    late PendingCheckoutRequest request;
    late CheckoutReceipt receipt;
    late Map<String, dynamic> order;
    setUp(() async {
      request = await journal.prepare(intent());
      receipt = CheckoutReceipt.parse(receiptResponse['orders']).single;
      order = {
        'id': receipt.orderId,
        'userId': request.ownerId,
        'sellerId': receipt.sellerId,
        'orderNumber': receipt.orderNumber,
        'total': receipt.total,
        'items': [],
        'deliveryAddress': {},
        'paymentMethod': 'cod'
      };
    });
    CartItemModel item(
            {String product = 'fixture_product',
            int quantity = 1,
            String? variant}) =>
        CartItemModel(
            id: 'fixture',
            productId: product,
            productName: 'Fixture',
            productImage: '',
            price: 999,
            quantity: quantity,
            userId: request.ownerId,
            addedAt: DateTime(2026),
            variant: variant);
    test(
        'display uses exact server receipt total instead of current cart price',
        () {
      expect(
          orderFromCheckoutReceipt(receipt, request.ownerId, order).total, 100);
      expect(checkoutMatchesCart(request, [item()], 'B2C'), true);
    });
    for (final change in [
      {'userId': 'other'},
      {'id': 'other'},
      {'sellerId': 'other'},
      {'orderNumber': 'other'},
      {'total': 1}
    ]) {
      test('wrong receipt document refuses $change', () {
        expect(
            () => orderFromCheckoutReceipt(
                receipt, request.ownerId, {...order, ...change}),
            throwsStateError);
      });
    }
    test(
        'changed product quantity variant mode or empty cart must be preserved',
        () {
      expect(
          checkoutMatchesCart(request, [item(product: 'other')], 'B2C'), false);
      expect(checkoutMatchesCart(request, [item(quantity: 2)], 'B2C'), false);
      expect(
          checkoutMatchesCart(request, [item(variant: 'other')], 'B2C'), false);
      expect(checkoutMatchesCart(request, [item()], 'B2B'), false);
      expect(checkoutMatchesCart(request, [], 'B2C'), false);
    });
    test('same items from another account cannot be cleared by this checkout',
        () {
      final other = CartItemModel(
          id: 'other',
          productId: 'fixture_product',
          productName: 'Fixture',
          productImage: '',
          price: 100,
          quantity: 1,
          userId: 'other-owner',
          addedAt: DateTime(2026));
      expect(checkoutMatchesCart(request, [other], 'B2C'), false);
    });
  });
}
