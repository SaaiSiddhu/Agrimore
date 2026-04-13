import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/themes/app_colors.dart';
import '../../../app/themes/app_text_styles.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../models/product_model.dart';
import '../../../core/utils/snackbar_helper.dart';
import 'widgets/image_uploader.dart';
import 'widgets/product_form.dart';
import 'widgets/stock_manager.dart';
import 'widgets/specification_form.dart';
import 'widgets/variant_form.dart';
import 'widgets/delivery_info_form.dart';
import '../../../providers/theme_provider.dart';

class EditProductScreen extends StatefulWidget {
  final ProductModel product;

  const EditProductScreen({Key? key, required this.product}) : super(key: key);

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  
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
    _tabController = TabController(length: 6, vsync: this); // 6 tabs
    
    // Load all data from widget.product
    _nameController = TextEditingController(text: widget.product.name);
    _priceController = TextEditingController(text: widget.product.salePrice.toString());
    _originalPriceController = TextEditingController(
      text: widget.product.originalPrice?.toString() ?? '',
    );
    _descriptionController = TextEditingController(text: widget.product.description);
    _selectedCategory = widget.product.categoryId;
    _isFeatured = widget.product.isFeatured;
    _isVerified = widget.product.isVerified;
    _isTrending = widget.product.isTrending;
    
    _imageUrls = List.from(widget.product.images);
    
    _stockController = TextEditingController(text: widget.product.stock.toString());
    _unitController = TextEditingController(text: widget.product.unit ?? '');
    _minOrderController = TextEditingController(
      text: widget.product.minOrderQuantity?.toString() ?? '1',
    );
    _maxOrderController = TextEditingController(
      text: widget.product.maxOrderQuantity?.toString() ?? '',
    );
    
    _specifications = Map.from(widget.product.specifications ?? {});
    
    _variantOptions = List.from(widget.product.variantOptions);
    _variants = List.from(widget.product.variants);
    
    _shippingDaysController = TextEditingController(text: widget.product.shippingDays ?? '2-3');
    _shippingPriceController = TextEditingController(text: widget.product.shippingPrice?.toString() ?? '0');
    _freeShippingAboveController = TextEditingController(text: widget.product.freeShippingAbove?.toString() ?? '500');
    _isFreeDelivery = widget.product.isFreeDelivery ?? true;
    _expressDelivery = widget.product.expressDelivery ?? false;
    _expressDeliveryDaysController = TextEditingController(text: widget.product.expressDeliveryDays ?? '1');
    
    Provider.of<CategoryProvider>(context, listen: false).loadCategories();
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

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) {
      _tabController.animateTo(0);
      SnackbarHelper.showError(context, 'Please fix errors in the Basic Info tab');
      return;
    }

    if (_imageUrls.isEmpty) {
      _tabController.animateTo(1); // Go to images tab
      SnackbarHelper.showError(context, 'Please add at least one image');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ✅ FIXED: Changed from ProductModel(...) to widget.product.copyWith(...)
      final updatedProduct = widget.product.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        salePrice: double.parse(_priceController.text.trim()),
        originalPrice: _originalPriceController.text.trim().isNotEmpty
            ? double.parse(_originalPriceController.text.trim())
            : null,
        categoryId: _selectedCategory, // This is already required in the model
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

      await Provider.of<AdminProvider>(context, listen: false)
          .updateProduct(widget.product.id, updatedProduct);

      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Product updated successfully! ✅');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to update product: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Edit Product'),
        backgroundColor: accentColor,
        foregroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: isDark ? Colors.black : Colors.white,
          labelColor: isDark ? Colors.black : Colors.white,
          unselectedLabelColor: isDark ? Colors.black.withOpacity(0.7) : Colors.white70,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline), text: 'Basic'),
            Tab(icon: Icon(Icons.image_outlined), text: 'Images'),
            Tab(icon: Icon(Icons.inventory_outlined), text: 'Stock'),
            Tab(icon: Icon(Icons.list_alt), text: 'Specs'),
            Tab(icon: Icon(Icons.style_outlined), text: 'Variants'),
            Tab(icon: Icon(Icons.local_shipping_outlined), text: 'Delivery'),
          ],
        ),
      ),
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: AppColors.textSecondary.withOpacity(0.3)),
                    foregroundColor: isDark ? Colors.white70 : Colors.black87,
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _updateProduct,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isLoading ? 'Updating...' : 'Save Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}