// lib/screens/admin/section_banners/add_edit_section_banner_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../providers/section_banner_provider.dart';

class AddEditSectionBannerDialog extends StatefulWidget {
  final SectionBannerModel? banner;
  
  const AddEditSectionBannerDialog({Key? key, this.banner}) : super(key: key);
  
  @override
  State<AddEditSectionBannerDialog> createState() => _AddEditSectionBannerDialogState();
}

class _AddEditSectionBannerDialogState extends State<AddEditSectionBannerDialog> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _titleController;
  late TextEditingController _subtitleController;
  late TextEditingController _shopUrlController;
  late TextEditingController _buttonTextController;
  late TextEditingController _positionController;
  
  int _displayAfterSection = 1;
  bool _isActive = true;
  bool _showAdBadge = false;
  
  String? _existingImageUrl;
  Uint8List? _newImageBytes;
  String? _newImageName;
  bool _isLoading = false;
  
  bool get isEditing => widget.banner != null;
  
  @override
  void initState() {
    super.initState();
    final banner = widget.banner;
    
    _titleController = TextEditingController(text: banner?.title ?? '');
    _subtitleController = TextEditingController(text: banner?.subtitle ?? '');
    _shopUrlController = TextEditingController(text: banner?.shopNowUrl ?? '');
    _buttonTextController = TextEditingController(text: banner?.buttonText ?? 'Shop now');
    _positionController = TextEditingController(text: (banner?.position ?? 0).toString());
    
    _displayAfterSection = banner?.displayAfterSection ?? 1;
    _isActive = banner?.isActive ?? true;
    _showAdBadge = banner?.showAdBadge ?? false;
    _existingImageUrl = banner?.imageUrl;
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _shopUrlController.dispose();
    _buttonTextController.dispose();
    _positionController.dispose();
    super.dispose();
  }
  
  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
      
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _newImageBytes = bytes;
          _newImageName = file.name;
        });
      }
    } catch (e) {
      SnackbarHelper.showError(context, 'Failed to pick image');
    }
  }
  
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_existingImageUrl == null && _newImageBytes == null) {
      SnackbarHelper.showError(context, 'Please select an image');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final provider = Provider.of<SectionBannerProvider>(context, listen: false);
      
      String imageUrl = _existingImageUrl ?? '';
      
      // Upload new image if selected
      if (_newImageBytes != null && _newImageName != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$_newImageName';
        imageUrl = await provider.uploadImage(_newImageBytes!, fileName);
      }
      
      if (isEditing) {
        await provider.updateBanner(
          id: widget.banner!.id,
          imageUrl: imageUrl,
          title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
          subtitle: _subtitleController.text.trim().isEmpty ? null : _subtitleController.text.trim(),
          shopNowUrl: _shopUrlController.text.trim().isEmpty ? null : _shopUrlController.text.trim(),
          buttonText: _buttonTextController.text.trim().isEmpty ? null : _buttonTextController.text.trim(),
          position: int.tryParse(_positionController.text) ?? 0,
          displayAfterSection: _displayAfterSection,
          isActive: _isActive,
          showAdBadge: _showAdBadge,
        );
        if (mounted) SnackbarHelper.showSuccess(context, 'Banner updated');
      } else {
        await provider.createBanner(
          imageUrl: imageUrl,
          title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
          subtitle: _subtitleController.text.trim().isEmpty ? null : _subtitleController.text.trim(),
          shopNowUrl: _shopUrlController.text.trim().isEmpty ? null : _shopUrlController.text.trim(),
          buttonText: _buttonTextController.text.trim().isEmpty ? null : _buttonTextController.text.trim(),
          position: int.tryParse(_positionController.text) ?? 0,
          displayAfterSection: _displayAfterSection,
          isActive: _isActive,
          showAdBadge: _showAdBadge,
        );
        if (mounted) SnackbarHelper.showSuccess(context, 'Banner created');
      }
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to save banner: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.image, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    isEditing ? 'Edit Section Banner' : 'Add Section Banner',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
            
            // Form Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image Upload
                      const Text('Banner Image *', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: _newImageBytes != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.memory(_newImageBytes!, fit: BoxFit.cover),
                                )
                              : _existingImageUrl != null && _existingImageUrl!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: CachedNetworkImage(
                                        imageUrl: _existingImageUrl!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.cloud_upload, size: 40, color: Colors.grey[400]),
                                        const SizedBox(height: 8),
                                        Text('Tap to upload image', style: TextStyle(color: Colors.grey[600])),
                                      ],
                                    ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Optional Fields Note
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, size: 18, color: Colors.blue),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'All fields below are optional. You can upload just an image.',
                                style: TextStyle(fontSize: 12, color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Title (optional)
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title (overlay text)',
                          hintText: 'e.g., Enjoy up to 20% OFF',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Subtitle (optional)
                      TextFormField(
                        controller: _subtitleController,
                        decoration: const InputDecoration(
                          labelText: 'Subtitle (overlay text)',
                          hintText: 'e.g., Wellness supplements...',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Shop Now URL (optional)
                      TextFormField(
                        controller: _shopUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Shop Now URL',
                          hintText: 'e.g., /shop or https://...',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.link),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Button Text (optional)
                      TextFormField(
                        controller: _buttonTextController,
                        decoration: const InputDecoration(
                          labelText: 'Button Text',
                          hintText: 'Default: Shop now',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Position & Section
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _positionController,
                              decoration: const InputDecoration(
                                labelText: 'Position',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _displayAfterSection,
                              decoration: const InputDecoration(
                                labelText: 'Show After Section',
                                border: OutlineInputBorder(),
                              ),
                              items: List.generate(10, (i) => i + 1)
                                  .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                                  .toList(),
                              onChanged: (v) => setState(() => _displayAfterSection = v ?? 1),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Toggles
                      SwitchListTile(
                        title: const Text('Active'),
                        subtitle: const Text('Show this banner on marketplace'),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                        activeColor: AppColors.primary,
                      ),
                      SwitchListTile(
                        title: const Text('Show Ad Badge'),
                        subtitle: const Text('Display "Ad" label on banner'),
                        value: _showAdBadge,
                        onChanged: (v) => setState(() => _showAdBadge = v),
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(isEditing ? 'Update' : 'Create'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
