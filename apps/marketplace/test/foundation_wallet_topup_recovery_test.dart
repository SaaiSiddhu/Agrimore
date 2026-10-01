@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'package:agrimore_marketplace/services/checkout_request_store.dart';
import 'package:agrimore_marketplace/services/checkout_request_store_file.dart';
import 'package:agrimore_marketplace/services/payment_checkout_order.dart';
import 'package:agrimore_marketplace/services/razorpay_service.dart';
import 'package:agrimore_marketplace/services/wallet_topup_recovery_service.dart';
import 'package:firebase_core/firebase_core.dart';
// Official Firebase test harness already cached in this app.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingStore implements CheckoutRequestStore {
  _FailingStore(this.delegate);
  final CheckoutRequestStore delegate;
  bool fail = true;
  @override
  Future<String?> read(String owner) => delegate.read(owner);
  @override
  Future<void> write(String owner, String value) async {
    if (fail) throw const FileSystemException('fixture persistence failure');
    await delegate.write(owner, value);
  }

  @override
  Future<void> remove(String owner) => delegate.remove(owner);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  const channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call',
      StandardMessageCodec());
  const sdk = MethodChannel('razorpay_flutter');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory directory;
  late String? uid;
  late CheckoutRequestStore store;
  late WalletTopupRecoveryService journal;
  late List<Map> calls, opens;
  late Map<String, dynamic> recovery, confirmation;
  late Future<List<Object?>> Function(Map) transport;
  final gateway = {
    'success': true,
    'orderId': 'order_wallet_fixture',
    'keyId': 'rzp_test_wallet_fixture',
    'amount': 10000,
    'currency': 'INR'
  };
  WalletTopupRecoveryService restart() =>
      WalletTopupRecoveryService(store: store, currentUserId: () => uid);
  Future<PendingWalletTopup> awaiting() async {
    final draft = await journal.prepare(100);
    return journal.attachGateway(draft.ownerId, draft.requestId,
        PaymentCheckoutOrder.fromResponse(gateway));
  }

  Future<PendingWalletTopup> ready() async {
    final saved = await awaiting();
    return journal.recordPayment(saved.ownerId, saved.requestId,
        paymentId: 'pay_wallet_fixture',
        orderId: 'order_wallet_fixture',
        signature: 'fixture_signature');
  }

  setUpAll(() async {
    await Firebase.initializeApp();
  });
  setUp(() async {
    directory =
        await Directory.systemTemp.createTemp('agrimore-wallet-journal-');
    uid = 'fixture_owner';
    store = FileCheckoutRequestStore(
        directory: () async => directory, walletTopups: true);
    journal = restart();
    calls = [];
    opens = [];
    recovery = {
      'success': true,
      'verified': true,
      'outcome': 'captured',
      'orderId': 'order_wallet_fixture',
      'paymentId': 'pay_wallet_fixture',
      'amountPaise': 10000,
      'currency': 'INR'
    };
    confirmation = {
      'success': true,
      'amount': 100.0,
      'alreadyCredited': false,
      'bonusCoins': 5,
      'balanceAfter': 100.0,
      'coinsAfter': 5,
      'private_metadata': 'omit'
    };
    transport = (call) async => [
          call['functionName'] == 'recoverWalletTopupPayment'
              ? recovery
              : confirmation
        ];
    messenger.setMockDecodedMessageHandler<Object?>(channel, (message) async {
      final call = (message as List).single as Map;
      calls.add(call);
      return transport(call);
    });
    messenger.setMockMethodCallHandler(sdk, (call) async {
      if (call.method == 'resync') return null;
      expect(call.method, 'open');
      opens.add(call.arguments as Map);
      return {
        'type': 1,
        'data': {'code': 2, 'message': 'fixture'}
      };
    });
  });
  tearDown(() async {
    messenger.setMockDecodedMessageHandler<Object?>(channel, null);
    messenger.setMockMethodCallHandler(sdk, null);
    await directory.delete(recursive: true);
  });
  test('frozen owner/paise/request survive a real file restart', () async {
    final saved = await journal.prepare(100.29);
    final resumed = (await restart().pending())!;
    expect(resumed.requestId, saved.requestId);
    expect(resumed.amountPaise, 10029);
    final copy = saved.toMap();
    copy['amountPaise'] = 9999;
    expect(saved.amountPaise, 10029);
    expect(
        await Directory('${directory.path}/wallet_topups_v1').exists(), true);
  });
  test('wallet and goods file namespaces never overwrite each other', () async {
    await journal.prepare(100);
    final goods = FileCheckoutRequestStore(directory: () async => directory);
    await goods.write(uid!, 'goods fixture');
    expect((await journal.pending())!.amount, 100);
    await store.remove(uid!);
    expect(await goods.read(uid!), 'goods fixture');
  });
  test('another amount cannot replace an uncertain attempt', () async {
    final saved = await awaiting();
    await expectLater(journal.prepare(200), throwsStateError);
    expect((await journal.pending())!.requestId, saved.requestId);
    expect(calls, isEmpty);
  });
  test('tuple and proof are durable before any credit call', () async {
    final saved = await ready();
    final resumed = (await restart().pending())!;
    expect(resumed.stage, 'ready');
    expect(resumed.proof!['signature'], 'fixture_signature');
    expect(saved.gateway!['amount'], 10000);
    expect(calls, isEmpty);
  });
  test('confirmed receipt survives restart and has no second credit RPC',
      () async {
    final saved = await ready();
    final receipt = await journal.confirm(saved.ownerId, saved.requestId);
    expect(receipt.containsKey('private_metadata'), false);
    expect(calls.single['functionName'], 'verifyWalletTopup');
    expect((calls.single['parameters'] as Map)['amount'], 100.0);
    expect(
        (calls.single['parameters'] as Map)['checkoutOwnerId'], saved.ownerId);
    final after = await restart().confirm(saved.ownerId, saved.requestId);
    expect(after, receipt);
    expect(calls.length, 1);
  });
  test('lost credit reply retains proof and retries exact original payment',
      () async {
    final saved = await ready();
    var count = 0;
    transport = (_) async {
      if (++count == 1) return ['unavailable', 'fixture', null];
      return [confirmation];
    };
    await expectLater(
        journal.confirm(saved.ownerId, saved.requestId), throwsA(anything));
    expect((await restart().pending())!.stage, 'ready');
    await restart().confirm(saved.ownerId, saved.requestId);
    expect(calls[0]['parameters'], calls[1]['parameters']);
  });
  test(
      'callback-independent capture persists API proof and sends no SDK signature',
      () async {
    final saved = await awaiting();
    await journal.recoverPayment(saved.ownerId, saved.requestId);
    final pending = (await restart().pending())!;
    expect(pending.proof!['source'], 'provider_api_recovery');
    await restart().confirm(saved.ownerId, saved.requestId);
    expect(calls.map((c) => c['functionName']).toList(), [
      'recoverWalletTopupPayment',
      'recoverWalletTopupPayment',
      'verifyWalletTopup'
    ]);
    final data = calls.last['parameters'] as Map;
    expect(data['proofSource'], 'provider_api_recovery');
    expect(data.containsKey('signature'), false);
  });
  test('late SDK callback preserves trusted API proof', () async {
    final saved = await awaiting();
    await journal.recoverPayment(saved.ownerId, saved.requestId);
    final pending = await journal.recordPayment(saved.ownerId, saved.requestId,
        paymentId: 'pay_wallet_fixture',
        orderId: 'order_wallet_fixture',
        signature: 'fixture_signature');
    expect(pending.proof!['source'], 'provider_api_recovery');
    expect(pending.proof!.containsKey('signature'), false);
  });
  test(
      'fresh API lookup preserves already saved SDK proof for the same capture',
      () async {
    final saved = await ready();
    final after = await journal.recoverPayment(saved.ownerId, saved.requestId);
    expect(after.proof, saved.proof);
  });
  test('same-owner concurrent confirmations serialize to one credit RPC',
      () async {
    final saved = await ready();
    await Future.wait([
      journal.confirm(saved.ownerId, saved.requestId),
      restart().confirm(saved.ownerId, saved.requestId)
    ]);
    expect(calls.length, 1);
  });
  test('incomplete or attempted topup cannot be acknowledged or discarded',
      () async {
    final saved = await awaiting();
    await expectLater(
        journal.acknowledge(saved.ownerId, saved.requestId), throwsStateError);
    await expectLater(
        journal.discardDraft(saved.ownerId, saved.requestId), throwsStateError);
    expect((await journal.pending())!.stage, 'awaiting_payment');
  });
  test(
      'explicit draft discard and completed acknowledgment alone remove records',
      () async {
    final draft = await journal.prepare(100);
    await journal.discardDraft(draft.ownerId, draft.requestId);
    expect(await journal.pending(), isNull);
    final saved = await ready();
    await journal.confirm(saved.ownerId, saved.requestId);
    await journal.acknowledge(saved.ownerId, saved.requestId);
    expect(await journal.pending(), isNull);
  });
  test('gateway amount cannot drift from frozen topup', () async {
    final saved = await journal.prepare(100);
    await expectLater(
        journal.attachGateway(saved.ownerId, saved.requestId,
            PaymentCheckoutOrder.fromResponse({...gateway, 'amount': 20000})),
        throwsStateError);
    expect((await journal.pending())!.stage, 'draft');
  });
  test('another provider order cannot replace saved gateway', () async {
    final saved = await awaiting();
    await expectLater(
        journal.attachGateway(
            saved.ownerId,
            saved.requestId,
            PaymentCheckoutOrder.fromResponse(
                {...gateway, 'orderId': 'order_another'})),
        throwsStateError);
  });
  test('mismatched SDK proof cannot replace the original tuple', () async {
    final saved = await awaiting();
    await expectLater(
        journal.recordPayment(saved.ownerId, saved.requestId,
            paymentId: 'pay_wrong',
            orderId: 'order_wrong',
            signature: 'fixture'),
        throwsStateError);
    expect((await journal.pending())!.stage, 'awaiting_payment');
  });
  for (final amount in [
    double.nan,
    double.infinity,
    99.0,
    100.001,
    9007199254740992.0
  ]) {
    test('invalid or unsafe amount $amount never persists or calls backend',
        () async {
      expect(() => journal.prepare(amount), throwsFormatException);
      expect(await journal.pending(), isNull);
      expect(calls, isEmpty);
    });
  }
  for (final entry in <String, Object?>{
    'verified': false,
    'amountPaise': 9999,
    'currency': 'USD',
    'orderId': 'order_wrong',
    'paymentId': 'pay_test_simulated'
  }.entries) {
    test('provider recovery refuses ${entry.key} mismatch', () async {
      final saved = await awaiting();
      recovery[entry.key] = entry.value;
      await expectLater(journal.recoverPayment(saved.ownerId, saved.requestId),
          throwsStateError);
      expect((await journal.pending())!.stage, 'awaiting_payment');
    });
  }
  for (final entry in <String, Object?>{
    'success': false,
    'amount': 200.0,
    'alreadyCredited': 'false',
    'bonusCoins': 0.5,
    'coinsAfter': double.infinity,
    'balanceAfter': double.nan
  }.entries) {
    test('invalid server confirmation ${entry.key} retains durable proof',
        () async {
      final saved = await ready();
      confirmation[entry.key] = entry.value;
      await expectLater(
          journal.confirm(saved.ownerId, saved.requestId), throwsA(anything));
      expect((await journal.pending())!.stage, 'ready');
    });
  }
  test('account switch during credit reply prevents old success', () async {
    final saved = await ready();
    transport = (_) async {
      uid = 'new_owner';
      return [confirmation];
    };
    await expectLater(
        journal.confirm(saved.ownerId, saved.requestId), throwsStateError);
    expect(await journal.pending(), isNull);
    uid = saved.ownerId;
    expect((await journal.pending())!.stage, 'ready');
  });
  test('old owner command cannot cross a new session', () async {
    final saved = await ready();
    uid = 'new_owner';
    await expectLater(
        journal.confirm(saved.ownerId, saved.requestId), throwsStateError);
    expect(calls, isEmpty);
  });
  for (final entry in <String, Object?>{
    'ownerId': 'another_owner',
    'amountPaise': 1,
    'requestId': 'bad',
    'stage': 'completed'
  }.entries) {
    test('corrupt journal ${entry.key} fails closed before new attempt',
        () async {
      final saved = await awaiting();
      await store.write(
          uid!, jsonEncode({...saved.toMap(), entry.key: entry.value}));
      await expectLater(journal.pending(), throwsFormatException);
      await expectLater(journal.prepare(100), throwsFormatException);
      expect(calls, isEmpty);
    });
  }
  test(
      'credit reply followed by disk failure preserves proof and retries original credit',
      () async {
    final saved = await ready();
    final broken = _FailingStore(store);
    final interrupted =
        WalletTopupRecoveryService(store: broken, currentUserId: () => uid);
    await expectLater(interrupted.confirm(saved.ownerId, saved.requestId),
        throwsA(isA<FileSystemException>()));
    expect((await journal.pending())!.stage, 'ready');
    broken.fail = false;
    confirmation['alreadyCredited'] = true;
    await interrupted.confirm(saved.ownerId, saved.requestId);
    expect(calls[0]['parameters'], calls[1]['parameters']);
    expect((await journal.pending())!.stage, 'completed');
  });
  test('failed gateway persistence prevents actual wallet SDK open', () async {
    final draft = await journal.prepare(100);
    final broken = _FailingStore(store);
    final interrupted =
        WalletTopupRecoveryService(store: broken, currentUserId: () => uid);
    transport = (_) async => [gateway];
    final failures = <String>[];
    final service = RazorpayService();
    service.initialize(onSuccess: (_, __, ___) {}, onFailure: failures.add);
    await service.openCheckout(
        amount: draft.amount,
        purpose: CheckoutPaymentPurpose.walletTopup,
        userName: '',
        userEmail: '',
        userPhone: '',
        onOrderCreated: (order) async {
          await interrupted.attachGateway(
              draft.ownerId, draft.requestId, order);
        });
    expect(opens, isEmpty);
    expect(failures.length, 1);
    expect((await journal.pending())!.stage, 'draft');
    service.dispose();
  });
  test('unconfirmed provider lookup retains original attempt without credit',
      () async {
    final saved = await awaiting();
    recovery['verified'] = false;
    recovery['outcome'] = 'unconfirmed';
    await expectLater(journal.recoverPayment(saved.ownerId, saved.requestId),
        throwsStateError);
    expect((await journal.pending())!.stage, 'awaiting_payment');
    expect(calls.single['functionName'], 'recoverWalletTopupPayment');
  });
  test('API capture identity change before credit keeps proof and refuses',
      () async {
    final saved = await awaiting();
    await journal.recoverPayment(saved.ownerId, saved.requestId);
    recovery['paymentId'] = 'pay_changed';
    await expectLater(
        journal.confirm(saved.ownerId, saved.requestId), throwsStateError);
    expect(
        calls.where((c) => c['functionName'] == 'verifyWalletTopup'), isEmpty);
    expect(
        (await journal.pending())!.proof!['paymentId'], 'pay_wallet_fixture');
  });
  test('provider unavailable before API credit never loses original proof',
      () async {
    final saved = await awaiting();
    await journal.recoverPayment(saved.ownerId, saved.requestId);
    transport = (_) async => ['unavailable', 'fixture', null];
    await expectLater(
        journal.confirm(saved.ownerId, saved.requestId), throwsA(anything));
    expect((await journal.pending())!.stage, 'ready');
  });
  test('wallet resume rejects account change after provider reply before SDK',
      () async {
    final service = RazorpayService();
    service.initialize(onSuccess: (_, __, ___) {}, onFailure: (_) {});
    recovery = {
      ...recovery,
      'verified': false,
      'outcome': 'unconfirmed',
      'keyId': gateway['keyId']
    };
    transport = (_) async {
      uid = 'new_owner';
      return [recovery];
    };
    await expectLater(
        service.resumeWalletTopup(
            order: PaymentCheckoutOrder.fromResponse(gateway),
            ownerId: 'fixture_owner',
            currentUserId: () => uid,
            userName: '',
            userEmail: '',
            userPhone: ''),
        throwsStateError);
    expect(opens, isEmpty);
    service.dispose();
  });
  for (final captured in [false, true]) {
    test('SDK wallet resume selects wallet endpoint; captured=$captured',
        () async {
      final service = RazorpayService();
      service.initialize(onSuccess: (_, __, ___) {}, onFailure: (_) {});
      if (!captured) {
        recovery = {
          ...recovery,
          'verified': false,
          'outcome': 'unconfirmed',
          'keyId': gateway['keyId']
        };
      }
      final result = await service.resumeWalletTopup(
          order: PaymentCheckoutOrder.fromResponse(gateway),
          ownerId: uid!,
          currentUserId: () => uid,
          userName: '',
          userEmail: '',
          userPhone: '');
      expect(
          result,
          captured
              ? GoodsCheckoutResumeOutcome.captured
              : GoodsCheckoutResumeOutcome.reopened);
      expect(calls.single['functionName'], 'recoverWalletTopupPayment');
      expect(opens.length, captured ? 0 : 1);
      if (!captured) expect(opens.single['order_id'], 'order_wallet_fixture');
      service.dispose();
    });
  }
}
