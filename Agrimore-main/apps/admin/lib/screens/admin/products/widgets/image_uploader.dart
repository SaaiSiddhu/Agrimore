import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../../app/themes/admin_colors.dart';

/// Premium Image Uploader with AdminColors theme
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
  double _uploadProgress = 0;

  void _addImageUrl() {
    if (_urlController.text.trim().isNotEmpty) {
      HapticFeedback.lightImpact();
      final newUrls = [...widget.imageUrls, _urlController.text.trim()];
      widget.onImagesChanged(newUrls);
      _urlController.clear();
      SnackbarHelper.showSuccess(context, 'Image URL added');
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _isUploading = true;
        _uploadProgress = 0;
      });

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

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      final newUrls = [...widget.imageUrls, downloadUrl];
      widget.onImagesChanged(newUrls);

      if (mounted) {
        HapticFeedback.heavyImpact();
        SnackbarHelper.showSuccess(context, 'Image uploaded successfully! ✅');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Upload failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  Future<void> _pickAndUploadMultipleImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (images.isEmpty) return;

      setState(() {
        _isUploading = true;
        _uploadProgress = 0;
      });

      List<String> uploadedUrls = [];
      int completed = 0;

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
          completed++;
          setState(() {
            _uploadProgress = completed / images.length;
          });
        } catch (e) {
          debugPrint('Error uploading image: $e');
        }
      }

      if (uploadedUrls.isNotEmpty) {
        final newUrls = [...widget.imageUrls, ...uploadedUrls];
        widget.onImagesChanged(newUrls);

        if (mounted) {
          HapticFeedback.heavyImpact();
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
        setState(() {
          _isUploading = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  void _removeImage(int index) async {
    HapticFeedback.mediumImpact();
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

  void _reorderImages(int oldIndex, int newIndex) {
    HapticFeedback.selectionClick();
    final newUrls = [...widget.imageUrls];
    if (newIndex > oldIndex) newIndex--;
    final item = newUrls.removeAt(oldIndex);
    newUrls.insert(newIndex, item);
    widget.onImagesChanged(newUrls);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header
        _buildSectionHeader(
          icon: Icons.image_rounded,
          title: 'Product Images',
          subtitle: 'Add photos to showcase your product',
        ),
        const SizedBox(height: 20),

        // Upload Zone
        _buildUploadZone(),
        const SizedBox(height: 20),

        // URL Input
        _buildUrlInput(),

        // Upload Progress
        if (_isUploading) ...[
          const SizedBox(height: 20),
          _buildUploadProgress(),
        ],

        const SizedBox(height: 24),

        // Images Section
        if (widget.imageUrls.isNotEmpty) ...[
          _buildImagesHeader(),
          const SizedBox(height: 16),
          _buildImageGrid(),
        ] else
          _buildEmptyState(),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AdminColors.primary.withOpacity(0.08),
            AdminColors.primaryLight.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AdminColors.primary, AdminColors.primaryLight],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AdminColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadZone() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AdminColors.primary.withOpacity(0.2),
          style: BorderStyle.solid,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AdminColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_upload_rounded,
              size: 40,
              color: AdminColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Upload Product Images',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AdminColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'JPG, PNG up to 10MB each',
            style: TextStyle(
              fontSize: 13,
              color: AdminColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildUploadButton(
                label: 'Single Image',
                icon: Icons.add_photo_alternate_rounded,
                onTap: _pickAndUploadImage,
                isPrimary: true,
              ),
              const SizedBox(width: 12),
              _buildUploadButton(
                label: 'Multiple',
                icon: Icons.collections_rounded,
                onTap: _pickAndUploadMultipleImages,
                isPrimary: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return Material(
      color: isPrimary ? AdminColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _isUploading ? null : () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isPrimary ? null : Border.all(color: AdminColors.primary.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isPrimary ? Colors.white : AdminColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isPrimary ? Colors.white : AdminColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUrlInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Or paste image URL',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AdminColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _urlController,
                  style: TextStyle(
                    fontSize: 14,
                    color: AdminColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'https://example.com/image.jpg',
                    hintStyle: TextStyle(
                      color: AdminColors.textSecondary.withOpacity(0.6),
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.link_rounded,
                      color: AdminColors.primary,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AdminColors.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    isDense: true,
                  ),
                  onFieldSubmitted: (_) => _addImageUrl(),
                  enabled: !_isUploading,
                ),
              ),
              const SizedBox(width: 12),
              Material(
                color: AdminColors.primary,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: _isUploading ? null : _addImageUrl,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUploadProgress() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.info.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.info.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AdminColors.info,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Uploading... ${(_uploadProgress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AdminColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: AdminColors.info.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(AdminColors.info),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagesHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.photo_library_rounded, color: AdminColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              '${widget.imageUrls.length} Image${widget.imageUrls.length > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AdminColors.textPrimary,
              ),
            ),
          ],
        ),
        Text(
          'Drag to reorder',
          style: TextStyle(
            fontSize: 12,
            color: AdminColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildImageGrid() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: widget.imageUrls.length,
      onReorder: _reorderImages,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Material(
              elevation: 8,
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: child,
            );
          },
          child: child,
        );
      },
      itemBuilder: (context, index) {
        return ReorderableDragStartListener(
          key: ValueKey(widget.imageUrls[index]),
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildImageCard(index),
          ),
        );
      },
    );
  }

  Widget _buildImageCard(int index) {
    final isPrimary = index == 0;
    
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPrimary ? AdminColors.primary.withOpacity(0.3) : Colors.grey.shade200,
          width: isPrimary ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(13),
              bottomLeft: Radius.circular(13),
            ),
            child: Image.network(
              widget.imageUrls[index],
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 100,
                  height: 100,
                  color: Colors.grey.shade100,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AdminColors.primary,
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                width: 100,
                height: 100,
                color: Colors.grey.shade100,
                child: Icon(Icons.broken_image_rounded, color: Colors.grey.shade400),
              ),
            ),
          ),
          
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isPrimary)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AdminColors.primary, AdminColors.primaryLight],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Primary',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    'Image ${index + 1}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AdminColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap and hold to reorder',
                    style: TextStyle(
                      fontSize: 12,
                      color: AdminColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Actions
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: () => _removeImage(index),
              icon: Icon(
                Icons.delete_outline_rounded,
                color: AdminColors.error,
                size: 22,
              ),
              style: IconButton.styleFrom(
                backgroundColor: AdminColors.error.withOpacity(0.1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.image_not_supported_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No images added yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AdminColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload images or paste URL to get started',
            style: TextStyle(
              fontSize: 13,
              color: AdminColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}