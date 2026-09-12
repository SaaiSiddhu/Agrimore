// lib/screens/admin/banners/banner_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_core/agrimore_core.dart';

class BannerCard extends StatelessWidget {
  final BannerModel banner;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const BannerCard({
    Key? key,
    required this.banner,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  }) : super(key: key);

  static const Map<String, Color> _statusColors = {
    'Live': Colors.green,
    'Scheduled': Colors.blue,
    'Expired': Colors.grey,
    'Disabled': Colors.orange,
  };

  static const Map<String, IconData> _statusIcons = {
    'Live': Icons.check_circle,
    'Scheduled': Icons.schedule,
    'Expired': Icons.event_busy,
    'Disabled': Icons.pause_circle_filled,
  };

  @override
  Widget build(BuildContext context) {
    final isActive = banner.isActive;
    final status = banner.scheduleStatus;
    final isCategoryHero = banner.placement == BannerModel.placementCategoryHero;

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
                      child: const Icon(Icons.broken_image, size: 60, color: Colors.grey),
                    ),
                  ),
                ),
                // Gradient overlay for text readability
                Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withValues(alpha: 0.4), Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
                // Publication status chip — Live/Scheduled/Expired/Disabled,
                // derived from isActive + the schedule window rather than a
                // separately-stored status.
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (_statusColors[status] ?? Colors.grey).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _statusIcons[status] ?? Icons.help_outline,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          status,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                // Placement chip — which surface this banner can appear on.
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCategoryHero ? Icons.category_outlined : Icons.home_outlined,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isCategoryHero ? 'Category Hero' : 'Home Hero',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
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
                  const SizedBox(height: 14),

                  // Control Row (Switch + Actions)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Toggle switch with label
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

                      // Edit / Delete buttons
                      Row(
                        children: [
                          Tooltip(
                            message: 'Edit Banner',
                            child: IconButton(
                              onPressed: onEdit,
                              icon: const Icon(Icons.edit, color: Colors.blueAccent),
                            ),
                          ),
                          Tooltip(
                            message: 'Delete Banner',
                            child: IconButton(
                              onPressed: onDelete,
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
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
    ).animate().fadeIn(duration: 400.ms).moveY(begin: 15, end: 0, curve: Curves.easeOut);
  }
}
