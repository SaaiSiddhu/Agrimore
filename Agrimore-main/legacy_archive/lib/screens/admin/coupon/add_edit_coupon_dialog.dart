// lib/screens/admin/coupon/add_edit_coupon_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../../app/themes/app_colors.dart';
import '../../../app/themes/app_text_styles.dart';
import '../../../models/coupon_model.dart';
import '../../../providers/coupon_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../core/utils/snackbar_helper.dart';

class AddEditCouponDialog extends StatefulWidget {
  final CouponModel? coupon;

  const AddEditCouponDialog({Key? key, this.coupon}) : super(key: key);

  @override
  State<AddEditCouponDialog> createState() => _AddEditCouponDialogState();
}

class _AddEditCouponDialogState extends State<AddEditCouponDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _codeController;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _discountController;
  late TextEditingController _minOrderController;
  late TextEditingController _maxDiscountController;
  late TextEditingController _usageLimitController;

  late CouponType _selectedType;
  late DateTime _validFrom;
  late DateTime _validTo;
  bool _isActive = true;
  bool _isSaving = false;

  String? _buyProductId;
  String? _getProductId;

  @override
  void initState() {
    super.initState();
    final c = widget.coupon;
    _codeController = TextEditingController(text: c?.code ?? '');
    _titleController = TextEditingController(text: c?.title ?? '');
    _descriptionController = TextEditingController(text: c?.description ?? '');
    _discountController = TextEditingController(text: c?.discount.toString() ?? '');
    _minOrderController = TextEditingController(text: c?.minOrderAmount.toString() ?? '');
    _maxDiscountController = TextEditingController(text: c?.maxDiscountAmount?.toString() ?? '');
    _usageLimitController = TextEditingController(text: c?.usageLimit.toString() ?? '');
    _selectedType = c?.type ?? CouponType.percentage;
    _validFrom = c?.validFrom ?? DateTime.now();
    _validTo = c?.validTo ?? DateTime.now().add(const Duration(days: 30));
    _isActive = c?.isActive ?? true;
    _buyProductId = c?.buyProductId;
    _getProductId = c?.getProductId;

    // Preload products for BOGO dropdowns
    Future.microtask(() =>
        Provider.of<ProductProvider>(context, listen: false).fetchProducts());
  }

  @override
  void dispose() {
    _codeController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _discountController.dispose();
    _minOrderController.dispose();
    _maxDiscountController.dispose();
    _usageLimitController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedType == CouponType.buyOneGetOne) {
      if (_buyProductId == null || _getProductId == null) {
        SnackbarHelper.showError(context, 'Please select Buy & Get products for BOGO coupon');
        return;
      }
    }

    setState(() => _isSaving = true);

    final coupon = CouponModel(
      id: widget.coupon?.id ?? '',
      code: _codeController.text.trim().toUpperCase(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      type: _selectedType,
      discount: _selectedType == CouponType.buyOneGetOne
          ? 0
          : double.tryParse(_discountController.text.trim()) ?? 0,
      minOrderAmount: _minOrderController.text.trim().isNotEmpty
          ? double.tryParse(_minOrderController.text.trim()) ?? 0
          : 0,
      maxDiscountAmount: _maxDiscountController.text.trim().isNotEmpty
          ? double.tryParse(_maxDiscountController.text.trim())
          : null,
      usageLimit: _usageLimitController.text.trim().isNotEmpty
          ? int.tryParse(_usageLimitController.text.trim()) ?? 0
          : 0,
      usedCount: widget.coupon?.usedCount ?? 0,
      isActive: _isActive,
      validFrom: _validFrom,
      validTo: _validTo,
      createdAt: widget.coupon?.createdAt ?? DateTime.now(),
      buyProductId: _selectedType == CouponType.buyOneGetOne ? _buyProductId : null,
      getProductId: _selectedType == CouponType.buyOneGetOne ? _getProductId : null,
    );

    final provider = Provider.of<CouponProvider>(context, listen: false);

    try {
      if (widget.coupon == null) {
        await provider.addCoupon(coupon);
        if (context.mounted) {
          Navigator.pop(context);
          SnackbarHelper.showSuccess(context, '✅ Coupon created successfully!');
        }
      } else {
        await provider.updateCoupon(coupon);
        if (context.mounted) {
          Navigator.pop(context);
          SnackbarHelper.showSuccess(context, '✅ Coupon updated successfully!');
        }
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.showError(
            context,
            '❌ Failed to ${widget.coupon == null ? 'create' : 'update'} coupon: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _generateCouponCode() {
    final codes = [
      'SAVE${DateTime.now().millisecondsSinceEpoch % 1000}',
      'DEAL${DateTime.now().millisecondsSinceEpoch % 1000}',
      'OFFER${DateTime.now().millisecondsSinceEpoch % 1000}',
      'SPECIAL${DateTime.now().millisecondsSinceEpoch % 1000}',
    ];
    _codeController.text = codes[DateTime.now().millisecond % codes.length];
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _validFrom : _validTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) _validFrom = picked;
        else _validTo = picked;
      });
    }
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: Colors.white.withOpacity(0.98),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.local_offer_rounded,
                              color: AppColors.primary, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          widget.coupon == null ? 'Add New Coupon' : 'Edit Coupon',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Coupon Code
                    TextFormField(
                      controller: _codeController,
                      enabled: widget.coupon == null,
                      decoration: InputDecoration(
                        labelText: 'Coupon Code *',
                        hintText: 'e.g., SAVE20',
                        prefixIcon: const Icon(Icons.code_rounded),
                        suffixIcon: widget.coupon == null
                            ? IconButton(
                                icon: const Icon(Icons.auto_awesome_rounded),
                                onPressed: _generateCouponCode,
                              )
                            : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                        LengthLimitingTextInputFormatter(20),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Please enter coupon code';
                        if (value.trim().length < 3) return 'Code must be at least 3 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Title
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Title *',
                        hintText: 'e.g., 20% Off on All Products',
                        prefixIcon: const Icon(Icons.title_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Please enter title' : null,
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description *',
                        hintText: 'Describe the offer details',
                        prefixIcon: const Icon(Icons.description_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      maxLines: 3,
                      validator: (value) => value == null || value.trim().isEmpty ? 'Please enter description' : null,
                    ),
                    const SizedBox(height: 20),

                    // Discount Type segmented
                    Text('Discount Type', style: _labelStyle(isRequired: true)),
                    const SizedBox(height: 8),
                    SegmentedButton<CouponType>(
                      segments: const [
                        ButtonSegment(value: CouponType.percentage, label: Text('Percentage')),
                        ButtonSegment(value: CouponType.flat, label: Text('Flat')),
                        ButtonSegment(value: CouponType.buyOneGetOne, label: Text('Buy 1 Get 1')),
                      ],
                      selected: {_selectedType},
                      onSelectionChanged: (v) => setState(() => _selectedType = v.first),
                    ),
                    const SizedBox(height: 16),

                    // 💥 BOGO Product Selection
                    if (_selectedType == CouponType.buyOneGetOne) ...[
                      const SizedBox(height: 12),
                      Text('Select Buy & Get Products', style: _labelStyle(isRequired: true)),
                      const SizedBox(height: 8),
                      Consumer<ProductProvider>(
                        builder: (context, productProvider, _) {
                          final products = productProvider.products;
                          if (products.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text('No products available. Add some products first.'),
                            );
                          }
                          return Column(
                            children: [
                              DropdownButtonFormField<String>(
                                value: _buyProductId,
                                items: products
                                    .map<DropdownMenuItem<String>>(
                                      (p) => DropdownMenuItem<String>(
                                        value: p.id,
                                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                                      ),
                                    )
                                    .toList(),
                                decoration: InputDecoration(
                                  labelText: 'Product to Buy',
                                  prefixIcon: const Icon(Icons.shopping_bag_rounded),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                onChanged: (value) => setState(() => _buyProductId = value),
                                validator: (v) => v == null || v.isEmpty ? 'Select product to buy' : null,
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: _getProductId,
                                items: products
                                    .map<DropdownMenuItem<String>>(
                                      (p) => DropdownMenuItem<String>(
                                        value: p.id,
                                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                                      ),
                                    )
                                    .toList(),
                                decoration: InputDecoration(
                                  labelText: 'Product to Get (Free)',
                                  prefixIcon: const Icon(Icons.card_giftcard_rounded),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                onChanged: (value) => setState(() => _getProductId = value),
                                validator: (v) => v == null || v.isEmpty ? 'Select product to give' : null,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_selectedType != CouponType.buyOneGetOne) ...[
                      TextFormField(
                        controller: _discountController,
                        decoration: InputDecoration(
                          labelText: _selectedType == CouponType.percentage ? 'Discount Percentage *' : 'Discount Amount *',
                          hintText: _selectedType == CouponType.percentage ? '20' : '100',
                          prefixIcon: Icon(_selectedType == CouponType.percentage ? Icons.percent_rounded : Icons.currency_rupee_rounded),
                          suffixText: _selectedType == CouponType.percentage ? '%' : '₹',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Please enter discount value';
                          final d = double.tryParse(value);
                          if (d == null || d <= 0) return 'Enter valid discount';
                          if (_selectedType == CouponType.percentage && d > 100) return 'Percentage cannot exceed 100';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    _buildAdvancedSettings(),
                    const SizedBox(height: 20),
                    _buildDateSelectors(),
                    const SizedBox(height: 20),
                    _buildStatusSwitch(),
                    const SizedBox(height: 24),
                    _buildSaveButton(colorScheme),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, size: 24),
              color: Colors.black54,
              tooltip: 'Close',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSettings() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.settings_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Advanced Settings', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          TextFormField(
            controller: _minOrderController,
            decoration: InputDecoration(
              labelText: 'Minimum Order Amount',
              hintText: '500',
              prefixIcon: const Icon(Icons.shopping_cart_rounded),
              suffixText: '₹',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
          ),
          const SizedBox(height: 12),
          if (_selectedType == CouponType.percentage)
            TextFormField(
              controller: _maxDiscountController,
              decoration: InputDecoration(
                labelText: 'Maximum Discount Amount (Optional)',
                hintText: '200',
                prefixIcon: const Icon(Icons.money_off_rounded),
                suffixText: '₹',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
            ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _usageLimitController,
            decoration: InputDecoration(
              labelText: 'Usage Limit',
              hintText: '100',
              prefixIcon: const Icon(Icons.people_alt_rounded),
              helperText: 'Set to 0 for unlimited uses',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelectors() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _pickDate(isFrom: true),
            child: _buildDateTile('Start', _validFrom, Icons.event_available_rounded),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => _pickDate(isFrom: false),
            child: _buildDateTile('End', _validTo, Icons.event_busy_rounded),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTile(String label, DateTime date, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 8),
          Text('$label: ${_formatDate(date)}', style: AppTextStyles.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildStatusSwitch() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isActive ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isActive ? Colors.green.shade200 : Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(_isActive ? Icons.check_circle : Icons.cancel_rounded, color: _isActive ? Colors.green : Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Coupon Status', style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                Text(_isActive ? 'Users can use this coupon' : 'Coupon is disabled', style: AppTextStyles.bodySmall.copyWith(color: Colors.grey.shade600)),
              ],
            ),
          ),
          Switch(value: _isActive, onChanged: (v) => setState(() => _isActive = v), activeColor: Colors.green),
        ],
      ),
    );
  }

  Widget _buildSaveButton(ColorScheme colorScheme) {
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton.icon(
        icon: _isSaving
            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.check_circle_outline),
        label: Text(_isSaving ? 'Saving...' : (widget.coupon == null ? 'Create Coupon' : 'Update Coupon')),
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: 4,
        ),
        onPressed: _isSaving ? null : _save,
      ),
    );
  }

  TextStyle _labelStyle({bool isRequired = false}) => TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: Colors.black87);
}