// Actual filesystem and Firebase callable transport; no real backend/provider.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agrimore_marketplace/services/checkout_recovery_service.dart';
import 'package:agrimore_marketplace/services/checkout_request_store.dart';
import 'package:agrimore_marketplace/services/checkout_request_store_file.dart';
import 'package:agrimore_marketplace/services/payment_checkout_order.dart';
import 'package:firebase_core/firebase_core.dart';
// Official Firebase test harness, already resolved through firebase_core.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class FaultStore implements CheckoutRequestStore {
  FaultStore(this.inner);
  final CheckoutRequestStore inner;
  bool failWrite = false;
  bool failRemove = false;
  void Function()? afterWrite;
  @override
  Future<String?> read(String ownerId) => inner.read(ownerId);
  @override
  Future<void> write(String ownerId, String value) async {
    if (failWrite) throw const FileSystemException('Synthetic write failure');
    await inner.write(ownerId, value);
    afterWrite?.call();
  }

  @override
  Future<void> remove(String ownerId) async {
    if (failRemove) throw const FileSystemException('Synthetic remove failure');
    await inner.remove(ownerId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  const channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call',
      StandardMessageCodec());
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory directory;
  late FaultStore store;
  late String? uid;
  late List<Map> calls;
  late Future<List<Object?>> Function(Map) handler;
  final gateway = PaymentCheckoutOrder.fromResponse({
    'success': true,
    'orderId': 'order_journal_fixture',
    'keyId': 'rzp_test_journal_fixture',
    'amount': 10000,
    'currency': 'INR',
  });
  final response = {
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
  Map<String, dynamic> intent({bool paid = false}) => {
        'items': [
          {'productId': 'fixture_product', 'quantity': 1}
        ],
        'orderMode': 'B2C',
        'paymentMethod': paid ? 'razorpay' : 'cod',
        'deliveryAddress': {'city': 'Fixture City'},
        'deliveryCharge': 0,
        'tax': 0,
      };
  CheckoutRecoveryService service() =>
      CheckoutRecoveryService(store: store, currentUserId: () => uid);
  Future<PendingCheckoutRequest> paidRequest() async {
    final s = service(), request = await s.prepare(intent(paid: true));
    await s.attachGateway(request.ownerId, request.requestId, gateway);
    return s.recordPayment(request.ownerId, request.requestId,
        paymentId: 'pay_journal_fixture',
        orderId: gateway.orderId,
        signature: 'fixture_signature');
  }

  setUpAll(() async => Firebase.initializeApp());
  setUp(() async {
    directory =
        await Directory.systemTemp.createTemp('agrimore-checkout-journal-');
    store =
        FaultStore(FileCheckoutRequestStore(directory: () async => directory));
    uid = 'fixture_owner';
    calls = [];
    handler = (call) async => [
          call['functionName'] == 'verifyRazorpayPayment'
              ? {'success': true, 'verified': true}
              : response
        ];
    messenger.setMockDecodedMessageHandler<Object?>(channel, (message) async {
      final call = (message! as List).single as Map;
      calls.add(call);
      return handler(call);
    });
  });
  tearDown(() async {
    messenger.setMockDecodedMessageHandler<Object?>(channel, null);
    await directory.delete(
        recursive: true); // Only this test's generated folder.
  });

  test('restart reads original request and caller cannot mutate its snapshot',
      () async {
    final payload = intent();
    final future = service().prepare(payload);
    (payload['items'] as List).first['quantity'] = 9;
    final first = await future;
    final copy = first.intent;
    (copy['items'] as List).first['quantity'] = 5;
    final restored = await service().pending();
    expect(restored!.requestId, first.requestId);
    expect((restored.intent['items'] as List).first['quantity'], 1);
    expect(first.requestId, matches(RegExp(r'^ck_[a-f0-9]{32}$')));
    expect(calls, isEmpty);
  });
  test('object key order does not replace the pending checkout', () async {
    final first = await service().prepare(intent());
    final reversed =
        Map<String, dynamic>.fromEntries(intent().entries.toList().reversed);
    expect((await service().prepare(reversed)).requestId, first.requestId);
  });
  test('changed intent refuses without overwriting saved details', () async {
    final first = await service().prepare(intent());
    await expectLater(service().prepare({...intent(), 'notes': 'different'}),
        throwsStateError);
    expect((await service().pending())!.toMap(), first.toMap());
  });
  test('concurrent service instances prepare one request', () async {
    final results = await Future.wait(
        [service().prepare(intent()), service().prepare(intent())]);
    expect(results[0].requestId, results[1].requestId);
  });
  test('failed initial persistence sends no financial RPC', () async {
    store.failWrite = true;
    await expectLater(
        service().prepare(intent()), throwsA(isA<FileSystemException>()));
    expect(calls, isEmpty);
  });
  test('unconfirmed payment cannot create an order', () async {
    final request = await service().prepare(intent(paid: true));
    await expectLater(service().confirm(request.ownerId, request.requestId),
        throwsStateError);
    expect(calls, isEmpty);
  });
  test('provider metadata and proof survive fresh service instances', () async {
    final request = await paidRequest(),
        restored = (await service().pending())!;
    expect(restored.requestId, request.requestId);
    expect(restored.stage, 'ready');
    expect(restored.gateway!['orderId'], gateway.orderId);
    expect(restored.payment!['paymentId'], 'pay_journal_fixture');
    expect(calls, isEmpty);
  });
  test('different callback provider order cannot replace saved attempt',
      () async {
    final request = await service().prepare(intent(paid: true));
    await service().attachGateway(request.ownerId, request.requestId, gateway);
    final before = (await service().pending())!.toMap();
    await expectLater(
        service().recordPayment(request.ownerId, request.requestId,
            paymentId: 'pay_other',
            orderId: 'order_other',
            signature: 'fixture'),
        throwsStateError);
    expect((await service().pending())!.toMap(), before);
  });
  test('verification refusal retains proof and never calls createOrder',
      () async {
    final request = await paidRequest();
    handler = (_) async => [
          {'success': true, 'verified': false}
        ];
    await expectLater(service().confirm(request.ownerId, request.requestId),
        throwsStateError);
    expect(calls.single['functionName'], 'verifyRazorpayPayment');
    expect((await service().pending())!.stage, 'ready');
  });
  test('lost order response retries exact request ID and frozen payload',
      () async {
    final request = await paidRequest();
    bool interrupted = false;
    handler = (call) async {
      if (call['functionName'] == 'createOrder' && !interrupted) {
        interrupted = true;
        return ['unavailable', 'Synthetic interruption', null];
      }
      return [
        call['functionName'] == 'verifyRazorpayPayment'
            ? {'verified': true}
            : response
      ];
    };
    await expectLater(service().confirm(request.ownerId, request.requestId),
        throwsA(isA<Exception>()));
    expect((await service().pending())!.stage, 'ready');
    final receipt = await service().confirm(request.ownerId, request.requestId);
    final orders =
        calls.where((c) => c['functionName'] == 'createOrder').toList();
    expect(orders, hasLength(2));
    expect(orders[0]['parameters'], orders[1]['parameters']);
    expect((orders.first['parameters'] as Map)['checkoutRequestId'],
        request.requestId);
    expect((orders.first['parameters'] as Map)['checkoutOwnerId'],
        request.ownerId);
    expect(receipt.single.total, 100);
  });
  test('ready state persists before COD confirmation is sent', () async {
    final request = await service().prepare(intent());
    // Read store directly: pending() would correctly wait on the active lock.
    handler = (_) async {
      expect(
          jsonDecode((await store.read(request.ownerId))!)['stage'], 'ready');
      return [response];
    };
    await service().confirm(request.ownerId, request.requestId);
    expect(calls.single['functionName'], 'createOrder');
  });
  test('concurrent confirmations share the completed receipt', () async {
    final request = await service().prepare(intent());
    final entered = Completer<void>(), release = Completer<void>();
    handler = (_) async {
      entered.complete();
      await release.future;
      return [response];
    };
    final first = service().confirm(request.ownerId, request.requestId);
    await entered.future;
    final second = service().confirm(request.ownerId, request.requestId);
    release.complete();
    final results = await Future.wait([first, second]);
    expect(results[0].single.orderId, results[1].single.orderId);
    expect(calls, hasLength(1));
  });
  test('completion persistence failure leaves same request available to retry',
      () async {
    final request = await service().prepare(intent());
    handler = (_) async {
      store.failWrite = true;
      return [response];
    };
    await expectLater(service().confirm(request.ownerId, request.requestId),
        throwsA(isA<FileSystemException>()));
    store.failWrite = false;
    handler = (_) async => [response];
    await service().confirm(request.ownerId, request.requestId);
    expect(calls, hasLength(2));
    expect(calls[0]['parameters'], calls[1]['parameters']);
  });
  test(
      'completed receipt survives restart and acknowledgment permits new request',
      () async {
    final request = await service().prepare(intent());
    await service().confirm(request.ownerId, request.requestId);
    final receipt = await service().confirm(request.ownerId, request.requestId);
    expect(receipt.single.orderId, 'fixture_order');
    expect(calls, hasLength(1));
    await service().acknowledge(request.ownerId, request.requestId);
    expect(await service().pending(), isNull);
    expect((await service().prepare(intent())).requestId,
        isNot(request.requestId));
  });
  test(
      'unconfirmed checkout cannot be acknowledged or discarded after gateway creation',
      () async {
    final request = await service().prepare(intent(paid: true));
    await expectLater(service().acknowledge(request.ownerId, request.requestId),
        throwsStateError);
    await service().attachGateway(request.ownerId, request.requestId, gateway);
    await expectLater(
        service().discardDraft(request.ownerId, request.requestId),
        throwsStateError);
    expect((await service().pending())!.stage, 'awaiting_payment');
  });
  test('draft without any provider attempt can be explicitly discarded',
      () async {
    final request = await service().prepare(intent());
    await service().discardDraft(request.ownerId, request.requestId);
    expect(await service().pending(), isNull);
  });
  test('account switch refuses old owner confirmation without RPC', () async {
    final request = await service().prepare(intent());
    uid = 'different_owner';
    await expectLater(service().confirm(request.ownerId, request.requestId),
        throwsStateError);
    expect(calls, isEmpty);
    expect(await service().pending(), isNull);
    uid = request.ownerId;
    expect((await service().pending())!.requestId, request.requestId);
  });
  test('account switch during payment verification prevents order RPC',
      () async {
    final request = await paidRequest();
    handler = (_) async {
      uid = 'different_owner';
      return [
        {'verified': true}
      ];
    };
    await expectLater(service().confirm(request.ownerId, request.requestId),
        throwsStateError);
    expect(calls, hasLength(1));
    expect(calls.single['functionName'], 'verifyRazorpayPayment');
    uid = request.ownerId;
    expect((await service().pending())!.stage, 'ready');
  });
  test(
      'account switch during order RPC never returns old receipt to new session',
      () async {
    final request = await service().prepare(intent());
    handler = (_) async {
      uid = 'different_owner';
      return [response];
    };
    await expectLater(service().confirm(request.ownerId, request.requestId),
        throwsStateError);
    uid = request.ownerId;
    expect((await service().pending())!.stage, 'ready');
  });
  for (final raw in [
    'not json',
    jsonEncode({'version': 99}),
    jsonEncode({'version': 1, 'ownerId': 'another'})
  ]) {
    test(
        'corrupt journal is preserved and cannot silently start a new checkout: $raw',
        () async {
      await store.write('fixture_owner', raw);
      await expectLater(
          service().prepare(intent()), throwsA(isA<FormatException>()));
      expect(await store.read('fixture_owner'), raw);
      expect(calls, isEmpty);
    });
  }
  for (final orders in [
    [],
    [
      {'orderId': 'bad/path', 'orderNumber': 'ORD', 'sellerId': 's', 'total': 1}
    ],
    [
      {'orderId': 'safe', 'orderNumber': 'ORD', 'sellerId': 's', 'total': -1}
    ]
  ]) {
    test('invalid server receipt never becomes a completed journal: $orders',
        () async {
      final request = await service().prepare(intent());
      handler = (_) async => [
            {'success': true, 'orders': orders}
          ];
      await expectLater(service().confirm(request.ownerId, request.requestId),
          throwsA(isA<FormatException>()));
      expect((await service().pending())!.stage, 'ready');
    });
  }
  test('owner filenames cannot escape the private journal directory', () async {
    await store.write('../owner/with/slashes', 'fixture');
    expect(await store.read('../owner/with/slashes'), 'fixture');
    expect(
        await Directory('${directory.path}/checkout_requests_v1').list().length,
        1);
  });
  test('oversized local record is refused before write', () async {
    await expectLater(
        store.write(
            'fixture_owner', 'x' * (FileCheckoutRequestStore.maxBytes + 1)),
        throwsA(isA<FormatException>()));
    expect(await store.read('fixture_owner'), isNull);
  });
  test(
      'interrupted initial staged write cannot silently create a fresh request',
      () async {
    final native = FileCheckoutRequestStore(directory: () async => directory);
    await native.write('fixture_owner', 'fixture');
    final file = (await Directory('${directory.path}/checkout_requests_v1')
            .list()
            .toList())
        .single as File;
    await file.rename('${file.path}.next');
    await expectLater(
        service().prepare(intent()), throwsA(isA<FormatException>()));
    expect(await File('${file.path}.next').readAsString(), 'fixture');
    expect(calls, isEmpty);
  });
  test(
      'failed removal keeps completed request available instead of starting another',
      () async {
    final request = await service().prepare(intent());
    await service().confirm(request.ownerId, request.requestId);
    store.failRemove = true;
    await expectLater(service().acknowledge(request.ownerId, request.requestId),
        throwsA(isA<FileSystemException>()));
    expect((await service().prepare(intent())).requestId, request.requestId);
    expect((await service().pending())!.stage, 'completed');
  });
  test(
      'session change during initial write never returns a prepared request to new account',
      () async {
    store.afterWrite = () => uid = 'different_owner';
    await expectLater(service().prepare(intent()), throwsStateError);
    store.afterWrite = null;
    expect(calls, isEmpty);
    expect(await service().pending(), isNull);
    uid = 'fixture_owner';
    expect((await service().pending())!.stage, 'draft');
  });
}
