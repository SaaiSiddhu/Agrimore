import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../../providers/product_provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'widgets/search_bar_widget.dart';
import 'widgets/search_filters.dart';
import 'widgets/search_product_card.dart';

class SearchResultsScreen extends StatefulWidget {
  final String query;

  const SearchResultsScreen({
    Key? key,
    required this.query,
  }) : super(key: key);

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;
  List<ProductModel> _filteredProducts = [];
  bool _isLoading = true;
  String _sortBy = 'relevance';
  Map<String, dynamic> _filters = {};

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.query);
    _searchFocusNode = FocusNode();
    _performSearch();
  }

  Future<void> _performSearch() async {
    setState(() => _isLoading = true);

    try {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      await productProvider.fetchProducts();

      final products = productProvider.products ?? [];
      final query = _searchController.text.toLowerCase().trim();

      _filteredProducts = products.where((product) {
        final nameMatch = product.name.toLowerCase().contains(query);
        final categoryMatch = product.category.toLowerCase().contains(query);
        final descriptionMatch = product.description?.toLowerCase().contains(query) ?? false;

        return nameMatch || categoryMatch || descriptionMatch;
      }).toList();

      _applySorting();
    } catch (e) {
      debugPrint('Error searching products: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applySorting() {
    switch (_sortBy) {
      case 'price_low_high':
        _filteredProducts.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_high_low':
        _filteredProducts.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'rating':
        _filteredProducts.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
        break;
      case 'newest':
        _filteredProducts.sort((a, b) => (b.createdAt ?? DateTime.now())
            .compareTo(a.createdAt ?? DateTime.now()));
        break;
      default: // relevance
        break;
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SearchFilters(
        currentFilters: _filters,
        onApplyFilters: (filters) {
          setState(() {
            _filters = filters;
            _applyFilters();
          });
        },
      ),
    );
  }

  void _applyFilters() {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final products = productProvider.products ?? [];
    final query = _searchController.text.toLowerCase().trim();

    _filteredProducts = products.where((product) {
      // Text search
      final nameMatch = product.name.toLowerCase().contains(query);
      final categoryMatch = product.category.toLowerCase().contains(query);
      if (!nameMatch && !categoryMatch) return false;

      // Price filter
      if (_filters.containsKey('minPrice')) {
        if (product.price < _filters['minPrice']) return false;
      }
      if (_filters.containsKey('maxPrice')) {
        if (product.price > _filters['maxPrice']) return false;
      }

      // Rating filter
      if (_filters.containsKey('minRating')) {
        if ((product.rating ?? 0) < _filters['minRating']) return false;
      }

      // Category filter
      if (_filters.containsKey('categories') && 
          (_filters['categories'] as List).isNotEmpty) {
        if (!(_filters['categories'] as List).contains(product.category)) {
          return false;
        }
      }

      return true;
    }).toList();

    _applySorting();
    setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Hero(
              tag: 'search-bar',
              child: Material(
                color: Colors.transparent,
                child: SearchBarWidget(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onSubmitted: (query) {
                    _performSearch();
                  },
                  onClear: () {
                    _searchController.clear();
                    setState(() => _filteredProducts = []);
                  },
                  onBack: () => Navigator.pop(context),
                ),
              ),
            ),

            // Results Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isLoading
                        ? 'Searching...'
                        : '${_filteredProducts.length} results found',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      // Sort Button
                      _buildActionButton(
                        icon: Icons.sort_rounded,
                        label: 'Sort',
                        onTap: _showSortSheet,
                      ),
                      const SizedBox(width: 8),
                      // Filter Button
                      _buildActionButton(
                        icon: Icons.tune_rounded,
                        label: 'Filter',
                        onTap: _showFilterSheet,
                        badge: _filters.isNotEmpty ? _filters.length : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Results Grid
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _filteredProducts.isEmpty
                      ? _buildEmptyState()
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          physics: const BouncingScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.65,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            return SearchProductCard(
                              product: _filteredProducts[index],
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    int? badge,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                if (badge != null)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        badge.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sort By',
                    style: AppTextStyles.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSortOption('Relevance', 'relevance'),
                  _buildSortOption('Price: Low to High', 'price_low_high'),
                  _buildSortOption('Price: High to Low', 'price_high_low'),
                  _buildSortOption('Customer Rating', 'rating'),
                  _buildSortOption('Newest First', 'newest'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSortOption(String label, String value) {
    final isSelected = _sortBy == value;
    return ListTile(
      onTap: () {
        setState(() {
          _sortBy = value;
          _applySorting();
        });
        Navigator.pop(context);
      },
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? AppColors.primary : AppColors.grey,
      ),
      title: Text(
        label,
        style: AppTextStyles.bodyMedium.copyWith(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 80,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No results found',
            style: AppTextStyles.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Try adjusting your search or filter to find what you\'re looking for',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
