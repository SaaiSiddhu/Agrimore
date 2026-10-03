import 'dart:async';
import 'package:agrimore_marketplace/providers/address_provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter_test/flutter_test.dart';

AddressModel address(String uid, String id, {bool primary = false}) =>
    AddressModel(
        id: id,
        userId: uid,
        name: 'Fixture',
        phone: '9000000000',
        addressLine1: 'Fixture',
        addressLine2: '',
        city: 'City',
        state: 'State',
        zipcode: '600001',
        isDefault: primary);
Future<void> settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class Fixture {
  Fixture(
      {Future<List<AddressModel>> Function(String)? read,
      Future<String> Function(AddressModel)? add,
      Future<void> Function(String, Map<String, dynamic>)? edit}) {
    provider = AddressProvider(
        currentUserId: () => owner,
        authChanges: () => auth.stream,
        snapshots: (uid) => streams.putIfAbsent(uid, LateStream.new),
        read: (uid) {
          reads.add(uid);
          return read?.call(uid) ?? Future.value(store[uid] ?? []);
        },
        add: (value) async {
          adds.add(value);
          return add == null ? 'created' : await add(value);
        },
        update: (id, value) async {
          edits.add((id, value));
          if (edit != null) await edit(id, value);
        },
        delete: (id) async {
          deletes.add(id);
        });
    addTearDown(() async {
      dispose();
      await auth.close();
    });
  }
  String? owner = 'a';
  final auth = StreamController<String?>.broadcast();
  final streams = <String, LateStream>{};
  final store = <String, List<AddressModel>>{};
  final reads = <String>[];
  final adds = <AddressModel>[];
  final edits = <(String, Map<String, dynamic>)>[];
  final deletes = <String>[];
  late AddressProvider provider;
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

  void emit(String uid, int sub, List<AddressModel> rows) =>
      streams[uid]!.subscriptions[sub].dataCallback!(rows);
}

class _LateSubscription implements StreamSubscription<List<AddressModel>> {
  _LateSubscription(this.dataCallback, this.errorCallback, this.doneCallback);
  void Function(List<AddressModel>)? dataCallback;
  Function? errorCallback;
  void Function()? doneCallback;
  int cancelCount = 0;

  @override
  Future<void> cancel() async {
    cancelCount++;
  }

  @override
  void onData(void Function(List<AddressModel> data)? handleData) =>
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

class LateStream extends Stream<List<AddressModel>> {
  final subscriptions = <_LateSubscription>[];

