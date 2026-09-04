// lib/screens/admin/bestsellers/edit_bestseller_slot_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../providers/bestseller_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../app/themes/admin_colors.dart';

class EditBestsellerSlotDialog extends StatefulWidget {
  final BestsellerSlotModel slot;

  const EditBestsellerSlotDialog({Key? key, required this.slot}) : super(key: key);

  @override
  State<EditBestsellerSlotDialog> createState() => _EditBestsellerSlotDialogState();
}

class _EditBestsellerSlotDialogState extends State<EditBestsellerSlotDialog> {
  late String _selectedCategoryId;
  late String _selectedCategoryName;
  String? _image1, _image2, _image3, _image4;
  Color _bgColor = const Color(0xFFFFF8E1);
  bool _isActive = true;
  bool _isSaving = false;
  final _imagePicker = ImagePicker();

  // Predefined colors
  static const List<Color> _colorOptions = [
    Color(0xFFFFF8E1), // Warm amber
    Color(0xFFE8F5E9), // Fresh green
    Color(0xFFFCE4EC), // Soft pink
    Color(0xFFE3F2FD), // Sky blue
    Color(0xFFFFF3E0), // Soft orange
    Color(0xFFF3E5F5), // Light purple
    Color(0xFFE0F2F1), // Teal
    Color(0xFFFBE9E7), // Deep orange light
    Color(0xFFEDE7F6), // Deep purple light
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.slot.categoryId;
    _selectedCategoryName = widget.slot.categoryName;
    _image1 = widget.slot.image1;
    _image2 = widget.slot.image2;
    _image3 = widget.slot.image3;
    _image4 = widget.slot.image4;
    _isActive = widget.slot.isActive;
    if (widget.slot.bgColorHex != null) {
      try {
        _bgColor = Color(int.parse(widget.slot.bgColorHex!.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    
    // Load categories when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().loadCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>().categories;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 650),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AdminColors.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    'Edit Slot ${widget.slot.position}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Dropdown
                    const Text(
                      'Select Category',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedCategoryId.isEmpty ? null : _selectedCategoryId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      ),
                      hint: const Text('Choose a category'),
                      items: categories.map((cat) {
                        return DropdownMenuItem(
                          value: cat.id,
                          child: Text(cat.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          final cat = categories.firstWhere((c) => c.id == value);
                          setState(() {
                            _selectedCategoryId = cat.id;
                            _selectedCategoryName = cat.name;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 24),

                    // Image Uploads - 2x2 Grid
                    const Text(
                      'Upload 4 Images',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      children: [
                        _buildImageSlot(1, _image1, (url) => setState(() => _image1 = url)),
                        _buildImageSlot(2, _image2, (url) => setState(() => _image2 = url)),
                        _buildImageSlot(3, _image3, (url) => setState(() => _image3 = url)),
                        _buildImageSlot(4, _image4, (url) => setState(() => _image4 = url)),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Background Color
                    const Text(
                      'Background Color',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _colorOptions.map((color) {
                        final isSelected = _bgColor.value == color.value;
                        return GestureDetector(
                          onTap: () => setState(() => _bgColor = color),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected 
                                    ? AdminColors.primary 
                                    : Colors.grey[300]!,
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                            child: isSelected
                                ? Icon(Icons.check, size: 18, 
                                    color: AdminColors.primary)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // Active Toggle
                    SwitchListTile(
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                      title: const Text('Active'),
                      subtitle: const Text('Show this slot on home screen'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  if (widget.slot.id.isNotEmpty)
                    TextButton.icon(
                      onPressed: _isSaving ? null : _deleteSlot,
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Reset', 
                        style: TextStyle(color: Colors.red)),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveSlot,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSlot(int position, String? imageUrl, Function(String?) onUpdate) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: imageUrl != null && imageUrl.isNotEmpty
          ? Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => onUpdate(null),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
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
                      'Image $position',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
              ],
            )
          : InkWell(
              onTap: () => _pickImage(position, onUpdate),
              borderRadius: BorderRadius.circular(7),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate, 
                    color: Colors.grey[400], size: 28),
                  const SizedBox(height: 4),
                  Text(
                    'Image $position',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _pickImage(int position, Function(String?) onUpdate) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 85,
      );

      if (picked == null) return;

      setState(() => _isSaving = true);

      final bytes = await picked.readAsBytes();
      final provider = context.read<BestsellerProvider>();
      
      final url = await provider.uploadImage(
        slotPosition: widget.slot.position,
        imagePosition: position,
        imageBytes: bytes,
        fileName: picked.name,
      );

      if (url != null) {
        onUpdate(url);
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

  Future<void> _saveSlot() async {
    if (_selectedCategoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final colorHex = '#${_bgColor.value.toRadixString(16).substring(2).toUpperCase()}';
    
    final updatedSlot = widget.slot.copyWith(
      categoryId: _selectedCategoryId,
      categoryName: _selectedCategoryName,
      image1: _image1,
      image2: _image2,
      image3: _image3,
      image4: _image4,
      bgColorHex: colorHex,
      isActive: _isActive,
    );

    final success = await context.read<BestsellerProvider>().saveSlot(updatedSlot);

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Slot saved successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            context.read<BestsellerProvider>().error ?? 'Failed to save')),
        );
      }
    }
  }

  Future<void> _deleteSlot() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Slot?'),
        content: const Text('This will clear all images and category selection.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isSaving = true);
      await context.read<BestsellerProvider>().deleteSlot(widget.slot.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Slot reset successfully')),
        );
      }
    }
  }
}
