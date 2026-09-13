import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../providers/category_provider.dart';

/// HOME-5: lets an admin pick the title and categories shown by
/// GroceryKitchenHomeStrip on Home, instead of its hardcoded name/slug
/// match. Leaving categories empty keeps that automatic match.
class HomeGroceryStripSettingsScreen extends StatefulWidget {
  const HomeGroceryStripSettingsScreen({Key? key}) : super(key: key);

  @override
  State<HomeGroceryStripSettingsScreen> createState() =>
      _HomeGroceryStripSettingsScreenState();
}

class _HomeGroceryStripSettingsScreenState
    extends State<HomeGroceryStripSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  final _titleController = TextEditingController();
  List<String> _categoryIds = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().loadCategories();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('home_grocery_strip_config')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          final rawTitle = data['titleOverride'];
          if (rawTitle is String && rawTitle.trim().isNotEmpty) {
            _titleController.text = rawTitle;
          }
          _categoryIds = List<String>.from(data['categoryIds'] ?? []);
        });
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to load settings: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('home_grocery_strip_config')
          .set({
        'titleOverride': _titleController.text.trim(),
        'categoryIds': _categoryIds,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        SnackbarHelper.showSuccess(
            context, 'Grocery & Kitchen strip settings saved');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to save settings: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context
        .watch<CategoryProvider>()
        .categories
        .where((c) => c.isActive)
        .toList();
    // See edit_category_section_screen.dart's identical comment: a deleted
    // category's id can outlive it in _categoryIds (AdminProvider.deleteCategory
    // never scrubs this reference), so counting/numbering off the raw list
    // would occupy a slot no chip below can ever show.
    final liveCategoryIds = liveSelectedCategoryIds(_categoryIds, categories);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Grocery & Kitchen Strip'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Home Grocery & Kitchen Strip',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose the title and which categories appear in this Home '
                    'strip. Leave both empty to keep the automatic name match.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Strip title (optional)',
                      hintText: 'Grocery & Kitchen',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Categories (${liveCategoryIds.length}/8)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select up to 8, in the order they should appear. Leave '
                    'empty to use the automatic match (any active category '
                    "whose name or slug contains 'grocery' or 'kitchen').",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 320),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: categories.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Loading categories…'),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: categories.length,
                            separatorBuilder: (_, __) =>
                                Divider(height: 1, color: Colors.grey.shade200),
                            itemBuilder: (context, index) {
                              final category = categories[index];
                              final isSelected =
                                  _categoryIds.contains(category.id);
                              final canSelect =
                                  isSelected || liveCategoryIds.length < 8;

                              return Material(
                                color: isSelected
                                    ? AppColors.primary.withOpacity(0.05)
                                    : Colors.transparent,
                                child: InkWell(
                                  onTap: canSelect
                                      ? () {
                                          HapticFeedback.selectionClick();
                                          setState(() {
                                            if (isSelected) {
                                              _categoryIds.remove(category.id);
                                            } else if (liveCategoryIds.length <
                                                8) {
                                              _categoryIds.add(category.id);
                                            }
                                          });
                                        }
                                      : null,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? AppColors.primary
                                                : Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isSelected
                                                  ? AppColors.primary
                                                  : Colors.grey.shade300,
                                              width: 2,
                                            ),
                                          ),
                                          child: isSelected
                                              ? const Icon(Icons.check,
                                                  size: 14,
                                                  color: Colors.white)
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            category.name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                              color: canSelect
                                                  ? null
                                                  : Colors.grey.shade400,
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '#${liveCategoryIds.indexOf(category.id) + 1}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Save Strip Settings'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
