// lib/screens/products/seller_products_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/seller_auth_provider.dart';
import '../../providers/seller_product_provider.dart';
import '../home/add_product_screen.dart';

class SellerProductsScreen extends StatefulWidget {
  const SellerProductsScreen({super.key});

  @override
  State<SellerProductsScreen> createState() => _SellerProductsScreenState();
}

class _SellerProductsScreenState extends State<SellerProductsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<SellerAuthProvider>();
      if (auth.currentUser != null) {
        context.read<SellerProductProvider>().loadSellerProducts(auth.currentUser!.uid);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: const Text('My Products', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              final auth = context.read<SellerAuthProvider>();
              if (auth.currentUser != null) {
                context.read<SellerProductProvider>().loadSellerProducts(auth.currentUser!.uid);
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProductScreen()));
        },
        backgroundColor: const Color(0xFF2D7D3C),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Consumer<SellerProductProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              // Stats row
              _buildStatsRow(provider, isDark),
              const SizedBox(height: 12),
              // Search bar
              _buildSearchBar(provider, isDark),
              const SizedBox(height: 8),
              // Products list
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF2D7D3C)))
                    : provider.products.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: provider.products.length,
                            itemBuilder: (context, index) => _buildProductCard(provider.products[index], provider, isDark),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsRow(SellerProductProvider provider, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatChip('Total', provider.totalProducts.toString(), Icons.inventory_2, Colors.blue, isDark),
          const SizedBox(width: 8),
          _buildStatChip('Active', provider.activeProducts.toString(), Icons.check_circle, Colors.green, isDark),
          const SizedBox(width: 8),
          _buildStatChip('Low', provider.lowStockProducts.toString(), Icons.warning_amber, Colors.orange, isDark),
          const SizedBox(width: 8),
          _buildStatChip('Out', provider.outOfStockProducts.toString(), Icons.cancel, Colors.red, isDark),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(SellerProductProvider provider, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        onChanged: provider.setSearchQuery,
        decoration: InputDecoration(
          hintText: 'Search products...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    provider.setSearchQuery('');
                  },
                )
              : null,
          filled: true,
          fillColor: isDark ? Colors.grey[900] : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildProductCard(ProductModel product, SellerProductProvider provider, bool isDark) {
    final stockColor = product.stock == 0
        ? Colors.red
        : product.stock < 10
            ? Colors.orange
            : Colors.green;
    final auth = context.read<SellerAuthProvider>();
    final sellerId = auth.currentUser?.uid ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product image
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
                image: product.primaryImage.isNotEmpty
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(product.primaryImage),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: product.primaryImage.isEmpty
                  ? const Icon(Icons.image, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 12),
            // Product details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Active toggle
                      Transform.scale(
                        scale: 0.7,
                        child: Switch(
                          value: product.isActive,
                          onChanged: (val) {
                            HapticFeedback.selectionClick();
                            provider.toggleProductActive(product.id, val, sellerId);
                          },
                          activeColor: const Color(0xFF2D7D3C),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '₹${product.salePrice.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2D7D3C)),
                      ),
                      if (product.originalPrice != null && product.originalPrice! > product.salePrice)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            '₹${product.originalPrice!.toStringAsFixed(0)}',
                            style: TextStyle(decoration: TextDecoration.lineThrough, fontSize: 12, color: Colors.grey[500]),
                          ),
                        ),
                      const Spacer(),
                      // Stock badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: stockColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              product.stock == 0 ? Icons.cancel : Icons.inventory_2,
                              size: 12,
                              color: stockColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              product.stock == 0 ? 'Out of Stock' : '${product.stock} in stock',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: stockColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Action buttons
                  Row(
                    children: [
                      // Edit Stock
                      _buildActionChip('Stock', Icons.edit, Colors.blue, () => _showStockDialog(product, provider, sellerId)),
                      const SizedBox(width: 8),
                      // Edit Product
                      _buildActionChip('Edit', Icons.edit_outlined, Colors.orange, () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => AddProductScreen(existingProduct: product),
                        ));
                      }),
                      const SizedBox(width: 8),
                      // Delete
                      _buildActionChip('Delete', Icons.delete_outline, Colors.red, () => _confirmDelete(product, provider, sellerId)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _showStockDialog(ProductModel product, SellerProductProvider provider, String sellerId) {
    final controller = TextEditingController(text: product.stock.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Update Stock'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Stock Quantity',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.inventory_2_outlined),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final newStock = int.tryParse(controller.text) ?? 0;
              provider.updateStock(product.id, newStock, sellerId);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2D7D3C)),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(ProductModel product, SellerProductProvider provider, String sellerId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Product?'),
        content: Text('Are you sure you want to delete "${product.name}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.deleteProduct(product.id, sellerId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No products yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Tap the + button to add your first product', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        ],
      ),
    );
  }
}
