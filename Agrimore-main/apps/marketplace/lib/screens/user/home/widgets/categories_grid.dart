import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../../app/routes.dart';
import 'package:agrimore_core/agrimore_core.dart'; // Import the model
import '../../../../providers/category_provider.dart';
import '../../../../providers/theme_provider.dart';

class CategoriesGrid extends StatefulWidget {
  const CategoriesGrid({Key? key}) : super(key: key);

  @override
  State<CategoriesGrid> createState() => _CategoriesGridState();
}

class _CategoriesGridState extends State<CategoriesGrid>
    with TickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Consumer<CategoryProvider>(
      builder: (context, categoryProvider, child) {
        final categories = categoryProvider.categories;

        if (categories.isEmpty) {
          return const SizedBox.shrink();
        }

        // --- NEW: Take 12 categories for 2x6 grid ---
        final displayCategories = categories.take(12).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0), // Match padding
              child: _buildSectionHeader(
                context,
                categories.length,
                isDark,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 190, // 2 rows * 95px each
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  // --- NEW: 6 Columns ---
                  _buildCategoryColumn(
                    context,
                    displayCategories.sublist(0, displayCategories.length >= 2 ? 2 : displayCategories.length),
                  ),
                  if (displayCategories.length > 2)
                    _buildCategoryColumn(
                      context,
                      displayCategories.sublist(2, displayCategories.length >= 4 ? 4 : displayCategories.length),
                    ),
                  if (displayCategories.length > 4)
                    _buildCategoryColumn(
                      context,
                      displayCategories.sublist(4, displayCategories.length >= 6 ? 6 : displayCategories.length),
                    ),
                  if (displayCategories.length > 6)
                    _buildCategoryColumn(
                      context,
                      displayCategories.sublist(6, displayCategories.length >= 8 ? 8 : displayCategories.length),
                    ),
                  if (displayCategories.length > 8)
                    _buildCategoryColumn(
                      context,
                      displayCategories.sublist(8, displayCategories.length >= 10 ? 10 : displayCategories.length),
                    ),
                  // --- Column 6 ---
                  if (displayCategories.length > 10)
                    _buildCategoryColumn(
                      context,
                      displayCategories.sublist(10, displayCategories.length >= 12 ? 12 : displayCategories.length),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryColumn(BuildContext context, List<CategoryModel> categories) {
    return Column(
      children: categories.map((category) {
        return _buildCategoryCard(context, category);
      }).toList(),
    );
  }

  // --- COMPACT CARD DESIGN ---
  Widget _buildCategoryCard(BuildContext context, CategoryModel category) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pushNamed(
          context,
          AppRoutes.categoryProducts,
          arguments: category.id,
        );
      },
      child: Container(
        width: 80,  // <-- Compact width
        height: 85, // <-- Reduced height to fix overflow
        margin: const EdgeInsets.all(3),  // <-- Reduced margin
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,  // <-- Smaller icon
              height: 40, // <-- Smaller icon
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              // --- THIS IS THE CRASH FIX ---
              child: category.imageUrl != null && category.imageUrl!.isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: category.imageUrl!, // <-- Was category.iconUrl
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2,
                          ),
                        ),
                        errorWidget: (context, url, error) => Icon(
                          Icons.category_rounded,
                          color: AppColors.primary,
                          size: 22, // <-- Smaller icon
                        ),
                      ),
                    )
                  : Icon(
                      Icons.category_rounded,
                      color: AppColors.primary,
                      size: 22, // <-- Smaller icon
                    ),
              // --- END OF FIX ---
            ),
            const SizedBox(height: 6), // <-- Reduced space
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                category.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 10, // <-- Smaller text
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UNIFIED HEADER (like all_products_grid.dart) ---
  Widget _buildSectionHeader(BuildContext context, int totalCategories, bool isDark) {
    return Row(
      children: [
        AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, child) {
            return Container(
              width: 5,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          AppColors.primaryLight,
                          AppColors.primaryLight.withValues(alpha: 0.5),
                        ]
                      : [
                          AppColors.primary,
                          AppColors.primary.withValues(alpha: 0.5),
                        ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? AppColors.primaryLight : AppColors.primary)
                        .withOpacity(0.4 + (_shimmerController.value * 0.2)),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Shop by Category', // <-- Title changed
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                AppColors.primaryLight.withValues(alpha: 0.2),
                                AppColors.primaryLight.withValues(alpha: 0.1),
                              ]
                            : [
                                AppColors.primary.withValues(alpha: 0.15),
                                AppColors.primary.withValues(alpha: 0.08),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark
                            ? AppColors.primaryLight.withValues(alpha: 0.3)
                            : AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      '$totalCategories', // <-- Use totalCategories
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.primaryLight : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Explore our top categories', // <-- Subtitle changed
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        // Use the "See All" button
        TextButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pushNamed(context, AppRoutes.categories); // <-- Correct navigation
          },
          style: TextButton.styleFrom(
            foregroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Row(
            children: const [
              Text(
                'See All',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios_rounded, size: 12),
            ],
          ),
        ),
      ],
    );
  }
}