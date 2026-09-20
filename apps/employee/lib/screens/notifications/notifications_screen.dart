import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../utils/sa_formatters.dart';

/// Notifications inbox screen for Sales Associates.
///
/// Streams notifications from `users/{uid}/notifications` ordered by `createdAt` desc.
/// Permitted by firestore.rules (`match /users/{userId}/notifications/{notificationId}`).
class NotificationsScreen extends StatelessWidget {
  final String? employeeUid;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? notificationsStream;

  const NotificationsScreen({
    super.key,
    this.employeeUid,
    this.notificationsStream,
  });

  Future<void> _markAllAsRead(BuildContext context, String uid) async {
    try {
      final unreadDocs = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();

      if (unreadDocs.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in unreadDocs.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update notifications: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.saTokens;
    final uid = employeeUid ?? FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        backgroundColor: tokens.pageBackground,
        body: Center(
          child: Text(
            'Sign in to view notifications',
            style: TextStyle(color: tokens.textSecondary),
          ),
        ),
      );
    }

    final notificationsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications');

    return Scaffold(
      backgroundColor: tokens.pageBackground,
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(SaIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded),
            tooltip: 'Mark all as read',
            onPressed: () => _markAllAsRead(context, uid),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: notificationsStream ??
            notificationsRef
                .orderBy('createdAt', descending: true)
                .limit(50)
                .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(SaTokens.space24),
                child: Text(
                  'Error loading notifications: ${snap.error}',
                  style: TextStyle(color: tokens.errorFg),
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return ListView.separated(
              padding: const EdgeInsets.all(SaTokens.space16),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(height: SaTokens.space12),
              itemBuilder: (_, __) => Container(
                height: 72,
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(SaTokens.radiusCard),
                  border: Border.all(color: tokens.divider),
                ),
              ),
            );
          }

          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(SaTokens.space32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: tokens.primarySubtle,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        SaIcons.bell,
                        size: 32,
                        color: tokens.primary,
                      ),
                    ),
                    const SizedBox(height: SaTokens.space16),
                    Text(
                      'No notifications yet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: tokens.textPrimary,
                          ),
                    ),
                    const SizedBox(height: SaTokens.space4),
                    Text(
                      'Updates on attributed orders and payouts will appear here.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: tokens.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(SaTokens.space16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: SaTokens.space12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final title = data['title']?.toString() ?? 'Notification';
              final message = data['message']?.toString() ??
                  data['body']?.toString() ??
                  '';
              final isRead = data['read'] == true;

              DateTime? createdAt;
              final ts = data['createdAt'];
              if (ts is Timestamp) {
                createdAt = ts.toDate();
              }

              return Container(
                decoration: BoxDecoration(
                  color: isRead ? tokens.surface : tokens.primarySubtle,
                  borderRadius: BorderRadius.circular(SaTokens.radiusCard),
                  border: Border.all(
                    color: isRead
                        ? tokens.divider
                        : tokens.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: SaTokens.space16,
                    vertical: SaTokens.space8,
                  ),
                  onTap: () {
                    if (!isRead) {
                      doc.reference.update({'read': true});
                    }
                  },
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isRead ? tokens.pageBackground : tokens.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      SaIcons.bell,
                      size: 20,
                      color: isRead ? tokens.textSecondary : tokens.primary,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: SaTokens.fsBody,
                            fontWeight: isRead ? FontWeight.w600 : FontWeight.w700,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: tokens.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: tokens.textSecondary,
                              height: 1.4,
                            ),
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          SaFormatters.formatDate(createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: tokens.textSecondary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
