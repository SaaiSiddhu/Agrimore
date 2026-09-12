import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/home_product_section_provider.dart';

/// Create/edit one Home product-carousel section — category + optional
/// title override + item cap + active toggle. Category dropdown mirrors
/// `add_edit_banner_dialog.dart`'s own `Consumer<AdminProvider>` pattern exactly.
class AddEditHomeProductSectionDialog extends StatefulWidget {
  final HomeProductSectionConfigModel? existing;

  const AddEditHomeProductSectionDialog({super.key, this.existing});

  @override
  State<AddEditHomeProductSectionDialog> createState() =>
      _AddEditHomeProductSectionDialogState();
}

class _AddEditHomeProductSectionDialogState
    extends State<AddEditHomeProductSectionDialog> {
  String? _selectedCategoryId;
  late final TextEditingController _titleController;
  late final TextEditingController _maxItemsController;
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.existing?.categoryId;
    _titleController = TextEditingController(text: widget.existing?.titleOverride ?? '');
    _maxItemsController =
        TextEditingController(text: (widget.existing?.maxItems ?? 10).toString());
    _isActive = widget.existing?.isActive ?? true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);
      if (adminProvider.categories.isEmpty) {
        adminProvider.loadCategories();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _maxItemsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      SnackbarHelper.showError(context, 'Choose a category for this section');
      return;
    }
    final maxItems = int.tryParse(_maxItemsController.text.trim());
    if (maxItems == null || maxItems < 1) {
      SnackbarHelper.showError(context, 'Max items must be a positive number');
      return;
    }

    setState(() => _isSaving = true);
    final provider = Provider.of<HomeProductSectionProvider>(context, listen: false);
    final title = _titleController.text.trim();

    bool ok;
    if (widget.existing == null) {
      ok = await provider.addSection(HomeProductSectionConfigModel(
        id: '',
        categoryId: _selectedCategoryId!,
        titleOverride: title.isEmpty ? null : title,
        maxItems: maxItems,
        position: 0,
        isActive: _isActive,
      ));
    } else {
      ok = await provider.updateSection(widget.existing!.copyWith(
        categoryId: _selectedCategoryId,
        titleOverride: title.isEmpty ? null : title,
        maxItems: maxItems,
        isActive: _isActive,
      ));
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) {
      Navigator.pop(context);
      SnackbarHelper.showSuccess(
          context, widget.existing == null ? 'Section added' : 'Section updated');
    } else {
      SnackbarHelper.showError(context, provider.error ?? 'Failed to save section');
    }
  }

  Widget _categoryDropdown() {
    return Consumer<AdminProvider>(
      builder: (context, adminProvider, _) {
        final categories = adminProvider.categories;
        final validSelection =
            categories.any((c) => c.id == _selectedCategoryId) ? _selectedCategoryId : null;
        return DropdownButtonFormField<String>(
          initialValue: validSelection,
          decoration: const InputDecoration(
            labelText: 'Category',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          hint: Text(categories.isEmpty ? 'Loading categories…' : 'Choose a category'),
          items: categories
              .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) => setState(() => _selectedCategoryId = v),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Home Section' : 'Edit Home Section'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _categoryDropdown(),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title override (optional)',
                hintText: 'Leave blank to use the category name',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _maxItemsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Max items',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
