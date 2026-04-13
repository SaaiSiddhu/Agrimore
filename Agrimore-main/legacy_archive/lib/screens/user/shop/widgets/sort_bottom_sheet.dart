import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../app/themes/app_text_styles.dart';
import '../../../../providers/theme_provider.dart';

class SortBottomSheet extends StatelessWidget {
  final String currentSort;
  final Function(String) onSort;

  const SortBottomSheet({
    Key? key,
    required this.currentSort,
    required this.onSort,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // --- Theme Integration ---
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardColor, // Use theme-aware card color
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.grey[700]
                  : Colors.grey[300], // Theme-aware handle
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16), // Reduced padding
            child: Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.sort, // Font Awesome Icon
                  color: accentColor,
                  size: 18, // Reduced size
                ),
                const SizedBox(width: 12),
                Text(
                  'Sort By',
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? Colors.white
                        : AppColors.textPrimary, // Theme-aware text
                  ),
                ),
              ],
            ),
          ),

          // Sort Options
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), // Reduced padding
            child: Column(
              children: [
                _buildSortOption(
                  context,
                  'Newest First',
                  'newest',
                  FontAwesomeIcons.wandMagicSparkles,
                  isDark,
                  accentColor,
                ),
                _buildSortOption(
                  context,
                  'Price: Low to High',
                  'price_low',
                  FontAwesomeIcons.arrowUpWideShort,
                  isDark,
                  accentColor,
                ),
                _buildSortOption(
                  context,
                  'Price: High to Low',
                  'price_high',
                  FontAwesomeIcons.arrowDownWideShort,
                  isDark,
                  accentColor,
                ),
                _buildSortOption(
                  context,
                  'Top Rated',
                  'rating',
                  FontAwesomeIcons.solidStar,
                  isDark,
                  accentColor,
                ),
                _buildSortOption(
                  context,
                  'Most Popular',
                  'popular',
                  FontAwesomeIcons.fire,
                  isDark,
                  accentColor,
                ),
              ],
            ),
          ),

          // Safe area padding for the bottom
          Padding(
            padding: EdgeInsets.only(
              bottom: 12.0 + MediaQuery.of(context).padding.bottom, // Reduced
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET MADE MORE COMPACT ---
  Widget _buildSortOption(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    bool isDark,
    Color accentColor,
  ) {
    final isSelected = currentSort == value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0), // Reduced spacing
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onSort(value);
          Navigator.pop(context);
        },
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // Reduced padding
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withOpacity(0.1)
                : (isDark ? Colors.grey[850] : Colors.grey[50]),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? accentColor
                  : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
              width: isSelected ? 1.5 : 1, // Slightly thinner border
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6), // Reduced icon padding
                decoration: BoxDecoration(
                  color: isSelected
                      ? accentColor.withOpacity(0.15)
                      : (isDark ? Colors.grey[800] : Colors.grey[100]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: FaIcon(
                  icon,
                  color: isSelected
                      ? accentColor
                      : (isDark ? Colors.grey[300] : Colors.grey[600]),
                  size: 18, // Reduced icon size
                ),
              ),
              const SizedBox(width: 10), // Reduced spacing
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14, // Reduced font size
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Container(
                width: 22, // Reduced checkmark size
                height: 22, // Reduced checkmark size
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? accentColor
                        : (isDark ? Colors.grey[600]! : Colors.grey[400]!),
                    width: 2,
                  ),
                  color: isSelected ? accentColor : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check,
                        color: Colors.white, size: 14) // Reduced icon size
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}