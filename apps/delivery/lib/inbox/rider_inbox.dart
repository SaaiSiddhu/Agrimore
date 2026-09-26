// lib/inbox/rider_inbox.dart
//
// Phase DLV-N1 — the rider's inbox: users/{uid}/notifications, written by
// Cloud Functions (functions/src/delivery/riderNotices.ts) and by admin
// broadcasts. firestore.rules lets the owner read it and change only
// unread / read / readAt. Title and body are shown as the server wrote them.
import 'package:cloud_firestore/cloud_firestore.dart';

/// Where a notice leads when tapped. DLVI1: split from one generic `money`
/// bucket into the brief's own distinct destinations, each with the real
/// identifier to get there (never trust the payload alone — the delivery
/// destination re-reads its order fresh, and the server's own security rule
/// is what actually authorizes it).
enum NoticeTarget { delivery, statement, payoutDetails, none }

class RiderNotice {
  const RiderNotice({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.unread,
    this.createdAt,
    this.orderId,
    this.payoutId,
  });
  final String id;
  final String type;
  final String title;
  final String body;
  final bool unread;
  final DateTime? createdAt;

  /// DLVI1: the order this notice is about, when it has one
  /// (delivery_assigned/unassigned, delivery_problem_resolved) — from the
  /// `data` map riderNotices.ts already writes into every notice document.
  final String? orderId;

  /// DLVI1: the statement this notice is about, when it has one
  /// (statement_ready, payout_sent) — same `data` map.
  final String? payoutId;

  factory RiderNotice.fromMap(String id, Map<String, dynamic> m) {
    final data = m['data'];
    final d = data is Map ? data : const {};
    String? str(Object? v) => v is String && v.isNotEmpty ? v : null;
    return RiderNotice(
      id: id,
      type: (m['type'] as String?) ?? '',
      title: (m['title'] as String?) ?? '',
      body: (m['body'] as String?) ?? (m['message'] as String?) ?? '',
      unread: m['unread'] == true || (m['unread'] == null && m['read'] == false),
      createdAt: m['createdAt'] is Timestamp ? (m['createdAt'] as Timestamp).toDate() : null,
      orderId: str(d['orderId']),
      payoutId: str(d['payoutId']),
    );
  }

  NoticeTarget get target => switch (type) {
        'delivery_assigned' || 'delivery_unassigned' || 'delivery_problem_resolved' =>
          orderId != null ? NoticeTarget.delivery : NoticeTarget.none,
        'statement_ready' || 'payout_sent' =>
          payoutId != null ? NoticeTarget.statement : NoticeTarget.none,
        'bank_change_approved' || 'bank_change_rejected' => NoticeTarget.payoutDetails,
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
