import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:agrimore_ui/agrimore_ui.dart';


class SponsoredBannerCard extends StatelessWidget {
  final SponsoredBannerModel banner;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const SponsoredBannerCard({
    Key? key,
    required this.banner,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isActive = banner.isActive;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Image with overlay
            Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 180,
                  child: Image.network(
                    banner.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.broken_image,
                          size: 60, color: Colors.grey),
                    ),
                  ),
                ),
                // Gradient overlay
                Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.4),
                        Colors.transparent
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
                // Active status chip
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.green.withOpacity(0.9)
                          : Colors.orange.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isActive
                              ? Icons.check_circle
                              : Icons.pause_circle_filled,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isActive ? 'Active' : 'Inactive',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                // Sponsored Badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.campaign_rounded,
                            color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Sponsored',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Details section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    banner.title,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    banner.subtitle,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2,
                            size: 14, color: Colors.blue[700]),
                        const SizedBox(width: 6),
                        Text(
                          'Product: ${banner.productId}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Control Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Switch(
                            value: isActive,
                            onChanged: (_) => onToggle(),
                            activeColor: AppColors.primary,
                          ),
                          Text(
                            isActive ? "Enabled" : "Disabled",
                            style: TextStyle(
                              color: isActive ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      Row(
                        children: [
                          Tooltip(
                            message: 'Edit Banner',
                            child: IconButton(
                              onPressed: onEdit,
                              icon: const Icon(Icons.edit,
                                  color: Colors.blueAccent),
                            ),
                          ),
                          Tooltip(
                            message: 'Delete Banner',
                            child: IconButton(
                              onPressed: onDelete,
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .moveY(begin: 15, end: 0, curve: Curves.easeOut);
  }
}
