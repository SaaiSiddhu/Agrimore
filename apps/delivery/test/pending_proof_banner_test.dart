// DLVPP1: the dashboard's only recovery surface for a delivery whose proof
// photo never attached. Covers: nothing shown when empty, a retryable entry
// retries and clears only on genuine backend confirmation, a failed retry
// leaves the entry in place, a missing local file dismisses without
// pretending to retry, and an expired entry offers only dismiss.
//
// readPhotoBytes/discardPhoto are always injected here, never the real
// dart:io defaults -- flutter_test's fake-async zone can stall a real file
// read/delete triggered from inside a widget's own event handler (see
// agrimore-flutter-test-stalls-real-dartio-from-postframe-callback; the
// same stall reproduces for a direct tap handler too, not only a
// post-frame-callback continuation).
import 'dart:convert';
import 'dart:typed_data';

import 'package:delivery/delivery/delivery_problems.dart';
import 'package:delivery/delivery/proof_photo_recovery.dart';
import 'package:delivery/l10n/app_localizations.dart';
import 'package:delivery/screens/home/pending_proof_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStore implements PendingProofStore {
  final List<String> disk = [];

  @override
  Future<void> save(PendingProof proof) async {
    final byOrder = <String, String>{for (final s in disk) PendingProof.fromJson(jsonDecode(s))!.orderId: s};
    byOrder[proof.orderId] = jsonEncode(proof.toJson());
    disk
      ..clear()
      ..addAll(byOrder.values);
  }

  @override
  Future<void> clear(String orderId) async {
    disk.removeWhere((s) => PendingProof.fromJson(jsonDecode(s))?.orderId == orderId);
  }

  @override
  Future<List<PendingProof>> all() async =>
      disk.map((s) => PendingProof.fromJson(jsonDecode(s))).whereType<PendingProof>().toList();
}

class _FakeBackend implements DeliveryProblemBackend {
  bool failAttach = false;
  final uploaded = <String>[];
  final attached = <String>[];

  @override
  Future<String> report(Map<String, dynamic> payload) async => 'x';

  @override
  Future<void> uploadProof(String orderId, Uint8List bytes, String contentType) async => uploaded.add(orderId);

  @override
  Future<void> attachProof(String orderId) async {
    if (failAttach) throw Exception('attach failed');
    attached.add(orderId);
  }
}

/// path -> bytes, or absent means "file gone". A plain in-memory map stands
/// in for the filesystem so no test here touches real dart:io.
class _FakeDisk {
  final Map<String, Uint8List> files = {};
  final discarded = <String>[];

  Future<Uint8List?> read(String path) async => files[path];
  Future<void> discard(String path) async {
    discarded.add(path);
    files.remove(path);
  }
}

Widget _host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

Widget _banner(_FakeStore store, _FakeBackend backend, _FakeDisk disk) => _host(PendingProofBanner(
      store: store,
      backend: backend,
      readPhotoBytes: disk.read,
      discardPhoto: disk.discard,
    ));

