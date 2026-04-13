import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/themes/app_colors.dart';
import '../../../app/themes/app_text_styles.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/product_model.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/theme_provider.dart'; // ✅ NEW IMPORT
import 'add_product_screen.dart';
import 'edit_product_screen.dart';
import 'category_management_screen.dart';
import 'widgets/admin_product_card.dart'; // ✅ NEW IMPORT

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({Key? key}) : super(key: key);

  @override
  State<ProductManagementScreen> createState() => _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _filterIndex = 0; // 0=All, 1=Active, 2=Low Stock, 3=Featured
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).listenToProducts();
    });
  }

  void _enterSelectionMode(String id) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _toggleSelect(String id) {
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

  Future<void> _bulkDelete(AdminProvider provider, bool isDark) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete selected products'),
        content: Text('Are you sure you want to delete ${_selectedIds.length} item(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await provider.deleteProducts(_selectedIds.toList());
      _clearSelection();
      SnackbarHelper.showSuccess(context, 'Deleted selected products');
    } catch (e) {
      SnackbarHelper.showError(context, 'Failed to delete some products');
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    
    return Consumer<AdminProvider>(
      builder: (context, provider, _) {
        final allProducts = provider.products;
        final filtered = _filterProducts(allProducts);

        final total = allProducts.length;
        final active = allProducts.where((p) => p.isActive).length;
        final lowStock = allProducts.where((p) => p.stock < 10).length;
        final featured = allProducts.where((p) => p.isFeatured).length;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade50,
          appBar: AppBar(
            backgroundColor: accentColor,
            foregroundColor: isDark ? Colors.black : Colors.white,
            title: _selectionMode
                ? Text('${_selectedIds.length} selected')
                : const Text('Product Management'),
            actions: _selectionMode
                ? [
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete',
                      onPressed: () => _bulkDelete(provider, isDark),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Cancel',
                      onPressed: _clearSelection,
                    ),
                  ]
                : [
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Refresh',
                      onPressed: provider.listenToProducts,
                    ),
                    IconButton(
                      icon: const Icon(Icons.category_rounded),
                      tooltip: 'Categories',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CategoryManagementScreen()),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_rounded),
                      tooltip: 'Add Product',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddProductScreen()),
                      ),
                    ),
                  ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSearchAndFilters(isDark),
                  const SizedBox(height: 12),
                  _buildStatsRow(total, active, lowStock, featured, isDark),
                  const SizedBox(height: 12),
                  Expanded(child: _buildContent(provider, filtered, isDark)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchAndFilters(bool isDark) {
    final inputFillColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value.trim()),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: 'Search products...',
            hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[500]),
            prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: inputFillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip(0, 'All', isDark),
              _filterChip(1, 'Active', isDark),
              _filterChip(2, 'Low Stock', isDark),
              _filterChip(3, 'Featured', isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip(int index, String label, bool isDark) {
    final selected = _filterIndex == index;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filterIndex = index),
        selectedColor: accentColor,
        backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade100,
        labelStyle: TextStyle(color: selected ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.black87)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[200]!)
        ),
      ),
    );
  }

  Widget _buildStatsRow(int total, int active, int lowStock, int featured, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _statCard('Total', total.toString(), Icons.inventory_2_rounded, AppColors.primary, isDark),
          _statCard('Active', active.toString(), Icons.check_circle, Colors.green, isDark),
          _statCard('Low Stock', lowStock.toString(), Icons.warning_amber_rounded, Colors.orange, isDark),
          _statCard('Featured', featured.toString(), Icons.star_rounded, Colors.purple, isDark),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.black54)),
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent(AdminProvider provider, List<ProductModel> products, bool isDark) {
    if (provider.isLoadingProducts) {
      return Center(child: CircularProgressIndicator(color: isDark ? AppColors.primaryLight : AppColors.primary));
    }

    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(
              _searchQuery.isNotEmpty ? 'No products match your search' : 'No products found',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: isDark ? AppColors.primaryLight : AppColors.primary,
      onRefresh: () async {
        provider.listenToProducts();
      },
      child: ListView.builder(
        itemCount: products.length,
        itemBuilder: (ctx, i) {
          final product = products[i];
          final isSelected = _selectedIds.contains(product.id);

          return GestureDetector(
            onLongPress: () => _enterSelectionMode(product.id),
            onTap: () {
              if (_selectionMode) {
                _toggleSelect(product.id);
              } else {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => EditProductScreen(product: product)));
              }
            },
            child: Stack(
              children: [
                AdminProductCard(
                  product: product,
                  onTap: () {
                     if (_selectionMode) {
                      _toggleSelect(product.id);
                    } else {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => EditProductScreen(product: product)));
                    }
                  },
                  onEdit: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditProductScreen(product: product))),
                  onDelete: () => _deleteProduct(product.id, product.name, isDark),
                ),
                if (_selectionMode)
                  Positioned(
                    left: 16,
                    top: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF121212).withOpacity(0.5) : Colors.white.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleSelect(product.id),
                        activeColor: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteProduct(String id, String name, bool isDark) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete product'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await Provider.of<AdminProvider>(context, listen: false).deleteProduct(id);
        SnackbarHelper.showSuccess(context, 'Product deleted');
      } catch (e) {
        SnackbarHelper.showError(context, 'Failed to delete product');
      }
    }
  }
}