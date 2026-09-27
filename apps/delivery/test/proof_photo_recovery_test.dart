// DLVPP1: the durable-staging primitives for an in-flight delivery proof
// photo. Real dart:io file I/O here is safe -- these are plain `test()`
// cases, not `testWidgets()`, so none of them run inside flutter_test's
// fake-async zone (see agrimore-flutter-test-stalls-real-dartio-from-
// postframe-callback: the stall is specific to that zone, not to dart:io).
import 'dart:convert';
import 'dart:io';

import 'package:delivery/delivery/proof_photo_recovery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PendingProof JSON round trip', () {
    test('every field survives', () {
      final p = PendingProof(
        orderId: 'o1',
        photoPath: '/tmp/o1.jpg',
        contentType: 'image/jpeg',
        capturedAt: DateTime.utc(2026, 9, 27, 12),
      );
      final restored = PendingProof.fromJson(jsonDecode(jsonEncode(p.toJson())));
      expect(restored, isNotNull);
      expect(restored!.orderId, 'o1');
      expect(restored.photoPath, '/tmp/o1.jpg');
      expect(restored.contentType, 'image/jpeg');
      expect(restored.capturedAt, DateTime.utc(2026, 9, 27, 12));
    });

    test('an unrecognisable value reads as null, not a crash', () {
      expect(PendingProof.fromJson(null), isNull);
      expect(PendingProof.fromJson('nope'), isNull);
      expect(PendingProof.fromJson(<String, dynamic>{}), isNull);
      expect(
        PendingProof.fromJson({'orderId': '', 'photoPath': 'x', 'contentType': 'y', 'capturedAt': DateTime.now().toIso8601String()}),
        isNull,
      );
      expect(PendingProof.fromJson({'orderId': 'o1', 'photoPath': 'x', 'contentType': 'y', 'capturedAt': 'not-a-date'}), isNull);
    });
  });

  group('expired()', () {
    test('just captured is not expired', () {
      final p = PendingProof(orderId: 'o1', photoPath: 'x', contentType: 'y', capturedAt: DateTime.now());
      expect(p.expired(), isFalse);
    });

    test('22 hours ago is not yet expired; 24 hours ago is', () {
      final now = DateTime.utc(2026, 9, 27, 12);
      final recent = PendingProof(orderId: 'o1', photoPath: 'x', contentType: 'y', capturedAt: now.subtract(const Duration(hours: 22)));
      final old = PendingProof(orderId: 'o1', photoPath: 'x', contentType: 'y', capturedAt: now.subtract(const Duration(hours: 24)));
      expect(recent.expired(now), isFalse);
      expect(old.expired(now), isTrue);
    });

    test("the recovery window stays under the server's 24h cutoff", () {
      // attachProofCore refuses too_late strictly after 24h from
      // deliveredAt; capturedAt is always at or before deliveredAt, so this
      // margin must never reach 24h or a rider could be shown a retry the
      // server would refuse.
      expect(proofRecoveryWindow, lessThan(const Duration(hours: 24)));
    });
  });

  group('stageProofPhotoBytes / discardStagedProofPhoto', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('dlvpp1_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('stages bytes at a fixed, order-keyed path and they read back identical', () async {
      final path = await stageProofPhotoBytes(tmp, 'order-1', [1, 2, 3, 4]);
      expect(path, '${tmp.path}/proof_photos/order-1.jpg');
      expect(await File(path).readAsBytes(), [1, 2, 3, 4]);
    });

    test('staging the same order twice overwrites, never accumulates', () async {
      await stageProofPhotoBytes(tmp, 'order-1', [1, 2, 3]);
      final path = await stageProofPhotoBytes(tmp, 'order-1', [9, 9]);
      expect(await File(path).readAsBytes(), [9, 9]);
      expect(Directory('${tmp.path}/proof_photos').listSync().length, 1);
    });

    test('discard removes the file', () async {
      final path = await stageProofPhotoBytes(tmp, 'order-1', [1]);
      expect(await File(path).exists(), isTrue);
      await discardStagedProofPhoto(path);
      expect(await File(path).exists(), isFalse);
    });

    test('discarding an already-missing file never throws', () async {
      await discardStagedProofPhoto('${tmp.path}/never-existed.jpg');
    });
  });

  group('PendingProofStore (in-memory, same JSON shape as the real store)', () {
    test('save then all() returns it; clear removes it', () async {
      final store = _FakePendingProofStore();
      final p = PendingProof(orderId: 'o1', photoPath: 'x', contentType: 'image/jpeg', capturedAt: DateTime.now());
      await store.save(p);
      expect((await store.all()).map((e) => e.orderId), ['o1']);
      await store.clear('o1');
      expect(await store.all(), isEmpty);
    });

    test('saving the same orderId twice replaces, never duplicates', () async {
      final store = _FakePendingProofStore();
      await store.save(PendingProof(orderId: 'o1', photoPath: 'a', contentType: 'x', capturedAt: DateTime.now()));
      await store.save(PendingProof(orderId: 'o1', photoPath: 'b', contentType: 'x', capturedAt: DateTime.now()));
      final all = await store.all();
      expect(all.length, 1);
      expect(all.single.photoPath, 'b');
    });

    test('multiple different orders coexist independently', () async {
      final store = _FakePendingProofStore();
      await store.save(PendingProof(orderId: 'o1', photoPath: 'a', contentType: 'x', capturedAt: DateTime.now()));
      await store.save(PendingProof(orderId: 'o2', photoPath: 'b', contentType: 'x', capturedAt: DateTime.now()));
      await store.clear('o1');
      final all = await store.all();
      expect(all.length, 1);
      expect(all.single.orderId, 'o2');
    });
  });
}

/// Backed by a list of JSON strings, the same shape
/// SharedPreferencesPendingProofStore persists -- exercises the real
/// toJson()/jsonEncode()/jsonDecode()/fromJson() path without touching the
/// real plugin.
class _FakePendingProofStore implements PendingProofStore {
  final List<String> disk = [];

  @override
  Future<void> save(PendingProof proof) async {
    final byOrder = <String, String>{
      for (final s in disk) PendingProof.fromJson(jsonDecode(s))!.orderId: s,
    };
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
