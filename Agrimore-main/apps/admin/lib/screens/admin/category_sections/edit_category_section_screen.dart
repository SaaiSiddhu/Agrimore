// lib/screens/admin/category_sections/edit_category_section_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../providers/category_section_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../app/themes/admin_colors.dart';

class EditCategorySectionScreen extends StatefulWidget {
  final CategorySectionSlotModel? section;

  const EditCategorySectionScreen({Key? key, required this.section}) : super(key: key);

  @override
  State<EditCategorySectionScreen> createState() => _EditCategorySectionScreenState();
}

class _EditCategorySectionScreenState extends State<EditCategorySectionScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late List<String> _selectedCategoryIds;
  List<String?> _images = List.filled(8, null);
  Color _bgColor = const Color(0xFFFFF8E1);
  bool _isActive = true;
  bool _isSaving = false;
  final _imagePicker = ImagePicker();

  bool get isNewSection => widget.section == null || widget.section!.id.isEmpty;

  static const List<Color> _colorOptions = [
    Color(0xFFFFF8E1), Color(0xFFE8F5E9), Color(0xFFFCE4EC),
    Color(0xFFE3F2FD), Color(0xFFFFF3E0), Color(0xFFF3E5F5),
    Color(0xFFE0F2F1), Color(0xFFFBE9E7), Color(0xFFEDE7F6),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.section != null) {
      _nameController.text = widget.section!.sectionName;
      _selectedCategoryIds = List.from(widget.section!.categoryIds);
      _images = [
        widget.section!.image1, widget.section!.image2,
        widget.section!.image3, widget.section!.image4,
        widget.section!.image5, widget.section!.image6,
        widget.section!.image7, widget.section!.image8,
      ];
      _isActive = widget.section!.isActive;
      if (widget.section!.bgColorHex != null) {
        try {
          _bgColor = Color(int.parse(widget.section!.bgColorHex!.replaceFirst('#', '0xFF')));
        } catch (_) {}
      }
    } else {
      _selectedCategoryIds = [];
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().loadCategories();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>().categories
        .where((c) => c.isActive).toList();
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: isMobile 
                ? _buildMobileLayout(categories)
                : _buildDesktopLayout(categories),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.black87,
      iconTheme: const IconThemeData(color: Colors.black87),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isNewSection ? 'Create Section' : 'Edit Section',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          if (!isNewSection)
            Text(
              widget.section!.sectionName,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontWeight: FontWeight.w400,
              ),
            ),
        ],
      ),
      actions: [
        if (!isNewSection)
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: Colors.red[400]),
            onPressed: _deleteSection,
            tooltip: 'Delete Section',
          ),
      ],
    );
  }

  Widget _buildMobileLayout(List<CategoryModel> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionNameCard(),
        const SizedBox(height: 16),
        _buildCategoriesCard(categories),
        const SizedBox(height: 16),
        _buildImageGridCard(),
        const SizedBox(height: 16),
        _buildSettingsCard(),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildDesktopLayout(List<CategoryModel> categories) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildSectionNameCard(),
              const SizedBox(height: 16),
              _buildImageGridCard(),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Right Column
        Expanded(
          flex: 2,
          child: Column(
            children: [
              _buildCategoriesCard(categories),
              const SizedBox(height: 16),
              _buildSettingsCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionNameCard() {
    return _PremiumCard(
      title: 'Section Details',
      icon: Icons.edit_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Section Name',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'e.g., Grocery & Kitchen',
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AdminColors.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            validator: (v) => v?.trim().isEmpty == true ? 'Name is required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesCard(List<CategoryModel> categories) {
    return _PremiumCard(
      title: 'Categories (${_selectedCategoryIds.length}/8)',
      icon: Icons.category_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select categories to display in this section',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: categories.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = _selectedCategoryIds.contains(category.id);
                final canSelect = isSelected || _selectedCategoryIds.length < 8;
                
                return Material(
                  color: isSelected ? AdminColors.primary.withOpacity(0.05) : Colors.transparent,
                  child: InkWell(
                    onTap: canSelect ? () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (isSelected) {
                          _selectedCategoryIds.remove(category.id);
                        } else if (_selectedCategoryIds.length < 8) {
                          _selectedCategoryIds.add(category.id);
                        }
                      });
                    } : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: isSelected ? AdminColors.primary : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected ? AdminColors.primary : Colors.grey[300]!,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: 14, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              category.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: canSelect ? null : Colors.grey[400],
                              ),
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AdminColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '#${_selectedCategoryIds.indexOf(category.id) + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AdminColors.primary,
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
        ],
      ),
    );
  }

  Widget _buildImageGridCard() {
    return _PremiumCard(
      title: 'Category Images',
      icon: Icons.photo_library_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload high-quality images for each category slot',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: List.generate(8, (i) {
              final slotNum = i + 1;
              final hasCategory = i < _selectedCategoryIds.length;
              
              return _ImageSlot(
                position: slotNum,
                imageUrl: _images[i],
                isActive: hasCategory,
                bgColor: _bgColor,
                onPick: () => _pickImage(i),
                onRemove: () => setState(() => _images[i] = null),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    return _PremiumCard(
      title: 'Settings',
      icon: Icons.tune_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Background Color
          const Text(
            'Background Color',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _colorOptions.map((color) {
              final isSelected = _bgColor.value == color.value;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _bgColor = color);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AdminColors.primary : Colors.grey[300]!,
                      width: isSelected ? 3 : 1,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: AdminColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ] : null,
                  ),
                  child: isSelected
                      ? Icon(Icons.check, size: 20, color: AdminColors.primary)
                      : null,
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 24),
          
          // Active Toggle
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  _isActive ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  color: _isActive ? Colors.green : Colors.grey[400],
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Text(
                        'Show on home screen',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isActive,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    setState(() => _isActive = v);
                  },
                  activeColor: AdminColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 4,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        isNewSection ? 'Create Section' : 'Save Changes',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(int index) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 90,
      );

      if (picked == null) return;

      setState(() => _isSaving = true);

      final bytes = await picked.readAsBytes();
      final provider = context.read<CategorySectionProvider>();
      
      final sectionId = widget.section?.id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
      
      final url = await provider.uploadCategoryImage(
        sectionId: sectionId,
        slotPosition: index + 1,
        imageBytes: bytes,
        fileName: picked.name,
      );

      if (url != null) {
        setState(() => _images[index] = url);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(provider.error ?? 'Failed to upload')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveSection() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedCategoryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one category')),
      );
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    final colorHex = '#${_bgColor.value.toRadixString(16).substring(2).toUpperCase()}';
    final provider = context.read<CategorySectionProvider>();
    
    bool success;
    
    if (isNewSection) {
      final newSection = CategorySectionSlotModel(
        id: '',
        position: 0,
        sectionName: _nameController.text.trim(),
        categoryIds: _selectedCategoryIds,
        image1: _images[0], image2: _images[1],
        image3: _images[2], image4: _images[3],
        image5: _images[4], image6: _images[5],
        image7: _images[6], image8: _images[7],
        bgColorHex: colorHex,
        isActive: _isActive,
      );
      success = await provider.addSection(newSection);
    } else {
      final updatedSection = widget.section!.copyWith(
        sectionName: _nameController.text.trim(),
        categoryIds: _selectedCategoryIds,
        image1: _images[0], image2: _images[1],
        image3: _images[2], image4: _images[3],
        image5: _images[4], image6: _images[5],
        image7: _images[6], image8: _images[7],
        bgColorHex: colorHex,
        isActive: _isActive,
      );
      success = await provider.updateSection(updatedSection);
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isNewSection ? 'Section created!' : 'Section updated!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error ?? 'Failed to save')),
        );
      }
    }
  }

  Future<void> _deleteSection() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Section?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<CategorySectionProvider>().deleteSection(widget.section!.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Section deleted')),
        );
      }
    }
  }
}

