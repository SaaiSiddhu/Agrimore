import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../app/themes/app_text_styles.dart';
import '../../../../models/product_model.dart';
import '../../../../providers/theme_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _currentOptions = List.from(widget.variantOptions);
    _currentVariants = List.from(widget.variants);
    for (var option in _currentOptions) {
      _optionValueControllers[option.name] = TextEditingController();
    }
  }

  void _addOption() {
    final name = _optionNameController.text.trim();
    if (name.isNotEmpty && !_currentOptions.any((o) => o.name == name)) {
      setState(() {
        _currentOptions.add(VariantOption(name: name, values: []));
        _optionValueControllers[name] = TextEditingController();
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
    setState(() {
      _currentOptions.removeWhere((o) => o.name == optionName);
      _optionValueControllers.remove(optionName);
      _generateVariants();
    });
    _notifyParent();
  }

  void _removeOptionValue(String optionName, String value) {
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
      // Try to find existing variant to preserve price/stock
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
    setState(() {
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
    });
    _notifyParent();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final inputFillColor = isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoCard(isDark, accentColor, cardColor),
        const SizedBox(height: 24),
        _buildAddOptionCard(isDark, inputFillColor, accentColor),
        const SizedBox(height: 16),
        ..._currentOptions.map((option) => 
          _buildOptionValuesCard(option, isDark, inputFillColor, cardColor)
        ),
        const SizedBox(height: 24),
        _buildGeneratedVariantsSection(isDark, cardColor, inputFillColor),
      ],
    );
  }

  Widget _buildInfoCard(bool isDark, Color accentColor, Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.layers, size: 40, color: accentColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Product Variants', style: AppTextStyles.titleMedium.copyWith(color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 4),
                Text(
                  'Add options like "Color" or "Size". Variants will be auto-generated.',
                  style: AppTextStyles.bodySmall.copyWith(color: isDark ? Colors.grey[400] : AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAddOptionCard(bool isDark, Color inputFillColor, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add New Option', style: AppTextStyles.titleSmall.copyWith(color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextFormField(
                  controller: _optionNameController,
                  hint: 'e.g., Color',
                  icon: Icons.style_outlined,
                  isDark: isDark,
                  fillColor: inputFillColor,
                  onSubmitted: (_) => _addOption(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _addOption,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionValuesCard(VariantOption option, bool isDark, Color inputFillColor, Color cardColor) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(option.name, style: AppTextStyles.titleMedium.copyWith(color: isDark ? Colors.white : Colors.black87)),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                onPressed: () => _removeOption(option.name),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildTextFormField(
                  controller: _optionValueControllers[option.name]!,
                  hint: 'e.g., Red, Blue, Small...',
                  icon: Icons.label_outline,
                  isDark: isDark,
                  fillColor: inputFillColor,
                  onSubmitted: (_) => _addOptionValue(option.name),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => _addOptionValue(option.name),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[200],
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Add Value'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: option.values.map((value) {
              return Chip(
                label: Text(value, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                onDeleted: () => _removeOptionValue(option.name, value),
                deleteIcon: const Icon(Icons.close, size: 14),
                backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratedVariantsSection(bool isDark, Color cardColor, Color inputFillColor) {
    if (_currentVariants.isEmpty) {
      if (_currentOptions.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.add_to_photos_outlined, size: 60, color: isDark ? Colors.grey[700] : Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Add values to your options', style: AppTextStyles.bodyLarge.copyWith(color: isDark ? Colors.white70 : Colors.black87)),
            const SizedBox(height: 8),
            Text(
              'Variants will be generated here automatically.',
              style: AppTextStyles.bodySmall.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Generated Variants (${_currentVariants.length})',
          style: AppTextStyles.titleMedium.copyWith(color: isDark ? Colors.white : Colors.black87),
        ),
        const SizedBox(height: 12),
        ..._currentVariants.asMap().entries.map((entry) {
          int index = entry.key;
          ProductVariant variant = entry.value;
          return Card(
            color: cardColor,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!)
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(variant.name, style: AppTextStyles.titleSmall.copyWith(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextFormField(
                          controller: TextEditingController(text: variant.salePrice.toStringAsFixed(0)),
                          label: 'Price (₹)',
                          hint: '0',
                          icon: Icons.currency_rupee,
                          isDark: isDark,
                          fillColor: inputFillColor,
                          keyboardType: TextInputType.number,
                          onSubmitted: (val) => _updateVariant(index, price: double.tryParse(val)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextFormField(
                          controller: TextEditingController(text: variant.stock.toString()),
                          label: 'Stock',
                          hint: '0',
                          icon: Icons.inventory_2_outlined,
                          isDark: isDark,
                          fillColor: inputFillColor,
                          keyboardType: TextInputType.number,
                          onSubmitted: (val) => _updateVariant(index, stock: int.tryParse(val)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
  
  Widget _buildTextFormField({
    required TextEditingController controller,
    String? label,
    required String hint,
    required IconData icon,
    required bool isDark,
    required Color fillColor,
    void Function(String)? onSubmitted,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
        prefixIcon: Icon(icon, color: isDark ? Colors.grey[400] : Colors.grey[600], size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)
        ),
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)
      ),
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      keyboardType: keyboardType,
    );
  }
}