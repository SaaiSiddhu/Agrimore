import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/themes/app_colors.dart';
import '../../../app/themes/app_text_styles.dart';
import '../../../providers/admin_provider.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../providers/theme_provider.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({Key? key}) : super(key: key);

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).listenToCategories();
    });
  }

  void _showAddCategoryDialog({Map<String, dynamic>? categoryToEdit}) {
    final bool isEditing = categoryToEdit != null;
    final nameController = TextEditingController(text: categoryToEdit?['name'] ?? '');
    final descController = TextEditingController(text: categoryToEdit?['description'] ?? '');
    String selectedIcon = categoryToEdit?['icon'] ?? 'category';

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final cardColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final inputFillColor = isDark ? const Color(0xFF3b3b3b) : Colors.grey.shade50;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isEditing ? 'Edit Category' : 'Add Category', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextFormField(nameController, 'Category Name', Icons.label_outline, isDark, inputFillColor),
              const SizedBox(height: 16),
              _buildTextFormField(descController, 'Description', Icons.description_outlined, isDark, inputFillColor, maxLines: 3),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedIcon,
                decoration: InputDecoration(
                  labelText: 'Icon',
                  labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  prefixIcon: Icon(Icons.emoji_emotions_outlined, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)),
                  filled: true,
                  fillColor: inputFillColor,
                ),
                dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                items: const [
                  DropdownMenuItem(value: 'category', child: Text('Category')),
                  DropdownMenuItem(value: 'agriculture', child: Text('Agriculture')),
                  DropdownMenuItem(value: 'grass', child: Text('Grass')),
                  DropdownMenuItem(value: 'eco', child: Text('Eco')),
                ],
                onChanged: (value) {
                  selectedIcon = value!;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                SnackbarHelper.showError(context, 'Name is required');
                return;
              }

              try {
                final adminProvider = Provider.of<AdminProvider>(context, listen: false);
                if (isEditing) {
                  await adminProvider.updateCategory(
                    categoryToEdit!['id'],
                    nameController.text.trim(),
                    descController.text.trim(),
                    selectedIcon,
                  );
                } else {
                  await adminProvider.addCategory(
                    nameController.text.trim(),
                    descController.text.trim(),
                    selectedIcon,
                  );
                }
                if (mounted) {
                  Navigator.pop(context);
                  SnackbarHelper.showSuccess(context, isEditing ? 'Category updated' : 'Category added');
                }
              } catch (e) {
                if (mounted) {
                  SnackbarHelper.showError(context, 'Failed to save category');
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: isDark ? Colors.black : Colors.white),
            child: Text(isEditing ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTextFormField(TextEditingController controller, String label, IconData icon, bool isDark, Color fillColor, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        prefixIcon: Icon(icon, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)),
        filled: true,
        fillColor: fillColor,
      ),
      maxLines: maxLines,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Category Management'),
        backgroundColor: accentColor,
        foregroundColor: isDark ? Colors.black : Colors.white,
      ),
      body: Consumer<AdminProvider>(
        builder: (context, adminProvider, child) {
          final categories = adminProvider.categories;

          if (adminProvider.isLoadingCategories) {
            return Center(child: CircularProgressIndicator(color: accentColor));
          }

          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category_outlined, size: 100, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No categories yet', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return Card(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!)
                ),
                child: ListTile(
                  leading: Icon(Icons.category, color: accentColor),
                  title: Text(category['name'] ?? 'Unknown', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                  subtitle: Text(category['description'] ?? '', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: AppColors.info),
                        onPressed: () => _showAddCategoryDialog(categoryToEdit: category),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: AppColors.error),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Text('Delete Category'),
                              content: Text('Delete "${category['name']}"?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.error,
                                  ),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            try {
                              await adminProvider.deleteCategory(category['id']);
                              if (mounted) {
                                SnackbarHelper.showSuccess(
                                  context,
                                  'Category deleted',
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                SnackbarHelper.showError(
                                  context,
                                  'Failed to delete',
                                );
                              }
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCategoryDialog,
        backgroundColor: accentColor,
        foregroundColor: isDark ? Colors.black : Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}