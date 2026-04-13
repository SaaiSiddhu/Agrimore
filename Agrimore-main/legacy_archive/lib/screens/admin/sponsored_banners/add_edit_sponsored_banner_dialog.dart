import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../models/sponsored_banner_model.dart';
import '../../../providers/sponsored_banner_provider.dart';
import '../../../providers/product_provider.dart';

class AddEditSponsoredBannerDialog extends StatefulWidget {
  final SponsoredBannerModel? banner;

  const AddEditSponsoredBannerDialog({Key? key, this.banner}) : super(key: key);

  @override
  State<AddEditSponsoredBannerDialog> createState() =>
      _AddEditSponsoredBannerDialogState();
}

class _AddEditSponsoredBannerDialogState
    extends State<AddEditSponsoredBannerDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _subtitleController;
  late TextEditingController _imageUrlController;
  late TextEditingController _productIdController;
  late TextEditingController _priorityController;

  bool _useUrl = true;
  File? _selectedImageFile;
  Uint8List? _selectedImageBytes;
  bool _isUploading = false;

  String _selectedColor = '#4CAF50';

  final List<String> _colorOptions = [
    '#4CAF50',
    '#2196F3',
    '#FF9800',
    '#9C27B0',
    '#F44336',
    '#00BCD4',
    '#FF5722',
    '#795548',
  ];

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.banner?.title ?? '');
    _subtitleController =
        TextEditingController(text: widget.banner?.subtitle ?? '');
    _imageUrlController =
        TextEditingController(text: widget.banner?.imageUrl ?? '');
    _productIdController =
        TextEditingController(text: widget.banner?.productId ?? '');
    _priorityController = TextEditingController(
        text: widget.banner?.priority.toString() ?? '0');
    _selectedColor = widget.banner?.colorHex ?? '#4CAF50';

    if (widget.banner != null && (widget.banner!.imageUrl.isNotEmpty)) {
      _useUrl = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _imageUrlController.dispose();
    _productIdController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
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
    final fileName =
        'sponsored_banner_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref =
        FirebaseStorage.instance.ref().child('sponsored_banners/$fileName');
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
      final provider =
          Provider.of<SponsoredBannerProvider>(context, listen: false);
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
      final productId = _productIdController.text.trim();
      final priority = int.tryParse(_priorityController.text.trim()) ?? 0;

      if (widget.banner == null) {
        await provider.createSponsoredBanner(
          productId: productId,
          imageUrl: imageUrl!,
          title: title,
          subtitle: subtitle,
          colorHex: _selectedColor,
          priority: priority,
        );
      } else {
        await provider.updateSponsoredBanner(widget.banner!.id, {
          'productId': productId,
          'imageUrl': imageUrl,
          'title': title,
          'subtitle': subtitle,
          'colorHex': _selectedColor,
          'priority': priority,
        });
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(widget.banner == null
                ? '✅ Sponsored banner created successfully!'
                : '✅ Sponsored banner updated successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: Colors.redAccent, content: Text('Error: $e')),
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
      backgroundColor: Colors.white.withValues(alpha: 0.98),
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
                    _buildTextField(
                        _productIdController, 'Product ID', Icons.inventory_2),
                    const SizedBox(height: 16),
                    _buildProductSelector(),
                    const SizedBox(height: 16),
                    _buildTextField(
                        _titleController, 'Banner Title', Icons.title),
                    const SizedBox(height: 16),
                    _buildTextField(
                        _subtitleController, 'Subtitle', Icons.subtitles),
                    const SizedBox(height: 16),
                    _buildTextField(_priorityController, 'Priority', Icons.sort,
                        inputType: TextInputType.number),
                    const Divider(height: 32),
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
                                color: selected
                                    ? Colors.black
                                    : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: selected
                                  ? [
                                      const BoxShadow(
                                          color: Colors.black26, blurRadius: 4)
                                    ]
                                  : [],
                            ),
                            child: selected
                                ? const Icon(Icons.check, color: Colors.white)
                                : null,
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
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                          _isUploading
                              ? 'Saving...'
                              : widget.banner == null
                                  ? 'Create Banner'
                                  : 'Update Banner',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
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
          widget.banner == null
              ? Icons.campaign_rounded
              : Icons.edit_rounded,
          color: Theme.of(context).colorScheme.primary,
          size: 28,
        ),
        const SizedBox(width: 10),
        Text(
          widget.banner == null
              ? 'Add Sponsored Banner'
              : 'Edit Sponsored Banner',
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
        final text = v.trim();
        if (!text.startsWith('http')) {
          return 'Enter a valid URL (starting with http/https)';
        }
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
                child: Text('Click to upload image',
                    style: TextStyle(color: Colors.grey)),
              ),
      ),
    );
  }

  Widget _buildProductSelector() {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        final products = productProvider.products ?? [];

        return DropdownButtonFormField<String>(
          value: _productIdController.text.isEmpty
              ? null
              : _productIdController.text,
          decoration: _inputDecoration('Select Product', Icons.shopping_bag),
          hint: const Text('Choose a product'),
          items: products.map((product) {
            return DropdownMenuItem(
              value: product.id,
              child: Text(
                product.name,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _productIdController.text = value;
              });
            }
          },
        );
      },
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {TextInputType inputType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      validator: (v) =>
          v == null || v.trim().isEmpty ? 'Please enter $label' : null,
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

  TextStyle _labelStyle() => const TextStyle(
      fontWeight: FontWeight.w600, fontSize: 14.5, color: Colors.black87);

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
