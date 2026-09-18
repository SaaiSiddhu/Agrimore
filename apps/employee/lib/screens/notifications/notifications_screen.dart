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
    final uid = employeeUid ?? FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        backgroundColor: SaTokens.pageBackground,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final notificationsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications');

    return Scaffold(
      backgroundColor: SaTokens.pageBackground,
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
                child: Text('Error loading notifications: ${snap.error}'),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
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
                      decoration: const BoxDecoration(
                        color: SaTokens.primarySubtle,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        SaIcons.bell,
                        size: 32,
                        color: SaTokens.primary,
                      ),
                    ),
                    const SizedBox(height: SaTokens.space16),
                    Text(
                      'No notifications yet',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: SaTokens.space4),
                    Text(
                      'Updates on attributed orders and payouts will appear here.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
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
                  color: isRead ? SaTokens.surface : SaTokens.primarySubtle,
                  borderRadius: BorderRadius.circular(SaTokens.radiusCard),
                  border: Border.all(
                    color: isRead ? SaTokens.divider : SaTokens.primary.withValues(alpha: 0.3),
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
                      color: isRead ? SaTokens.pageBackground : SaTokens.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      SaIcons.bell,
                      size: 20,
                      color: isRead ? SaTokens.textSecondary : SaTokens.primary,
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
                            color: SaTokens.textPrimary,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: const BoxDecoration(
                            color: SaTokens.primary,
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
                              color: SaTokens.textSecondary,
                              height: 1.4,
                            ),
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          SaFormatters.formatDate(createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: SaTokens.textSecondary.withValues(alpha: 0.8),
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
