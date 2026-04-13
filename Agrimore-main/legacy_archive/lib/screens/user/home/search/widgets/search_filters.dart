import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../../app/themes/app_colors.dart';
import '../../../../../app/themes/app_text_styles.dart';
import '../../../../../providers/category_provider.dart';

class SearchFilters extends StatefulWidget {
  final Map<String, dynamic> currentFilters;
  final Function(Map<String, dynamic>) onApplyFilters;

  const SearchFilters({
    Key? key,
    required this.currentFilters,
    required this.onApplyFilters,
  }) : super(key: key);

  @override
  State<SearchFilters> createState() => _SearchFiltersState();
}

class _SearchFiltersState extends State<SearchFilters> {
  late Map<String, dynamic> _filters;
  RangeValues _priceRange = const RangeValues(0, 10000);
  double _minRating = 0;
  List<String> _selectedCategories = [];

  @override
  void initState() {
    super.initState();
    _filters = Map.from(widget.currentFilters);
    
    if (_filters.containsKey('minPrice') && _filters.containsKey('maxPrice')) {
      _priceRange = RangeValues(
        _filters['minPrice'].toDouble(),
        _filters['maxPrice'].toDouble(),
      );
    }
    
    if (_filters.containsKey('minRating')) {
      _minRating = _filters['minRating'].toDouble();
    }
    
    if (_filters.containsKey('categories')) {
      _selectedCategories = List<String>.from(_filters['categories']);
    }
  }

  void _applyFilters() {
    final filters = <String, dynamic>{};
    
    if (_priceRange.start > 0 || _priceRange.end < 10000) {
      filters['minPrice'] = _priceRange.start;
      filters['maxPrice'] = _priceRange.end;
    }
    
    if (_minRating > 0) {
      filters['minRating'] = _minRating;
    }
    
    if (_selectedCategories.isNotEmpty) {
      filters['categories'] = _selectedCategories;
    }
    
    widget.onApplyFilters(filters);
    Navigator.pop(context);
  }

  void _clearFilters() {
    setState(() {
      _priceRange = const RangeValues(0, 10000);
      _minRating = 0;
      _selectedCategories = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
              color: AppColors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filters',
                  style: AppTextStyles.headlineMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _clearFilters();
                  },
                  child: Text(
                    'Clear All',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: AppColors.lightGrey),

          // Filters Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Price Range
                  _buildSectionTitle('Price Range'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹${_priceRange.start.toInt()}',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹${_priceRange.end.toInt()}',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  RangeSlider(
                    values: _priceRange,
                    min: 0,
                    max: 10000,
                    divisions: 100,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.primary.withValues(alpha: 0.2),
                    onChanged: (values) {
                      setState(() => _priceRange = values);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Rating
                  _buildSectionTitle('Minimum Rating'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [1, 2, 3, 4, 5].map((rating) {
                      final isSelected = _minRating >= rating;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _minRating = rating.toDouble();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.lightGrey,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Text(
                                rating.toString(),
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.star_rounded,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.amber,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Categories
                  _buildSectionTitle('Categories'),
                  const SizedBox(height: 16),
                  Consumer<CategoryProvider>(
                    builder: (context, categoryProvider, child) {
                      final categories = categoryProvider.categories ?? [];
                      
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: categories.map((category) {
                          final isSelected = _selectedCategories.contains(category.name);
                          
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                if (isSelected) {
                                  _selectedCategories.remove(category.name);
                                } else {
                                  _selectedCategories.add(category.name);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.grey.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  if (isSelected) const SizedBox(width: 6),
                                  Text(
                                    category.name,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Apply Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _applyFilters();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                'Apply Filters',
                style: AppTextStyles.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: AppTextStyles.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
