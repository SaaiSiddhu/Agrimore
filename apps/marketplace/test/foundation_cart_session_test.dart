@TestOn('vm')
library;

import 'dart:async';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:agrimore_marketplace/providers/cart_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// Cached official local Firebase harness; no real network.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth implements AuthService {
  String? uid = 'owner_a';
  int cancels = 0;
  late final changes = StreamController<User?>.broadcast(onCancel: () {
    cancels++;
  });
  @override
  String? get currentUserId => uid;
  @override
  Stream<User?> get authStateChanges => changes.stream;
  void switchTo(String? owner) {
    uid = owner;
    changes.add(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Deliberately supports late callback delivery even after cancel. This proves
// generation checks independently of normal StreamController cancellation.
class _Subscription implements StreamSubscription<CartModel?> {
  _Subscription(this.data, this.error, this.done);
  void Function(CartModel?)? data;
  Function? error;
  void Function()? done;
  int cancelled = 0;
  @override
  void onData(void Function(CartModel?)? handleData) {
    data = handleData;
  }

  @override
  void onError(Function? handleError) {
    error = handleError;
  }

  @override
  void onDone(void Function()? handleDone) {
    done = handleDone;
  }

  @override
  Future<void> cancel() async {
    cancelled++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Stream extends Stream<CartModel?> {
  final subscriptions = <_Subscription>[];
  @override
  StreamSubscription<CartModel?> listen(void Function(CartModel?)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    final s = _Subscription(onData, onError, onDone);
    subscriptions.add(s);
    return s;
  }

  void emit(CartModel? value) {
    for (final s in List.of(subscriptions)) {
      s.data?.call(value);
    }
  }

  void fail() {
    for (final s in List.of(subscriptions)) {
      Function.apply(s.error!, [StateError('PRIVATE_CART_FIXTURE')]);
    }
  }
}

class _Database implements DatabaseService {
  final streams = <String, List<_Stream>>{};
  final writes = <({String owner, CartModel cart})>[];
  final clears = <String>[];
  Future<void> Function()? beforeWrite, beforeClear;
  bool writeFails = false, readThrows = false, clearFails = false;
  @override
  Stream<CartModel?> getUserCart(String owner) {
    if (readThrows) throw StateError('PRIVATE_CART_FIXTURE');
    final stream = _Stream();
    streams.putIfAbsent(owner, () => []).add(stream);
    return stream;
  }

  _Stream latest(String owner) => streams[owner]!.last;
  @override
  Future<void> updateCart(String owner, CartModel cart) async {
    writes.add((owner: owner, cart: cart));
    await beforeWrite?.call();
    if (writeFails) throw StateError('PRIVATE_CART_FIXTURE');
  }

  @override
  Future<void> clearCart(String owner) async {
    clears.add(owner);
    await beforeClear?.call();
    if (clearFails) throw StateError('PRIVATE_CART_FIXTURE');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  late _Auth auth;
  late _Database db;
  late CartProvider cart;
  CartItemModel item(String owner,
          {String id = 'product', int quantity = 1, String? variant}) =>
      CartItemModel(
          id: 'line',
          productId: id,
          productName: 'Fixture',
          productImage: '',
          price: 10,
          quantity: quantity,
          userId: owner,
          sellerId: 'seller_fixture',
          addedAt: DateTime(2026),
          variant: variant);
  CartModel value(String owner, {List<CartItemModel>? items}) => CartModel(
      id: owner,
      userId: owner,
      items: items ?? [item(owner)],
      updatedAt: DateTime(2026));
  Future<void> drain() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  void bind() {
    cart.loadCart();
    db.latest(auth.uid!).emit(value(auth.uid!));
  }

  setUpAll(() async {
    await Firebase.initializeApp();
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesService.init();
  });
  setUp(() {
    auth = _Auth();
    db = _Database();
    cart = CartProvider(databaseService: db, authService: auth);
  });
  tearDown(() async {
    cart.dispose();
    await auth.changes.close();
  });
  test('same user repeated load creates one cart and auth subscription',
      () async {
    bind();
    cart.loadCart();
    cart.loadCart();
    expect(db.streams['owner_a']!.length, 1);
    expect(cart.itemCount, 1);
    expect(auth.changes.hasListener, true);
  });
  test('current owner changes hide cart and checkout hints before auth event',
      () {
    bind();
    cart.setCheckoutSubscriptionIntent('Auto Delivery', 'weekly');
    auth.uid = 'owner_b';
    expect(cart.cart, isNull);
    expect(cart.items, isEmpty);
    expect(cart.subtotal, 0);
    expect(cart.itemCount, 0);
    expect(cart.checkoutOrderType, isNull);
    expect(cart.cartMode, isNull);
  });
  test('auth switch cancels old cart listener and binds new owned cart',
      () async {
    bind();
    final old = db.latest('owner_a');
    auth.switchTo('owner_b');
    await drain();
    expect(old.subscriptions.single.cancelled, 1);
    expect(cart.items, isEmpty);
    db
        .latest('owner_b')
        .emit(value('owner_b', items: [item('owner_b', id: 'new')]));
    expect(cart.items.single.productId, 'new');
    expect(cart.items.single.userId, 'owner_b');
  });
  test('late old snapshot and error cannot overwrite new session', () async {
    bind();
    final old = db.latest('owner_a');
    auth.switchTo('owner_b');
    await drain();
    db.latest('owner_b').emit(value('owner_b'));
    old.emit(value('owner_a'));
    old.fail();
    expect(cart.cart!.userId, 'owner_b');
    expect(cart.error, isNull);
    expect(db.latest('owner_b').subscriptions.single.cancelled, 0);
  });
  test('same owner reset fences late callbacks by generation', () {
    bind();
    final old = db.latest('owner_a');
    cart.reset();
    cart.loadCart();
    db
        .latest('owner_a')
        .emit(value('owner_a', items: [item('owner_a', id: 'fresh')]));
    old.emit(value('owner_a', items: [item('owner_a', id: 'stale')]));
    old.fail();
    expect(cart.items.single.productId, 'fresh');
    expect(cart.error, isNull);
    expect(old.subscriptions.single.cancelled, 1);
  });
  test('reset cancels subscription and clears cart intent', () {
    bind();
    cart.setCheckoutSubscriptionIntent('Auto Delivery', 'weekly');
    final old = db.latest('owner_a');
    cart.reset();
    expect(old.subscriptions.single.cancelled, 1);
    expect(cart.items, isEmpty);
    expect(cart.checkoutOrderType, isNull);
    expect(cart.isLoading, false);
  });
  test('dispose cancels both subscriptions and rejects late callbacks',
      () async {
    bind();
    final old = db.latest('owner_a');
    var notified = 0;
    cart.addListener(() => notified++);
    cart.dispose();
    old.emit(value('owner_a'));
    old.fail();
    await drain();
    expect(old.subscriptions.single.cancelled, 1);
    expect(auth.cancels, 1);
    expect(notified, 0);
    expect(cart.items, isEmpty);
    expect(await cart.clearCart(), false);
    expect(db.clears, isEmpty);
    cart = CartProvider(databaseService: db, authService: auth);
  });
  test('signout cancels account stream and isolates guest cart', () async {
    bind();
    final old = db.latest('owner_a');
    auth.switchTo(null);
    await drain();
    expect(old.subscriptions.single.cancelled, 1);
    expect(cart.cart!.userId, 'guest_user');
    expect(cart.items, isEmpty);
    old.emit(value('owner_a'));
    expect(cart.cart!.userId, 'guest_user');
  });
  test(
      'guest edits never write database; signed-in session cannot inherit guest items',
      () async {
    auth.uid = null;
    cart.loadCart();
    await cart.addOrderItems([item('owner_a')]);
    expect(db.writes, isEmpty);
    auth.switchTo('owner_b');
    await drain();
    db.latest('owner_b').emit(value('owner_b', items: []));
    expect(cart.items, isEmpty);
  });
  for (final mixed in [false, true]) {
    test('mismatched ${mixed ? 'item' : 'cart'} owner refused', () {
      bind();
      db.latest('owner_a').emit(mixed
          ? value('owner_a', items: [item('owner_b')])
          : value('owner_b'));
      expect(cart.items, isEmpty);
      expect(cart.cart, isNull);
      expect(cart.error, contains('needs attention'));
    });
  }
  test('valid own variant quantities and subtotal retained', () {
    cart.loadCart();
    db.latest('owner_a').emit(value('owner_a',
        items: [item('owner_a', quantity: 3, variant: 'large')]));
    expect(cart.subtotal, 30);
    expect(cart.itemCount, 3);
    expect(cart.getItemQuantity('product', variant: 'large'), 3);
  });
  test('first owned cart load preserves persisted B2B mode across restart',
      () async {
    await SharedPreferencesService.setString('cart_mode_state', 'B2B');
    bind();
    expect(cart.cartMode, 'B2B');
    auth.switchTo('owner_b');
    await drain();
    db.latest('owner_b').emit(value('owner_b'));
    expect(cart.cartMode, isNull);
  });
  test('listener failure is safe and retry cancels failed subscription', () {
    bind();
    final old = db.latest('owner_a');
    old.fail();
    expect(cart.error, contains('Please refresh'));
    expect(cart.error, isNot(contains('PRIVATE')));
    expect(old.subscriptions.single.cancelled, 1);
    cart.loadCart();
    db.latest('owner_a').emit(value('owner_a'));
    expect(cart.error, isNull);
  });
  test('reorder account switch during read prevents write and old UI',
      () async {
    bind();
    final pending = cart.addOrderItems([item('owner_a')]);
    final read = db.latest('owner_a');
    auth.switchTo('owner_b');
    await drain();
    read.emit(value('owner_a'));
    expect(await pending, false);
    expect(db.writes, isEmpty);
    expect(cart.items, isEmpty);
  });
  test('reorder reset during read cannot resurrect same-owner old cart',
      () async {
    bind();
    final pending = cart.addOrderItems([item('owner_a')]);
    final read = db.latest('owner_a');
    cart.reset();
    expect(cart.isLoading, false);
    read.emit(value('owner_a'));
    expect(await pending, false);
    expect(db.writes, isEmpty);
    expect(cart.items, isEmpty);
  });
  test('reorder read failure cannot replace unknown existing cart', () async {
    bind();
    db.readThrows = true;
    expect(await cart.addOrderItems([item('owner_a')]), false);
    expect(db.writes, isEmpty);
    expect(cart.error, isNot(contains('PRIVATE')));
  });
  test('reorder with wrong owner document refuses persistence', () async {
    bind();
    final pending = cart.addOrderItems([item('owner_a')]);
    db.latest('owner_a').emit(value('owner_b'));
    expect(await pending, false);
    expect(db.writes, isEmpty);
  });
  test('reorder old write reply cannot publish into new owner', () async {
    bind();
    final reply = Completer<void>();
    db.beforeWrite = () => reply.future;
    final pending = cart.addOrderItems([item('owner_a')]);
    db.latest('owner_a').emit(value('owner_a'));
    await drain();
    expect(db.writes.single.owner, 'owner_a');
    auth.switchTo('owner_b');
    await drain();
    db
        .latest('owner_b')
        .emit(value('owner_b', items: [item('owner_b', id: 'new')]));
    reply.complete();
    expect(await pending, false);
    expect(cart.items.single.productId, 'new');
  });
  test('reorder freezes incoming list before read await', () async {
    bind();
    final incoming = [item('owner_a', id: 'requested')];
    final pending = cart.addOrderItems(incoming);
    incoming.clear();
    db.latest('owner_a').emit(value('owner_a', items: []));
    expect(await pending, true);
    expect(db.writes.single.cart.items.single.productId, 'requested');
    expect(cart.items.single.userId, 'owner_a');
  });
  test('reorder disposed during awaited read never writes or notifies',
      () async {
    bind();
    final pending = cart.addOrderItems([item('owner_a')]);
    final read = db.latest('owner_a');
    cart.dispose();
    read.emit(value('owner_a'));
    expect(await pending, false);
    expect(db.writes, isEmpty);
    cart = CartProvider(databaseService: db, authService: auth);
  });
  test('background cart save failure caught with safe feedback', () async {
    bind();
    db.writeFails = true;
    await cart.removeItem('absent');
    await drain();
    expect(cart.error, contains('could not be saved'));
    expect(cart.error, isNot(contains('PRIVATE')));
  });
  test('late background write failure never changes new account error',
      () async {
    bind();
    final reply = Completer<void>();
    db.beforeWrite = () => reply.future;
    db.writeFails = true;
    await cart.removeItem('absent');
    auth.switchTo('owner_b');
    await drain();
    db.latest('owner_b').emit(value('owner_b'));
    reply.complete();
    await drain();
    expect(cart.error, isNull);
    expect(cart.cart!.userId, 'owner_b');
  });
  test(
      'clear waits for server and reports failure without discarding visible cart',
      () async {
    bind();
    final reply = Completer<void>();
    db.beforeClear = () => reply.future;
    db.clearFails = true;
    var finished = false;
    final pending = cart.clearCart().then((r) {
      finished = true;
      return r;
    });
    await drain();
    expect(finished, false);
    expect(cart.items.length, 1);
    reply.complete();
    expect(await pending, false);
    expect(cart.items.length, 1);
    expect(cart.error, contains('could not be cleared'));
  });
  test('clear reply after switch cannot erase new owner cart', () async {
    bind();
    final reply = Completer<void>();
    db.beforeClear = () => reply.future;
    final pending = cart.clearCart();
    auth.switchTo('owner_b');
    await drain();
    db.latest('owner_b').emit(value('owner_b'));
    reply.complete();
    expect(await pending, false);
    expect(db.clears, ['owner_a']);
    expect(cart.cart!.userId, 'owner_b');
  });
  test('valid owned clear acknowledged once', () async {
    bind();
    expect(await cart.clearCart(), true);
    expect(db.clears, ['owner_a']);
    expect(cart.items, isEmpty);
    expect(cart.error, isNull);
  });
  test('synchronous observer account switch prevents background persistence',
      () async {
    bind();
    cart.addListener(() {
      auth.uid = 'owner_b';
    });
    expect(await cart.removeItem('absent'), false);
    expect(db.writes, isEmpty);
    expect(cart.items, isEmpty);
  });
  test('owned variant edit retains other variant and writes captured owner',
      () async {
    cart.loadCart();
    db.latest('owner_a').emit(value('owner_a', items: [
          item('owner_a', quantity: 2),
          item('owner_a', quantity: 3, variant: 'large')
        ]));
    expect(await cart.updateQuantity('product', 4, variant: 'large'), true);
    await drain();
    expect(cart.getItemQuantity('product'), 2);
    expect(cart.getItemQuantity('product', variant: 'large'), 4);
    expect(db.writes.single.owner, 'owner_a');
    expect(cart.subtotal, 60);
  });
  test(
      'guest product addition remains local and B2B MOQ and price are preserved',
      () async {
    auth.uid = null;
    final product = ProductModel.fromMap({
      'name': 'Fixture',
      'salePrice': 10,
      'sellerId': 'seller_fixture',
      'isB2BEnabled': true,
      'b2bPrice': 7,
      'b2bMoq': 5
    }, 'bulk');
    expect(await cart.addItem(product, quantity: 1, isB2BMode: true), true);
    expect(cart.items.single.userId, 'guest_user');
    expect(cart.items.single.price, 7);
    expect(cart.items.single.quantity, 5);
    expect(cart.cartMode, 'B2B');
    expect(db.writes, isEmpty);
  });
  test('dispose during clear reply cannot notify or report successful handoff',
      () async {
    bind();
    final reply = Completer<void>();
    db.beforeClear = () => reply.future;
    final pending = cart.clearCart();
    cart.dispose();
    reply.complete();
    expect(await pending, false);
    cart = CartProvider(databaseService: db, authService: auth);
  });
}
