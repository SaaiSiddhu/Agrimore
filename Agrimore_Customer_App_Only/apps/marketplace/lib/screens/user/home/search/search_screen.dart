import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../../app/routes.dart';
import '../../../../providers/product_provider.dart';
import '../../../../providers/category_provider.dart';
import '../../../../providers/cart_provider.dart';
import '../../../../providers/theme_provider.dart';
import 'package:agrimore_core/agrimore_core.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<ProductModel> _searchResults = [];
  List<String> _recentProductIds = [];
  List<ProductModel> _recentProducts = [];
  bool _isSearching = false;
  String _searchQuery = '';

  // Trending category colors - Green theme
  final List<Color> _categoryColors = [
    const Color(0xFF2E7D32),
    const Color(0xFF388E3C),
    const Color(0xFF43A047),
    const Color(0xFF4CAF50),
    const Color(0xFF66BB6A),
    const Color(0xFF81C784),
  ];

  @override
  void initState() {
    super.initState();
    _loadRecentProducts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  Future<void> _loadRecentProducts() async {
    final prefs = await SharedPreferences.getInstance();
    _recentProductIds = prefs.getStringList('recent_viewed_products') ?? [];
    _updateRecentProductsList();
  }

  void _updateRecentProductsList() {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final allProducts = productProvider.products;
    
    _recentProducts = _recentProductIds
        .map((id) {
          try {
            return allProducts.firstWhere((p) => p.id == id);
          } catch (e) {
            return null;
          }
        })
        .whereType<ProductModel>()
        .take(5)
        .toList();
    setState(() {});
  }

  Future<void> _saveRecentProduct(String productId) async {
    if (productId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    _recentProductIds.remove(productId);
    _recentProductIds.insert(0, productId);
    if (_recentProductIds.length > 10) {
      _recentProductIds = _recentProductIds.sublist(0, 10);
    }
    await prefs.setStringList('recent_viewed_products', _recentProductIds);
    _updateRecentProductsList();
  }

  Future<void> _clearRecentProducts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_viewed_products');
    setState(() {
      _recentProductIds = [];
      _recentProducts = [];
    });
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
          (product.category.toLowerCase().contains(searchLower));
    }).toList();

    setState(() => _isSearching = false);
  }

  // Get autocomplete suggestions (limited to 7)
  List<ProductModel> get _autocompleteSuggestions {
    if (_searchQuery.isEmpty) return [];
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final allProducts = productProvider.products;
    
    return allProducts
        .where((product) => 
            product.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .take(7)
        .toList();
  }

  void _onProductTap(ProductModel product) {
    HapticFeedback.lightImpact();
    _saveRecentProduct(product.id);
    Navigator.pushNamed(
      context,
      AppRoutes.productDetails,
      arguments: product.id,
    );
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
    final suggestions = _autocompleteSuggestions;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // Green Gradient Header with Search Bar
          _buildGreenHeader(isDark),
          
          // Content - Show autocomplete suggestions OR search results
          Expanded(
            child: _searchQuery.isEmpty
                ? _buildIdleState(isDark)
                : _isSearching
                    ? Center(
                        child: CircularProgressIndicator(
                          color: isDark ? AppColors.primaryLight : const Color(0xFF2E7D32),
                        ),
                      )
                    : _buildSearchWithSuggestions(isDark, suggestions),
          ),
        ],
      ),
    );
  }

  // New widget that shows suggestions + results
  Widget _buildSearchWithSuggestions(bool isDark, List<ProductModel> suggestions) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Autocomplete Suggestions
          if (suggestions.isNotEmpty) _buildAutocompleteSuggestions(isDark, suggestions),
          
          // Divider
          if (suggestions.isNotEmpty && _searchResults.isNotEmpty)
            Divider(
              height: 1,
              color: isDark ? Colors.grey[800] : Colors.grey[300],
            ),
          
          // Search Results Title
          if (_searchResults.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'Showing results for "$_searchQuery"',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          
          // Search Results Grid
          if (_searchResults.isNotEmpty)
            _buildSearchResultsGrid(isDark)
          else
            _buildNoResults(isDark),
        ],
      ),
    );
  }

  Widget _buildAutocompleteSuggestions(bool isDark, List<ProductModel> suggestions) {
    return Container(
      color: isDark ? const Color(0xFF1A2A1A) : const Color(0xFFF1F8F2),
      child: Column(
        children: suggestions.map((product) {
          return InkWell(
            onTap: () => _onProductTap(product),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  // Product Image - Small square with light grey bg
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF252525) : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                          ? Image.network(
                              product.imageUrl!,
                              width: 32,
                              height: 32,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Center(
                                child: Icon(
                                  Icons.shopping_bag_outlined, 
                                  size: 16, 
                                  color: Colors.grey[400],
                                ),
                              ),
                            )
                          : Center(
                              child: Icon(
                                Icons.shopping_bag_outlined, 
                                size: 16, 
                                color: Colors.grey[400],
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Product Name with highlighted matching text
                  Expanded(
                    child: _buildHighlightedText(
                      product.name,
                      _searchQuery,
                      isDark,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHighlightedText(String text, String query, bool isDark) {
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final startIndex = lowerText.indexOf(lowerQuery);
    
    if (startIndex == -1) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white : Colors.black87,
        ),
      );
    }
    
    final beforeMatch = text.substring(0, startIndex);
    final match = text.substring(startIndex, startIndex + query.length);
    final afterMatch = text.substring(startIndex + query.length);
    
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: [
          TextSpan(
            text: beforeMatch,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          TextSpan(
            text: match,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2E7D32),
            ),
          ),
          TextSpan(
            text: afterMatch,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsGrid(bool isDark) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65,
        crossAxisSpacing: 6,
        mainAxisSpacing: 8,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildSearchResultCard(_searchResults[index], isDark);
      },
    );
  }

  Widget _buildGreenHeader(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
              : [const Color(0xFF1B5E20), const Color(0xFF2E7D32)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _performSearch,
                    onSubmitted: (query) {
                      if (query.isNotEmpty) {
                        // Navigate to shop screen with search query
                        Navigator.pop(context, query);
                      }
                    },
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 15,
                    ),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search for atta, dal, coke and more',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: const Color(0xFF2E7D32),
                        size: 22,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: Colors.grey[600],
                                size: 20,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _performSearch('');
                              },
                            )
                          : const Icon(
                              Icons.mic,
                              color: Color(0xFF2E7D32),
                            ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdleState(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent Products (products user viewed/searched)
          if (_recentProducts.isNotEmpty) _buildRecentProducts(isDark),
          
          // Trending Categories
          _buildTrendingCategories(isDark),
          
          // Popular Products
          _buildPopularProducts(isDark),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildRecentProducts(bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent searches',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              GestureDetector(
                onTap: _clearRecentProducts,
                child: Text(
                  'clear',
                  style: TextStyle(
                    fontSize: 12,
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
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: _recentProducts.map((product) {
              return GestureDetector(
                onTap: () => _onProductTap(product),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                      // Product Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                            ? Image.network(
                                product.imageUrl!,
                                width: 28,
                                height: 28,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 28,
                                  height: 28,
                                  color: Colors.grey[200],
                                  child: Icon(Icons.shopping_bag, size: 16, color: Colors.grey[400]),
                                ),
                              )
                            : Container(
                                width: 28,
                                height: 28,
                                color: Colors.grey[200],
                                child: Icon(Icons.shopping_bag, size: 16, color: Colors.grey[400]),
                              ),
                      ),
                      const SizedBox(width: 8),
                      // Product Name
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 100),
                        child: Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTrendingCategories(bool isDark) {
    return Consumer<CategoryProvider>(
      builder: (context, categoryProvider, child) {
        final categories = categoryProvider.categories.take(6).toList();
        if (categories.isEmpty) return const SizedBox.shrink();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                'Trending in your city',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.1,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final color = _categoryColors[index % _categoryColors.length];
                return _buildCategoryCard(category, color, isDark);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryCard(CategoryModel category, Color color, bool isDark) {
    // Get icon based on category name
    IconData getCategoryIcon(String name) {
      final lower = name.toLowerCase();
      if (lower.contains('vegetable') || lower.contains('veg')) return Icons.eco;
      if (lower.contains('fruit')) return Icons.apple;
      if (lower.contains('dairy') || lower.contains('milk')) return Icons.water_drop;
      if (lower.contains('biscuit') || lower.contains('cookie')) return Icons.cookie;
      if (lower.contains('chip') || lower.contains('snack') || lower.contains('namkeen')) return Icons.restaurant;
      if (lower.contains('chocolate') || lower.contains('candy')) return Icons.cake;
      if (lower.contains('detergent') || lower.contains('clean')) return Icons.cleaning_services;
      if (lower.contains('oil')) return Icons.opacity;
      if (lower.contains('rice') || lower.contains('grain')) return Icons.grain;
      if (lower.contains('spice') || lower.contains('masala')) return Icons.spa;
      if (lower.contains('beverage') || lower.contains('drink')) return Icons.local_cafe;
      if (lower.contains('bread') || lower.contains('bakery')) return Icons.bakery_dining;
      if (lower.contains('meat') || lower.contains('chicken')) return Icons.set_meal;
      if (lower.contains('fish') || lower.contains('seafood')) return Icons.set_meal;
      if (lower.contains('frozen')) return Icons.ac_unit;
      if (lower.contains('baby')) return Icons.child_care;
      if (lower.contains('personal') || lower.contains('care')) return Icons.face;
      if (lower.contains('health')) return Icons.health_and_safety;
      if (lower.contains('bath') || lower.contains('wash') || lower.contains('hand')) return Icons.bathtub;
      return Icons.shopping_basket;
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pushNamed(
          context,
          AppRoutes.categoryProducts,
          arguments: category.id,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            // Title
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                category.name,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Icon
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    getCategoryIcon(category.name),
                    size: 28,
                    color: color,
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
        final products = productProvider.products.take(8).toList();
        if (products.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Text(
                'Popular products',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  return _buildProductCard(products[index], isDark);
                },
              ),
            ),
            const SizedBox(height: 20),
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
            width: 120,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(10),
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
                            top: Radius.circular(10),
                          ),
                        ),
                        child: product.imageUrl != null
                            ? ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(10),
                                ),
                                child: Image.network(
                                  product.imageUrl!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              )
                            : Center(
                                child: Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 32,
                                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                                ),
                              ),
                      ),
                      // Add Button
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: GestureDetector(
                          onTap: isInCart
                              ? null
                              : () {
                                  HapticFeedback.mediumImpact();
                                  cartProvider.addItem(product, quantity: 1);
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: isInCart
                                  ? Colors.grey[400]
                                  : const Color(0xFF2E7D32),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isInCart ? '✓' : 'ADD',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
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
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${product.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13,
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

  Widget _buildSearchResultCard(ProductModel product, bool isDark) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        final isInCart = cartProvider.isInCart(product.id);

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _saveRecentProduct(product.id);
            Navigator.pushNamed(
              context,
              AppRoutes.productDetails,
              arguments: product.id,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.grey[800]! : const Color(0xFFE0E0E0),
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Section
                Expanded(
                  flex: 4,
                  child: Stack(
                    children: [
                      // Product Image
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF252525) : const Color(0xFFFAFAFA),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        ),
                        child: product.imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  product.imageUrl!,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              )
                            : Center(
                                child: Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 28,
                                  color: isDark ? Colors.grey[600] : Colors.grey[350],
                                ),
                              ),
                      ),
                      // ADD Button
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: GestureDetector(
                          onTap: isInCart
                              ? null
                              : () {
                                  HapticFeedback.mediumImpact();
                                  cartProvider.addItem(product, quantity: 1);
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isInCart 
                                  ? Colors.grey[400] 
                                  : const Color(0xFF2E7D32),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isInCart ? Colors.grey[500]! : const Color(0xFF1B5E20),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              isInCart ? '✓' : 'ADD',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Details Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Name
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Price
                      Text(
                        '₹${product.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12,
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
          const SizedBox(height: 20),
          Text(
            'No products found',
            style: TextStyle(
              fontSize: 20,
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
