import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../models/review_model.dart';
import '../../../../providers/review_provider.dart';
import '../../../../services/auth_service.dart';

class ReviewCard extends StatelessWidget {
  final ReviewModel review;
  final bool isDark;

  const ReviewCard({
    Key? key,
    required this.review,
    required this.isDark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white70 : Colors.black87;
    // ✅ FIXED: Added ! to Colors.grey[]
    final lightTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, lightTextColor),
            const SizedBox(height: 12),
            _buildRating(accentColor),
            const SizedBox(height: 8),
            Text(
              review.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              review.comment,
              style: TextStyle(
                fontSize: 13,
                color: textColor,
                height: 1.5,
              ),
            ),
            if (review.imageUrls.isNotEmpty)
              _buildReviewImages(context, review.imageUrls),
            const SizedBox(height: 12),
            Divider(color: isDark ? Colors.grey[800] : Colors.grey[200]),
            const SizedBox(height: 8),
            _buildFooter(context, lightTextColor),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color lightTextColor) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isOwner = authService.currentUserId == review.userId;

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
          backgroundImage: review.userAvatar.isNotEmpty
              ? NetworkImage(review.userAvatar)
              : null,
          child: review.userAvatar.isEmpty
              ? Icon(Icons.person, color: isDark ? Colors.grey[400] : Colors.grey[600])
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                review.userName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                DateFormat('MMM dd, yyyy').format(review.createdAt),
                style: TextStyle(fontSize: 12, color: lightTextColor),
              ),
            ],
          ),
        ),
        if (isOwner)
          PopupMenuButton(
            icon: Icon(Icons.more_vert, color: lightTextColor, size: 20),
            color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: const [
                    Icon(Icons.edit_outlined, size: 18, color: AppColors.info),
                    SizedBox(width: 10),
                    Text('Edit'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: const [
                    Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                    SizedBox(width: 10),
                    Text('Delete', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'delete') {
                _showDeleteDialog(context, review.productId, review.reviewId);
              } else if (value == 'edit') {
                // TODO: Implement edit functionality
              }
            },
          ),
      ],
    );
  }

  Widget _buildRating(Color accentColor) {
    return Row(
      children: [
        Row(
          children: List.generate(5, (index) {
            return Icon(
              index < review.rating ? Icons.star_rounded : Icons.star_border_rounded,
              color: Colors.amber[700],
              size: 18,
            );
          }),
        ),
        if (review.isVerifiedPurchase) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Verified Purchase',
              style: TextStyle(
                color: accentColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReviewImages(BuildContext context, List<String> imageUrls) {
    return Container(
      height: 80,
      margin: const EdgeInsets.only(top: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrls[index],
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 80,
                  height: 80,
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  child: Icon(Icons.broken_image, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFooter(BuildContext context, Color lightTextColor) {
    final reviewProvider = Provider.of<ReviewProvider>(context, listen: false);
    final userId = Provider.of<AuthService>(context, listen: false).currentUserId;

    bool isHelpful = review.helpfulUsers.contains(userId);
    bool isUnhelpful = review.unhelpfulUsers.contains(userId);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'Helpful?',
          style: TextStyle(fontSize: 12, color: lightTextColor, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 8),
        _buildHelpfulButton(
          context: context,
          text: review.helpfulCount.toString(),
          icon: isHelpful ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
          color: isHelpful ? (isDark ? AppColors.primaryLight : AppColors.primary) : lightTextColor,
          onTap: () {
            if (userId != null) {
              reviewProvider.markHelpful(review.productId, review.reviewId, userId, true);
            }
          },
        ),
        const SizedBox(width: 8),
        _buildHelpfulButton(
          context: context,
          text: review.unhelpfulCount.toString(),
          icon: isUnhelpful ? Icons.thumb_down_alt_rounded : Icons.thumb_down_alt_outlined,
          color: isUnhelpful ? AppColors.error : lightTextColor,
          onTap: () {
             if (userId != null) {
              reviewProvider.markHelpful(review.productId, review.reviewId, userId, false);
            }
          },
        ),
      ],
    );
  }

  Widget _buildHelpfulButton({
    required BuildContext context,
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String productId, String reviewId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Review'),
        content: const Text('Are you sure you want to delete this review? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Provider.of<ReviewProvider>(context, listen: false)
                  .deleteReview(productId, reviewId);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}