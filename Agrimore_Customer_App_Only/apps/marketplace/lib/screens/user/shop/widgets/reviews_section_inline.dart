import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../../providers/review_provider.dart';
import '../../../../providers/theme_provider.dart';
import 'package:agrimore_services/agrimore_services.dart';
import 'add_review_dialog.dart';
import 'review_card.dart';

/// Inline version of ReviewsSection for use in CustomScrollView (no Expanded)
class ReviewsSectionInline extends StatefulWidget {
  final String productId;
  final String productName;
  final bool isDark;

  const ReviewsSectionInline({
    Key? key,
    required this.productId,
    required this.productName,
    required this.isDark,
  }) : super(key: key);

  @override
  State<ReviewsSectionInline> createState() => _ReviewsSectionInlineState();
}

class _ReviewsSectionInlineState extends State<ReviewsSectionInline> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ReviewProvider>(context, listen: false)
          .loadReviewStats(widget.productId);
    });
  }

  void _showAddReviewDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return MultiProvider(
          providers: [
            Provider.value(value: context.read<AuthService>()),
            ChangeNotifierProvider.value(value: context.read<ThemeProvider>()),
          ],
          child: AddReviewDialog(
            productId: widget.productId,
            productName: widget.productName,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.isDark ? AppColors.primaryLight : AppColors.primary;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Customer Reviews',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: widget.isDark ? Colors.white : Colors.black87,
              ),
            ),
            TextButton.icon(
              onPressed: _showAddReviewDialog,
              icon: Icon(Icons.add_comment_outlined, size: 16, color: accentColor),
              label: Text('Add Review', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                backgroundColor: accentColor.withOpacity(0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Stats Section
        _buildStatsSection(),
        
        const SizedBox(height: 24),
        
        // Reviews List (limited to show first few reviews)
        StreamBuilder<List<ReviewModel>>(
          stream: Provider.of<ReviewProvider>(context, listen: false)
              .getReviewsStream(widget.productId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            
            final reviews = snapshot.data ?? [];
            
            if (reviews.isEmpty) {
              return _buildEmptyState();
            }
            
            // Show first 3 reviews inline
            final displayReviews = reviews.take(3).toList();
            return Column(
              children: [
                ...displayReviews.map((review) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ReviewCard(review: review, isDark: widget.isDark),
                )),
                if (reviews.length > 3)
                  TextButton(
                    onPressed: () {
                      // Could navigate to full reviews page
                    },
                    child: Text(
                      'View all ${reviews.length} reviews',
                      style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return Consumer<ReviewProvider>(
      builder: (context, provider, child) {
        if (provider.reviewStats == null) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final stats = provider.reviewStats!;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Overall Rating
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Text(
                      stats.averageRating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: widget.isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) => Icon(
                        i < stats.averageRating.floor() ? Icons.star_rounded : Icons.star_border_rounded,
                        color: Colors.amber[700],
                        size: 14,
                      )),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${stats.totalReviews} Reviews',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Separator
              Container(
                width: 1,
                height: 80,
                color: widget.isDark ? Colors.grey[700] : Colors.grey[300],
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              // Rating Bars
              Expanded(
                flex: 3,
                child: Column(
                  children: List.generate(5, (index) {
                    final stars = 5 - index;
                    return _buildRatingBar(
                      stars: stars,
                      percentage: stats.getPercentageForRating(stars),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRatingBar({required int stars, required double percentage}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          Text(
            '$stars',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(width: 4),
          Icon(Icons.star, color: Colors.amber[700], size: 10),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: widget.isDark ? Colors.grey[700] : Colors.grey[300],
                color: Colors.amber[700],
                minHeight: 5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.reviews_outlined, size: 48, color: widget.isDark ? Colors.grey[700] : Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No Reviews Yet',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              'Be the first to share your thoughts!',
              style: TextStyle(fontSize: 13, color: widget.isDark ? Colors.grey[500] : Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
