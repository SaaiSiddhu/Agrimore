@TestOn('browser')
library;

import 'dart:convert';
import 'dart:async';
import 'dart:js_interop';

import 'package:agrimore_marketplace/services/razorpay_web.dart';
import 'package:agrimore_marketplace/services/payment_checkout_order.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

@JS('eval')
external JSAny? _eval(String code);

class _FixtureFunctions extends Fake implements FirebaseFunctions {
  final callable = _FixtureCallable();

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    expect(name, 'createRazorpayOrder');
    return callable;
  }
}

class _FixtureCallable extends Fake implements HttpsCallable {
  Map<String, dynamic> response = {
    'success': true,
    'orderId': 'order_foundation_web',
    'keyId': 'rzp_test_foundation_fixture',
    'amount': 59999,
    'currency': 'INR',
  };
  Map<String, dynamic>? parameters;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    this.parameters = Map<String, dynamic>.from(parameters as Map);
    return _FixtureResult<T>(response as T);
  }
}

class _FixtureResult<T> extends Fake implements HttpsCallableResult<T> {
  _FixtureResult(this.data);
  @override
  final T data;
}

void main() {
  late RazorpayWebService service;
  late List<String> failures;
  late List<List<String?>> successes;
  late _FixtureFunctions functions;

  setUp(() {
    failures = [];
    successes = [];
    _eval('''
      window._fixtureOptions = null;
      window._fixtureOpened = false;
      window._fixtureInjected = false;
      window.Razorpay = function(options) {
        window._fixtureOptions = options;
        this.on = function(event, callback) { window._fixtureFailure = callback; };
        this.open = function() { window._fixtureOpened = true; };
      };
    ''');
    functions = _FixtureFunctions();
    service = RazorpayWebService(functions: functions);
    service.initialize(
      onSuccess: (payment, order, signature) =>
          successes.add([payment, order, signature]),
      onFailure: failures.add,
    );
  });
  tearDown(() {
    service.dispose();
    _eval(
        'delete window.Razorpay; delete window._fixtureOptions; delete window._fixtureFailure;');
  });
  Future<void> checkout(
          {String? description,
          String orderId = 'order_foundation_web',
          String userName = 'Fixture Customer'}) =>
      service.openCheckoutForExistingOrder(
        keyId: 'rzp_test_foundation_fixture',
        orderId: orderId,
        amountPaise: 59999,
        userName: userName,
        userEmail: 'fixture@example.invalid',
        userPhone: '',
        description: description,
      );
  Map<String, dynamic> options() => jsonDecode(
          (_eval('JSON.stringify(window._fixtureOptions)') as JSString).toDart)
      as Map<String, dynamic>;

  test('browser SDK receives exact server minor units', () async {
    await checkout();
    expect(options()['amount'], 59999);
    expect(options()['order_id'], 'order_foundation_web');
    expect(failures, isEmpty);
  });
  test('browser SDK waits for validated order persistence hook', () async {
    final entered = Completer<void>(), release = Completer<void>();
    final pending = service.openCheckout(
      amount: 599.99,
      userName: '',
      userEmail: '',
      userPhone: '',
      onOrderCreated: (order) async {
        expect(order.orderId, 'order_foundation_web');
        expect(order.amountPaise, 59999);
        entered.complete();
        await release.future;
      },
    );
    await entered.future;
    expect((_eval('window._fixtureOpened') as JSBoolean).toDart, false);
    release.complete();
    await pending;
    expect(options()['amount'], 59999);
    expect(failures, isEmpty);
  });
  test('browser persistence failure cannot open SDK', () async {
    await service.openCheckout(
      amount: 599.99,
      userName: '',
      userEmail: '',
      userPhone: '',
      onOrderCreated: (_) async {
        throw StateError('Synthetic persistence failure');
      },
    );
    expect((_eval('window._fixtureOpened') as JSBoolean).toDart, false);
    expect(successes, isEmpty);
    expect(failures, hasLength(1));
  });
  test('browser disposal during persistence suppresses late modal', () async {
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
    expect((_eval('window._fixtureOpened') as JSBoolean).toDart, false);
    expect(failures, isEmpty);
  });
  test('quotes and newlines remain text in SDK options', () async {
    const description = "Order\n'); window._fixtureInjected = true; //\\\"";
    await checkout(description: description, userName: 'Fixture\nCustomer');
    expect(options()['description'], description);
    expect((options()['prefill'] as Map)['name'], 'Fixture\nCustomer');
    expect((_eval('window._fixtureInjected') as JSBoolean).toDart, isFalse);
    expect(failures, isEmpty);
  });
  for (final purpose in [
    CheckoutPaymentPurpose.goods,
    CheckoutPaymentPurpose.walletTopup
  ]) {
    test(
        'generic browser ${purpose.value} forwards intent and exact server paise',
        () async {
      functions.callable.response['amount'] = 29;
      await service.openCheckout(
        amount: 0.29,
        purpose: purpose,
        userName: '',
        userEmail: '',
        userPhone: '',
      );
      expect(functions.callable.parameters!['purpose'], purpose.value);
      expect(options()['amount'], 29);
      expect(failures, isEmpty);
    });
  }
  test('generic browser rejects malformed server amount before SDK opens',
      () async {
    functions.callable.response['amount'] = 59999.5;
    await service.openCheckout(
        amount: 599.99, userName: '', userEmail: '', userPhone: '');
    expect((_eval('window._fixtureOpened') as JSBoolean).toDart, isFalse);
    expect(failures, hasLength(1));
  });
  test('browser success callback retains payment, order and signature',
      () async {
    await checkout();
    _eval(
        "window._fixtureOptions.handler({razorpay_payment_id:'pay_fixture',razorpay_order_id:'order_foundation_web',razorpay_signature:'fixture_signature'});");
    expect(successes, [
      ['pay_fixture', 'order_foundation_web', 'fixture_signature']
    ]);
  });
  test('browser dismissal callback reaches caller', () async {
    await checkout();
    _eval('window._fixtureOptions.modal.ondismiss();');
    expect(failures, ['Payment cancelled by user']);
  });
  test('provider failure callback reaches caller', () async {
    await checkout();
    _eval("window._fixtureFailure({error:{description:'Fixture declined'}});");
    expect(failures, ['Fixture declined']);
  });
  test('malformed server order cannot open browser SDK', () async {
    await checkout(orderId: 'bad/path');
    expect((_eval('window._fixtureOpened') as JSBoolean).toDart, isFalse);
    expect(failures, hasLength(1));
  });
}
