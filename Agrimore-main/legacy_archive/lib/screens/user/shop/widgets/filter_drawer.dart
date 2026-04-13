import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../app/themes/app_text_styles.dart';
import '../../../../models/category_model.dart';
import '../../../../providers/category_provider.dart';
import '../../../../providers/theme_provider.dart';

class FilterDrawer extends StatefulWidget {
  final Function(Map<String, dynamic>) onApply;
  // ✅ NEW: Pass in initial values so the filter can be stateful
  final Map<String, dynamic> initialFilters;

  const FilterDrawer({
    Key? key,
    required this.onApply,
    this.initialFilters = const {},
  }) : super(key: key);

  @override
  State<FilterDrawer> createState() => _FilterDrawerState();
}

class _FilterDrawerState extends State<FilterDrawer>
    with SingleTickerProviderStateMixin {
  late RangeValues _priceRange;
  late double _minRating;
  late List<String> _selectedCategories;
  late bool _inStock;
  // ✅ NEW: Extra features from ProductModel
  late bool _isNew;
  late bool _isVerified;
  late bool _isTrending;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    // ✅ NEW: Initialize state from initialFilters
    _priceRange = widget.initialFilters['priceRange'] ?? const RangeValues(0, 10000);
    _minRating = widget.initialFilters['minRating'] ?? 0.0;
    _selectedCategories = List<String>.from(widget.initialFilters['categories'] ?? []);
    _inStock = widget.initialFilters['inStock'] ?? false;
    _isNew = widget.initialFilters['isNew'] ?? false;
    _isVerified = widget.initialFilters['isVerified'] ?? false;
    _isTrending = widget.initialFilters['isTrending'] ?? false;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // --- Theme Integration ---
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.grey[50];

    return Drawer(
      backgroundColor: backgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            // ✅ THEMED HEADER
            _buildHeader(isDark, accentColor),

            // ✅ FILTERS CONTENT
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // Price Range
                  _buildPriceRangeSection(isDark, accentColor),

                  // Rating
                  _buildRatingSection(isDark, accentColor),

                  // ✅ DYNAMIC CATEGORIES (using SortBottomSheet style)
                  _buildCategoriesSection(isDark, accentColor),

                  // ✅ NEW: Availability & Tags (extra features)
                  _buildTagsSection(isDark, accentColor),
                ],
              ),
            ),

            // ✅ THEMED APPLY BUTTON
            _buildApplyButton(isDark, accentColor, cardColor),
          ],
        ),
      ),
    );
  }

  // ✅ THEMED HEADER
  Widget _buildHeader(bool isDark, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor,
            accentColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const FaIcon(
              FontAwesomeIcons.sliders,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filters',
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Refine your search',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _resetFilters,
            icon: const FaIcon(FontAwesomeIcons.rotateLeft,
                color: Colors.white, size: 14),
            label: const Text(
              'Reset',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper to build section titles ---
  Widget _buildSectionTitle(
      IconData icon, String title, bool isDark, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12, left: 4),
      child: Row(
        children: [
          FaIcon(icon, color: accentColor, size: 16),
          const SizedBox(width: 10),
          Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ COMPACT PRICE RANGE SECTION
  Widget _buildPriceRangeSection(bool isDark, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
            FontAwesomeIcons.indianRupeeSign, 'Price Range', isDark, accentColor),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
          ),
          child: Column(
            children: [
              RangeSlider(
                values: _priceRange,
                min: 0,
                max: 10000,
                divisions: 100,
                activeColor: accentColor,
                inactiveColor: accentColor.withOpacity(0.2),
                labels: RangeLabels(
                  '₹${_priceRange.start.round()}',
                  '₹${_priceRange.end.round()}',
                ),
                onChanged: (values) {
                  setState(() {
                    _priceRange = values;
                  });
                  HapticFeedback.selectionClick();
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₹${_priceRange.start.round()}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                  Text(
                    '₹${_priceRange.end.round()}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ COMPACT RATING SECTION
  Widget _buildRatingSection(bool isDark, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
            FontAwesomeIcons.solidStar, 'Minimum Rating', isDark, accentColor),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(5, (index) {
              final rating = index + 1;
              final isSelected = _minRating == rating.toDouble();
              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _minRating = isSelected ? 0 : rating.toDouble();
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accentColor
                        : (isDark ? Colors.grey[850] : Colors.grey[50]),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? accentColor
                          : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FaIcon(
                        FontAwesomeIcons.solidStar,
                        size: 14,
                        color: isSelected ? Colors.white : Colors.amber[700],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$rating+',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.grey[200] : Colors.grey[800]),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // ✅ DYNAMIC CATEGORIES (USING SortBottomSheet STYLE)
  Widget _buildCategoriesSection(bool isDark, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
            FontAwesomeIcons.layerGroup, 'Categories', isDark, accentColor),
        Consumer<CategoryProvider>(
          builder: (context, categoryProvider, child) {
            if (categoryProvider.isLoading) {
              return const Center(
                  child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator()));
            }
            if (categoryProvider.categories.isEmpty) {
              return Center(
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('No categories available',
                          style: TextStyle(color: Colors.grey[600]))));
            }

            return Column(
              children: categoryProvider.categories.map((category) {
                return _buildCategoryOption(
                  context,
                  category.name,
                  category.id,
                  // ⬇️ --- FIXED LINE --- ⬇️
                  // Use a default icon since we can't map the string name
                  FontAwesomeIcons.tag,
                  // ⬆️ --- FIXED LINE --- ⬆️
                  isDark,
                  accentColor,
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ✅ CATEGORY OPTION (Style copied from SortBottomSheet)
  Widget _buildCategoryOption(
    BuildContext context,
    String title,
    String categoryId,
    IconData icon,
    bool isDark,
    Color accentColor,
  ) {
    final isSelected = _selectedCategories.contains(categoryId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            if (isSelected) {
              _selectedCategories.remove(categoryId);
            } else {
              _selectedCategories.add(categoryId);
            }
          });
        },
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withOpacity(0.1)
                : (isDark ? Colors.grey[850] : Colors.grey[50]),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? accentColor
                  : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
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
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Container(
                width: 22,
                height: 22,
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
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ NEW TAGS SECTION (for all boolean filters)
  Widget _buildTagsSection(bool isDark, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
            FontAwesomeIcons.tags, 'Filter by Tag', isDark, accentColor),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
          ),
          child: Column(
            children: [
              _buildSwitchOption(
                'In Stock Only',
                'Show only available products',
                _inStock,
                (value) => setState(() => _inStock = value),
                isDark,
                accentColor,
              ),
              _buildSwitchOption(
                'New Arrivals',
                'Show recently added products',
                _isNew,
                (value) => setState(() => _isNew = value),
                isDark,
                accentColor,
              ),
              _buildSwitchOption(
                'Verified Products',
                'Show only verified items',
                _isVerified,
                (value) => setState(() => _isVerified = value),
                isDark,
                accentColor,
              ),
              _buildSwitchOption(
                'Trending Now',
                'Show popular products',
                _isTrending,
                (value) => setState(() => _isTrending = value),
                isDark,
                accentColor,
                hideDivider: true, // No divider on the last item
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Helper for compact Switch rows ---
  Widget _buildSwitchOption(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
    bool isDark,
    Color accentColor, {
    bool hideDivider = false,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(!value);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[200] : Colors.grey[800],
                        ),
                      ),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch(
                  value: value,
                  onChanged: (val) {
                    HapticFeedback.selectionClick();
                    onChanged(val);
                  },
                  activeColor: accentColor,
                ),
              ],
            ),
          ),
        ),
        if (!hideDivider)
          Divider(color: isDark ? Colors.grey[800] : Colors.grey[200], height: 1),
      ],
    );
  }

  // ✅ THEMED APPLY BUTTON
  Widget _buildApplyButton(bool isDark, Color accentColor, Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
        ),
      ),
      child: ElevatedButton(
        onPressed: _applyFilters,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: isDark ? Colors.black : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          minimumSize: const Size(double.infinity, 50),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            FaIcon(FontAwesomeIcons.check, size: 18),
            SizedBox(width: 12),
            Text(
              'Apply Filters',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _resetFilters() {
    HapticFeedback.mediumImpact();
    setState(() {
      _priceRange = const RangeValues(0, 10000);
      _minRating = 0;
      _selectedCategories = [];
      _inStock = false;
      _isNew = false;
      _isVerified = false;
      _isTrending = false;
    });
    // Also apply the reset immediately
    widget.onApply({
      'priceRange': const RangeValues(0, 10000),
      'minRating': 0.0,
      'categories': [],
      'inStock': false,
      'isNew': false,
      'isVerified': false,
      'isTrending': false,
    });
    Navigator.pop(context);
  }

  void _applyFilters() {
    HapticFeedback.mediumImpact();
    widget.onApply({
      'priceRange': _priceRange,
      'minRating': _minRating,
      'categories': _selectedCategories,
      'inStock': _inStock,
      'isNew': _isNew,
      'isVerified': _isVerified,
      'isTrending': _isTrending,
    });
    Navigator.pop(context);
  }
}