  @override
  StreamSubscription<List<AddressModel>> listen(
    void Function(List<AddressModel>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final subscription = _LateSubscription(onData, onError, onDone);
    subscriptions.add(subscription);
    return subscription;
  }

  void emit(List<AddressModel> value) {
    for (final subscription in List.of(subscriptions)) {
      // Deliberately permits a queued callback after cancellation.
      subscription.dataCallback?.call(value);
    }
  }
}

void main() {
  test('valid owner list default and selection', () {
    final f = Fixture();
    f.provider.loadAddresses();
    final rows = [address('a', 'one'), address('a', 'two', primary: true)];
    f.emit('a', 0, rows);
    f.provider.selectAddress(rows.first);
    expect(f.provider.defaultAddress!.id, 'two');
    expect(f.provider.selectedAddress!.id, 'one');
    expect(f.provider.hasAddresses, true);
  });
  test('identity change hides list default and selected address immediately',
      () {
    final f = Fixture();
    f.provider.loadAddresses();
    final row = address('a', 'private');
    f.emit('a', 0, [row]);
    f.provider.selectAddress(row);
    f.owner = 'b';
    expect(f.provider.addresses, isEmpty);
    expect(f.provider.selectedAddress, isNull);
    expect(f.provider.defaultAddress, isNull);
    expect(f.provider.hasAddresses, false);
  });
  test('switch binds new owner and rejects old callback', () async {
    final f = Fixture();
    f.provider.loadAddresses();
    await f.switchTo('b');
    f.emit('b', 0, [address('b', 'new')]);
    f.emit('a', 0, [address('a', 'late')]);
    expect(f.provider.addresses.single.id, 'new');
  });
  test('same owner reload rejects old data and error', () {
    final f = Fixture();
    f.provider.loadAddresses();
    f.provider.loadAddresses();
    f.emit('a', 1, [address('a', 'fresh')]);
    f.emit('a', 0, [address('a', 'late')]);
    f.streams['a']!.subscriptions[0].errorCallback!(StateError('private'));
    expect(f.provider.addresses.single.id, 'fresh');
    expect(f.provider.error, isNull);
  });
  test('A B A rejects original A callback', () async {
    final f = Fixture();
    f.provider.loadAddresses();
    await f.switchTo('b');
    await f.switchTo('a');
    f.emit('a', 1, [address('a', 'fresh')]);
    f.emit('a', 0, [address('a', 'late')]);
    expect(f.provider.addresses.single.id, 'fresh');
  });
  test('sign out clears selection and sign in resumes', () async {
    final f = Fixture();
    f.provider.loadAddresses();
    final row = address('a', 'one');
    f.emit('a', 0, [row]);
    f.provider.selectAddress(row);
    await f.switchTo(null);
    f.emit('a', 0, [row]);
    expect(f.provider.addresses, isEmpty);
    expect(f.provider.selectedAddress, isNull);
    await f.switchTo('b');
    f.emit('b', 0, [address('b', 'new')]);
    expect(f.provider.addresses.single.userId, 'b');
  });
  test('disposed ignores callbacks and further loads', () {
    final f = Fixture();
    f.provider.loadAddresses();
    f.dispose();
    expect(() => f.emit('a', 0, [address('a', 'late')]), returnsNormally);
    expect(f.provider.addresses, isEmpty);
    f.provider.loadAddresses();
    expect(f.streams['a']!.subscriptions.length, 1);
  });
  test('foreign model cannot enter list or selection', () {
    final f = Fixture();
    f.provider.loadAddresses();
    f.emit('a', 0, [address('b', 'private')]);
    f.provider.selectAddress(address('b', 'private'));
    expect(f.provider.addresses, isEmpty);
    expect(f.provider.selectedAddress, isNull);
  });
  test('list getter is immutable', () {
    final f = Fixture();
    f.provider.loadAddresses();
    f.emit('a', 0, [address('a', 'one')]);
    expect(() => f.provider.addresses.clear(), throwsUnsupportedError);
    expect(f.provider.hasAddresses, true);
  });
  test('first new address becomes default from fresh owner list', () async {
    final f = Fixture();
    expect(await f.provider.addAddress(address('a', '')), 'created');
    expect(f.adds.single.isDefault, true);
    expect(f.reads, ['a']);
  });
  test('old cache cannot demote another owner default', () async {
    final f = Fixture();
    f.provider.loadAddresses();
    f.emit('a', 0, [address('a', 'private', primary: true)]);
    f.owner = 'b';
    f.store['b'] = [address('b', 'existing', primary: true)];
    expect(await f.provider.addAddress(address('b', '', primary: true)),
        'created');
    expect(f.edits.single.$1, 'existing');
    expect(f.reads, ['b']);
  });
  test('foreign add and ownership transfer update refuse before writes',
      () async {
    final f = Fixture();
    f.store['a'] = [address('a', 'one')];
    expect(await f.provider.addAddress(address('b', '')), isNull);
    expect(await f.provider.updateAddress('one', {'userId': 'b'}), false);
    expect(f.adds, isEmpty);
    expect(f.edits, isEmpty);
  });
  test('missing own update delete default targets refuse', () async {
    final f = Fixture();
    expect(await f.provider.updateAddress('foreign', {'name': 'x'}), false);
    expect(await f.provider.deleteAddress('foreign'), false);
    expect(await f.provider.setDefaultAddress('foreign'), false);
    expect(f.edits, isEmpty);
    expect(f.deletes, isEmpty);
  });
  test('valid own update delete default remain functional', () async {
    final f = Fixture();
    f.store['a'] = [address('a', 'one'), address('a', 'two', primary: true)];
    expect(await f.provider.updateAddress('one', {'name': 'updated'}), true);
    expect(await f.provider.setDefaultAddress('one'), true);
    expect(await f.provider.deleteAddress('one'), true);
    expect(f.edits.map((e) => e.$1), ['one', 'two', 'one']);
    expect(f.deletes, ['one']);
  });
  test('switch during read stops all writes', () async {
    final pending = Completer<List<AddressModel>>();
    final f = Fixture(read: (_) => pending.future);
    final work = f.provider.addAddress(address('a', ''));
    await settle();
    await f.switchTo('b');
    pending.complete([]);
    expect(await work, isNull);
    expect(f.adds, isEmpty);
    expect(f.edits, isEmpty);
  });
  test('switch during default demotion stops next writes and creation',
      () async {
    final pending = Completer<void>();
    final f = Fixture(edit: (_, __) => pending.future);
    f.store['a'] = [
      address('a', 'one', primary: true),
      address('a', 'two', primary: true)
    ];
    f.provider.loadAddresses();
    f.emit('a', 0, f.store['a']!);
    final work = f.provider.addAddress(address('a', '', primary: true));
    await settle();
    await f.switchTo('b');
    pending.complete();
    expect(await work, isNull);
    expect(f.edits.length, 1);
    expect(f.adds, isEmpty);
    expect(f.provider.error, isNull);
  });
  test('switch during default demotion stops target promotion', () async {
    final pending = Completer<void>();
    final f = Fixture(edit: (_, __) => pending.future);
    f.store['a'] = [address('a', 'one', primary: true), address('a', 'two')];
    f.provider.loadAddresses();
    f.emit('a', 0, f.store['a']!);
    final work = f.provider.setDefaultAddress('two');
    await settle();
    await f.switchTo('b');
    pending.complete();
    expect(await work, false);
    expect(f.edits.length, 1);
  });
  test('late saved ID cannot report success into new account', () async {
    final pending = Completer<String>();
    final f = Fixture(add: (_) => pending.future);
    final work = f.provider.addAddress(address('a', ''));
    await settle();
    await f.switchTo('b');
    pending.complete('old');
    expect(await work, isNull);
    expect(f.provider.isLoading, false);
    expect(f.provider.error, isNull);
  });
  test('unsigned and disposed mutation writes nothing', () async {
    final f = Fixture();
    f.owner = null;
    expect(await f.provider.addAddress(address('a', '')), isNull);
    expect(await f.provider.deleteAddress('one'), false);
    f.owner = 'a';
    f.dispose();
    expect(await f.provider.addAddress(address('a', '')), isNull);
    expect(f.adds, isEmpty);
    expect(f.deletes, isEmpty);
  });
  test('foreign fresh list refuses rather than demoting it', () async {
    final f = Fixture(
        read: (_) => Future.value([address('b', 'private', primary: true)]));
    expect(
        await f.provider.addAddress(address('a', '', primary: true)), isNull);
    expect(f.edits, isEmpty);
    expect(f.adds, isEmpty);
  });
  test('delayed auth selection rebinds previously opened owner list', () async {
    final f = Fixture();
    f.provider.loadAddresses();
    f.owner = 'b';
    f.provider.selectAddress(address('b', 'selected'));
    f.auth.add('b');
    await settle();
    expect(f.streams.containsKey('b'), true);
    f.emit('b', 0, [address('b', 'selected')]);
    expect(f.provider.selectedAddress!.userId, 'b');
  });
  test('current stream error clears on valid reload', () {
    final f = Fixture();
    f.provider.loadAddresses();
    f.streams['a']!.subscriptions[0].errorCallback!(StateError('private'));
    expect(f.provider.error, isNotNull);
    expect(f.provider.error, isNot(contains('private')));
    f.provider.loadAddresses();
    f.emit('a', 1, [address('a', 'one')]);
    expect(f.provider.error, isNull);
  });
  test('obsolete auth event does not clear new owner list', () async {
    final f = Fixture();
    f.provider.loadAddresses();
    await f.switchTo('b');
    f.emit('b', 0, [address('b', 'new')]);
    f.auth.add('a');
    f.auth.add(null);
    await settle();
    expect(f.provider.addresses.single.id, 'new');
  });
  test('dispose during read blocks writes and notifications', () async {
    final pending = Completer<List<AddressModel>>();
    final f = Fixture(read: (_) => pending.future);
    var notifications = 0;
    f.provider.addListener(() => notifications++);
    final work = f.provider.addAddress(address('a', ''));
    await settle();
    final before = notifications;
    f.dispose();
    pending.complete([]);
    expect(await work, isNull);
    expect(f.adds, isEmpty);
    expect(notifications, before);
  });
  test('ABA during read cannot create first A address', () async {
    final pending = Completer<List<AddressModel>>();
    final f = Fixture(read: (_) => pending.future);
    final work = f.provider.addAddress(address('a', ''));
    await settle();
    await f.switchTo('b');
    await f.switchTo('a');
    pending.complete([]);
    expect(await work, isNull);
    expect(f.adds, isEmpty);
  });
  test('same owner reload preserves active address save', () async {
    final pending = Completer<String>();
    final f = Fixture(add: (_) => pending.future);
    f.provider.loadAddresses();
    final work = f.provider.addAddress(address('a', ''));
    await settle();
    f.provider.loadAddresses();
    pending.complete('created');
    expect(await work, 'created');
  });
  test('queued old work refuses after old write completes in a new session',
      () async {
    final pending = Completer<String>();
    final f = Fixture(add: (_) => pending.future);
    final first = f.provider.addAddress(address('a', ''));
    await settle();
    final second = f.provider.addAddress(address('a', ''));
    await f.switchTo('b');
    pending.complete('old');
    expect(await first, isNull);
    expect(await second, isNull);
    expect(f.adds.length, 1);
  });
  test('late write error cannot expose old detail in new session', () async {
    final pending = Completer<String>();
    final f = Fixture(add: (_) => pending.future);
    final work = f.provider.addAddress(address('a', ''));
    await settle();
    await f.switchTo('b');
    pending.completeError(StateError('old private detail'));
    expect(await work, isNull);
    expect(f.provider.error, isNull);
    expect(f.provider.isLoading, false);
  });
}
