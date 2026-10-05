import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_services/database/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class WriteDb extends Fake implements FirebaseFirestore {
  final records = <String, Map<String, dynamic>>{};
  final reads = <String>[], writes = <String>[];
  Future<void> Function()? onRead;
  FirebaseException? failure;
  void Function()? onRetry;
  void Function()? afterCommit;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      WriteCollection(this, path);
  @override
  Future<T> runTransaction<T>(TransactionHandler<T> handler,
      {Duration timeout = const Duration(seconds: 30),
      int maxAttempts = 5}) async {
    var tx = WriteTransaction(this);
    var result = await handler(tx);
    if (onRetry != null) {
      onRetry!();
      tx = WriteTransaction(this);
      result = await handler(tx);
    }
    if (failure != null) throw failure!;
    for (final action in tx.pending) {
      action();
    }
    afterCommit?.call();
    return result;
  }
}

// Controlled SDK interfaces only; production uses the SDK sealed classes.
// ignore: subtype_of_sealed_class
class WriteCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  WriteCollection(this.db, this.path);
  final WriteDb db;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      WriteRef(db, '$path/$id');
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get(
          [GetOptions? options]) async =>
      EmptyReviews();
}

// ignore: subtype_of_sealed_class
class EmptyReviews extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [];
}

// ignore: subtype_of_sealed_class
class WriteSnapshot<T extends Object?> extends Fake
    implements DocumentSnapshot<T> {
  WriteSnapshot(this.value);
  final T? value;
  @override
  bool get exists => value != null;
  @override
  T? data() => value;
}

// ignore: subtype_of_sealed_class
class WriteRef extends Fake implements DocumentReference<Map<String, dynamic>> {
  WriteRef(this.db, this.path);
  final WriteDb db;
  @override
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  CollectionReference<Map<String, dynamic>> collection(String name) =>
      WriteCollection(db, '$path/$name');
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get(
      [GetOptions? options]) async {
    db.reads.add(path);
    await db.onRead?.call();
    return WriteSnapshot(
        db.records[path] == null ? null : Map.of(db.records[path]!));
  }

  @override
  Future<void> set(Map<String, dynamic> value, [SetOptions? options]) async {
    if (db.failure != null) throw db.failure!;
    db.writes.add(path);
    db.records[path] = {...?db.records[path], ...value};
  }

  @override
  Future<void> update(Map<Object, Object?> value) async {
    if (db.failure != null) throw db.failure!;
    if (!db.records.containsKey(path)) {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'not-found');
    }
    db.writes.add(path);
    db.records[path]!.addAll(Map<String, dynamic>.from(value));
  }

  @override
  Future<void> delete() async {
    if (db.failure != null) throw db.failure!;
    db.writes.add(path);
    db.records.remove(path);
  }
}

class WriteTransaction extends Fake implements Transaction {
  WriteTransaction(this.db);
  final WriteDb db;
  final pending = <void Function()>[];
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
      DocumentReference<T> ref) async {
    db.reads.add(ref.path);
    await db.onRead?.call();
    return WriteSnapshot<T>(db.records[ref.path] == null
        ? null
        : Map.of(db.records[ref.path]!) as T?);
  }

  @override
  Transaction set<T>(DocumentReference<T> ref, T value, [SetOptions? options]) {
    final data = Map<String, dynamic>.from(value as Map);
    pending.add(() {
      db.writes.add(ref.path);
      db.records[ref.path] = {...?db.records[ref.path], ...data};
    });
    return this;
  }

  @override
  Transaction update(DocumentReference ref, Map<String, dynamic> value) {
    pending.add(() {
      db.writes.add(ref.path);
      db.records[ref.path]!.addAll(value);
    });
    return this;
  }

  @override
  Transaction delete(DocumentReference ref) {
    pending.add(() {
      db.writes.add(ref.path);
      db.records.remove(ref.path);
    });
    return this;
  }
}

ReviewModel review(
        {String owner = 'owner_a',
        String id = 'legacy',
        String product = 'A',
        int rating = 5,
        List<String> images = const []}) =>
    ReviewModel(
        reviewId: id,
        productId: product,
        userId: owner,
        userName: 'Fixture',
        userAvatar: '',
        rating: rating,
        comment: 'Review comment',
        title: 'Review title',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026, 2),
        imageUrls: images);
