import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/themes/admin_colors.dart';

/// Premium Specification Form with AdminColors theme
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
  final _keyFocusNode = FocusNode();
  final _valueFocusNode = FocusNode();

  // Common specs suggestions
  final List<String> _suggestions = [
    'Weight',
    'Dimensions',
    'Material',
    'Color',
    'Size',
    'Brand',
    'Warranty',
    'Expiry Date',
    'Country of Origin',
    'Ingredients',
  ];

  void _addSpecification() {
    if (_keyController.text.trim().isNotEmpty && _valueController.text.trim().isNotEmpty) {
      HapticFeedback.lightImpact();
      final newSpecs = {...widget.specifications};
      newSpecs[_keyController.text.trim()] = _valueController.text.trim();
      widget.onSpecificationsChanged(newSpecs);
      _keyController.clear();
      _valueController.clear();
      _keyFocusNode.requestFocus();
    }
  }

  void _removeSpecification(String key) {
    HapticFeedback.mediumImpact();
    final newSpecs = {...widget.specifications};
    newSpecs.remove(key);
    widget.onSpecificationsChanged(newSpecs);
  }

  void _useSuggestion(String suggestion) {
    HapticFeedback.selectionClick();
    _keyController.text = suggestion;
    _valueFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _keyController.dispose();
    _valueController.dispose();
    _keyFocusNode.dispose();
    _valueFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header
        _buildSectionHeader(
          icon: Icons.list_alt_rounded,
          title: 'Product Specifications',
          subtitle: 'Add technical details and attributes',
        ),
        const SizedBox(height: 24),

        // Add Spec Card
        _buildAddSpecCard(),
        const SizedBox(height: 20),

        // Quick Suggestions
        _buildQuickSuggestions(),
        const SizedBox(height: 24),

        // Specifications List
        if (widget.specifications.isEmpty)
          _buildEmptyState()
        else
          _buildSpecsList(),

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

  Widget _buildAddSpecCard() {
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
          Row(
            children: [
              Expanded(
                child: _buildPremiumTextField(
                  controller: _keyController,
                  focusNode: _keyFocusNode,
                  label: 'Specification Name',
                  hint: 'e.g., Weight',
                  icon: Icons.label_outline_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPremiumTextField(
                  controller: _valueController,
                  focusNode: _valueFocusNode,
                  label: 'Value',
                  hint: 'e.g., 5 kg',
                  icon: Icons.notes_rounded,
                  onSubmitted: (_) => _addSpecification(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Material(
              color: AdminColors.primary,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _addSpecification,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Add Specification',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSuggestions() {
    // Filter out already used specs
    final available = _suggestions.where((s) => !widget.specifications.containsKey(s)).toList();
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
          children: available.take(6).map((suggestion) {
            return Material(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () => _useSuggestion(suggestion),
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
                      Text(
                        suggestion,
                        style: TextStyle(
                          fontSize: 13,
                          color: AdminColors.textPrimary,
                        ),
                      ),
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

  Widget _buildSpecsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AdminColors.success, size: 18),
            const SizedBox(width: 8),
            Text(
              '${widget.specifications.length} Specification${widget.specifications.length > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AdminColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...widget.specifications.entries.map((entry) => _buildSpecCard(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildSpecCard(String key, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AdminColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.check_rounded, color: AdminColors.success, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    key,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AdminColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      color: AdminColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _removeSpecification(key),
              icon: Icon(Icons.delete_outline_rounded, color: AdminColors.error, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: AdminColors.error.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.list_alt_rounded,
              size: 40,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No specifications added',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AdminColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add product details like weight, dimensions, etc.',
            style: TextStyle(
              fontSize: 13,
              color: AdminColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    void Function(String)? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      onFieldSubmitted: onSubmitted,
      style: TextStyle(
        fontSize: 15,
        color: AdminColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: AdminColors.textSecondary,
          fontSize: 14,
        ),
        hintText: hint,
        hintStyle: TextStyle(
          color: AdminColors.textSecondary.withOpacity(0.6),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          icon,
          color: AdminColors.primary,
          size: 22,
        ),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}