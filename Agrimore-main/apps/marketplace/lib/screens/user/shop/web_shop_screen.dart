import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../app/routes.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/category_provider.dart';
import 'widgets/product_card.dart';

class WebShopScreen extends StatefulWidget {
  final String? categoryId;
  final bool showRecentlyViewed;
  final bool showDeals;

  const WebShopScreen({
    Key? key,
    this.categoryId,
    this.showRecentlyViewed = false,
    this.showDeals = false,
  }) : super(key: key);

  @override
  State<WebShopScreen> createState() => _WebShopScreenState();
}

class _WebShopScreenState extends State<WebShopScreen> {
  String _selectedCategory = 'All';
  String _sortBy = 'newest';
  RangeValues _priceRange = const RangeValues(0, 10000);

  @override
  void initState() {
    super.initState();
    
    // ✅ Set initial category if provided
    if (widget.categoryId != null) {
      _selectedCategory = widget.categoryId!;
    }
    
    _loadData();
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<ProductProvider>(context, listen: false).loadProducts();
      Provider.of<CategoryProvider>(context, listen: false).loadCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Dynamic title based on screen type
    String title = 'Shop';
    if (widget.showRecentlyViewed) {
      title = 'Recently Viewed';
    } else if (widget.showDeals) {
      title = 'Deals For You';
    } else if (widget.categoryId != null && widget.categoryId != 'All') {
      title = widget.categoryId!;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          title,
          style: AppTextStyles.headlineMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: () {
                AppRoutes.navigateTo(context, AppRoutes.search);
              },
              icon: const Icon(Icons.search),
              label: const Text('Search Products'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // ✅ Hide sidebar if showing recently viewed or deals
          if (!widget.showRecentlyViewed && !widget.showDeals)
            Container(
              width: 280,
              color: Colors.white,
              child: _buildSidebar(),
            ),
          Expanded(
            child: Consumer<ProductProvider>(
              builder: (context, productProvider, child) {
                if (productProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final products = _getFilteredProducts(productProvider);

                if (products.isEmpty) {
                  return _buildEmptyState();
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(40),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 0.6,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    return ProductCard(product: products[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Filters',
          style: AppTextStyles.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Categories',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Consumer<CategoryProvider>(
          builder: (context, categoryProvider, child) {
            final categories = ['All', ...categoryProvider.categories.map((c) => c.name)];
            return Column(
              children: categories.map((category) {
                final isSelected = _selectedCategory == category;
                return RadioListTile<String>(
                  title: Text(category),
                  value: category,
                  groupValue: _selectedCategory,
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                    });
                  },
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          'Price Range',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        RangeSlider(
          values: _priceRange,
          min: 0,
          max: 10000,
          divisions: 100,
          activeColor: AppColors.primary,
          labels: RangeLabels(
            '₹${_priceRange.start.round()}',
            '₹${_priceRange.end.round()}',
          ),
          onChanged: (values) {
            setState(() {
              _priceRange = values;
            });
          },
        ),
      ],
    );
  }

  // ✅ FIXED: Added support for deals and recently viewed
  List<ProductModel> _getFilteredProducts(ProductProvider provider) {
    var products = provider.products;
    
    // ✅ Filter for recently viewed
    if (widget.showRecentlyViewed) {
      products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return products.take(20).toList();
    }
    
    // ✅ Filter for deals
    if (widget.showDeals) {
      products = products.where((p) => 
        p.discount != null && p.discount! > 0
      ).toList();
      products.sort((a, b) => (b.discount ?? 0).compareTo(a.discount ?? 0));
      return products;
    }
    
    if (_selectedCategory != 'All') {
      products = products.where((p) => p.category == _selectedCategory).toList();
    }
    
    products = products.where((p) =>
      p.price >= _priceRange.start && p.price <= _priceRange.end
    ).toList();
    
    switch (_sortBy) {
      case 'price_low':
        products.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_high':
        products.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'rating':
        products.sort((a, b) => b.rating.compareTo(a.rating));
        break;
    }
    
    return products;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 120,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            'No products found',
            style: AppTextStyles.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
