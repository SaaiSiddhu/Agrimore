import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/home_product_section_provider.dart';
import 'add_edit_home_product_section_dialog.dart';

/// HOME-3: which categories become a Home product-carousel section, their
/// order, title override and item cap. Reorder/delete/active-toggle mirror
/// CategorySectionManagementScreen's own up/down pattern exactly. An empty
/// list here is a valid, expected state — apps/marketplace falls back to
/// its pre-existing loop-all-active-categories behaviour, never a blank Home.
class HomeProductSectionManagementScreen extends StatefulWidget {
  const HomeProductSectionManagementScreen({super.key});

  @override
  State<HomeProductSectionManagementScreen> createState() =>
      _HomeProductSectionManagementScreenState();
}

class _HomeProductSectionManagementScreenState
    extends State<HomeProductSectionManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<HomeProductSectionProvider>(context, listen: false).loadSections();
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);
      if (adminProvider.categories.isEmpty) adminProvider.loadCategories();
    });
  }

  void _openDialog({HomeProductSectionConfigModel? existing}) {
    // HomeProductSectionProvider is registered at the app root (main.dart),
    // so it's already reachable here without re-providing it — mirrors how
    // add_edit_banner_dialog.dart reaches AdminProvider the same way.
    showDialog(
      context: context,
      builder: (_) => AddEditHomeProductSectionDialog(existing: existing),
    );
  }

  Future<void> _confirmDelete(HomeProductSectionConfigModel section) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this section'),
        content: const Text('This removes it from Home. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await Provider.of<HomeProductSectionProvider>(context, listen: false)
        .deleteSection(section.id);
    if (!mounted) return;
    if (ok) {
      SnackbarHelper.showSuccess(context, 'Section deleted');
    } else {
      SnackbarHelper.showError(context, 'Failed to delete section');
    }
  }

  String _categoryName(AdminProvider adminProvider, String categoryId) {
    final match = adminProvider.categories.where((c) => c.id == categoryId);
    return match.isNotEmpty ? match.first.name : '(unknown category)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Home Product Sections'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Section'),
        backgroundColor: AppColors.primary,
      ),
      body: Consumer2<HomeProductSectionProvider, AdminProvider>(
        builder: (context, provider, adminProvider, _) {
          if (provider.isLoading && provider.sections.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.sections.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.view_carousel_outlined, size: 56, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      'No configured sections yet',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Home currently shows every active category with products, in a '
                      'default order. Add a section to take control of which categories '
                      'appear, their order, and their title.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: provider.sections.length,
            itemBuilder: (context, index) {
              final section = provider.sections[index];
              final title = section.titleOverride ??
                  _categoryName(adminProvider, section.categoryId);
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        section.isActive ? AppColors.primary : Colors.grey[400],
                    child: Text('${section.position}',
                        style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Max ${section.maxItems} items · ${section.isActive ? 'Active' : 'Inactive'}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_up_rounded),
                        onPressed: index == 0
                            ? null
                            : () => provider.reorderSections(index, index - 1),
                      ),
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        onPressed: index == provider.sections.length - 1
                            ? null
                            : () => provider.reorderSections(index, index + 1),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _openDialog(existing: section),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _confirmDelete(section),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
