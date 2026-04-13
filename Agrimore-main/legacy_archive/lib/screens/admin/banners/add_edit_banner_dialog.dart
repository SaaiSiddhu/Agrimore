// lib/screens/admin/banners/add_edit_banner_dialog.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../models/banner_model.dart';
import '../../../providers/banner_provider.dart';

class AddEditBannerDialog extends StatefulWidget {
  final BannerModel? banner;

  const AddEditBannerDialog({Key? key, this.banner}) : super(key: key);

  @override
  State<AddEditBannerDialog> createState() => _AddEditBannerDialogState();
}

class _AddEditBannerDialogState extends State<AddEditBannerDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _subtitleController;
  late TextEditingController _imageUrlController;
  late TextEditingController _targetRouteController;
  late TextEditingController _priorityController;

  bool _useUrl = true;
  File? _selectedImageFile;
  Uint8List? _selectedImageBytes;
  bool _isUploading = false;

  String? _selectedIcon;
  String _selectedColor = '#4CAF50';

  final List<String?> _iconOptions = [
    null, // No Icon
    'eco',
    'local_shipping',
    'local_offer',
    'spa',
    'flash_on',
    'new_releases',
    'star',
    'shopping_bag',
  ];

  final List<String> _colorOptions = [
    '#4CAF50',
    '#2196F3',
    '#FF9800',
    '#9C27B0',
    '#F44336',
    '#00BCD4',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.banner?.title ?? '');
    _subtitleController = TextEditingController(text: widget.banner?.subtitle ?? '');
    _imageUrlController = TextEditingController(text: widget.banner?.imageUrl ?? '');
    _targetRouteController = TextEditingController(text: widget.banner?.targetRoute ?? '');
    _priorityController = TextEditingController(text: widget.banner?.priority.toString() ?? '0');
    _selectedIcon = widget.banner?.iconName.isNotEmpty == true ? widget.banner!.iconName : null;
    _selectedColor = widget.banner?.colorHex ?? '#4CAF50';
    // If an existing banner has an imageUrl, default to URL mode
    if (widget.banner != null && (widget.banner!.imageUrl.isNotEmpty)) {
      _useUrl = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _imageUrlController.dispose();
    _targetRouteController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image != null) {
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageFile = null;
        });
      } else {
        setState(() {
          _selectedImageFile = File(image.path);
          _selectedImageBytes = null;
        });
      }
    }
  }

  Future<String> uploadImage(dynamic image, {required bool isWeb}) async {
    final fileName = 'banner_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref().child('banners/$fileName');
    final UploadTask uploadTask;
    if (isWeb) {
      uploadTask = ref.putData(image as Uint8List);
    } else {
      uploadTask = ref.putFile(image as File);
    }
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _saveBanner() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isUploading = true);

    try {
      final provider = Provider.of<BannerProvider>(context, listen: false);
      String? imageUrl;

      if (_useUrl) {
        final url = _imageUrlController.text.trim();
        if (url.isEmpty) {
          throw Exception('Please enter image URL');
        }
        imageUrl = url;
      } else {
        if (kIsWeb && _selectedImageBytes != null) {
          imageUrl = await uploadImage(_selectedImageBytes!, isWeb: true);
        } else if (!kIsWeb && _selectedImageFile != null) {
          imageUrl = await uploadImage(_selectedImageFile!, isWeb: false);
        } else {
          throw Exception('Please select an image to upload');
        }
      }

      final title = _titleController.text.trim();
      final subtitle = _subtitleController.text.trim();
      final targetRoute = _targetRouteController.text.trim().isEmpty ? null : _targetRouteController.text.trim();
      final priority = int.tryParse(_priorityController.text.trim()) ?? 0;
      final iconName = _selectedIcon ?? '';

      if (widget.banner == null) {
        await provider.createBannerWithUrl(
          imageUrl: imageUrl!,
          title: title,
          subtitle: subtitle,
          iconName: iconName,
          targetRoute: targetRoute,
          colorHex: _selectedColor,
          priority: priority,
        );
      } else {
        await provider.updateBanner(widget.banner!.id, {
          'imageUrl': imageUrl,
          'title': title,
          'subtitle': subtitle,
          'iconName': iconName,
          'targetRoute': targetRoute,
          'colorHex': _selectedColor,
          'priority': priority,
        });
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(widget.banner == null ? '✅ Banner created successfully!' : '✅ Banner updated successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: Colors.white.withAlpha((0.98 * 255).round()),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _headerSection(context),
                    const SizedBox(height: 20),
                    _imageModeToggle(),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _useUrl ? _urlInput() : _imageUploader(),
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(_titleController, 'Banner Title', Icons.title),
                    const SizedBox(height: 16),
                    _buildTextField(_subtitleController, 'Subtitle', Icons.subtitles),
                    const SizedBox(height: 16),
                    _buildTextField(_targetRouteController, 'Target Route (optional)', Icons.link),
                    const SizedBox(height: 16),
                    _buildTextField(_priorityController, 'Priority', Icons.sort, inputType: TextInputType.number),
                    const Divider(height: 32),
                    Text('Choose Icon (Optional)', style: _labelStyle()),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _iconOptions.map((icon) {
                        final isSelected = _selectedIcon == icon;
                        return ChoiceChip(
                          label: icon == null
                              ? const Text('No Icon')
                              : Icon(_getIconData(icon), color: isSelected ? Colors.white : Colors.black87),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _selectedIcon = icon),
                          selectedColor: colorScheme.primary,
                          backgroundColor: Colors.grey.shade100,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Text('Banner Theme Color', style: _labelStyle()),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      children: _colorOptions.map((hex) {
                        final color = _hexToColor(hex);
                        final selected = _selectedColor == hex;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedColor = hex),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected ? Colors.black : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: selected ? [const BoxShadow(color: Colors.black26, blurRadius: 4)] : [],
                            ),
                            child: selected ? const Icon(Icons.check, color: Colors.white) : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        icon: _isUploading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                          _isUploading ? 'Saving...' : widget.banner == null ? 'Create Banner' : 'Update Banner',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          elevation: 4,
                        ),
                        onPressed: _isUploading ? null : _saveBanner,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, size: 24),
              color: Colors.black54,
              tooltip: 'Close',
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerSection(BuildContext context) {
    return Row(
      children: [
        Icon(
          widget.banner == null ? Icons.add_photo_alternate_rounded : Icons.edit_rounded,
          color: Theme.of(context).colorScheme.primary,
          size: 28,
        ),
        const SizedBox(width: 10),
        Text(
          widget.banner == null ? 'Add New Banner' : 'Edit Banner',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _imageModeToggle() {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: true, label: Text('Image URL')),
        ButtonSegment(value: false, label: Text('Upload Image')),
      ],
      selected: {_useUrl},
      onSelectionChanged: (v) => setState(() => _useUrl = v.first),
    );
  }

  Widget _urlInput() {
    return TextFormField(
      controller: _imageUrlController,
      decoration: _inputDecoration('Banner Image URL', Icons.link),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Please enter image URL';
        // basic validation
        final text = v.trim();
        if (!text.startsWith('http')) return 'Enter a valid URL (starting with http/https)';
        return null;
      },
    );
  }

  Widget _imageUploader() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(16),
        ),
        child: _selectedImageFile != null || _selectedImageBytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: kIsWeb
                    ? Image.memory(_selectedImageBytes!, fit: BoxFit.cover)
                    : Image.file(_selectedImageFile!, fit: BoxFit.cover),
              )
            : const Center(
                child: Text('Click to upload image', style: TextStyle(color: Colors.grey)),
              ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon,
      {TextInputType inputType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      validator: (v) => v == null || v.trim().isEmpty ? 'Please enter $label' : null,
      decoration: _inputDecoration(label, icon),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }

  TextStyle _labelStyle() =>
      const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: Colors.black87);

  IconData _getIconData(String? icon) {
    switch (icon) {
      case 'eco':
        return Icons.eco;
      case 'local_shipping':
        return Icons.local_shipping;
      case 'local_offer':
        return Icons.local_offer;
      case 'spa':
        return Icons.spa;
      case 'flash_on':
        return Icons.flash_on;
      case 'new_releases':
        return Icons.new_releases;
      case 'star':
        return Icons.star;
      case 'shopping_bag':
        return Icons.shopping_bag;
      default:
        return Icons.help_outline;
    }
  }

  Color _hexToColor(String hex) {
    var cleaned = hex.replaceAll('#', '');
    if (cleaned.length == 3) {
      cleaned = cleaned.split('').map((c) => '$c$c').join();
    }
    if (cleaned.length == 6) cleaned = 'FF$cleaned';
    try {
      return Color(int.parse(cleaned, radix: 16));
    } catch (_) {
      return const Color(0xFF4CAF50);
    }
  }
}