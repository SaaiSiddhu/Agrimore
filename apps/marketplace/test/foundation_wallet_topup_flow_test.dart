@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:agrimore_marketplace/services/checkout_request_store_file.dart';
import 'package:agrimore_marketplace/services/checkout_recovery_service.dart';
import 'package:agrimore_marketplace/services/mobile_checkout_flow.dart';
import 'package:agrimore_marketplace/services/payment_checkout_order.dart';
import 'package:agrimore_marketplace/services/wallet_topup_recovery_service.dart';
import 'package:agrimore_marketplace/services/wallet_topup_flow.dart';
import 'package:firebase_core/firebase_core.dart';
// Official cached Firebase transport harness; no network or real provider.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  const functions = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call',
      StandardMessageCodec());
  const sdk = MethodChannel('razorpay_flutter');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final gateway = {
    'success': true,
    'orderId': 'order_wallet_fixture',
    'keyId': 'rzp_test_fixture',
    'amount': 10000,
    'currency': 'INR'
  };
  final receipt = {
    'success': true,
    'amount': 100.0,
    'alreadyCredited': false,
    'bonusCoins': 5,
    'balanceAfter': 110.0,
    'coinsAfter': 8
  };
  final capture = {
    'success': true,
    'verified': true,
    'outcome': 'captured',
    'orderId': 'order_wallet_fixture',
    'paymentId': 'pay_wallet_fixture',
    'amountPaise': 10000,
    'currency': 'INR'
  };
  late Directory directory;
  late FileCheckoutRequestStore store;
  late String? uid;
  late WalletTopupRecoveryService journal;
  late WalletTopupFlow flow;
  late List<WalletTopupFlow> flows;
  late List<MobileCheckoutFlow> goodsFlows;
  late List<Map> calls, opens;
  late List<String> errors;
  late Completer<void> done, failed;
  late Future<List<Object?>> Function(Map) transport;
  late Future<Map<String, dynamic>> Function(Map) sdkReply;
  WalletTopupFlow makeFlow(
      {Future<void> Function(PendingWalletTopup, Map<String, dynamic>)? handoff,
      void Function()? changed}) {
    final f = WalletTopupFlow(
        journal: journal,
        currentUserId: () => uid,
        onChanged: changed ?? () {},
        onError: (message) {
          errors.add(message);
          if (!failed.isCompleted) failed.complete();
        },
        onConfirmed: handoff ??
            (request, result) async {
              expect(request.stage, 'completed');
              expect(result['amount'], 100);
              if (!done.isCompleted) done.complete();
            });
    flows.add(f);
    return f;
  }

  Future<void> settle(Completer<void> c) =>
      c.future.timeout(const Duration(seconds: 3));
  Future<PendingWalletTopup> saved({String stage = 'awaiting_payment'}) async {
    var p = await journal.prepare(100);
    if (stage != 'draft') {
      p = await journal.attachGateway(
          p.ownerId, p.requestId, PaymentCheckoutOrder.fromResponse(gateway));
    }
    if (stage == 'ready' || stage == 'completed') {
      p = await journal.recordPayment(p.ownerId, p.requestId,
          paymentId: 'pay_wallet_fixture',
          orderId: 'order_wallet_fixture',
          signature: 'fixture_signature');
    }
    if (stage == 'completed') {
      await journal.confirm(p.ownerId, p.requestId);
      p = (await journal.pending())!;
      calls.clear();
    }
    return p;
  }

  MobileCheckoutFlow goods() {
    final g = MobileCheckoutFlow(
        journal: CheckoutRecoveryService(
            store: FileCheckoutRequestStore(directory: () async => directory),
            currentUserId: () => uid),
        currentUserId: () => uid,
        onChanged: () {},
        onError: (_) {},
        onConfirmed: (_, __) async {});
    goodsFlows.add(g);
    return g;
  }

  Future<void> startGoods(MobileCheckoutFlow g) => g.start(
          intent: {
            'items': [
              {'productId': 'fixture_product', 'quantity': 1}
            ],
            'paymentMethod': 'razorpay',
            'orderMode': 'B2C',
            'deliveryAddress': {'name': 'Fixture'}
          },
          amount: 100,
          customer: const MobileCheckoutCustomer(
              name: 'Fixture', phone: '', email: ''));
  setUpAll(() async => Firebase.initializeApp());
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('agrimore-wallet-flow-');
    store = FileCheckoutRequestStore(
        directory: () async => directory, walletTopups: true);
    uid = 'fixture_owner';
    journal =
        WalletTopupRecoveryService(store: store, currentUserId: () => uid);
    flows = [];
    goodsFlows = [];
    calls = [];
    opens = [];
    errors = [];
    done = Completer();
    failed = Completer();
    transport = (call) async => [
          switch (call['functionName']) {
            'createRazorpayOrder' => gateway,
            'recoverWalletTopupPayment' => capture,
            _ => receipt
          }
        ];
    sdkReply = (options) async => {
          'type': 0,
          'data': {
            'razorpay_payment_id': 'pay_wallet_fixture',
            'razorpay_order_id': options['order_id'],
            'razorpay_signature': 'fixture_signature'
          }
        };
    messenger.setMockDecodedMessageHandler<Object?>(functions, (message) async {
      final call = (message! as List).single as Map;
      calls.add(call);
      return transport(call);
    });
    messenger.setMockMethodCallHandler(sdk, (call) async {
      if (call.method == 'resync') return null;
      final options = call.arguments as Map;
      opens.add(options);
      return sdkReply(options);
    });
    flow = makeFlow();
  });
  tearDown(() async {
    for (final f in flows) {
      f.dispose();
    }
    for (final g in goodsFlows) {
      g.dispose();
    }
    messenger.setMockDecodedMessageHandler<Object?>(functions, null);
    messenger.setMockMethodCallHandler(sdk, null);
    await directory.delete(recursive: true);
  });
  test(
      'gateway and proof are durable before SDK and credit; frozen amount and owner sent',
      () async {
    sdkReply = (options) async {
      final p = (await journal.pending())!;
      expect(p.stage, 'awaiting_payment');
      expect(p.gateway!['orderId'], options['order_id']);
      return {
        'type': 0,
        'data': {
          'razorpay_payment_id': 'pay_wallet_fixture',
          'razorpay_order_id': options['order_id'],
          'razorpay_signature': 'fixture_signature'
        }
      };
    };
    transport = (call) async {
      if (call['functionName'] == 'createRazorpayOrder') return [gateway];
      final p = jsonDecode((await store.read('fixture_owner'))!) as Map;
      expect(p['stage'], 'ready');
      expect(p['proof']['paymentId'], 'pay_wallet_fixture');
      return [receipt];
    };
    await flow.start(amount: 100);
    await settle(done);
    expect(calls.map((c) => c['functionName']),
        ['createRazorpayOrder', 'verifyWalletTopup']);
    expect(calls.last['parameters']['amount'], 100);
    expect(calls.last['parameters']['checkoutOwnerId'], uid);
    expect(flow.pending!.stage, 'completed');
    expect(errors, isEmpty);
  });
  test(
      'lost SDK callback resumes captured original payment without new SDK order',
      () async {
    await saved();
    await flow.restore();
    await flow.resume();
    await settle(done);
    expect(opens, isEmpty);
    expect(calls.any((c) => c['functionName'] == 'createRazorpayOrder'), false);
    expect(calls.last['parameters']['proofSource'], 'provider_api_recovery');
  });
  test('unconfirmed provider outcome reopens only saved SDK order', () async {
    await saved();
    transport = (call) async => [
          call['functionName'] == 'recoverWalletTopupPayment'
              ? {
                  'success': true,
                  'verified': false,
                  'outcome': 'unconfirmed',
                  'keyId': gateway['keyId'],
                  'orderId': 'order_wallet_fixture',
                  'amountPaise': 10000,
                  'currency': 'INR'
                }
              : receipt
        ];
    await flow.resume();
    await settle(done);
    expect(opens.single['order_id'], 'order_wallet_fixture');
    expect(calls.any((c) => c['functionName'] == 'createRazorpayOrder'), false);
  });
  test('lost credit reply restart reuses identical proof and amount', () async {
    await saved(stage: 'ready');
    transport = (_) async => ['unavailable', 'fixture', null];
    await flow.resume();
    expect(flow.pending!.stage, 'ready');
    final original = Map.of(calls.single['parameters'] as Map);
    flow.dispose();
    flow = makeFlow();
    transport = (_) async => [receipt];
    await flow.restore();
    await flow.resume();
    await settle(done);
    expect(calls.last['parameters'], original);
    expect(opens, isEmpty);
  });
  test('completed restart performs no credit RPC', () async {
    await saved(stage: 'completed');
    await flow.restore();
    await flow.resume();
    await settle(done);
    expect(calls, isEmpty);
    expect(opens, isEmpty);
  });
  test(
      'failed wallet refresh retains completed receipt and retries only handoff',
      () async {
    await saved(stage: 'ready');
    var attempts = 0;
    flow.dispose();
    flow = makeFlow(handoff: (p, r) async {
      attempts++;
      if (attempts == 1) throw StateError('server read fixture');
      done.complete();
    });
    await flow.resume();
    expect(flow.pending!.stage, 'completed');
    await flow.resume();
    await settle(done);
    expect(attempts, 2);
    expect(calls.length, 1);
  });
  test('provider outage keeps attempted payment and safe feedback', () async {
    await saved();
    transport = (_) async => ['unavailable', 'fixture', null];
    await flow.resume();
    expect(flow.pending!.stage, 'awaiting_payment');
    expect(opens, isEmpty);
    expect(errors.single, contains('saved top-up'));
  });
  test('draft requires explicit review; attempted payment cannot be discarded',
      () async {
    await saved(stage: 'draft');
    await flow.resume();
    expect(calls, isEmpty);
    await flow.discardDraft();
    expect(await journal.pending(), isNull);
    await saved();
    await flow.restore();
    await flow.discardDraft();
    expect((await journal.pending())!.stage, 'awaiting_payment');
  });
  test(
      'account switch during gateway creation prevents SDK and hides old pending',
      () async {
    transport = (call) async {
      uid = 'other_owner';
      return [gateway];
    };
    await flow.start(amount: 100);
    expect(opens, isEmpty);
    expect(flow.pending, isNull);
    uid = 'fixture_owner';
    expect((await journal.pending())!.stage, 'draft');
  });
  test('account switch immediately after persisted gateway prevents SDK',
      () async {
    flow.dispose();
    var switched = false;
    flow = makeFlow(changed: () {
      if (!switched && flow.pending?.stage == 'awaiting_payment') {
        switched = true;
        uid = 'other_owner';
      }
    });
    await flow.start(amount: 100);
    expect(opens, isEmpty);
    uid = 'fixture_owner';
    expect((await journal.pending())!.stage, 'awaiting_payment');
  });
  test('disposal during gateway creation prevents SDK and UI callbacks',
      () async {
    transport = (call) async {
      flow.dispose();
      return [gateway];
    };
    await flow.start(amount: 100);
    expect(opens, isEmpty);
    expect(errors, isEmpty);
    expect(done.isCompleted, false);
  });
  test('account switch during credit response retains ready proof without UI',
      () async {
    await saved(stage: 'ready');
    transport = (call) async {
      uid = 'other_owner';
      return [receipt];
    };
    await flow.resume();
    expect(done.isCompleted, false);
    expect(flow.pending, isNull);
    uid = 'fixture_owner';
    expect((await journal.pending())!.stage, 'ready');
  });
  for (final walletFirst in [true, false]) {
    test(
        '${walletFirst ? 'wallet' : 'goods'} foreground blocks competing purpose before second provider order',
        () async {
      final held = Completer<Map<String, dynamic>>();
      sdkReply = (_) async => held.future;
      final g = goods();
      if (walletFirst) {
        await flow.start(amount: 100);
        await startGoods(g);
      } else {
        await startGoods(g);
        await flow.start(amount: 100);
      }
      expect(
          calls.where((c) => c['functionName'] == 'createRazorpayOrder').length,
          1);
      expect(opens.length, 1);
      flow.dispose();
      g.dispose();
      held.complete({
        'type': 1,
        'data': {'code': 2, 'message': 'fixture cancelled'}
      });
      await Future<void>.delayed(Duration.zero);
    });
  }
  test('duplicate starts keep one foreground SDK flight', () async {
    final held = Completer<Map<String, dynamic>>();
    sdkReply = (_) async => held.future;
    await Future.wait([flow.start(amount: 100), flow.start(amount: 200)]);
    expect(opens.length, 1);
    expect(flow.pending!.amount, 100);
    flow.dispose();
    held.complete({
      'type': 1,
      'data': {'code': 2, 'message': 'fixture'}
    });
    await Future<void>.delayed(Duration.zero);
  });
  test(
      'disposed flow releases foreground gate without erasing original journal',
      () async {
    final held = Completer<Map<String, dynamic>>();
    sdkReply = (_) async => held.future;
    await flow.start(amount: 100);
    flow.dispose();
    final g = goods();
    await startGoods(g);
    expect(opens.length, 2);
    expect((await journal.pending())!.stage, 'awaiting_payment');
    g.dispose();
    held.complete({
      'type': 1,
      'data': {'code': 2, 'message': 'fixture'}
    });
    await Future<void>.delayed(Duration.zero);
  });
  test('acknowledge removes only completed saved receipt', () async {
    await saved(stage: 'completed');
    await flow.restore();
    await flow.acknowledge(flow.pending!);
    expect(await store.read('fixture_owner'), isNull);
    expect(flow.pending, isNull);
  });
  test('cancelled SDK retains original order for recovery', () async {
    sdkReply = (_) async => {
          'type': 1,
          'data': {'code': 2, 'message': 'fixture cancelled'}
        };
    await flow.start(amount: 100);
    await settle(failed);
    expect(flow.pending!.stage, 'awaiting_payment');
    expect(calls.length, 1);
    expect(errors.single, contains('saved top-up'));
  });
  test('corrupt journal refuses new provider order', () async {
    await store.write(
        'fixture_owner', jsonEncode({'version': 1, 'stage': 'ready'}));
    await flow.restore();
    await flow.start(amount: 100);
    expect(calls, isEmpty);
    expect(opens, isEmpty);
    expect(errors, isNotEmpty);
  });
}
