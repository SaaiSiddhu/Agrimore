// lib/screens/admin/marketing/widgets/coupon_form.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../app/themes/app_text_styles.dart';
import '../../../../models/coupon_model.dart';

class CouponForm extends StatefulWidget {
  final CouponModel? coupon;
  final Function(CouponModel) onSubmit;

  const CouponForm({
    Key? key,
    this.coupon,
    required this.onSubmit,
  }) : super(key: key);

  @override
  State<CouponForm> createState() => _CouponFormState();
}

class _CouponFormState extends State<CouponForm> {
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

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.coupon?.code ?? '');
    _titleController = TextEditingController(text: widget.coupon?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.coupon?.description ?? '');
    _discountController =
        TextEditingController(text: widget.coupon?.discount.toString() ?? '');
    _minOrderController = TextEditingController(
        text: widget.coupon?.minOrderAmount.toString() ?? '');
    _maxDiscountController = TextEditingController(
        text: widget.coupon?.maxDiscountAmount?.toString() ?? '');
    _usageLimitController = TextEditingController(
        text: widget.coupon?.usageLimit.toString() ?? '');
    _selectedType = widget.coupon?.type ?? CouponType.percentage;
    _validFrom = widget.coupon?.validFrom ?? DateTime.now();
    _validTo =
        widget.coupon?.validTo ?? DateTime.now().add(const Duration(days: 30));
    _isActive = widget.coupon?.isActive ?? true;
  }

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final coupon = CouponModel(
      id: widget.coupon?.id ?? '',
      code: _codeController.text.trim().toUpperCase(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      type: _selectedType,
      discount: _selectedType == CouponType.buyOneGetOne
          ? 0
          : double.parse(_discountController.text.trim()),
      minOrderAmount: _minOrderController.text.trim().isNotEmpty
          ? double.parse(_minOrderController.text.trim())
          : 0,
      maxDiscountAmount: _maxDiscountController.text.trim().isNotEmpty
          ? double.parse(_maxDiscountController.text.trim())
          : null,
      usageLimit: _usageLimitController.text.trim().isNotEmpty
          ? int.parse(_usageLimitController.text.trim())
          : 0,
      usedCount: widget.coupon?.usedCount ?? 0,
      isActive: _isActive,
      validFrom: _validFrom,
      validTo: _validTo,
      createdAt: widget.coupon?.createdAt ?? DateTime.now(),
    );

    await Future.delayed(const Duration(milliseconds: 800)); // smooth UX delay

    widget.onSubmit(coupon);
    if (mounted) setState(() => _isSaving = false);
  }

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
                    _headerSection(context),
                    const SizedBox(height: 24),

                    // Coupon Code
                    _buildTextField(
                      controller: _codeController,
                      label: 'Coupon Code',
                      icon: Icons.code_rounded,
                      isRequired: true,
                      hint: 'e.g., SAVE20, WELCOME50',
                      readOnly: widget.coupon != null,
                      suffixIcon: widget.coupon == null
                          ? IconButton(
                              icon: const Icon(Icons.auto_awesome_rounded),
                              onPressed: _generateCouponCode,
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Title
                    _buildTextField(
                      controller: _titleController,
                      label: 'Title',
                      icon: Icons.title_rounded,
                      isRequired: true,
                      hint: 'e.g., 20% Off on All Products',
                    ),
                    const SizedBox(height: 16),

                    // Description
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Description',
                      icon: Icons.description_rounded,
                      hint: 'Describe the offer details',
                      maxLines: 3,
                      isRequired: true,
                    ),
                    const SizedBox(height: 20),

                    // Discount Type Segmented Selector
                    Text('Discount Type',
                        style: _labelStyle(isRequired: true)),
                    const SizedBox(height: 8),
                    SegmentedButton<CouponType>(
                      segments: const [
                        ButtonSegment(
                            value: CouponType.percentage,
                            label: Text('Percentage')),
                        ButtonSegment(
                            value: CouponType.flat, label: Text('Flat')),
                        ButtonSegment(
                            value: CouponType.buyOneGetOne,
                            label: Text('Buy 1 Get 1')),
                      ],
                      selected: {_selectedType},
                      onSelectionChanged: (v) =>
                          setState(() => _selectedType = v.first),
                    ),
                    const SizedBox(height: 24),

                    // Discount Value (if not BOGO)
                    if (_selectedType != CouponType.buyOneGetOne)
                      _buildTextField(
                        controller: _discountController,
                        label: _selectedType == CouponType.percentage
                            ? 'Discount Percentage'
                            : 'Discount Amount',
                        icon: _selectedType == CouponType.percentage
                            ? Icons.percent_rounded
                            : Icons.currency_rupee_rounded,
                        hint: _selectedType == CouponType.percentage
                            ? '20'
                            : '100',
                        inputType: TextInputType.number,
                        suffixText:
                            _selectedType == CouponType.percentage ? '%' : '₹',
                        isRequired: true,
                      ),
                    if (_selectedType != CouponType.buyOneGetOne)
                      const SizedBox(height: 24),

                    // Advanced Settings
                    _advancedSettingsSection(),
                    const SizedBox(height: 24),

                    // Validity Dates
                    Row(
                      children: [
                        Expanded(
                          child: _buildDatePicker(
                            label: 'Start Date',
                            icon: Icons.event_available_rounded,
                            date: _validFrom,
                            onDateSelected: (d) =>
                                setState(() => _validFrom = d),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDatePicker(
                            label: 'End Date',
                            icon: Icons.event_busy_rounded,
                            date: _validTo,
                            onDateSelected: (d) => setState(() => _validTo = d),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Status Switch
                    _statusToggle(),
                    const SizedBox(height: 28),

                    // Save Button
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        icon: _isSaving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                          _isSaving
                              ? 'Saving...'
                              : widget.coupon == null
                                  ? 'Create Coupon'
                                  : 'Update Coupon',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                          elevation: 4,
                        ),
                        onPressed: _isSaving ? null : _handleSubmit,
                      ),
                    ),
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
              icon: const Icon(Icons.close_rounded),
              color: Colors.black54,
              tooltip: 'Close',
            ),
          ),
        ],
      ),
    );
  }

  // -------------------- COMPONENTS --------------------

  Widget _headerSection(BuildContext context) {
    return Row(
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
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isRequired = false,
    String? hint,
    int maxLines = 1,
    TextInputType inputType = TextInputType.text,
    String? suffixText,
    bool readOnly = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      maxLines: maxLines,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: '$label${isRequired ? " *" : ""}',
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        suffixText: suffixText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: (value) {
        if (isRequired && (value == null || value.trim().isEmpty)) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }

  Widget _advancedSettingsSection() {
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
            Text('Advanced Settings',
                style: AppTextStyles.titleMedium
                    .copyWith(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _minOrderController,
            label: 'Minimum Order Amount',
            icon: Icons.shopping_cart_rounded,
            hint: '500',
            suffixText: '₹',
            inputType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          if (_selectedType == CouponType.percentage)
            _buildTextField(
              controller: _maxDiscountController,
              label: 'Maximum Discount Amount',
              icon: Icons.money_off_rounded,
              hint: '200',
              suffixText: '₹',
              inputType: TextInputType.number,
            ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _usageLimitController,
            label: 'Usage Limit',
            icon: Icons.people_alt_rounded,
            hint: '100',
            inputType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required IconData icon,
    required DateTime date,
    required Function(DateTime) onDateSelected,
  }) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(primary: AppColors.primary),
            ),
            child: child!,
          ),
        );
        if (picked != null) onDateSelected(picked);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('${date.day}/${date.month}/${date.year}',
                style: AppTextStyles.bodyLarge),
          ],
        ),
      ),
    );
  }

  Widget _statusToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isActive ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _isActive ? Colors.green.shade200 : Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(_isActive ? Icons.check_circle : Icons.cancel_rounded,
              color: _isActive ? Colors.green : Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Coupon Status',
                    style: AppTextStyles.titleSmall
                        .copyWith(fontWeight: FontWeight.bold)),
                Text(
                    _isActive
                        ? 'Users can use this coupon'
                        : 'Coupon is disabled',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: Colors.grey.shade600)),
              ],
            ),
          ),
          Switch(
            value: _isActive,
            onChanged: (v) => setState(() => _isActive = v),
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }

  TextStyle _labelStyle({bool isRequired = false}) => TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14.5,
        color: Colors.black87,
      );

  void _generateCouponCode() {
    final codes = [
      'SAVE${DateTime.now().millisecondsSinceEpoch % 1000}',
      'DEAL${DateTime.now().millisecondsSinceEpoch % 1000}',
      'OFFER${DateTime.now().millisecondsSinceEpoch % 1000}',
      'SPECIAL${DateTime.now().millisecondsSinceEpoch % 1000}',
    ];
    _codeController.text = codes[DateTime.now().millisecond % codes.length];
  }
}