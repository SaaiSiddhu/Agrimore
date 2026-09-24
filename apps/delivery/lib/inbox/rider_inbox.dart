// lib/inbox/rider_inbox.dart
//
// Phase DLV-N1 — the rider's inbox: users/{uid}/notifications, written by
// Cloud Functions (functions/src/delivery/riderNotices.ts) and by admin
// broadcasts. firestore.rules lets the owner read it and change only
// unread / read / readAt. Title and body are shown as the server wrote them.
import 'package:cloud_firestore/cloud_firestore.dart';

/// Where a notice leads when tapped.
enum NoticeTarget { money, none }

class RiderNotice {
  const RiderNotice({required this.id, required this.type, required this.title, required this.body, required this.unread, this.createdAt});
  final String id;
  final String type;
  final String title;
  final String body;
  final bool unread;
  final DateTime? createdAt;

  factory RiderNotice.fromMap(String id, Map<String, dynamic> m) => RiderNotice(
        id: id,
        type: (m['type'] as String?) ?? '',
        title: (m['title'] as String?) ?? '',
        body: (m['body'] as String?) ?? (m['message'] as String?) ?? '',
        unread: m['unread'] == true || (m['unread'] == null && m['read'] == false),
        createdAt: m['createdAt'] is Timestamp ? (m['createdAt'] as Timestamp).toDate() : null,
      );

  NoticeTarget get target => switch (type) {
        'statement_ready' || 'payout_sent' || 'bank_change_approved' || 'bank_change_rejected' => NoticeTarget.money,
        _ => NoticeTarget.none,
      };
}

/// How many notices the inbox shows (the newest).
const int kInboxSize = 50;

abstract class RiderInboxSource {
  Stream<List<RiderNotice>> latest(String riderId);
  Stream<int> unreadCount(String riderId);
  Future<void> markRead(String riderId, Iterable<String> ids);
}

class FirestoreRiderInbox implements RiderInboxSource {
  FirestoreRiderInbox({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String riderId) =>
      _db.collection('users').doc(riderId).collection('notifications');

  @override
  Stream<List<RiderNotice>> latest(String riderId) => _col(riderId)
      .orderBy('createdAt', descending: true)
      .limit(kInboxSize)
      .snapshots()
      .map((s) => s.docs.map((d) => RiderNotice.fromMap(d.id, d.data())).toList());

  @override
  Stream<int> unreadCount(String riderId) =>
      _col(riderId).where('unread', isEqualTo: true).limit(kInboxSize).snapshots().map((s) => s.size);

  @override
  Future<void> markRead(String riderId, Iterable<String> ids) async {
    final list = ids.toList();
    for (var i = 0; i < list.length; i += 400) {
      final batch = _db.batch();
      for (final id in list.skip(i).take(400)) {
        batch.update(_col(riderId).doc(id), {'unread': false, 'read': true, 'readAt': FieldValue.serverTimestamp()});
      }
      await batch.commit();
    }
  }
}

/// "3", or "50+" when the inbox holds at least [kInboxSize] unread.
String unreadBadgeText(int n) => n >= kInboxSize ? '$kInboxSize+' : '$n';
