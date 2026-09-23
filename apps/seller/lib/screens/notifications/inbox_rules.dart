import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../home/home_stats.dart';

/// H-02 filter chips (ADR §10.2). Account covers everything else.
enum InboxCategory { orders, quotes, payments, account }

/// Category from the server's `type` (orderNotifications.ts, rfq.ts,
/// payoutNotifications.ts). Pure — unit-tested.
InboxCategory inboxCategoryOf(String type) {
  if (type.startsWith('rfq')) return InboxCategory.quotes;
  if (type.startsWith('payout')) return InboxCategory.payments;
  if (type.contains('order')) return InboxCategory.orders;
  return InboxCategory.account;
}

/// Where tapping an entry goes, parsed from `data.actionUrl`.
enum InboxTarget { order, quote, payments, none }

@immutable
class InboxLink {
  const InboxLink(this.target, [this.id = '']);
  final InboxTarget target;
  final String id;

  static InboxLink parse(String? actionUrl) {
    final parts = (actionUrl ?? '').split('/');
    if (parts.length == 2 && parts[1].isNotEmpty) {
      switch (parts[0]) {
        case 'order':
          return InboxLink(InboxTarget.order, parts[1]);
        case 'rfq':
          return InboxLink(InboxTarget.quote, parts[1]);
        case 'payout':
          return InboxLink(InboxTarget.payments, parts[1]);
      }
    }
    return const InboxLink(InboxTarget.none);
  }
}

/// One `users/{uid}/notifications` document.
@immutable
class InboxEntry {
  const InboxEntry({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.unread,
    this.createdAt,
    this.link = const InboxLink(InboxTarget.none),
  });

  factory InboxEntry.fromMap(String id, Map<String, dynamic> d) {
    final data = d['data'] is Map ? Map<String, dynamic>.from(d['data'] as Map) : const <String, dynamic>{};
    final at = d['createdAt'];
    // Writers disagree: order/RFQ/payout notifications carry `unread`,
    // older ones `read`/`isRead`. Unread unless something says it was read.
    final unread = d['unread'] == true || (d['unread'] == null && d['read'] != true && d['isRead'] != true);
    return InboxEntry(
      id: id,
      title: (d['title'] ?? '').toString(),
      body: (d['body'] ?? '').toString(),
      type: (d['type'] ?? '').toString(),
      unread: unread,
      createdAt: at is Timestamp ? at.toDate() : null,
      link: InboxLink.parse(data['actionUrl']?.toString()),
    );
  }

  final String id;
  final String title;
  final String body;
  final String type;
  final bool unread;
  final DateTime? createdAt;
  final InboxLink link;

  InboxCategory get category => inboxCategoryOf(type);

  /// Received on the Indian calendar day containing [now].
  bool isToday(DateTime now) => createdAt != null && istDayKey(createdAt!) == istDayKey(now);
}

/// The update that marks an entry read, for every reader's convention.
Map<String, Object> markReadUpdate() => {'unread': false, 'read': true, 'readAt': FieldValue.serverTimestamp()};
