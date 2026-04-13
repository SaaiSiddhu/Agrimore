import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../app/themes/app_text_styles.dart';
import '../../../../models/review_model.dart';
import '../../../../providers/review_provider.dart';
import '../../../../providers/theme_provider.dart';
import '../../../../services/auth_service.dart';
import 'add_review_dialog.dart';
import 'review_card.dart'; // ✅ NEW IMPORT

class ReviewsSection extends StatefulWidget {
  final String productId;
  final String productName;
  final bool isDark;

  const ReviewsSection({
    Key? key,
    required this.productId,
    required this.productName,
    required this.isDark,
  }) : super(key: key);

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  @override
  void initState() {
    super.initState();
    // Load stats when the widget is first initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ReviewProvider>(context, listen: false)
          .loadReviewStats(widget.productId);
    });
  }

  void _showAddReviewDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        // ✅ FIXED: Pass the providers from the *current* context into the dialog's context
        return MultiProvider(
          providers: [
            // ✅ FIXED: AuthService is NOT a ChangeNotifier, use Provider.value
            Provider.value(
              value: context.read<AuthService>(),
            ),
            ChangeNotifierProvider.value(
              value: context.read<ThemeProvider>(),
            ),
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
    
    // ✅ FIXED: Wrapped in a Column with Expanded to prevent layout overflow
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        
        // Reviews List
        Expanded(
          child: StreamProvider<List<ReviewModel>>.value(
            value: Provider.of<ReviewProvider>(context, listen: false)
                .getReviewsStream(widget.productId),
            initialData: const [],
            child: Consumer<List<ReviewModel>>(
              builder: (context, reviews, child) {
                if (reviews.isEmpty) {
                  return _buildEmptyState();
                }
                
                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: reviews.length,
                  itemBuilder: (context, index) {
                    return ReviewCard( // ✅ This widget now exists
                      review: reviews[index],
                      isDark: widget.isDark,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return Consumer<ReviewProvider>(
      builder: (context, provider, child) {
        if (provider.reviewStats == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final stats = provider.reviewStats!;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.isDark ? Colors.grey[800]! : Colors.grey[200]!)
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
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: widget.isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) => Icon(
                        i < stats.averageRating.floor() ? Icons.star_rounded : Icons.star_border_rounded,
                        color: Colors.amber[700],
                        size: 16,
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
                height: 100,
                color: widget.isDark ? Colors.grey[800] : Colors.grey[200],
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
                      isDark: widget.isDark,
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

  Widget _buildRatingBar({required int stars, required double percentage, required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            '$stars',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(width: 4),
          Icon(Icons.star, color: Colors.amber[700], size: 12),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                color: Colors.amber[700],
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.reviews_outlined, size: 60, color: widget.isDark ? Colors.grey[700] : Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No Reviews Yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white70 : Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to share your thoughts!',
            style: TextStyle(color: widget.isDark ? Colors.grey[500] : Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}