// ============================================
// PREMIUM CARD
// ============================================
class _PremiumCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _PremiumCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AdminColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: AdminColors.primary),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[100]),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ============================================
// IMAGE SLOT
// ============================================
class _ImageSlot extends StatelessWidget {
  final int position;
  final String? imageUrl;
  final bool isActive;
  final Color bgColor;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _ImageSlot({
    required this.position,
    required this.imageUrl,
    required this.isActive,
    required this.bgColor,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isActive 
            ? (hasImage ? bgColor.withOpacity(0.3) : Colors.grey[100])
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasImage 
              ? AdminColors.primary.withOpacity(0.3)
              : (isActive ? Colors.grey[300]! : Colors.grey[200]!),
          width: hasImage ? 2 : 1,
        ),
      ),
      child: hasImage
          ? Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    imageUrl!,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Icon(Icons.broken_image, color: Colors.grey[400]),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$position',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isActive ? onPick : null,
                borderRadius: BorderRadius.circular(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isActive ? Icons.add_photo_alternate_rounded : Icons.block_rounded,
                      color: isActive ? Colors.grey[400] : Colors.grey[300],
                      size: 28,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isActive ? 'Slot $position' : '-',
                      style: TextStyle(
                        color: Colors.grey[isActive ? 500 : 300],
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
