import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../../providers/review_provider.dart';
import '../../../../providers/auth_provider.dart' as app_auth;
import 'add_review_dialog.dart';
import 'package:agrimore_services/agrimore_services.dart';

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
            // SELLER-ACCOUNT-1a: the seller's public reply.
            if (review.sellerReplyText != null &&
                review.sellerReplyText!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Response from the seller',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: textColor),
                    ),
                    const SizedBox(height: 4),
                    Text(review.sellerReplyText!,
                        style: TextStyle(
                            fontSize: 13, color: textColor, height: 1.4)),
                  ],
                ),
              ),
            ],
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
    final auth = context.watch<app_auth.AuthProvider>();
    final epoch = auth.sessionVersion;
    bool owns() =>
        context.mounted &&
        identical(context.read<app_auth.AuthProvider>(), auth) &&
        identical(context.read<AuthService>(), authService) &&
        auth.isSessionCurrent(review.userId, epoch) &&
        authService.currentUserId == review.userId;
    final isOwner = owns();

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
          backgroundImage: review.userAvatar.isNotEmpty
              ? NetworkImage(review.userAvatar)
              : null,
          child: review.userAvatar.isEmpty
              ? Icon(Icons.person,
                  color: isDark ? Colors.grey[400] : Colors.grey[600])
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
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: lightTextColor, size: 20),
            color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                    Icon(Icons.delete_outline,
                        size: 18, color: AppColors.error),
                    SizedBox(width: 10),
                    Text('Delete', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (!owns()) return;
              if (value == 'delete') {
                _showDeleteDialog(context, review.productId, review.reviewId);
              } else if (value == 'edit') {
                _showEditDialog(context, review);
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
              index < review.rating
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
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
              color: accentColor.withValues(alpha: 0.1),
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
                  child: Icon(Icons.broken_image,
                      color: isDark ? Colors.grey[600] : Colors.grey[400]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFooter(BuildContext context, Color lightTextColor) {
    final reviewProvider = context.watch<ReviewProvider>();
    final service = context.read<AuthService>();
    final auth = context.watch<app_auth.AuthProvider>();
    final userId = service.currentUserId;
    final epoch = auth.sessionVersion;
    final productId = review.productId;
    final reviewId = review.reviewId;
    final route = ModalRoute.of(context);
    bool current() =>
        context.mounted &&
        userId != null &&
        (route?.isCurrent ?? false) &&
        identical(context.read<ReviewProvider>(), reviewProvider) &&
        identical(context.read<AuthService>(), service) &&
        identical(context.read<app_auth.AuthProvider>(), auth) &&
        auth.isSessionCurrent(userId, epoch) &&
        service.currentUserId == userId &&
        context.widget is ReviewCard &&
        (context.widget as ReviewCard).review.productId == productId &&
        (context.widget as ReviewCard).review.reviewId == reviewId;
    final busy = reviewProvider.isVoting(productId, reviewId, userId);
    Future<void> vote(bool helpful) async {
      if (userId == null ||
          !current() ||
          reviewProvider.isVoting(productId, reviewId, userId)) {
        return;
      }
      try {
        await reviewProvider.markHelpful(productId, reviewId, userId, helpful,
            isSessionCurrent: current);
      } catch (_) {
        if (context.mounted && current()) {
          SnackbarHelper.showError(
              context, 'Could not save your vote. Try again.');
        }
      }
    }

    final isHelpful = review.helpfulUsers.contains(userId);
    final isUnhelpful = review.unhelpfulUsers.contains(userId);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          busy ? 'Saving vote...' : 'Helpful?',
          style: TextStyle(
              fontSize: 12, color: lightTextColor, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 8),
        _buildHelpfulButton(
          context: context,
          text: review.helpfulCount.toString(),
          icon: isHelpful
              ? Icons.thumb_up_alt_rounded
              : Icons.thumb_up_alt_outlined,
          color: isHelpful
              ? (isDark ? AppColors.primaryLight : AppColors.primary)
              : lightTextColor,
          onTap: current() && !busy ? () => vote(true) : null,
        ),
        const SizedBox(width: 8),
        _buildHelpfulButton(
          context: context,
          text: review.unhelpfulCount.toString(),
          icon: isUnhelpful
              ? Icons.thumb_down_alt_rounded
              : Icons.thumb_down_alt_outlined,
          color: isUnhelpful ? AppColors.error : lightTextColor,
          onTap: current() && !busy ? () => vote(false) : null,
        ),
      ],
    );
  }

  Widget _buildHelpfulButton({
    required BuildContext context,
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
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

  void _showDeleteDialog(
      BuildContext context, String productId, String reviewId) {
    final auth = context.read<app_auth.AuthProvider>();
    final service = context.read<AuthService>();
    final provider = context.read<ReviewProvider>();
    final owner = review.userId;
    final scope = Navigator.of(context).context;
    final originRoute = ModalRoute.of(context);
    final epoch = auth.sessionVersion;
    bool owns() =>
        scope.mounted &&
        (originRoute?.isActive ?? false) &&
        identical(scope.read<app_auth.AuthProvider>(), auth) &&
        identical(scope.read<AuthService>(), service) &&
        identical(scope.read<ReviewProvider>(), provider) &&
        auth.isSessionCurrent(owner, epoch) &&
        service.currentUserId == owner;
    if (!owns()) return;
    showDialog<void>(
        context: context,
        builder: (_) => _DeleteReviewDialog(
            isDark: isDark,
            owns: owns,
            delete: (guard) => provider.deleteReview(productId, reviewId,
                isSessionCurrent: guard)));
  }

  void _showEditDialog(BuildContext context, ReviewModel review) {
    showDialog<bool>(
        context: context,
        builder: (_) => AddReviewDialog(
            productId: review.productId,
            productName: 'Product review',
            reviewToEdit: review));
  }
}

class _DeleteReviewDialog extends StatefulWidget {
  const _DeleteReviewDialog(
      {required this.isDark, required this.owns, required this.delete});
  final bool isDark;
  final bool Function() owns;
  final Future<void> Function(bool Function()) delete;
  @override
  State<_DeleteReviewDialog> createState() => _DeleteReviewDialogState();
}

class _DeleteReviewDialogState extends State<_DeleteReviewDialog> {
  bool _busy = false;
  bool _canAct() =>
      mounted && widget.owns() && (ModalRoute.of(context)?.isCurrent ?? false);
  Future<void> _submit() async {
    if (_busy || !_canAct()) return;
    setState(() {
      _busy = true;
    });
    try {
      await widget.delete(_canAct);
      if (mounted && _canAct()) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted && _canAct()) {
        SnackbarHelper.showError(
            context, 'Unable to delete your review. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<app_auth.AuthProvider>();
    final owns = widget.owns();
    return PopScope(
        canPop: !_busy,
        child: AlertDialog(
          backgroundColor:
              widget.isDark ? const Color(0xFF2C2C2C) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Review'),
          content: Text(!owns
              ? 'Your session changed. Close this dialog and try again.'
              : 'Are you sure you want to delete this review? This action cannot be undone.'),
          actions: [
            TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: Text(owns ? 'Cancel' : 'Close')),
            ElevatedButton(
                onPressed: _busy || !owns ? null : _submit,
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: Text(_busy ? 'Deleting…' : 'Delete')),
          ],
        ));
  }
}
