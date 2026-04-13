import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../app/app_router.dart';
import '../../../app/themes/admin_colors.dart';
import 'widgets/image_uploader.dart';
import 'widgets/product_form.dart';
import 'widgets/stock_manager.dart';
import 'widgets/specification_form.dart';
import 'widgets/variant_form.dart';
import 'widgets/delivery_info_form.dart';

/// Unified screen for adding and editing products.
/// Pass [product] to edit directly, or [productId] to fetch and edit.
/// Leave both null to add new product.
class ProductFormScreen extends StatefulWidget {
  final ProductModel? product;
  final String? productId;

  const ProductFormScreen({Key? key, this.product, this.productId}) : super(key: key);

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  
  ProductModel? _product;
  bool _isLoadingProduct = false;
  
  bool get isEditMode => _product != null;
  
  // Tab 1: Basic Info
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _originalPriceController;
  late TextEditingController _descriptionController;
  String? _selectedCategory;
  bool _isFeatured = false;
  bool _isVerified = false;
  bool _isTrending = false;

  // Tab 2: Images
  List<String> _imageUrls = [];
  
  // Tab 3: Stock
  late TextEditingController _stockController;
  late TextEditingController _unitController;
  late TextEditingController _minOrderController;
  late TextEditingController _maxOrderController;
  
  // Tab 4: Specifications
  Map<String, String> _specifications = {};

  // Tab 5: Variants
  List<VariantOption> _variantOptions = [];
  List<ProductVariant> _variants = [];

  // Tab 6: Delivery
  late TextEditingController _shippingDaysController;
  late TextEditingController _shippingPriceController;
  late TextEditingController _freeShippingAboveController;
  bool _isFreeDelivery = true;
  bool _expressDelivery = false;
  late TextEditingController _expressDeliveryDaysController;
  
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    
    // Initialize empty controllers first
    _nameController = TextEditingController();
    _priceController = TextEditingController();
    _originalPriceController = TextEditingController();
    _descriptionController = TextEditingController();
    _stockController = TextEditingController(text: '0');
    _unitController = TextEditingController();
    _minOrderController = TextEditingController(text: '1');
    _maxOrderController = TextEditingController();
    _shippingDaysController = TextEditingController(text: '2-3');
    _shippingPriceController = TextEditingController(text: '0');
    _freeShippingAboveController = TextEditingController(text: '500');
    _expressDeliveryDaysController = TextEditingController(text: '1');
    
    // If product passed directly, use it
    if (widget.product != null) {
      _product = widget.product;
      _initializeFromProduct(_product!);
    } 
    // If productId passed, fetch the product
    else if (widget.productId != null) {
      _fetchProduct(widget.productId!);
    }
    
