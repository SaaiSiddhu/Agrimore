import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../../providers/theme_provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_services/agrimore_services.dart';

class AddReviewDialog extends StatefulWidget {
  final String productId;
  final String productName;
  final ReviewModel? reviewToEdit;

  const AddReviewDialog({
    Key? key,
    required this.productId,
    required this.productName,
    this.reviewToEdit,
  }) : super(key: key);

  @override
  State<AddReviewDialog> createState() => _AddReviewDialogState();
}

class _AddReviewDialogState extends State<AddReviewDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _commentController;
  int _rating = 5;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _pickedImages = [];

  // --- Purchase Verification ---
  bool _isCheckingPurchase = true;
  bool _hasPurchased = false;
  bool _didCheckPurchase = false; // ✅ Flag to prevent multiple checks

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.reviewToEdit?.title ?? '',
    );
    _commentController = TextEditingController(
      text: widget.reviewToEdit?.comment ?? '',
    );
    _rating = widget.reviewToEdit?.rating ?? 5;
    
    // ❌ DO NOT check purchase here, context is not ready
  }

  // ✅ FIXED: Use didChangeDependencies to safely access providers
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This runs after initState and has a valid context
    if (!_didCheckPurchase) {
      _didCheckPurchase = true;
      _checkPurchaseStatus();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _checkPurchaseStatus() async {
    if (!mounted) return;
    
    // ✅ This call is now safe
    final authService = context.read<AuthService>();
    final currentUserId = authService.getCurrentUserId();

    if (currentUserId == null) {
      if (mounted) {
        setState(() {
          _hasPurchased = false;
          _isCheckingPurchase = false;
        });
      }
      return;
    }

    final user = await authService.getUserData(currentUserId);
    if (user?.role == 'admin') {
      if (mounted) {
        setState(() {
          _hasPurchased = true;
          _isCheckingPurchase = false;
        });
      }
      return;
    }
    
    if (widget.reviewToEdit != null) {
       if (mounted) {
         setState(() {
          _hasPurchased = widget.reviewToEdit!.isVerifiedPurchase;
          _isCheckingPurchase = false;
        });
       }
      return;
    }

    try {
      // ✅ This query points to the root 'orders' collection
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders') 
          .where('userId', isEqualTo: currentUserId)
          .where('orderStatus', isEqualTo: 'delivered')
          .get();

      bool found = false;
      for (var doc in ordersSnapshot.docs) {
        final orderData = doc.data();
        final List<dynamic> items = orderData['items'] ?? [];
        if (items.any((item) => item['productId'] == widget.productId)) {
          found = true;
          break;
        }
      }
      
      if (mounted) {
        setState(() {
          _hasPurchased = found;
          _isCheckingPurchase = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCheckingPurchase = false);
      }
      debugPrint('Error checking purchase status: $e');
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1024,
      );
      if (images.isNotEmpty) {
        setState(() {
          _pickedImages.addAll(images);
        });
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to pick images')),
        );
      }
    }
  }

  Future<List<String>> _uploadReviewImages() async {
    setState(() => _isLoading = true);
    List<String> imageUrls = [];
    final userId = context.read<AuthService>().getCurrentUserId();
    if (userId == null) return [];

    try {
      for (int i = 0; i < _pickedImages.length; i++) {
        final xFile = _pickedImages[i];
        final fileName = 'review_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final ref = FirebaseStorage.instance.ref(
          'reviews/${widget.productId}/$userId/$fileName'
        );
        
        // Use bytes for web compatibility
        final Uint8List bytes = await xFile.readAsBytes();
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        final downloadUrl = await ref.getDownloadURL();
        imageUrls.add(downloadUrl);
      }
    } catch (e) {
      debugPrint('Error uploading images: $e');
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload images. Please try again.')),
        );
      }
      setState(() => _isLoading = false);
      return []; // Return empty list on failure
    }
    
    return imageUrls;
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final authService = context.read<AuthService>();
    final databaseService = DatabaseService();
    final currentUserId = authService.getCurrentUserId();
    final currentUser = await authService.getUserData(currentUserId!);

    if (currentUser == null) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load user data')),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Upload Images
      List<String> imageUrls = await _uploadReviewImages();
      
      // If editing, merge old images with new ones
      if (widget.reviewToEdit != null) {
        imageUrls.addAll(widget.reviewToEdit!.imageUrls ?? []);
      }

      // 2. Create Review Model
      final review = ReviewModel(
        reviewId: widget.reviewToEdit?.reviewId ?? '',
        productId: widget.productId,
        userId: currentUserId,
        userName: currentUser.name,
        userAvatar: currentUser.photoUrl ?? '',
        rating: _rating,
        title: _titleController.text.trim(),
        comment: _commentController.text.trim(),
        createdAt: widget.reviewToEdit?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        isVerifiedPurchase: _hasPurchased, // ✅ Set automatically
        imageUrls: imageUrls, // ✅ Add image URLs
      );

      // 3. Submit to Database
      if (widget.reviewToEdit != null) {
        await databaseService.updateReview(review);
      } else {
        await databaseService.addReview(review);
      }

      if (mounted) {
        Navigator.pop(context, true); // Pop dialog and signal success
      }
      
    } catch (e) {
      debugPrint('❌ Error submitting review: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.reviewToEdit != null ? 'Edit Your Review' : 'Write a Review',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.productName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Divider(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        height: 32,
                      ),
                      Text(
                        'Your Rating',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return GestureDetector(
                            onTap: () => setState(() => _rating = index + 1),
                            child: Icon(
                              index < _rating
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              size: 40,
                              color: Colors.amber[600],
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
                      _buildTextFormField(
                        controller: _titleController,
                        label: 'Review Title',
                        hint: 'e.g., "Great product!"',
                        icon: Icons.title_rounded,
                        isDark: isDark,
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please enter a title'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextFormField(
                        controller: _commentController,
                        label: 'Your Review',
                        hint: 'Share your thoughts...',
                        icon: Icons.comment_outlined,
                        isDark: isDark,
                        maxLines: 4,
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please enter a comment'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      _buildAddPhotos(isDark),
                      _buildPhotoThumbnails(isDark),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submitReview,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                widget.reviewToEdit != null ? 'Update Review' : 'Submit Review',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Close Button
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                ),
              ),
            ),
            // Loading Overlay (only while checking - no purchase requirement)
            if (_isCheckingPurchase)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                    child: Container(
                      decoration: BoxDecoration(
                        color: (isDark ? const Color(0xFF1E1E1E) : Colors.white).withOpacity(0.9),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: accentColor),
                            const SizedBox(height: 16),
                            Text(
                              'Loading...',
                              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[500]),
            prefixIcon: Icon(icon, color: isDark ? Colors.grey[400] : Colors.grey[600], size: 20),
            filled: true,
            fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: isDark ? AppColors.primaryLight : AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.red[600]!, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.red[600]!, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildAddPhotos(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add Photos (Optional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: _pickImages,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Icon(Icons.add_a_photo_outlined, color: isDark ? Colors.grey[400] : Colors.grey[600], size: 30),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to add photos',
                    style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoThumbnails(bool isDark) {
    if (_pickedImages.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      height: 90,
      margin: const EdgeInsets.only(top: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _pickedImages.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: Stack(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: kIsWeb
                        // On web, use Image.network with blob URL
                        ? Image.network(
                            _pickedImages[index].path,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => 
                              const Icon(Icons.image, color: Colors.grey),
                          )
                        // On mobile, use Image.network with file path
                        : FutureBuilder<Uint8List>(
                            future: _pickedImages[index].readAsBytes(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return Image.memory(
                                  snapshot.data!,
                                  fit: BoxFit.cover,
                                );
                              }
                              return const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            },
                          ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _pickedImages.removeAt(index);
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}