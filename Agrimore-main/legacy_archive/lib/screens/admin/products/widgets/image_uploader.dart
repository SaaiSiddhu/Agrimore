import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../app/themes/app_text_styles.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../providers/theme_provider.dart';

class ImageUploader extends StatefulWidget {
  final List<String> imageUrls;
  final Function(List<String>) onImagesChanged;

  const ImageUploader({
    Key? key,
    required this.imageUrls,
    required this.onImagesChanged,
  }) : super(key: key);

  @override
  State<ImageUploader> createState() => _ImageUploaderState();
}

class _ImageUploaderState extends State<ImageUploader> {
  final _urlController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  // Add image from URL
  void _addImageUrl() {
    if (_urlController.text.trim().isNotEmpty) {
      final newUrls = [...widget.imageUrls, _urlController.text.trim()];
      widget.onImagesChanged(newUrls);
      _urlController.clear();
      SnackbarHelper.showSuccess(context, 'Image URL added');
    }
  }

  // Pick and upload image from device
  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      final String fileName = '${const Uuid().v4()}.jpg';
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('products')
          .child(fileName);

      UploadTask uploadTask;
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        uploadTask = storageRef.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        uploadTask = storageRef.putFile(File(image.path));
      }

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      final newUrls = [...widget.imageUrls, downloadUrl];
      widget.onImagesChanged(newUrls);

      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Image uploaded successfully! ✅');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Upload failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  // Pick and upload multiple images
  Future<void> _pickAndUploadMultipleImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (images.isEmpty) return;

      setState(() => _isUploading = true);

      List<String> uploadedUrls = [];

      for (var image in images) {
        try {
          final String fileName = '${const Uuid().v4()}.jpg';
          final Reference storageRef = FirebaseStorage.instance
              .ref()
              .child('products')
              .child(fileName);

          UploadTask uploadTask;
          if (kIsWeb) {
            final bytes = await image.readAsBytes();
            uploadTask = storageRef.putData(
              bytes,
              SettableMetadata(contentType: 'image/jpeg'),
            );
          } else {
            uploadTask = storageRef.putFile(File(image.path));
          }

          final TaskSnapshot snapshot = await uploadTask;
          final String downloadUrl = await snapshot.ref.getDownloadURL();
          uploadedUrls.add(downloadUrl);
        } catch (e) {
          debugPrint('Error uploading image: $e');
        }
      }

      if (uploadedUrls.isNotEmpty) {
        final newUrls = [...widget.imageUrls, ...uploadedUrls];
        widget.onImagesChanged(newUrls);

        if (mounted) {
          SnackbarHelper.showSuccess(
            context,
            '${uploadedUrls.length} images uploaded! ✅',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Upload failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  // Remove image
  void _removeImage(int index) async {
    final url = widget.imageUrls[index];

    if (url.contains('firebase')) {
      try {
        await FirebaseStorage.instance.refFromURL(url).delete();
      } catch (e) {
        debugPrint('Error deleting image: $e');
      }
    }

    final newUrls = [...widget.imageUrls];
    newUrls.removeAt(index);
    widget.onImagesChanged(newUrls);
    SnackbarHelper.showSuccess(context, 'Image removed');
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final inputFillColor = isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50;
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Upload Methods Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cloud_upload, size: 32, color: accentColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Upload Methods', style: AppTextStyles.titleMedium.copyWith(color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 4),
                        Text(
                          'Choose from device or paste URL',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isDark ? Colors.grey[400] : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Upload Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isUploading ? null : _pickAndUploadImage,
                      icon: _isUploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.photo_library, size: 18),
                      label: const Text('Single'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isUploading ? null : _pickAndUploadMultipleImages,
                      icon: _isUploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Multiple'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[200],
                        foregroundColor: isDark ? Colors.white : Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Divider with Text
        Row(
          children: [
            Expanded(child: Divider(color: isDark ? Colors.grey[700] : Colors.grey[300])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OR',
                style: AppTextStyles.bodySmall.copyWith(color: Colors.grey),
              ),
            ),
            Expanded(child: Divider(color: isDark ? Colors.grey[700] : Colors.grey[300])),
          ],
        ),

        const SizedBox(height: 24),

        // Add Image URL
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _urlController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Image URL',
                  labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  hintText: 'https://example.com/image.jpg',
                  hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
                  prefixIcon: Icon(Icons.link, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)
                  ),
                  filled: true,
                  fillColor: inputFillColor,
                ),
                onSubmitted: (_) => _addImageUrl(),
                enabled: !_isUploading,
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _addImageUrl,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Upload Progress
        if (_isUploading)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.info),
                ),
                const SizedBox(width: 16),
                Text(
                  'Uploading images...',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.info,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

        if (_isUploading) const SizedBox(height: 24),

        // Image Count
        if (widget.imageUrls.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              '${widget.imageUrls.length} image(s) added',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),

        // Image Grid
        if (widget.imageUrls.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.image_outlined, size: 80, color: isDark ? Colors.grey[700] : Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No images added', style: AppTextStyles.bodyLarge.copyWith(color: isDark ? Colors.white70 : Colors.black87)),
                  const SizedBox(height: 8),
                  Text(
                    'Upload from device or paste URL',
                    style: AppTextStyles.bodySmall.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: widget.imageUrls.length,
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        widget.imageUrls[index],
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: isDark ? Colors.grey[800] : Colors.grey.shade200,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          color: isDark ? Colors.grey[800] : Colors.grey.shade200,
                          child: Icon(Icons.broken_image, size: 50, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                        ),
                      ),
                    ),
                  ),
                  
                  // Delete Button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                        onPressed: () => _removeImage(index),
                      ),
                    ),
                  ),
                  
                  // Primary Badge
                  if (index == 0)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, color: isDark ? Colors.black : Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              'Primary',
                              style: TextStyle(
                                color: isDark ? Colors.black : Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}