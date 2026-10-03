import 'dart:async';
import 'package:agrimore_marketplace/providers/wishlist_provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter_test/flutter_test.dart';

WishlistModel wish(String uid, List<String> ids) => WishlistModel(
    id: uid, userId: uid, productIds: ids, updatedAt: DateTime.utc(2026));
ProductModel product(String id) => ProductModel(
    id: id,
    name: id,
    description: 'fixture',
    salePrice: 1,
    categoryId: 'fixture',
    images: [],
    stock: 1,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026));
Future<void> settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class Fixture {
  Fixture(
      {Future<WishlistModel?> Function(String)? read,
      Future<void> Function(String, WishlistModel)? write}) {
    provider = WishlistProvider(
        currentUserId: () => owner,
        authChanges: () => auth.stream,
        snapshots: (uid) => streams.putIfAbsent(uid, LateStream.new),
        read: (uid) {
          reads.add(uid);
          return read?.call(uid) ?? Future.value(store[uid]);
        },
        write: (uid, value) async {
          writes.add((uid, value));
          if (write != null) await write(uid, value);
          store[uid] = value;
        });
    addTearDown(() async {
      dispose();
      await auth.close();
    });
  }
  String? owner = 'a';
  final auth = StreamController<String?>.broadcast();
  final streams = <String, LateStream>{};
  final store = <String, WishlistModel>{};
  final reads = <String>[];
  final writes = <(String, WishlistModel)>[];
  late WishlistProvider provider;
  bool disposed = false;
  void dispose() {
    if (!disposed) {
      disposed = true;
      provider.dispose();
    }
  }

  Future<void> switchTo(String? uid) async {
    owner = uid;
    auth.add(uid);
    await settle();
  }

  void emit(String uid, int sub, List<String> ids) =>
      streams[uid]!.subscriptions[sub].dataCallback!(wish(uid, ids));
}

class _LateSubscription implements StreamSubscription<WishlistModel?> {
  _LateSubscription(this.dataCallback, this.errorCallback, this.doneCallback);
  void Function(WishlistModel?)? dataCallback;
  Function? errorCallback;
  void Function()? doneCallback;
  int cancelCount = 0;

  @override
  Future<void> cancel() async {
    cancelCount++;
  }

  @override
  void onData(void Function(WishlistModel? data)? handleData) =>
      dataCallback = handleData;
  @override
  void onError(Function? handleError) => errorCallback = handleError;
  @override
  void onDone(void Function()? handleDone) => doneCallback = handleDone;
  @override
  void pause([Future<void>? resumeSignal]) {}
  @override
  void resume() {}
  @override
  bool get isPaused => false;
  @override
  Future<E> asFuture<E>([E? futureValue]) => Future<E>.value(futureValue);
}

class LateStream extends Stream<WishlistModel?> {
  final subscriptions = <_LateSubscription>[];

  @override
  StreamSubscription<WishlistModel?> listen(
    void Function(WishlistModel?)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final subscription = _LateSubscription(onData, onError, onDone);
    subscriptions.add(subscription);
    return subscription;
  }

  void emit(WishlistModel? value) {
    for (final subscription in List.of(subscriptions)) {
      // Deliberately permits a queued callback after cancellation.
      subscription.dataCallback?.call(value);
    }
  }
}

