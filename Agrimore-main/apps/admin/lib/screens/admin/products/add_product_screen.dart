import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/category_provider.dart';

import 'package:agrimore_ui/agrimore_ui.dart';
import 'widgets/image_uploader.dart';
import 'widgets/product_form.dart';
import 'widgets/stock_manager.dart';
import 'widgets/specification_form.dart';
import 'widgets/variant_form.dart';
import 'widgets/delivery_info_form.dart'; // ✅ NEW IMPORT
import '../../../providers/theme_provider.dart'; // ✅ NEW IMPORT

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({Key? key}) : super(key: key);

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  
  // Tab 1: Basic Info
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategory;
  String? _selectedLocation;
  bool _isFeatured = false;
  bool _isVerified = false; // ✅ NEW
  bool _isTrending = false; // ✅ NEW

  // Tab 2: Images
  List<String> _imageUrls = [];
  
  // Tab 3: Stock
  final _stockController = TextEditingController(text: '0');
  final _unitController = TextEditingController();
  final _minOrderController = TextEditingController(text: '1');
  final _maxOrderController = TextEditingController();

  // Tab 4: Specifications
  Map<String, String> _specifications = {};

  // Tab 5: Variants
  List<VariantOption> _variantOptions = [];
  List<ProductVariant> _variants = [];

  // Tab 6: Delivery
  final _shippingDaysController = TextEditingController(text: '2-3');
  final _shippingPriceController = TextEditingController(text: '0');
  final _freeShippingAboveController = TextEditingController(text: '500');
  bool _isFreeDelivery = true;
  bool _expressDelivery = false;
  final _expressDeliveryDaysController = TextEditingController(text: '1');
  
  late TabController _tabController;
  bool _isLoading = false;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this); // ✅ 6 TABS NOW
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

  Future<void> _addProduct() async {
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
      final product = ProductModel(
        id: '', // Handled by Firestore
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        salePrice: double.parse(_priceController.text.trim()),
        originalPrice: _originalPriceController.text.trim().isNotEmpty
            ? double.parse(_originalPriceController.text.trim())
            : null,
        categoryId: _selectedCategory!, // Validator ensures this is not null
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
        isNew: true, // New product
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

      await Provider.of<AdminProvider>(context, listen: false).addProduct(product);

      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Product added successfully! 🎉');
        Navigator.pop(context);
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Add New Product'),
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
            Tab(icon: Icon(Icons.local_shipping_outlined), text: 'Delivery'), // ✅ NEW TAB
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Basic Info
            ProductForm(
              nameController: _nameController,
              priceController: _priceController,
              originalPriceController: _originalPriceController,
              descriptionController: _descriptionController,
              selectedCategory: _selectedCategory,
              selectedLocation: _selectedLocation,
              isFeatured: _isFeatured,
              isVerified: _isVerified,
              isTrending: _isTrending,
              onCategoryChanged: (value) => setState(() => _selectedCategory = value),
              onLocationChanged: (value) => setState(() => _selectedLocation = value),
              onFeaturedChanged: (value) => setState(() => _isFeatured = value ?? false),
              onVerifiedChanged: (value) => setState(() => _isVerified = value ?? false),
              onTrendingChanged: (value) => setState(() => _isTrending = value ?? false),
            ),

            // Tab 2: Images
            ImageUploader(
              imageUrls: _imageUrls,
              onImagesChanged: (urls) => setState(() => _imageUrls = urls),
            ),

            // Tab 3: Stock
            StockManager(
              stockController: _stockController,
              unitController: _unitController,
              minOrderController: _minOrderController,
              maxOrderController: _maxOrderController,
            ),

            // Tab 4: Specifications
            SpecificationForm(
              specifications: _specifications,
              onSpecificationsChanged: (specs) => setState(() => _specifications = specs),
            ),

            // Tab 5: Variants
            VariantForm(
              variantOptions: _variantOptions,
              variants: _variants,
              onVariantsChanged: (options, variants) => setState(() {
                _variantOptions = options;
                _variants = variants;
              }),
            ),

            // ✅ NEW TAB 6: Delivery
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
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: AppColors.textSecondary.withOpacity(0.3)),
                    foregroundColor: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _addProduct,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.add_circle_outline),
                  label: Text(_isLoading ? 'Adding Product...' : 'Add Product'),
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