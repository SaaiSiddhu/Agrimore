import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

import '../../../providers/admin_provider.dart';
import '../../../app/app_router.dart';
import '../../../app/themes/admin_colors.dart';
import 'category_management_screen.dart';
import 'widgets/admin_product_card.dart';

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  State<ProductManagementScreen> createState() => _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _filterIndex = 0; // 0=All, 1=Active, 2=Low Stock, 3=Featured
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).listenToProducts();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _enterSelectionMode(String id) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _toggleSelect(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedIds.contains(id) ? _selectedIds.remove(id) : _selectedIds.add(id);
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _bulkDelete(AdminProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AdminColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: AdminColors.error),
            ),
            const SizedBox(width: 12),
            const Text('Delete Products'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ${_selectedIds.length} product(s)? This action cannot be undone.',
          style: TextStyle(color: AdminColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AdminColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await provider.deleteProducts(_selectedIds.toList());
      _clearSelection();
      if (mounted) SnackbarHelper.showSuccess(context, 'Deleted ${_selectedIds.length} products');
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Failed to delete some products');
    }
  }

  List<ProductModel> _filterProducts(List<ProductModel> list) {
    var filtered = list;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((p) => p.name.toLowerCase().contains(q)).toList();
    }
    switch (_filterIndex) {
      case 1:
        filtered = filtered.where((p) => p.isActive).toList();
        break;
      case 2:
        filtered = filtered.where((p) => p.stock < 10).toList();
        break;
      case 3:
        filtered = filtered.where((p) => p.isFeatured).toList();
        break;
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, _) {
        final allProducts = provider.products;
        final filtered = _filterProducts(allProducts);

        final total = allProducts.length;
        final active = allProducts.where((p) => p.isActive).length;
        final lowStock = allProducts.where((p) => p.stock < 10).length;
        final featured = allProducts.where((p) => p.isFeatured).length;

        return Scaffold(
          backgroundColor: AdminColors.background,
          body: CustomScrollView(
            slivers: [
              // Premium App Bar
              _buildSliverAppBar(provider),
              
              // Stats Cards
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _buildStatsRow(total, active, lowStock, featured),
                ),
              ),
              
              // Search and Filters
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildSearchAndFilters(),
                ),
              ),
              
              // Products Content
              _buildProductsSliver(provider, filtered),
            ],
          ),
          floatingActionButton: _selectionMode ? null : _buildFAB(),
        );
      },
    );
  }

  Widget _buildSliverAppBar(AdminProvider provider) {
    return SliverAppBar(
      expandedHeight: _selectionMode ? 70 : 140,
      floating: false,
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          decoration: const BoxDecoration(
            gradient: AdminColors.headerGradient,
          ),
          child: SafeArea(
            child: _selectionMode
                ? _buildSelectionHeader(provider)
                : _buildNormalHeader(),
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: Container(
          height: 4,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AdminColors.primary.withValues(alpha: 0.3),
                AdminColors.primaryLight.withValues(alpha: 0.1),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNormalHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Product Management',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Manage your product catalog',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              // Actions
              Row(
                children: [
                  _headerAction(Icons.refresh_rounded, 'Refresh', () {
                    HapticFeedback.lightImpact();
                    Provider.of<AdminProvider>(context, listen: false).listenToProducts();
                  }),
                  const SizedBox(width: 8),
                  _headerAction(Icons.category_rounded, 'Categories', () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const CategoryManagementScreen(),
                    ));
                  }),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerAction(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionHeader(AdminProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_selectedIds.length}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Selected',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _bulkDelete(provider),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.red.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.delete_rounded, size: 20),
            label: const Text('Delete'),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _clearSelection,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(int total, int active, int lowStock, int featured) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatCard(
            'Total Products',
            total.toString(),
            Icons.inventory_2_rounded,
            AdminColors.primary,
            AdminColors.primaryLight,
          ),
          _buildStatCard(
            'Active',
            active.toString(),
            Icons.check_circle_rounded,
            AdminColors.success,
            AdminColors.successLight,
          ),
          _buildStatCard(
            'Low Stock',
            lowStock.toString(),
            Icons.warning_amber_rounded,
            AdminColors.warning,
            AdminColors.warningLight,
          ),
          _buildStatCard(
            'Featured',
            featured.toString(),
            Icons.star_rounded,
            AdminColors.badgeFeatured,
            const Color(0xFFFFD700),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, Color lightColor) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, lightColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: AdminColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        // Premium Search Bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AdminColors.shadowLight,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value.trim()),
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Search products by name...',
              hintStyle: TextStyle(color: AdminColors.textTertiary),
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AdminColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.search_rounded, color: AdminColors.primary, size: 20),
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, color: AdminColors.textTertiary),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(0, 'All', Icons.apps_rounded),
              _buildFilterChip(1, 'Active', Icons.check_circle_outline_rounded),
              _buildFilterChip(2, 'Low Stock', Icons.warning_amber_rounded),
              _buildFilterChip(3, 'Featured', Icons.star_outline_rounded),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(int index, String label, IconData icon) {
    final isSelected = _filterIndex == index;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: isSelected ? AdminColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _filterIndex = index);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AdminColors.primary : AdminColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? Colors.white : AdminColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AdminColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductsSliver(AdminProvider provider, List<ProductModel> products) {
    if (provider.isLoadingProducts) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AdminColors.primary),
              const SizedBox(height: 16),
              Text(
                'Loading products...',
                style: TextStyle(color: AdminColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (products.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState(),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final product = products[index];
            final isSelected = _selectedIds.contains(product.id);
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onLongPress: () => _enterSelectionMode(product.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: isSelected 
                        ? Border.all(color: AdminColors.primary, width: 2)
                        : null,
                  ),
                  child: Stack(
                    children: [
                      AdminProductCard(
                        product: product,
                        onTap: () {
                          if (_selectionMode) {
                            _toggleSelect(product.id);
                          } else {
                            context.go('/products/${product.id}/edit');
                          }
                        },
                        onEdit: () => context.go('/products/${product.id}/edit'),
                        onDelete: () => _deleteProduct(product.id, product.name),
                      ),
                      if (_selectionMode)
                        Positioned(
                          right: 12,
                          top: 12,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? AdminColors.primary 
                                  : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected 
                                    ? AdminColors.primary 
                                    : AdminColors.border,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AdminColors.shadowLight,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                isSelected ? Icons.check : null,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
          childCount: products.length,
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AdminColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _searchQuery.isNotEmpty 
                  ? Icons.search_off_rounded 
                  : Icons.inventory_2_outlined,
              size: 64,
              color: AdminColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isNotEmpty 
                ? 'No products found'
                : 'No products yet',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AdminColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty 
                ? 'Try a different search term'
                : 'Add your first product to get started',
            style: TextStyle(
              fontSize: 14,
              color: AdminColors.textSecondary,
            ),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go(AdminRoutes.productNew),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Product'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return Container(
      decoration: BoxDecoration(
        gradient: AdminColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AdminColors.primary.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            context.go(AdminRoutes.productNew);
          },
          borderRadius: BorderRadius.circular(16),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 22),
                SizedBox(width: 8),
                Text(
                  'Add Product',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteProduct(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AdminColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: AdminColors.error),
            ),
            const SizedBox(width: 12),
            const Text('Delete Product'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "$name"? This action cannot be undone.',
          style: TextStyle(color: AdminColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AdminColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await Provider.of<AdminProvider>(context, listen: false).deleteProduct(id);
        if (mounted) SnackbarHelper.showSuccess(context, 'Product deleted');
      } catch (e) {
        if (mounted) SnackbarHelper.showError(context, 'Failed to delete product');
      }
    }
  }
}