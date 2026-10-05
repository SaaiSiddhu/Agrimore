import 'dart:async';
import 'package:agrimore_services/database/database_service.dart';
import 'package:agrimore_marketplace/providers/review_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'product_review_writer_test.dart' show WriteDb, review;

const target = 'products/A/reviews/legacy';
WriteDb fixture() {
  final db = WriteDb();
  db.records[target] = {
    ...review().toMap(),
    'helpfulUsers': ['other'],
    'unhelpfulUsers': ['critic'],
    'helpfulCount': 1,
    'unhelpfulCount': 1
  };
  return db;
}

void main() {
  test('self vote preserves other voters and content', () async {
    final db = fixture();
    final before = Map.of(db.records[target]!);
    await DatabaseService(firestore: db, reviewUserId: () => 'reader')
        .markReviewHelpful('A', 'legacy', 'reader', true);
    expect(db.records[target]!['helpfulUsers'], ['other', 'reader']);
    expect(db.records[target]!['unhelpfulUsers'], ['critic']);
    expect(db.records[target]!['helpfulCount'], 2);
    expect(db.records[target]!['comment'], before['comment']);
    expect(db.writes, [target]);
  });
  test('toggle then switch changes only actor membership', () async {
    final db = fixture();
    final s = DatabaseService(firestore: db, reviewUserId: () => 'reader');
    await s.markReviewHelpful('A', 'legacy', 'reader', true);
    await s.markReviewHelpful('A', 'legacy', 'reader', true);
    expect(db.records[target]!['helpfulUsers'], ['other']);
    await s.markReviewHelpful('A', 'legacy', 'reader', false);
    await s.markReviewHelpful('A', 'legacy', 'reader', true);
    expect(db.records[target]!['helpfulUsers'], ['other', 'reader']);
    expect(db.records[target]!['unhelpfulUsers'], ['critic']);
  });
  test('foreign claimed actor rejected before SDK read', () async {
    final db = fixture();
    await expectLater(
        DatabaseService(firestore: db, reviewUserId: () => 'reader')
            .markReviewHelpful('A', 'legacy', 'other', true),
        throwsException);
    expect(db.reads, isEmpty);
    expect(db.writes, isEmpty);
  });
  test('signed out actor refused before SDK read', () async {
    final db = fixture();
    await expectLater(
        DatabaseService(firestore: db, reviewUserId: () => null)
            .markReviewHelpful('A', 'legacy', 'reader', true),
        throwsException);
    expect(db.reads, isEmpty);
  });
  test('transaction retry rereads and preserves another committed vote',
      () async {
    final db = fixture()..onRetry = () {};
    db.onRetry = () {
      db.records[target]!['helpfulUsers'] = ['other', 'second'];
      db.records[target]!['helpfulCount'] = 2;
    };
    await DatabaseService(firestore: db, reviewUserId: () => 'reader')
        .markReviewHelpful('A', 'legacy', 'reader', true);
    expect(db.reads, [target, target]);
    expect(db.records[target]!['helpfulUsers'], ['other', 'second', 'reader']);
    expect(db.records[target]!['helpfulCount'], 3);
    expect(db.writes, [target]);
  });
  test('retry keeps first selected intent if same actor commits meanwhile',
      () async {
    final db = fixture();
    db.onRetry = () {
      db.records[target]!['helpfulUsers'] = ['other', 'reader'];
      db.records[target]!['helpfulCount'] = 2;
    };
    await DatabaseService(firestore: db, reviewUserId: () => 'reader')
        .markReviewHelpful('A', 'legacy', 'reader', true);
    expect(db.reads.length, 2);
    expect(db.records[target]!['helpfulUsers'], ['other', 'reader']);
    expect(db.records[target]!['helpfulCount'], 2);
  });
  test('account switch during read refuses write', () async {
    final db = fixture();
    String? actor = 'reader';
    db.onRead = () async {
      actor = 'next';
    };
    await expectLater(
        DatabaseService(firestore: db, reviewUserId: () => actor)
            .markReviewHelpful('A', 'legacy', 'reader', true),
        throwsException);
    expect(db.writes, isEmpty);
  });
  test('same uid session invalidation refuses delayed read', () async {
    final db = fixture();
    bool current = true;
    db.onRead = () async {
      current = false;
    };
    await expectLater(
        DatabaseService(
                firestore: db,
                reviewUserId: () => 'reader',
                isReviewSessionCurrent: () => current)
            .markReviewHelpful('A', 'legacy', 'reader', true),
        throwsException);
    expect(db.writes, isEmpty);
  });
  test('retry with changed session refuses pending transaction', () async {
    final db = fixture();
    bool current = true;
    db.onRetry = () {
      current = false;
    };
    await expectLater(
        DatabaseService(
                firestore: db,
                reviewUserId: () => 'reader',
                isReviewSessionCurrent: () => current)
            .markReviewHelpful('A', 'legacy', 'reader', true),
        throwsException);
    expect(db.writes, isEmpty);
  });
  test('postcommit switch rejects stale receipt without claiming undo',
      () async {
    final db = fixture();
    String? actor = 'reader';
    db.afterCommit = () {
      actor = 'next';
    };
    await expectLater(
        DatabaseService(firestore: db, reviewUserId: () => actor)
            .markReviewHelpful('A', 'legacy', 'reader', true),
        throwsException);
    expect(db.writes, [target]);
  });
  for (final entry in <String, Map<String, dynamic>>{
    'wrong product': {'productId': 'other'},
    'superseded': {'supersededBy': 'winner'},
    'null list': {'helpfulUsers': null},
    'wrong list type': {'helpfulUsers': 'reader'},
    'duplicate': {
      'helpfulUsers': ['other', 'other'],
      'helpfulCount': 2
    },
    'overlap': {
      'unhelpfulUsers': ['other']
    },
    'nonstrings': {
      'helpfulUsers': [1]
    },
    'wrong count': {'helpfulCount': 900},
    'fractional count': {'helpfulCount': 1.5},
    'null count': {'helpfulCount': null},
    'invalid voter': {
      'helpfulUsers': [' bad ']
    },
  }.entries) {
    test('refuses malformed raw record: ${entry.key}', () async {
      final db = fixture();
      db.records[target]!.addAll(entry.value);
      await expectLater(
          DatabaseService(firestore: db, reviewUserId: () => 'reader')
              .markReviewHelpful('A', 'legacy', 'reader', true),
          throwsException);
      expect(db.writes, isEmpty);
    });
  }
  test('missing empty fields supported without model invention', () async {
    final db = fixture();
    for (final key in [
      'helpfulUsers',
      'unhelpfulUsers',
      'helpfulCount',
      'unhelpfulCount'
    ]) {
      db.records[target]!.remove(key);
    }
    await DatabaseService(firestore: db, reviewUserId: () => 'reader')
        .markReviewHelpful('A', 'legacy', 'reader', true);
    expect(db.records[target]!['helpfulUsers'], ['reader']);
    expect(db.records[target]!['unhelpfulCount'], 0);
  });
  test('missing review refuses without creation', () async {
    final db = WriteDb();
    await expectLater(
        DatabaseService(firestore: db, reviewUserId: () => 'reader')
            .markReviewHelpful('A', 'legacy', 'reader', true),
        throwsException);
    expect(db.writes, isEmpty);
  });
  test('provider propagates SDK refusal and settles loading', () async {
    final db = fixture()
      ..failure =
          FirebaseException(plugin: 'firestore', code: 'permission-denied');
    final p = ReviewProvider(firestore: db, reviewUserId: () => 'reader');
    await expectLater(
        p.markHelpful('A', 'legacy', 'reader', true), throwsException);
    expect(p.isLoading, false);
    expect(db.writes, isEmpty);
    p.dispose();
  });
  test('disposed provider refuses without read', () async {
    final db = fixture();
    final p = ReviewProvider(firestore: db, reviewUserId: () => 'reader')
      ..dispose();
    await expectLater(
        p.markHelpful('A', 'legacy', 'reader', true), throwsException);
    expect(db.reads, isEmpty);
  });
  test('provider disposal during read fences writes and notifications',
      () async {
    final db = fixture();
    final p = ReviewProvider(firestore: db, reviewUserId: () => 'reader');
    db.onRead = () async {
      p.dispose();
    };
    await expectLater(
        p.markHelpful('A', 'legacy', 'reader', true), throwsException);
    expect(db.writes, isEmpty);
  });
  test('provider duplicate target is refused and pending settles', () async {
    final db = fixture();
    final held = Completer<void>();
    db.onRead = () => held.future;
    final p = ReviewProvider(firestore: db, reviewUserId: () => 'reader');
    final first = p.markHelpful('A', 'legacy', 'reader', true);
    expect(p.isVoting('A', 'legacy', 'reader'), true);
    expect(p.isVoting('A', 'legacy', 'next'), false);
    await expectLater(
        p.markHelpful('A', 'legacy', 'reader', false), throwsException);
    expect(db.reads.length, 1);
    held.complete();
    await first;
    expect(p.isVoting('A', 'legacy', 'reader'), false);
    expect(p.isLoading, false);
    p.dispose();
  });
}