    Provider.of<CategoryProvider>(context, listen: false).loadCategories();
  }
  
  Future<void> _fetchProduct(String productId) async {
    setState(() => _isLoadingProduct = true);
    try {
      final provider = Provider.of<AdminProvider>(context, listen: false);
      final product = provider.products.firstWhere(
        (p) => p.id == productId,
        orElse: () => throw Exception('Product not found'),
      );
      _product = product;
      _initializeFromProduct(product);
    } catch (e) {
      debugPrint('Error loading product: $e');
      if (mounted) {
        SnackbarHelper.showError(context, 'Product not found');
        context.go(AdminRoutes.products);
      }
    } finally {
      if (mounted) setState(() => _isLoadingProduct = false);
    }
  }
  
  void _initializeFromProduct(ProductModel p) {
    _nameController.text = p.name;
    _priceController.text = p.salePrice.toString();
    _originalPriceController.text = p.originalPrice?.toString() ?? '';
    _descriptionController.text = p.description;
    _selectedCategory = p.categoryId;
    _isFeatured = p.isFeatured;
    _isVerified = p.isVerified;
    _isTrending = p.isTrending;
    
    _imageUrls = List.from(p.images);
    
    _stockController.text = p.stock.toString();
    _unitController.text = p.unit ?? '';
    _minOrderController.text = p.minOrderQuantity?.toString() ?? '1';
    _maxOrderController.text = p.maxOrderQuantity?.toString() ?? '';
    
    _specifications = Map.from(p.specifications ?? {});
    
    _variantOptions = List.from(p.variantOptions ?? []);
    _variants = List.from(p.variants ?? []);
    
    _shippingDaysController.text = p.shippingDays ?? '2-3';
    _shippingPriceController.text = p.shippingPrice?.toString() ?? '0';
    _freeShippingAboveController.text = p.freeShippingAbove?.toString() ?? '500';
    _isFreeDelivery = p.isFreeDelivery ?? true;
    _expressDelivery = p.expressDelivery ?? false;
    _expressDeliveryDaysController.text = p.expressDeliveryDays ?? '1';
    
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _descriptionController.dispose();
    _stockController.dispose();
    _unitController.dispose();
    _minOrderController.dispose();
    _maxOrderController.dispose();
    _shippingDaysController.dispose();
    _shippingPriceController.dispose();
    _freeShippingAboveController.dispose();
    _expressDeliveryDaysController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      _tabController.animateTo(0);
      SnackbarHelper.showError(context, 'Please fix errors in the Basic Info tab');
      return;
    }

    if (_imageUrls.isEmpty) {
      _tabController.animateTo(1);
      SnackbarHelper.showError(context, 'Please add at least one image');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (isEditMode) {
        // ✅ UPDATE: Use copyWith to preserve existing fields
        final updatedProduct = _product!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          salePrice: double.parse(_priceController.text.trim()),
          originalPrice: _originalPriceController.text.trim().isNotEmpty
              ? double.parse(_originalPriceController.text.trim())
              : null,
          categoryId: _selectedCategory,
          images: _imageUrls,
          stock: int.parse(_stockController.text.trim()),
          isFeatured: _isFeatured,
          updatedAt: DateTime.now(),
          unit: _unitController.text.trim().isNotEmpty ? _unitController.text.trim() : null,
          minOrderQuantity: _minOrderController.text.trim().isNotEmpty
              ? int.parse(_minOrderController.text.trim())
              : null,
          maxOrderQuantity: _maxOrderController.text.trim().isNotEmpty
              ? int.parse(_maxOrderController.text.trim())
              : null,
          isVerified: _isVerified,
          isTrending: _isTrending,
          specifications: _specifications,
          variantOptions: _variantOptions,
          variants: _variants,
          shippingDays: _shippingDaysController.text.trim(),
          shippingPrice: double.tryParse(_shippingPriceController.text.trim()) ?? 0,
          freeShippingAbove: double.tryParse(_freeShippingAboveController.text.trim()) ?? 500,
          isFreeDelivery: _isFreeDelivery,
          expressDelivery: _expressDelivery,
          expressDeliveryDays: _expressDeliveryDaysController.text.trim(),
        );

        debugPrint('📝 Updating product: ${_product!.id}');
        debugPrint('   Variants: ${_variants.length}');
        for (var v in _variants) {
          debugPrint('   - ${v.name}: ₹${v.salePrice}, stock: ${v.stock}');
        }

        await Provider.of<AdminProvider>(context, listen: false)
            .updateProduct(_product!.id, updatedProduct);

        if (mounted) {
          SnackbarHelper.showSuccess(context, 'Product updated successfully! ✅');
          context.go(AdminRoutes.products);
        }
      } else {
        // ✅ ADD: Create new product
        final product = ProductModel(
          id: '', // Handled by Firestore
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          salePrice: double.parse(_priceController.text.trim()),
          originalPrice: _originalPriceController.text.trim().isNotEmpty
              ? double.parse(_originalPriceController.text.trim())
              : null,
          categoryId: _selectedCategory!,
          images: _imageUrls,
          stock: int.parse(_stockController.text.trim()),
          rating: 0.0,
          reviewCount: 0,
          isFeatured: _isFeatured,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          unit: _unitController.text.trim().isNotEmpty ? _unitController.text.trim() : null,
          minOrderQuantity: _minOrderController.text.trim().isNotEmpty
              ? int.parse(_minOrderController.text.trim())
              : null,
          maxOrderQuantity: _maxOrderController.text.trim().isNotEmpty
              ? int.parse(_maxOrderController.text.trim())
              : null,
          isNew: true,
          isVerified: _isVerified,
          isTrending: _isTrending,
          specifications: _specifications,
          variantOptions: _variantOptions,
          variants: _variants,
          shippingDays: _shippingDaysController.text.trim(),
          shippingPrice: double.tryParse(_shippingPriceController.text.trim()) ?? 0,
          freeShippingAbove: double.tryParse(_freeShippingAboveController.text.trim()) ?? 500,
          isFreeDelivery: _isFreeDelivery,
          expressDelivery: _expressDelivery,
          expressDeliveryDays: _expressDeliveryDaysController.text.trim(),
        );

        debugPrint('➕ Adding new product: ${product.name}');
        debugPrint('   Variants: ${_variants.length}');
        for (var v in _variants) {
          debugPrint('   - ${v.name}: ₹${v.salePrice}, stock: ${v.stock}');
        }

        await Provider.of<AdminProvider>(context, listen: false).addProduct(product);

        if (mounted) {
          SnackbarHelper.showSuccess(context, 'Product added successfully! 🎉');
          context.go(AdminRoutes.products);
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProduct) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AdminColors.primary),
              const SizedBox(height: 16),
              Text(
                'Loading product...',
                style: TextStyle(color: AdminColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabController,
          children: [
            ProductForm(
              nameController: _nameController,
              priceController: _priceController,
              originalPriceController: _originalPriceController,
              descriptionController: _descriptionController,
              selectedCategory: _selectedCategory,
              isFeatured: _isFeatured,
              isVerified: _isVerified,
              isTrending: _isTrending,
              onCategoryChanged: (value) => setState(() => _selectedCategory = value),
              onFeaturedChanged: (value) => setState(() => _isFeatured = value ?? false),
              onVerifiedChanged: (value) => setState(() => _isVerified = value ?? false),
              onTrendingChanged: (value) => setState(() => _isTrending = value ?? false),
            ),

            ImageUploader(
              imageUrls: _imageUrls,
              onImagesChanged: (urls) => setState(() => _imageUrls = urls),
            ),

            StockManager(
              stockController: _stockController,
              unitController: _unitController,
              minOrderController: _minOrderController,
              maxOrderController: _maxOrderController,
            ),

            SpecificationForm(
              specifications: _specifications,
              onSpecificationsChanged: (specs) => setState(() => _specifications = specs),
            ),

            VariantForm(
              variantOptions: _variantOptions,
              variants: _variants,
              onVariantsChanged: (options, variants) => setState(() {
                _variantOptions = options;
                _variants = variants;
              }),
            ),

            DeliveryInfoForm(
              shippingDaysController: _shippingDaysController,
              shippingPriceController: _shippingPriceController,
              freeShippingAboveController: _freeShippingAboveController,
              isFreeDelivery: _isFreeDelivery,
              expressDelivery: _expressDelivery,
              expressDeliveryDaysController: _expressDeliveryDaysController,
              onFreeDeliveryChanged: (value) => setState(() => _isFreeDelivery = value),
              onExpressDeliveryChanged: (value) => setState(() => _expressDelivery = value),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }
  
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.black87,
      iconTheme: const IconThemeData(color: Colors.black87),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.go(AdminRoutes.products),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEditMode ? 'Edit Product' : 'Add New Product',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          if (isEditMode && _product != null)
            Text(
              _product!.name,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontWeight: FontWeight.w400,
              ),
            ),
        ],
      ),
      actions: [
        if (isEditMode)
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: Colors.red[400]),
            onPressed: _showDeleteDialog,
            tooltip: 'Delete Product',
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorColor: AdminColors.primary,
            indicatorWeight: 3,
            labelColor: AdminColors.primary,
            unselectedLabelColor: AdminColors.textSecondary,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            tabs: const [
              Tab(icon: Icon(Icons.info_outline_rounded, size: 20), text: 'Basic'),
              Tab(icon: Icon(Icons.image_rounded, size: 20), text: 'Images'),
              Tab(icon: Icon(Icons.inventory_2_rounded, size: 20), text: 'Stock'),
              Tab(icon: Icon(Icons.list_alt_rounded, size: 20), text: 'Specs'),
              Tab(icon: Icon(Icons.layers_rounded, size: 20), text: 'Variants'),
              Tab(icon: Icon(Icons.local_shipping_rounded, size: 20), text: 'Delivery'),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${_product!.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteProduct();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProduct() async {
    if (_product == null) return;
    
    setState(() => _isLoading = true);
    try {
      final provider = context.read<AdminProvider>();
      await provider.deleteProduct(_product!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Product deleted successfully'),
            backgroundColor: AdminColors.success,
          ),
        );
        context.go(AdminRoutes.products);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AdminColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : () => context.go(AdminRoutes.products),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 4,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        isEditMode ? 'Save Changes' : 'Add Product',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
