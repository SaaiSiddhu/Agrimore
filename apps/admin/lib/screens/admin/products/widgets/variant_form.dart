import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../../app/themes/admin_colors.dart';

/// Premium Variant Form with AdminColors theme
class VariantForm extends StatefulWidget {
  final List<VariantOption> variantOptions;
  final List<ProductVariant> variants;
  final Function(List<VariantOption>, List<ProductVariant>) onVariantsChanged;

  const VariantForm({
    Key? key,
    required this.variantOptions,
    required this.variants,
    required this.onVariantsChanged,
  }) : super(key: key);

  @override
  State<VariantForm> createState() => _VariantFormState();
}

class _VariantFormState extends State<VariantForm> {
  final _optionNameController = TextEditingController();
  final Map<String, TextEditingController> _optionValueControllers = {};

  List<ProductVariant> _currentVariants = [];
  List<VariantOption> _currentOptions = [];

  // Common option suggestions
  final List<String> _optionSuggestions = ['Color', 'Size', 'Weight', 'Pack Size', 'Material'];

  @override
  void initState() {
    super.initState();
    _currentOptions = List.from(widget.variantOptions);
    _currentVariants = List.from(widget.variants);
    for (var option in _currentOptions) {
      _optionValueControllers[option.name] = TextEditingController();
    }
  }

  void _addOption([String? name]) {
    final optionName = name ?? _optionNameController.text.trim();
    if (optionName.isNotEmpty && !_currentOptions.any((o) => o.name == optionName)) {
      HapticFeedback.lightImpact();
      setState(() {
        _currentOptions.add(VariantOption(name: optionName, values: []));
        _optionValueControllers[optionName] = TextEditingController();
      });
      _optionNameController.clear();
      _notifyParent();
    }
  }

  void _addOptionValue(String optionName) {
    final controller = _optionValueControllers[optionName];
    if (controller == null) return;
    final value = controller.text.trim();
    
    if (value.isNotEmpty) {
      HapticFeedback.selectionClick();
      setState(() {
        final option = _currentOptions.firstWhere((o) => o.name == optionName);
        if (!option.values.contains(value)) {
          option.values.add(value);
          controller.clear();
          _generateVariants();
        }
      });
      _notifyParent();
    }
  }

  void _removeOption(String optionName) {
    HapticFeedback.mediumImpact();
    setState(() {
      _currentOptions.removeWhere((o) => o.name == optionName);
      _optionValueControllers.remove(optionName);
      _generateVariants();
    });
    _notifyParent();
  }

  void _removeOptionValue(String optionName, String value) {
    HapticFeedback.selectionClick();
    setState(() {
      final option = _currentOptions.firstWhere((o) => o.name == optionName);
      option.values.remove(value);
      _generateVariants();
    });
    _notifyParent();
  }

  void _generateVariants() {
    if (_currentOptions.isEmpty || _currentOptions.any((o) => o.values.isEmpty)) {
      setState(() {
        _currentVariants = [];
      });
      _notifyParent();
      return;
    }

    List<Map<String, String>> combinations = [{}];
    for (var option in _currentOptions) {
      List<Map<String, String>> newCombinations = [];
      for (var combination in combinations) {
        for (var value in option.values) {
          newCombinations.add({...combination, option.name: value});
        }
      }
      combinations = newCombinations;
    }

    List<ProductVariant> newVariants = [];
    for (var combo in combinations) {
      final name = combo.values.join(' / ');
      final existing = _currentVariants.firstWhere(
        (v) => v.name == name,
        orElse: () => ProductVariant(
          id: const Uuid().v4(),
          name: name,
          options: combo,
          salePrice: 0,
          stock: 0,
        ),
      );
      newVariants.add(existing);
    }

    setState(() {
      _currentVariants = newVariants;
    });
    _notifyParent();
  }

  void _notifyParent() {
    widget.onVariantsChanged(_currentOptions, _currentVariants);
  }

  void _updateVariant(int index, {double? price, int? stock}) {
    final variant = _currentVariants[index];
    _currentVariants[index] = ProductVariant(
      id: variant.id,
      name: variant.name,
      options: variant.options,
      salePrice: price ?? variant.salePrice,
      stock: stock ?? variant.stock,
      sku: variant.sku,
      images: variant.images,
      originalPrice: variant.originalPrice
    );
    _notifyParent();
  }