const path = 'products/A/reviews/owner_a';
void main() {
  test('owned add keeps stable UID and content-only SDK write', () async {
    final db = WriteDb();
    final service =
        DatabaseService(firestore: db, reviewUserId: () => 'owner_a');
    expect(await service.addReview(review()), 'owner_a');
    expect(db.records[path]?['rating'], 5);
    expect(db.records[path]?.containsKey('helpfulUsers'), false);
  });
  test('customer review save never attempts backend aggregate writes',
      () async {
    final db = WriteDb();
    final service =
        DatabaseService(firestore: db, reviewUserId: () => 'owner_a');
    await service.addReview(review());
    expect(db.writes, [path]);
  });
  test('edit preserves votes badge and creation evidence', () async {
    final db = WriteDb();
    final legacy = 'products/A/reviews/legacy';
    db.records[legacy] = {
      'userId': 'owner_a',
      'productId': 'A',
      'helpfulCount': 7,
      'helpfulUsers': ['voter'],
      'isVerifiedPurchase': true,
      'createdAt': 'original',
      'sellerReply': {'text': 'Reply'}
    };
    await DatabaseService(firestore: db, reviewUserId: () => 'owner_a')
        .updateReview(review());
    expect(db.records[legacy]?['helpfulCount'], 7);
    expect(db.records[legacy]?['isVerifiedPurchase'], true);
    expect(db.records[legacy]?['createdAt'], 'original');
    expect(db.writes, [legacy]);
  });
  test('foreign model actor refuses before SDK read or write', () async {
    final db = WriteDb();
    final s = DatabaseService(firestore: db, reviewUserId: () => 'owner_b');
    await expectLater(s.addReview(review()), throwsA(isA<Exception>()));
    expect(db.reads, isEmpty);
    expect(db.writes, isEmpty);
  });
  test('sign-out during target read prevents write dispatch', () async {
    final db = WriteDb();
    String? uid = 'owner_a';
    db.onRead = () async {
      uid = null;
    };
    final s = DatabaseService(firestore: db, reviewUserId: () => uid);
    await expectLater(s.addReview(review()), throwsA(isA<Exception>()));
    expect(db.writes, isEmpty);
  });
  test('caller session guard refuses before SDK access', () async {
    final db = WriteDb();
    final service = DatabaseService(
        firestore: db,
        reviewUserId: () => 'owner_a',
        isReviewSessionCurrent: () => false);
    await expectLater(service.addReview(review()), throwsA(isA<Exception>()));
    expect(db.reads, isEmpty);
    expect(db.writes, isEmpty);
  });
  test('missing edit target is refused', () async {
    final db = WriteDb();
    await expectLater(
        DatabaseService(firestore: db, reviewUserId: () => 'owner_a')
            .updateReview(review()),
        throwsA(isA<Exception>()));
    expect(db.writes, isEmpty);
  });
  test('foreign fresh delete target is refused', () async {
    final db = WriteDb();
    db.records[path] = {'userId': 'owner_b', 'productId': 'A'};
    await expectLater(
        DatabaseService(firestore: db, reviewUserId: () => 'owner_a')
            .deleteReview('A', 'owner_a'),
        throwsA(isA<Exception>()));
    expect(db.writes, isEmpty);
  });
  test('SDK commit failure cannot become confirmed success', () async {
    final db = WriteDb()
      ..failure =
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    await expectLater(
        DatabaseService(firestore: db, reviewUserId: () => 'owner_a')
            .addReview(review()),
        throwsA(isA<Exception>()));
    expect(db.writes, isEmpty);
  });
  test('mutable image draft is frozen before first SDK await', () async {
    final db = WriteDb(), images = <String>['original'];
    db.onRead = () async {
      images.add('late');
    };
    await DatabaseService(firestore: db, reviewUserId: () => 'owner_a')
        .addReview(review(images: images));
    expect(db.records[path]?['imageUrls'], ['original']);
  });
  test('author rereview preserves current metadata and creation timestamp',
      () async {
    final db = WriteDb();
    db.records[path] = {
      'userId': 'owner_a',
      'productId': 'A',
      'createdAt': 'original',
      'helpfulUsers': ['voter'],
      'helpfulCount': 1,
      'isVerifiedPurchase': true,
      'sellerReply': {'text': 'Reply'},
      'supersededBy': 'legacy'
    };
    await DatabaseService(firestore: db, reviewUserId: () => 'owner_a')
        .addReview(review());
    expect(db.writes, [path]);
    expect(db.records[path]?['createdAt'], 'original');
    expect(db.records[path]?['helpfulUsers'], ['voter']);
    expect(db.records[path]?['isVerifiedPurchase'], true);
    expect(db.records[path]?['sellerReply'], {'text': 'Reply'});
    expect(db.records[path]?['supersededBy'], 'legacy');
  });
  test('same UID epoch change after read refuses write', () async {
    final db = WriteDb();
    bool current = true;
    db.onRead = () async {
      current = false;
    };
    await expectLater(
        DatabaseService(
            firestore: db,
            reviewUserId: () => 'owner_a',
            isReviewSessionCurrent: () => current).addReview(review()),
        throwsA(isA<AuthException>()));
    expect(db.writes, isEmpty);
  });
  test('transaction retry rechecks fresh author ownership', () async {
    final db = WriteDb();
    db.records[path] = {'userId': 'owner_a', 'productId': 'A'};
    db.onRetry = () {
      db.records[path] = {'userId': 'owner_b', 'productId': 'A'};
    };
    await expectLater(
        DatabaseService(firestore: db, reviewUserId: () => 'owner_a')
            .addReview(review()),
        throwsA(isA<DatabaseException>()));
    expect(db.writes, isEmpty);
    expect(db.reads.length, 2);
  });
  test('transaction retry cannot adopt a different session', () async {
    final db = WriteDb();
    String? uid = 'owner_a';
    db.onRetry = () {
      uid = 'owner_b';
    };
    await expectLater(
        DatabaseService(firestore: db, reviewUserId: () => uid)
            .addReview(review()),
        throwsA(isA<AuthException>()));
    expect(db.writes, isEmpty);
  });
  test('late commit cannot publish success after account switch', () async {
    final db = WriteDb();
    String? uid = 'owner_a';
    db.afterCommit = () {
      uid = 'owner_b';
    };
    await expectLater(
        DatabaseService(firestore: db, reviewUserId: () => uid)
            .addReview(review()),
        throwsA(isA<AuthException>()));
    expect(
        db.writes, [path]); // dispatched commit is real; no fictitious rollback
  });
  test('owned legacy delete and repeated missing delete are confirmed',
      () async {
    final db = WriteDb();
    final legacy = 'products/A/reviews/legacy';
    db.records[legacy] = {'userId': 'owner_a', 'productId': 'A'};
    final service =
        DatabaseService(firestore: db, reviewUserId: () => 'owner_a');
    await service.deleteReview('A', 'legacy');
    await service.deleteReview('A', 'legacy');
    expect(db.records[legacy], isNull);
    expect(db.writes, [legacy]);
  });
  test('missing or mismatched fresh product identity refuses edits', () async {
    for (final product in <String?>[null, 'B']) {
      final db = WriteDb();
      db.records['products/A/reviews/legacy'] = {
        'userId': 'owner_a',
        if (product != null) 'productId': product
      };
      await expectLater(
          DatabaseService(firestore: db, reviewUserId: () => 'owner_a')
              .updateReview(review()),
          throwsA(isA<DatabaseException>()));
      expect(db.writes, isEmpty);
    }
  });
  for (final product in ['', 'A/B', ' A']) {
    test('invalid product identifier refuses SDK access $product', () async {
      final db = WriteDb();
      await expectLater(
          DatabaseService(firestore: db, reviewUserId: () => 'owner_a')
              .addReview(review(product: product)),
          throwsA(isA<ValidationException>()));
      expect(db.reads, isEmpty);
      expect(db.writes, isEmpty);
    });
  }
  for (final rating in [0, 6]) {
    test('invalid rating refuses SDK access $rating', () async {
      final db = WriteDb();
      await expectLater(
          DatabaseService(firestore: db, reviewUserId: () => 'owner_a')
              .addReview(review(rating: rating)),
          throwsA(isA<ValidationException>()));
      expect(db.reads, isEmpty);
      expect(db.writes, isEmpty);
    });
  }
}
