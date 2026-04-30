import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../providers/seller_auth_provider.dart';
import '../../providers/seller_product_provider.dart';

class AddProductScreen extends StatefulWidget {
  final ProductModel? existingProduct;

  const AddProductScreen({super.key, this.existingProduct});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _categoryController = TextEditingController();
  final _lowStockThresholdController = TextEditingController(text: '10');

  bool _isGeneratingAI = false;
  bool _isSaving = false;

  bool get isEditing => widget.existingProduct != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final p = widget.existingProduct!;
      _nameController.text = p.name;
      _descriptionController.text = p.description;
      _priceController.text = p.salePrice.toStringAsFixed(0);
      _originalPriceController.text = (p.originalPrice ?? p.salePrice).toStringAsFixed(0);
      _stockController.text = p.stock.toString();
      _categoryController.text = p.categoryId;
      _lowStockThresholdController.text = (p.lowStockThreshold ?? 10).toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _stockController.dispose();
    _categoryController.dispose();
    _lowStockThresholdController.dispose();
    super.dispose();
  }

  Future<void> _generateAIDescription() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      SnackbarHelper.showError(context, 'Please enter a product name first.');
      return;
    }

    setState(() => _isGeneratingAI = true);

    // Simulate AI Generation Delay
    await Future.delayed(const Duration(seconds: 2));

    final aiDescription = 'Premium quality $name sourced directly from trusted farms. '
        'Rich in flavor and naturally grown to ensure the best health benefits for you and your family. '
        'Perfect for everyday use.\n\n'
        '✨ 100% Organic\n'
        '✨ Farm Fresh\n'
        '✨ No Artificial Preservatives';

    setState(() {
      _descriptionController.text = aiDescription;
      _isGeneratingAI = false;
    });

    if (mounted) {
      SnackbarHelper.showSuccess(context, 'AI Description Generated Successfully!');
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<SellerAuthProvider>();
    if (auth.currentUser == null) return;

    setState(() => _isSaving = true);

    final salePrice = double.tryParse(_priceController.text) ?? 0.0;
    final originalPrice = double.tryParse(_originalPriceController.text);
    final stock = int.tryParse(_stockController.text) ?? 0;
    final lowThreshold = int.tryParse(_lowStockThresholdController.text) ?? 10;

    if (isEditing) {
      // Update existing product
      final updated = widget.existingProduct!.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        salePrice: salePrice,
        originalPrice: originalPrice,
        stock: stock,
        categoryId: _categoryController.text.trim().isEmpty ? 'general' : _categoryController.text.trim(),
        lowStockThreshold: lowThreshold,
        updatedAt: DateTime.now(),
      );

      final success = await context.read<SellerProductProvider>().updateProduct(updated);

      setState(() => _isSaving = false);

      if (success && mounted) {
        SnackbarHelper.showSuccess(context, 'Product updated successfully!');
        Navigator.pop(context);
      }
    } else {
      // Create new product
      final product = ProductModel(
        id: '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        salePrice: salePrice,
        originalPrice: originalPrice,
        stock: stock,
        categoryId: _categoryController.text.trim().isEmpty ? 'general' : _categoryController.text.trim(),
        sellerId: auth.currentUser!.uid,
        location: 'Default Location',
        isVerified: false,
        isActive: true,
        images: [],
        lowStockThreshold: lowThreshold,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final success = await context.read<SellerProductProvider>().addProduct(product);

      setState(() => _isSaving = false);

      if (success && mounted) {
        SnackbarHelper.showSuccess(context, 'Product added successfully! Waiting for admin approval.');
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Product' : 'Add New Product'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Placeholder
              Container(
                width: double.infinity,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withOpacity(0.3), style: BorderStyle.solid),
                  image: isEditing && widget.existingProduct!.primaryImage.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(widget.existingProduct!.primaryImage),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: (isEditing && widget.existingProduct!.primaryImage.isNotEmpty)
                    ? null
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Upload Product Images', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.shopping_bag_outlined),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // AI Description Field
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.withOpacity(0.3), width: 2),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.auto_awesome, color: Colors.purple, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'AI Description',
                                style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: _isGeneratingAI ? null : _generateAIDescription,
                            icon: _isGeneratingAI 
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.flash_on, size: 16),
                            label: Text(_isGeneratingAI ? 'Generating...' : 'Generate'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Enter product description or use AI to generate an SEO-friendly description.',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Sale Price (₹)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _originalPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'MRP (₹)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.price_change_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Stock + Low Stock Threshold
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Stock Qty',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _lowStockThresholdController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Low Stock Alert',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.notifications_active_outlined),
                        helperText: 'Alert when below this',
                        helperMaxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category (e.g., Vegetables)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
                ),
              ),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveProduct,
                  icon: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Icon(isEditing ? Icons.save : Icons.check),
                  label: Text(
                    _isSaving ? 'Saving...' : (isEditing ? 'Update Product' : 'Save Product'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2D7D3C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
