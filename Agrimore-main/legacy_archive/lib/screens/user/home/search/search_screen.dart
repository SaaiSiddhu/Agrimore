import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../app/themes/app_text_styles.dart';
import '../../../../app/routes.dart';
import '../../../../providers/product_provider.dart';
import 'widgets/search_bar_widget.dart';
import 'widgets/recent_searches.dart';
import 'widgets/trending_searches.dart';
import 'widgets/search_suggestions.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;
  late AnimationController _animationController;
  List<String> _suggestions = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Auto-focus search bar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
      _animationController.forward();
    });

    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      setState(() => _showSuggestions = true);
      _fetchSuggestions(query);
    } else {
      setState(() {
        _showSuggestions = false;
        _suggestions = [];
      });
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    try {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      final products = productProvider.products ?? [];
      
      final suggestions = products
          .where((product) =>
              product.name.toLowerCase().contains(query.toLowerCase()) ||
              product.category.toLowerCase().contains(query.toLowerCase()))
          .map((product) => product.name)
          .take(5)
          .toList();

      setState(() => _suggestions = suggestions);
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');
    }
  }

  Future<void> _saveRecentSearch(String query) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || query.trim().isEmpty) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('recent_searches')
          .add({
        'query': query.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving recent search: $e');
    }
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) return;

    HapticFeedback.lightImpact();
    _saveRecentSearch(query);
    
    Navigator.pushNamed(
      context,
      AppRoutes.searchResults,
      arguments: query,
    );
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _showSuggestions = false;
      _suggestions = [];
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _animationController.dispose();
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
                  onSubmitted: _performSearch,
                  onClear: _clearSearch,
                  onBack: () => Navigator.pop(context),
                ),
              ),
            ),

            // Content
            Expanded(
              child: _showSuggestions
                  ? SearchSuggestions(
                      query: _searchController.text,
                      suggestions: _suggestions,
                      onSuggestionTap: (suggestion) {
                        _searchController.text = suggestion;
                        _performSearch(suggestion);
                      },
                    )
                  : FadeTransition(
                      opacity: _animationController,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),

                            // Recent Searches
                            RecentSearches(
                              onSearchTap: (query) {
                                _searchController.text = query;
                                _performSearch(query);
                              },
                            ),

                            const SizedBox(height: 24),

                            // Trending Searches
                            TrendingSearches(
                              onTrendingTap: (query) {
                                _searchController.text = query;
                                _performSearch(query);
                              },
                            ),

                            const SizedBox(height: 24),

                            // Popular Categories
                            _buildPopularCategories(),

                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularCategories() {
    final categories = [
      {'name': 'Electronics', 'icon': Icons.devices_rounded, 'color': Colors.blue},
      {'name': 'Fashion', 'icon': Icons.checkroom_rounded, 'color': Colors.pink},
      {'name': 'Home & Living', 'icon': Icons.home_rounded, 'color': Colors.orange},
      {'name': 'Beauty', 'icon': Icons.face_rounded, 'color': Colors.purple},
      {'name': 'Sports', 'icon': Icons.sports_basketball_rounded, 'color': Colors.green},
      {'name': 'Books', 'icon': Icons.menu_book_rounded, 'color': Colors.brown},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.5),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Popular Categories',
                style: AppTextStyles.headlineSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.0,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _searchController.text = category['name'] as String;
                _performSearch(category['name'] as String);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (category['color'] as Color).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        category['icon'] as IconData,
                        color: category['color'] as Color,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      category['name'] as String,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