void main() {
  testWidgets('nothing pending: renders nothing', (t) async {
    await t.pumpWidget(_banner(_FakeStore(), _FakeBackend(), _FakeDisk()));
    await t.pumpAndSettle();
    expect(find.byType(PendingProofBanner), findsOneWidget);
    expect(find.text('Proof photo not saved'), findsNothing);
  });

  testWidgets('a retryable entry shows the banner; a successful retry clears it and confirms', (t) async {
    final disk = _FakeDisk()..files['order-1.jpg'] = Uint8List.fromList([1, 2, 3]);
    final store = _FakeStore()
      ..disk.add(jsonEncode(PendingProof(orderId: 'order-1', photoPath: 'order-1.jpg', contentType: 'image/jpeg', capturedAt: DateTime.now()).toJson()));
    final backend = _FakeBackend();

    await t.pumpWidget(_banner(store, backend, disk));
    await t.pumpAndSettle();

    expect(find.text('Proof photo not saved'), findsOneWidget);
    await t.tap(find.text('Retry'));
    await t.pumpAndSettle();

    expect(backend.uploaded, ['order-1']);
    expect(backend.attached, ['order-1']);
    expect(find.text('Proof photo not saved'), findsNothing);
    expect(find.text('Proof photo saved.'), findsOneWidget);
    expect(await store.all(), isEmpty);
    expect(disk.discarded, ['order-1.jpg']); // staged file cleaned up
  });

  testWidgets('a failed retry leaves the entry in place -- never claims success before confirmation', (t) async {
    final disk = _FakeDisk()..files['order-1.jpg'] = Uint8List.fromList([1, 2, 3]);
    final store = _FakeStore()
      ..disk.add(jsonEncode(PendingProof(orderId: 'order-1', photoPath: 'order-1.jpg', contentType: 'image/jpeg', capturedAt: DateTime.now()).toJson()));
    final backend = _FakeBackend()..failAttach = true;

    await t.pumpWidget(_banner(store, backend, disk));
    await t.pumpAndSettle();
    await t.tap(find.text('Retry'));
    await t.pumpAndSettle();

    expect(find.text('Proof photo not saved'), findsOneWidget); // still there
    expect(await store.all(), hasLength(1)); // never cleared
    expect(disk.discarded, isEmpty); // never discarded
  });

  testWidgets('a pending entry whose file is gone dismisses itself instead of retrying', (t) async {
    final disk = _FakeDisk(); // deliberately empty -- 'order-1.jpg' is not present
    final store = _FakeStore()
      ..disk.add(jsonEncode(PendingProof(orderId: 'order-1', photoPath: 'order-1.jpg', contentType: 'image/jpeg', capturedAt: DateTime.now()).toJson()));
    final backend = _FakeBackend();

    await t.pumpWidget(_banner(store, backend, disk));
    await t.pumpAndSettle();
    await t.tap(find.text('Retry'));
    await t.pumpAndSettle();

    expect(backend.uploaded, isEmpty); // never attempted with no bytes to send
    expect(find.text("That photo is no longer on this device and can't be recovered."), findsOneWidget);
    expect(await store.all(), isEmpty);
  });

  testWidgets('an expired entry offers only dismiss, never a retry the server would refuse', (t) async {
    final disk = _FakeDisk()..files['order-1.jpg'] = Uint8List.fromList([1]);
    final store = _FakeStore()
      ..disk.add(jsonEncode(PendingProof(
        orderId: 'order-1',
        photoPath: 'order-1.jpg',
        contentType: 'image/jpeg',
        capturedAt: DateTime.now().subtract(const Duration(hours: 24)),
      ).toJson()));

    await t.pumpWidget(_banner(store, _FakeBackend(), disk));
    await t.pumpAndSettle();

    expect(find.text('Proof photo window closed'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    await t.tap(find.text('Dismiss'));
    await t.pumpAndSettle();

    expect(await store.all(), isEmpty);
    expect(find.text('Proof photo window closed'), findsNothing);
  });

  testWidgets('two independent pending proofs render as two banners', (t) async {
    final disk = _FakeDisk()
      ..files['a.jpg'] = Uint8List.fromList([1])
      ..files['b.jpg'] = Uint8List.fromList([2]);
    final store = _FakeStore()
      ..disk.add(jsonEncode(PendingProof(orderId: 'order-a', photoPath: 'a.jpg', contentType: 'image/jpeg', capturedAt: DateTime.now()).toJson()))
      ..disk.add(jsonEncode(PendingProof(orderId: 'order-b', photoPath: 'b.jpg', contentType: 'image/jpeg', capturedAt: DateTime.now()).toJson()));

    await t.pumpWidget(_banner(store, _FakeBackend(), disk));
    await t.pumpAndSettle();

    expect(find.text('Proof photo not saved'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('pending-proof-order-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('pending-proof-order-b')), findsOneWidget);
  });
}
