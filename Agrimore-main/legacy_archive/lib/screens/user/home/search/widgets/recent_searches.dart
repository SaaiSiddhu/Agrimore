import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../../app/themes/app_colors.dart';
import '../../../../../app/themes/app_text_styles.dart';

class RecentSearches extends StatelessWidget {
  final Function(String) onSearchTap;

  const RecentSearches({
    Key? key,
    required this.onSearchTap,
  }) : super(key: key);

  Future<void> _deleteSearch(String docId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('recent_searches')
          .doc(docId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting search: $e');
    }
  }

  Future<void> _clearAllSearches(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('recent_searches')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Recent searches cleared'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error clearing searches: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('recent_searches')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final searches = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primary.withValues(alpha: 0.1),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Recent Searches',
                        style: AppTextStyles.headlineSmall.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _clearAllSearches(context);
                    },
                    child: Text(
                      'Clear All',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: searches.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final searchDoc = searches[index];
                final query = searchDoc['query'] as String;
                final docId = searchDoc.id;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onSearchTap(query);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          color: AppColors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            query,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: AppColors.grey,
                            size: 20,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _deleteSearch(docId);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
