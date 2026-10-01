import 'dart:async';
import 'dart:convert';

import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_marketplace/services/checkout_request_store.dart';
import 'package:agrimore_marketplace/services/checkout_recovery_service.dart';
import 'package:agrimore_marketplace/services/mobile_checkout_confirmation.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryStore implements CheckoutRequestStore {
  String? value;
  @override
  Future<String?> read(String ownerId) async => value;
  @override
  Future<void> write(String ownerId, String data) async {
    value = data;
  }

  @override
  Future<void> remove(String ownerId) async {
    value = null;
  }
}

void main() {
  late PendingCheckoutRequest request;
  late List<CheckoutReceipt> receipts;
  late String? owner;
  late bool mounted;
  late List<CartItemModel> items;
  late List<String> effects;
  late Future<Map<String, dynamic>?> Function(String) read;
  late Future<bool> Function() clear;
  late Map<String, dynamic> order;
  Future<void> finish() => finishMobileCheckout(
        request: request,
        receipts: receipts,
        isMounted: () => mounted,
        currentUserId: () => owner,
        readOrder: (id) => read(id),
        currentItems: () => items,
        currentMode: () => 'B2C',
        clearCart: () => clear(),
        clearCoupon: () => effects.add('coupon'),
        clearSubscriptionHint: () => effects.add('hint'),
        acknowledge: (_) async {
          effects.add('ack');
        },
        showOrder: (value) {
          effects.add('show:${value.id}');
        },
      );
  CartItemModel item(String product, {String uid = 'fixture_owner'}) =>
      CartItemModel(
          id: 'line',
          productId: product,
          productName: 'Fixture',
          productImage: '',
          price: 10,
          quantity: 1,
          userId: uid,
          sellerId: 'fixture_seller',
          addedAt: DateTime(2026));
  setUp(() async {
    owner = 'fixture_owner';
    mounted = true;
    effects = [];
    items = [item('fixture_product')];
    final store = MemoryStore();
    final journal =
        CheckoutRecoveryService(store: store, currentUserId: () => owner);
    final draft = await journal.prepare({
      'items': [
        {'productId': 'fixture_product', 'quantity': 1}
      ],
      'paymentMethod': 'cod',
      'orderMode': 'B2C',
      'deliveryAddress': {'name': 'Fixture'}
    });
    final rows = [
      {
        'orderId': 'fixture_order',
        'orderNumber': 'ORD-FIXTURE',
        'sellerId': 'fixture_seller',
        'total': 10.0
      }
    ];
    store.value =
        jsonEncode({...draft.toMap(), 'stage': 'completed', 'orders': rows});
    request = (await journal.pending())!;
    receipts = request.receipts;
    order = {
      'id': 'fixture_order',
      'orderNumber': 'ORD-FIXTURE',
      'userId': owner,
      'sellerId': 'fixture_seller',
      'total': 10.0,
      'items': <Map<String, dynamic>>[]
    };
    read = (id) async {
      effects.add('read:$id');
      return order;
    };
    clear = () async {
      effects.add('cart');
      return true;
    };
  });
  test('original receipt fetched before cart, acknowledgment and route',
      () async {
    await finish();
    expect(effects, [
      'read:fixture_order',
      'cart',
      'coupon',
      'hint',
      'ack',
      'show:fixture_order'
    ]);
  });
  test('cart changed while payment was open stays intact', () async {
    items = [item('different_product')];
    await finish();
    expect(effects, ['read:fixture_order', 'ack', 'show:fixture_order']);
  });
  test('empty cart still opens saved server order', () async {
    items = [];
    await finish();
    expect(effects, ['read:fixture_order', 'ack', 'show:fixture_order']);
  });
  test('stale other-account cart is never cleared', () async {
    items = [item('fixture_product', uid: 'different_owner')];
    await finish();
    expect(effects, ['read:fixture_order', 'ack', 'show:fixture_order']);
  });
  for (final field in ['userId', 'id', 'orderNumber', 'sellerId', 'total']) {
    test('mismatched server $field preserves journal/cart', () async {
      order[field] = field == 'total' ? 20.0 : 'different';
      await expectLater(finish(), throwsStateError);
      expect(effects, ['read:fixture_order']);
    });
  }
  test('missing original order cannot use current cart fallback', () async {
    read = (_) async => null;
    await expectLater(finish(), throwsStateError);
    expect(effects, isEmpty);
  });
  for (final close in [false, true]) {
    test('session closes during order fetch: mounted=$close', () async {
      final result = Completer<Map<String, dynamic>?>();
      read = (_) => result.future;
      final operation = finish();
      if (close) {
        mounted = false;
      } else {
        owner = 'another_owner';
      }
      result.complete(order);
      await expectLater(operation, throwsStateError);
      expect(effects, isEmpty);
    });
    test('session closes during cart clear: mounted=$close', () async {
      final result = Completer<bool>();
      final started = Completer<void>();
      clear = () {
        started.complete();
        return result.future;
      };
      final operation = finish();
      await started.future;
      if (close) {
        mounted = false;
      } else {
        owner = 'another_owner';
      }
      result.complete(true);
      await expectLater(operation, throwsStateError);
      expect(effects, ['read:fixture_order']);
    });
  }
  test('failed cart update leaves receipt unacknowledged for retry', () async {
    clear = () async => false;
    await expectLater(finish(), throwsStateError);
    expect(effects, ['read:fixture_order']);
  });
  test('already disposed refuses server read', () async {
    mounted = false;
    await expectLater(finish(), throwsStateError);
    expect(effects, isEmpty);
  });
}