  @override
  void dispose() {
    _optionNameController.dispose();
    for (var controller in _optionValueControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header
        _buildSectionHeader(
          icon: Icons.layers_rounded,
          title: 'Product Variants',
          subtitle: 'Create options like Color, Size to auto-generate combinations',
        ),
        const SizedBox(height: 24),

        // Add Option Card
        _buildAddOptionCard(),
        const SizedBox(height: 16),

        // Quick Add Options
        if (_currentOptions.isEmpty) ...[
          _buildQuickAddOptions(),
          const SizedBox(height: 16),
        ],

        // Existing Options
        ..._currentOptions.map((option) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildOptionCard(option),
        )),

        // Generated Variants
        if (_currentOptions.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildVariantsSection(),
        ],

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AdminColors.primary.withOpacity(0.08),
            AdminColors.primaryLight.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AdminColors.primary, AdminColors.primaryLight],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AdminColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddOptionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add Option Type',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AdminColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPremiumTextField(
                  controller: _optionNameController,
                  hint: 'e.g., Color, Size',
                  icon: Icons.style_rounded,
                  onSubmitted: (_) => _addOption(),
                ),
              ),
              const SizedBox(width: 12),
              Material(
                color: AdminColors.primary,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => _addOption(),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddOptions() {
    final available = _optionSuggestions.where((s) => !_currentOptions.any((o) => o.name == s)).toList();
    if (available.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Add',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AdminColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: available.map((suggestion) {
            return Material(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () => _addOption(suggestion),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 14, color: AdminColors.primary),
                      const SizedBox(width: 6),
                      Text(suggestion, style: TextStyle(fontSize: 13, color: AdminColors.textPrimary)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildOptionCard(VariantOption option) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AdminColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.style_rounded, color: AdminColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AdminColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _removeOption(option.name),
                icon: Icon(Icons.delete_outline_rounded, color: AdminColors.error, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: AdminColors.error.withOpacity(0.1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildPremiumTextField(
                  controller: _optionValueControllers[option.name]!,
                  hint: 'Add value (e.g., Red, Blue)',
                  icon: Icons.label_outline_rounded,
                  onSubmitted: (_) => _addOptionValue(option.name),
                ),
              ),
              const SizedBox(width: 12),
              Material(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => _addOptionValue(option.name),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AdminColors.primary.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AdminColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (option.values.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: option.values.map((value) => _buildValueChip(option.name, value)).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildValueChip(String optionName, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AdminColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AdminColors.primary,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => _removeOptionValue(optionName, value),
            child: Icon(Icons.close_rounded, size: 14, color: AdminColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantsSection() {
    if (_currentVariants.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_box_outlined, size: 36, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 16),
            Text(
              'Add values to generate variants',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AdminColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Variants will appear here automatically',
              style: TextStyle(
                fontSize: 12,
                color: AdminColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: AdminColors.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              '${_currentVariants.length} Variant${_currentVariants.length > 1 ? 's' : ''} Generated',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AdminColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._currentVariants.asMap().entries.map((entry) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildVariantCard(entry.key, entry.value),
        )),
      ],
    );
  }

  Widget _buildVariantCard(int index, ProductVariant variant) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AdminColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              variant.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AdminColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: variant.salePrice > 0 ? variant.salePrice.toStringAsFixed(2) : '',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) => _updateVariant(index, price: double.tryParse(val) ?? 0),
                  style: TextStyle(fontSize: 14, color: AdminColors.textPrimary, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    labelText: 'Price (₹)',
                    labelStyle: TextStyle(color: AdminColors.textSecondary, fontSize: 13),
                    hintText: '0.00',
                    hintStyle: TextStyle(color: AdminColors.textSecondary.withOpacity(0.5)),
                    prefixIcon: Icon(Icons.currency_rupee_rounded, color: AdminColors.primary, size: 18),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AdminColors.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: variant.stock > 0 ? variant.stock.toString() : '',
                  keyboardType: TextInputType.number,
                  onChanged: (val) => _updateVariant(index, stock: int.tryParse(val) ?? 0),
                  style: TextStyle(fontSize: 14, color: AdminColors.textPrimary, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    labelText: 'Stock',
                    labelStyle: TextStyle(color: AdminColors.textSecondary, fontSize: 13),
                    hintText: '0',
                    hintStyle: TextStyle(color: AdminColors.textSecondary.withOpacity(0.5)),
                    prefixIcon: Icon(Icons.inventory_2_rounded, color: AdminColors.primary, size: 18),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AdminColors.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    void Function(String)? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      onFieldSubmitted: onSubmitted,
      style: TextStyle(
        fontSize: 14,
        color: AdminColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: AdminColors.textSecondary.withOpacity(0.6),
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: AdminColors.primary, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AdminColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}