void main() {
  test('valid owner list and helpers', () {
    final f = Fixture();
    f.provider.loadWishlist();
    f.emit('a', 0, ['one']);
    expect(f.provider.itemCount, 1);
    expect(f.provider.isInWishlist('one'), true);
    expect(f.provider.isEmpty, false);
  });
  test('identity change hides old data before auth event', () {
    final f = Fixture();
    f.provider.loadWishlist();
    f.emit('a', 0, ['private']);
    f.owner = 'b';
    expect(f.provider.wishlist, isNull);
    expect(f.provider.productIds, isEmpty);
    expect(f.provider.isInWishlist('private'), false);
    expect(f.provider.itemCount, 0);
  });
  test('auth switch rebinds and rejects old snapshots', () async {
    final f = Fixture();
    f.provider.loadWishlist();
    f.emit('a', 0, ['private']);
    await f.switchTo('b');
    f.emit('b', 0, ['new']);
    f.emit('a', 0, ['late']);
    expect(f.provider.productIds, ['new']);
  });
  test('same owner reload rejects old data and error', () {
    final f = Fixture();
    f.provider.loadWishlist();
    f.provider.loadWishlist();
    f.emit('a', 1, ['fresh']);
    f.emit('a', 0, ['late']);
    f.streams['a']!.subscriptions[0].errorCallback!(StateError('late'));
    expect(f.provider.productIds, ['fresh']);
    expect(f.provider.error, isNull);
  });
  test('A B A rejects first A list', () async {
    final f = Fixture();
    f.provider.loadWishlist();
    await f.switchTo('b');
    await f.switchTo('a');
    f.emit('a', 1, ['fresh']);
    f.emit('a', 0, ['late']);
    expect(f.provider.productIds, ['fresh']);
  });
  test('sign out clears and later sign in resumes', () async {
    final f = Fixture();
    f.provider.loadWishlist();
    f.emit('a', 0, ['private']);
    await f.switchTo(null);
    f.emit('a', 0, ['late']);
    expect(f.provider.productIds, isEmpty);
    await f.switchTo('b');
    f.emit('b', 0, ['new']);
    expect(f.provider.productIds, ['new']);
  });
  test('disposed provider ignores late data and further loads', () {
    final f = Fixture();
    f.provider.loadWishlist();
    f.emit('a', 0, ['private']);
    f.dispose();
    expect(() => f.emit('a', 0, ['late']), returnsNormally);
    expect(f.provider.wishlist, isNull);
    f.provider.loadWishlist();
    expect(f.streams['a']!.subscriptions.length, 1);
  });
  test('foreign owner stream model fails closed', () {
    final f = Fixture();
    f.provider.loadWishlist();
    f.streams['a']!.subscriptions[0].dataCallback!(wish('b', ['private']));
    expect(f.provider.wishlist, isNull);
    expect(f.provider.productIds, isEmpty);
  });
  test('getters cannot mutate cached IDs', () {
    final f = Fixture();
    f.provider.loadWishlist();
    f.emit('a', 0, ['one']);
    expect(() => f.provider.productIds.add('injected'), throwsUnsupportedError);
    expect(
        () => f.provider.wishlist!.productIds.clear(), throwsUnsupportedError);
    expect(f.provider.productIds, ['one']);
  });
  test('new owner add reads own existing list not old cache', () async {
    final f = Fixture();
    f.provider.loadWishlist();
    f.emit('a', 0, ['private']);
    f.store['b'] = wish('b', ['existing']);
    f.owner = 'b';
    expect(await f.provider.addItem(product('new')), true);
    expect(f.writes.single.$1, 'b');
    expect(f.writes.single.$2.productIds, ['existing', 'new']);
    expect(f.reads, ['b']);
  });
  test('missing own list starts empty', () async {
    final f = Fixture();
    expect(await f.provider.addItem(product('new')), true);
    expect(f.writes.single.$2.productIds, ['new']);
  });
  test('remove uses fresh own list', () async {
    final f = Fixture();
    f.store['a'] = wish('a', ['one', 'two']);
    expect(await f.provider.removeItem('one'), true);
    expect(f.writes.single.$2.productIds, ['two']);
  });
  test('toggle uses fresh list instead of cached membership', () async {
    final f = Fixture();
    f.store['a'] = wish('a', ['one']);
    expect(await f.provider.toggleItem(product('one')), true);
    expect(f.writes.single.$2.productIds, isEmpty);
  });
  test('clear affects only owner document', () async {
    final f = Fixture();
    f.store['a'] = wish('a', ['one']);
    expect(await f.provider.clearWishlist(), true);
    expect(f.writes.single.$1, 'a');
    expect(f.writes.single.$2.userId, 'a');
    expect(f.writes.single.$2.productIds, isEmpty);
  });
  test('signed out and disposed mutations do not dispatch', () async {
    final f = Fixture();
    f.owner = null;
    expect(await f.provider.addItem(product('one')), false);
    expect(await f.provider.removeItem('one'), false);
    expect(await f.provider.clearWishlist(), false);
    f.owner = 'a';
    f.dispose();
    expect(await f.provider.addItem(product('one')), false);
    expect(f.writes, isEmpty);
    expect(f.reads, isEmpty);
  });
  test('switch during fresh read prevents write', () async {
    final pending = Completer<WishlistModel?>();
    final f = Fixture(read: (_) => pending.future);
    final work = f.provider.addItem(product('one'));
    await settle();
    await f.switchTo('b');
    pending.complete(wish('a', ['private']));
    expect(await work, false);
    expect(f.writes, isEmpty);
    expect(f.provider.error, isNull);
  });
  test('ABA during read rejects first A write', () async {
    final pending = Completer<WishlistModel?>();
    final f = Fixture(read: (_) => pending.future);
    f.provider.loadWishlist();
    final work = f.provider.addItem(product('one'));
    await settle();
    await f.switchTo('b');
    await f.switchTo('a');
    pending.complete(wish('a', []));
    expect(await work, false);
    expect(f.writes, isEmpty);
  });
  test('foreign fresh model never writes', () async {
    final f = Fixture(read: (_) => Future.value(wish('b', ['private'])));
    expect(await f.provider.addItem(product('one')), false);
    expect(f.writes, isEmpty);
  });
  test('late dispatched write success does not finish new session', () async {
    final pending = Completer<void>();
    final f = Fixture(write: (_, __) => pending.future);
    f.provider.loadWishlist();
    final work = f.provider.addItem(product('one'));
    await settle();
    await f.switchTo('b');
    pending.complete();
    expect(await work, false);
    expect(f.provider.isLoading, false);
    expect(f.provider.productIds, isEmpty);
  });
  test('late write error does not leak into new session', () async {
    final pending = Completer<void>();
    final f = Fixture(write: (_, __) => pending.future);
    f.provider.loadWishlist();
    final work = f.provider.addItem(product('one'));
    await settle();
    await f.switchTo('b');
    pending.completeError(StateError('old private details'));
    expect(await work, false);
    expect(f.provider.error, isNull);
  });
  test('two local mutations preserve both products', () async {
    final f = Fixture();
    final a = f.provider.addItem(product('one'));
    final b = f.provider.addItem(product('two'));
    expect(await a, true);
    expect(await b, true);
    expect(f.store['a']!.productIds, ['one', 'two']);
  });
  test('obsolete auth events cannot clear the current list', () async {
    final f = Fixture();
    f.provider.loadWishlist();
    await f.switchTo('b');
    f.emit('b', 0, ['current']);
    f.auth.add('a');
    f.auth.add(null);
    await settle();
    expect(f.provider.productIds, ['current']);
    expect(f.streams['b']!.subscriptions.length, 1);
  });
  test('command before delayed auth rebinds a previously opened list',
      () async {
    final f = Fixture();
    f.provider.loadWishlist();
    f.owner = 'b';
    expect(await f.provider.addItem(product('new')), true);
    f.auth.add('b');
    await settle();
    expect(f.streams.containsKey('b'), true);
    f.emit('b', 0, ['fresh']);
    expect(f.provider.productIds, ['fresh']);
  });
  test('same owner list refresh preserves a pending write', () async {
    final pending = Completer<WishlistModel?>();
    final f = Fixture(read: (_) => pending.future);
    f.provider.loadWishlist();
    final work = f.provider.addItem(product('new'));
    await settle();
    f.provider.loadWishlist();
    pending.complete(wish('a', ['existing']));
    expect(await work, true);
    expect(f.writes.single.$2.productIds, ['existing', 'new']);
  });
  test('dispose during fresh read prevents writes and notifications', () async {
    final pending = Completer<WishlistModel?>();
    final f = Fixture(read: (_) => pending.future);
    var notifications = 0;
    f.provider.addListener(() => notifications++);
    final work = f.provider.addItem(product('new'));
    await settle();
    final before = notifications;
    f.dispose();
    pending.complete(wish('a', []));
    expect(await work, false);
    expect(f.writes, isEmpty);
    expect(notifications, before);
    expect(f.provider.isLoading, false);
  });
  test('new owner work need not wait for old dispatched write', () async {
    final pending = Completer<void>();
    final f = Fixture(
        write: (uid, _) => uid == 'a' ? pending.future : Future.value());
    final a = f.provider.addItem(product('old'));
    await settle();
    await f.switchTo('b');
    expect(await f.provider.addItem(product('new')), true);
    expect(f.store['b']!.productIds, ['new']);
    pending.complete();
    expect(await a, false);
    expect(f.provider.productIds, ['new']);
  });
  test('queued old session work cannot dispatch after switch', () async {
    final pending = Completer<void>();
    final f = Fixture(write: (_, __) => pending.future);
    final first = f.provider.addItem(product('one'));
    await settle();
    final queued = f.provider.addItem(product('two'));
    await f.switchTo('b');
    pending.complete();
    expect(await first, false);
    expect(await queued, false);
    expect(f.writes.length, 1);
  });
  test('mismatched document ID refuses fresh owner mutation', () async {
    final f = Fixture(
        read: (_) => Future.value(WishlistModel(
            id: 'b',
            userId: 'a',
            productIds: ['private'],
            updatedAt: DateTime.utc(2026))));
    expect(await f.provider.addItem(product('new')), false);
    expect(f.writes, isEmpty);
  });
  test('valid retry after write failure clears error and preserves data',
      () async {
    var calls = 0;
    final f = Fixture(write: (_, __) async {
      if (++calls == 1) throw StateError('fixture');
    });
    f.store['a'] = wish('a', ['existing']);
    expect(await f.provider.addItem(product('new')), false);
    expect(f.provider.error, isNotNull);
    expect(await f.provider.addItem(product('new')), true);
    expect(f.provider.error, isNull);
    expect(f.store['a']!.productIds, ['existing', 'new']);
  });

  test('current read failure refuses mutation with generic error', () async {
    final f = Fixture(read: (_) => Future.error(StateError('private detail')));
    expect(await f.provider.addItem(product('one')), false);
    expect(f.writes, isEmpty);
    expect(f.provider.error, isNot(contains('private detail')));
    expect(f.provider.error, isNotNull);
  });
}
