import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../app/themes/app_text_styles.dart';
import '../../../../providers/theme_provider.dart';

class SpecificationForm extends StatefulWidget {
  final Map<String, String> specifications;
  final Function(Map<String, String>) onSpecificationsChanged;

  const SpecificationForm({
    Key? key,
    required this.specifications,
    required this.onSpecificationsChanged,
  }) : super(key: key);

  @override
  State<SpecificationForm> createState() => _SpecificationFormState();
}

class _SpecificationFormState extends State<SpecificationForm> {
  final _keyController = TextEditingController();
  final _valueController = TextEditingController();

  void _addSpecification() {
    if (_keyController.text.trim().isNotEmpty && _valueController.text.trim().isNotEmpty) {
      final newSpecs = {...widget.specifications};
      newSpecs[_keyController.text.trim()] = _valueController.text.trim();
      widget.onSpecificationsChanged(newSpecs);
      _keyController.clear();
      _valueController.clear();
      FocusScope.of(context).unfocus(); // Dismiss keyboard
    }
  }

  void _removeSpecification(String key) {
    final newSpecs = {...widget.specifications};
    newSpecs.remove(key);
    widget.onSpecificationsChanged(newSpecs);
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
        // Info Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 40, color: AppColors.info),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Product Specifications', style: AppTextStyles.titleMedium.copyWith(color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 4),
                    Text(
                      'Add details like weight, dimensions, etc.',
                      style: AppTextStyles.bodySmall.copyWith(color: isDark ? Colors.grey[400] : AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Add Specification Form
        _buildTextFormField(
          controller: _keyController,
          label: 'Specification Name',
          hint: 'e.g., Weight',
          icon: Icons.label_outline,
          isDark: isDark,
          fillColor: inputFillColor,
        ),
        const SizedBox(height: 12),
        _buildTextFormField(
          controller: _valueController,
          label: 'Value',
          hint: 'e.g., 5 kg',
          icon: Icons.notes,
          isDark: isDark,
          fillColor: inputFillColor,
          onSubmitted: (_) => _addSpecification(),
        ),

        const SizedBox(height: 12),

        ElevatedButton.icon(
          onPressed: _addSpecification,
          icon: const Icon(Icons.add),
          label: const Text('Add Specification'),
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: isDark ? Colors.black : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

        const SizedBox(height: 24),

        // Specifications List
        if (widget.specifications.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.list_alt, size: 60, color: isDark ? Colors.grey[700] : Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No specifications added', style: AppTextStyles.bodyLarge.copyWith(color: isDark ? Colors.white70 : Colors.black87)),
                  const SizedBox(height: 8),
                  Text(
                    'Add product specifications above',
                    style: AppTextStyles.bodySmall.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          ...widget.specifications.entries.map((entry) {
            return Card(
              color: cardColor,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!)
              ),
              child: ListTile(
                leading: Icon(Icons.check_circle, color: AppColors.success),
                title: Text(entry.key, style: AppTextStyles.titleSmall.copyWith(color: isDark ? Colors.white : Colors.black87)),
                subtitle: Text(entry.value, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.error),
                  onPressed: () => _removeSpecification(entry.key),
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

    Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    required Color fillColor,
    void Function(String)? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
        prefixIcon: Icon(icon, color: isDark ? Colors.grey[400] : Colors.grey[600]),
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
      ),
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
    );
  }
}