import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../app/themes/app_colors.dart';
import '../../../../../app/themes/app_text_styles.dart';

class TrendingSearches extends StatelessWidget {
  final Function(String) onTrendingTap;

  const TrendingSearches({
    Key? key,
    required this.onTrendingTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('trending_searches')
          .orderBy('count', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        // Fallback to default trending searches if Firebase data not available
        final List<Map<String, dynamic>> trendingData = snapshot.hasData
            ? snapshot.data!.docs
                .map((doc) => {
                      'query': doc['query'] as String,
                      'count': doc['count'] as int,
                    })
                .toList()
            : [
                {'query': 'Organic Vegetables', 'count': 1250},
                {'query': 'Fresh Fruits', 'count': 980},
                {'query': 'Dairy Products', 'count': 850},
                {'query': 'Farm Equipment', 'count': 720},
                {'query': 'Seeds & Plants', 'count': 650},
                {'query': 'Agricultural Tools', 'count': 580},
                {'query': 'Fertilizers', 'count': 520},
                {'query': 'Pesticides', 'count': 480},
              ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.secondary,
                          AppColors.secondary.withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        color: Colors.orange,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Trending Now',
                        style: AppTextStyles.headlineSmall.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: trendingData.length,
                itemBuilder: (context, index) {
                  final trending = trendingData[index];
                  final isTop3 = index < 3;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onTrendingTap(trending['query']);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: isTop3
                            ? LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primary.withOpacity(0.8),
                                ],
                              )
                            : null,
                        color: isTop3 ? null : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: isTop3
                            ? null
                            : Border.all(
                                color: AppColors.primary.withOpacity(0.3),
                              ),
                        boxShadow: isTop3
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isTop3)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (isTop3) const SizedBox(width: 8),
                          Text(
                            trending['query'],
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: isTop3 ? Colors.white : AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: trendingData.skip(0).take(8).map((trending) {
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onTrendingTap(trending['query']);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lightGrey,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.trending_up_rounded,
                            size: 16,
                            color: AppColors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            trending['query'],
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}
