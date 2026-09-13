import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

/// HOME-9: lets an admin reorder the Home screen's own reorderable content
/// sections, independently per platform -- mobile's and web's own section
/// sets already differ (web alone has `categories_grid`). Mirrors
/// `home_grocery_strip_settings_screen.dart`'s own load/save shape: local
/// state, direct Firestore read/write, no dedicated provider needed on the
/// write side.
///
/// These identifier lists and their human-readable labels intentionally
/// duplicate `HomeSectionOrderProvider`'s own `defaultMobileOrder` /
/// `defaultWebOrder` constants (marketplace app, not importable from here --
/// a separate Flutter app with no shared package between them for this) --
/// matching this codebase's own established convention of repeating a small
/// literal list per call site rather than introducing a new cross-app
/// package dependency for it.
class HomeSectionOrderSettingsScreen extends StatefulWidget {
  const HomeSectionOrderSettingsScreen({Key? key}) : super(key: key);

  @override
  State<HomeSectionOrderSettingsScreen> createState() =>
      _HomeSectionOrderSettingsScreenState();
}

class _HomeSectionOrderSettingsScreenState
    extends State<HomeSectionOrderSettingsScreen> {
  static const List<String> _defaultMobileOrder = [
    'bestsellers',
    'grocery_kitchen_strip',
    'recently_viewed',
    'dynamic_category_sections',
    'product_sections',
  ];

  static const List<String> _defaultWebOrder = [
    'recently_viewed',
    'categories_grid',
    'bestsellers',
    'grocery_kitchen_strip',
    'dynamic_category_sections',
    'product_sections',
  ];

  static const Map<String, String> _labels = {
    'bestsellers': 'Bestsellers',
    'grocery_kitchen_strip': 'Grocery & Kitchen Strip',
    'recently_viewed': 'Recently Viewed',
    'dynamic_category_sections': 'Dynamic Category Sections',
    'product_sections': 'Product Sections by Category',
    'categories_grid': 'Categories Grid',
  };

  bool _isLoading = true;
  bool _isSaving = false;
  late List<String> _mobileOrder;
  late List<String> _webOrder;

  @override
  void initState() {
    super.initState();
    _mobileOrder = List.of(_defaultMobileOrder);
    _webOrder = List.of(_defaultWebOrder);
    _loadSettings();
  }

  bool _isValidPermutation(List<String>? candidate, List<String> platformDefault) {
    if (candidate == null) return false;
    if (candidate.length != platformDefault.length) return false;
    if (candidate.toSet().length != candidate.length) return false;
    return candidate.toSet().containsAll(platformDefault);
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('home_section_order')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final rawMobile = data['mobileOrder'];
        final candidateMobile = rawMobile is List
            ? rawMobile.map((e) => e.toString()).toList()
            : null;
        final rawWeb = data['webOrder'];
        final candidateWeb =
            rawWeb is List ? rawWeb.map((e) => e.toString()).toList() : null;

        setState(() {
          if (_isValidPermutation(candidateMobile, _defaultMobileOrder)) {
            _mobileOrder = candidateMobile!;
          }
          if (_isValidPermutation(candidateWeb, _defaultWebOrder)) {
            _webOrder = candidateWeb!;
          }
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
          .doc('home_section_order')
          .set({
        'mobileOrder': _mobileOrder,
        'webOrder': _webOrder,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Home section order saved');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to save settings: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _reorder(List<String> order, int index, int direction) {
    final newIndex = index + direction;
    if (newIndex < 0 || newIndex >= order.length) return;
    HapticFeedback.lightImpact();
    setState(() {
      final item = order.removeAt(index);
      order.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Home Section Order'),
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
                    'Home Section Order',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Reorder the sections that appear on the Home screen, '
                    'independently for mobile and web. The banner (always '
                    'first) and footer (always last) are not shown here -- '
                    'they never move.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  _buildOrderList(
                    title: 'Mobile Home Order',
                    order: _mobileOrder,
                    onReorder: (index, direction) =>
                        _reorder(_mobileOrder, index, direction),
                  ),
                  const SizedBox(height: 24),
                  _buildOrderList(
                    title: 'Web Home Order',
                    order: _webOrder,
                    onReorder: (index, direction) =>
                        _reorder(_webOrder, index, direction),
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
                          : const Text('Save Section Order'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildOrderList({
    required String title,
    required List<String> order,
    required void Function(int index, int direction) onReorder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: order.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: Colors.grey.shade200),
            itemBuilder: (context, index) {
              final identifier = order[index];
              return ListTile(
                dense: true,
                leading: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                title: Text(_labels[identifier] ?? identifier),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                      tooltip: 'Move Up',
                      onPressed: index > 0 ? () => onReorder(index, -1) : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                      tooltip: 'Move Down',
                      onPressed: index < order.length - 1
                          ? () => onReorder(index, 1)
                          : null,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
