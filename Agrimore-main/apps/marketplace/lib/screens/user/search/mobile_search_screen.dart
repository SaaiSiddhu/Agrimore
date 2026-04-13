import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app/routes.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/theme_provider.dart';
import 'package:agrimore_core/agrimore_core.dart';

class MobileSearchScreen extends StatefulWidget {
  const MobileSearchScreen({Key? key}) : super(key: key);

  @override
  State<MobileSearchScreen> createState() => _MobileSearchScreenState();
}

class _MobileSearchScreenState extends State<MobileSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<ProductModel> _searchResults = [];
  List<String> _recentSearches = [];
  bool _isSearching = false;
  String _searchQuery = '';

  // Trending category colors
  final List<Color> _categoryColors = [
    const Color(0xFF4CAF50),
    const Color(0xFF9C27B0),
    const Color(0xFF2196F3),
    const Color(0xFFFF9800),
    const Color(0xFFE91E63),
    const Color(0xFF00BCD4),
  ];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList('recent_searches') ?? [];
    });
  }

  Future<void> _saveRecentSearch(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    _recentSearches.remove(query);
    _recentSearches.insert(0, query);
    if (_recentSearches.length > 10) {
      _recentSearches = _recentSearches.sublist(0, 10);
    }
    await prefs.setStringList('recent_searches', _recentSearches);
    setState(() {});
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_searches');
    setState(() => _recentSearches = []);
  }

  void _performSearch(String query) {
    setState(() => _searchQuery = query);

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final allProducts = productProvider.products;

    _searchResults = allProducts.where((product) {
      final searchLower = query.toLowerCase();
      return product.name.toLowerCase().contains(searchLower) ||
          product.description.toLowerCase().contains(searchLower) ||
          (product.category?.toLowerCase().contains(searchLower) ?? false);
    }).toList();

    setState(() => _isSearching = false);

    if (query.length >= 3) {
      _saveRecentSearch(query);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            _buildSearchBar(isDark),
            
            // Content
            Expanded(
              child: _searchQuery.isEmpty
                  ? _buildIdleState(isDark)
                  : _isSearching
                      ? const Center(child: CircularProgressIndicator())
                      : _searchResults.isEmpty
                          ? _buildNoResults(isDark)
                          : _buildSearchResults(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _performSearch,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Search for atta, dal, coke and more',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: isDark ? Colors.grey[500] : Colors.grey[500],
                            size: 18,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _performSearch('');
                          },
                        )
                      : Icon(
                          Icons.mic,
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdleState(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent Searches
          if (_recentSearches.isNotEmpty) _buildRecentSearches(isDark),
          
          // Trending Categories
          _buildTrendingCategories(isDark),
          
          // Popular Products
          _buildPopularProducts(isDark),
        ],
      ),
    );
  }

  Widget _buildRecentSearches(bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent searches',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              GestureDetector(
                onTap: _clearRecentSearches,
                child: Text(
                  'clear',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.primaryLight : const Color(0xFF2E7D32),
                  ),
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: _recentSearches.take(5).map((search) {
              return GestureDetector(
                onTap: () {
                  _searchController.text = search;
                  _performSearch(search);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history,
                        size: 16,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        search,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTrendingCategories(bool isDark) {
    return Consumer<CategoryProvider>(
      builder: (context, categoryProvider, child) {
        final categories = categoryProvider.categories.take(6).toList();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Text(
                'Trending in your city',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final color = _categoryColors[index % _categoryColors.length];
                  return _buildCategoryCard(category, color, isDark);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryCard(CategoryModel category, Color color, bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pushNamed(
          context,
          AppRoutes.categoryProducts,
          arguments: {'categoryId': category.id, 'categoryName': category.name},
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
              child: Text(
                category.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Images
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: category.imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            category.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.category,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.category, color: Colors.grey),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularProducts(bool isDark) {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        final products = productProvider.products.take(6).toList();
        if (products.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Text(
                'Popular products',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  return _buildProductCard(products[index], isDark);
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildProductCard(ProductModel product, bool isDark) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        final isInCart = cartProvider.isInCart(product.id);

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pushNamed(
              context,
              AppRoutes.productDetails,
              arguments: product.id,
            );
          },
          child: Container(
            width: 140,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(14),
                          ),
                        ),
                        child: product.imageUrl != null
                            ? ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(14),
                                ),
                                child: Image.network(
                                  product.imageUrl!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.shopping_bag_outlined, size: 40),
                              ),
                      ),
                      // Add Button
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: GestureDetector(
                          onTap: isInCart
                              ? null
                              : () => cartProvider.addItem(product, quantity: 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isInCart
                                  ? Colors.grey
                                  : (isDark ? AppColors.primaryLight : const Color(0xFF2E7D32)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.primaryLight.withOpacity(0.5)
                                    : const Color(0xFF2E7D32),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              isInCart ? 'Added' : 'ADD',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Details
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${product.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchResults(bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildSearchResultCard(_searchResults[index], isDark);
      },
    );
  }

  Widget _buildSearchResultCard(ProductModel product, bool isDark) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        final isInCart = cartProvider.isInCart(product.id);

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pushNamed(
              context,
              AppRoutes.productDetails,
              arguments: product.id,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(14),
                          ),
                        ),
                        child: product.imageUrl != null
                            ? ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(14),
                                ),
                                child: Image.network(
                                  product.imageUrl!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.shopping_bag_outlined, size: 48),
                              ),
                      ),
                      // Add Button
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: GestureDetector(
                          onTap: isInCart
                              ? null
                              : () => cartProvider.addItem(product, quantity: 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isInCart
                                  ? Colors.grey
                                  : (isDark ? AppColors.primaryLight : const Color(0xFF2E7D32)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.primaryLight.withOpacity(0.5)
                                    : const Color(0xFF2E7D32),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              isInCart ? 'Added' : 'ADD',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Details
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '₹${product.price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoResults(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 80,
            color: isDark ? Colors.grey[700] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No products found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching with different keywords',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
