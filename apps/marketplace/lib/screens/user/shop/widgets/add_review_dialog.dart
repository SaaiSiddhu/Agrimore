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
import '../../../../providers/auth_provider.dart' as app_auth;
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_services/agrimore_services.dart';

class AddReviewDialog extends StatefulWidget {
  final String productId;
  final String productName;
  final ReviewModel? reviewToEdit;
  final Future<bool> Function(String, String)? purchaseCheck;
  final Future<List<XFile>> Function()? pickImages;
  final Future<String> Function(String, Uint8List)? uploadImage;
  final DatabaseService Function(bool Function())? databaseFactory;

  const AddReviewDialog({
    Key? key,
    required this.productId,
    required this.productName,
    this.reviewToEdit,
    this.purchaseCheck,
    this.pickImages,
    this.uploadImage,
    this.databaseFactory,
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
  bool _didCheckPurchase = false;
  late final AddReviewDialog _openingWidget;
  late final app_auth.AuthProvider _openingAuth;
  late final AuthService _openingService;
  late final String? _owner;
  late final int _version;
  late final String _product;
  late final ReviewModel? _edit;
  ModalRoute<dynamic>? _route;
  bool _expired = false;
  bool _picking = false;
  bool get _owns =>
      mounted &&
      !_expired &&
      _owner != null &&
      _owner.isNotEmpty &&
      _product.trim() == _product &&
      _product.isNotEmpty &&
      !_product.contains('/') &&
      identical(context.read<app_auth.AuthProvider>(), _openingAuth) &&
      identical(context.read<AuthService>(), _openingService) &&
      _openingAuth.isSessionCurrent(_owner, _version) &&
      _openingService.currentUserId == _owner &&
      widget.productId == _product &&
      identical(widget.reviewToEdit, _edit) &&
      widget.purchaseCheck == _openingWidget.purchaseCheck &&
      widget.pickImages == _openingWidget.pickImages &&
      widget.uploadImage == _openingWidget.uploadImage &&
      widget.databaseFactory == _openingWidget.databaseFactory &&
      (_edit == null ||
          (_edit.userId == _owner &&
              _edit.productId == _product &&
              _edit.reviewId.isNotEmpty &&
              !_edit.reviewId.contains('/')));
  bool get _canAct => _owns && _route?.isCurrent == true;
  void _expire() {
    _expired = true;
    _pickedImages.clear();
  }

  void _authChanged() {
    if (mounted && !_owns) setState(_expire);
  }

  void _close() {
    if (_canAct) Navigator.pop(context);
  }

  void _closeExpired() {
    if (mounted && _route?.isCurrent == true) Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
    _openingWidget = widget;
    _openingAuth = context.read<app_auth.AuthProvider>();
    _openingService = context.read<AuthService>();
    _owner = _openingAuth.currentUser?.uid;
    _version = _openingAuth.sessionVersion;
    _product = widget.productId;
    _edit = widget.reviewToEdit;
    _openingAuth.addListener(_authChanged);
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
    _route ??= ModalRoute.of(context);
    if (!_didCheckPurchase) {
      _didCheckPurchase = true;
      _checkPurchaseStatus();
    }
  }

  @override
  void didUpdateWidget(covariant AddReviewDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_owns) _expire();
  }

  @override
  void dispose() {
    _openingAuth.removeListener(_authChanged);
    _expire();
    _titleController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _checkPurchaseStatus() async {
    if (!_owns) return;
    try {
      bool found;
      if (_edit != null) {
        found = _edit.isVerifiedPurchase;
      } else if (widget.purchaseCheck != null) {
        found = await widget.purchaseCheck!(_owner!, _product);
      } else {
        final orders = await FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: _owner)
            .where('orderStatus', isEqualTo: 'delivered')
            .get();
        if (!_owns) return;
        found = orders.docs.any((doc) {
          final data = doc.data();
          final items = data['items'];
          return data['userId'] == _owner &&
              data['orderStatus'] == 'delivered' &&
              items is List &&
              items.any((item) => item is Map && item['productId'] == _product);
        });
      }
      if (_owns) {
        setState(() {
          _hasPurchased = found;
          _isCheckingPurchase = false;
        });
      }
    } catch (error) {
      debugPrint('Review purchase read failed: ${error.runtimeType}');
      if (_owns) {
        setState(() {
          _hasPurchased = false;
          _isCheckingPurchase = false;
        });
      }
    }
  }

  Future<void> _pickImages() async {
    if (!_canAct || _isLoading || _picking) return;
    _picking = true;
    try {
      final images = await (widget.pickImages?.call() ??
          _picker.pickMultiImage(imageQuality: 80, maxWidth: 1024));
      if (_canAct && !_isLoading && images.isNotEmpty) {
        setState(() => _pickedImages.addAll(images));
      }
    } catch (error) {
      debugPrint('Review photo selection failed: ${error.runtimeType}');
      if (mounted && _canAct) {
        SnackbarHelper.showError(
            context, 'Could not select photos. Please try again.');
      }
    } finally {
      _picking = false;
    }
  }

  Future<List<String>> _uploadReviewImages(List<XFile> images) async {
    final urls = <String>[];
    for (var i = 0; i < images.length; i++) {
      if (!_canAct) throw AuthException('The review session changed.');
      final bytes = await images[i].readAsBytes();
      if (!_canAct) throw AuthException('The review session changed.');
      final name = 'review_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      final path = 'reviews/$_product/$_owner/$name';
      final String url;
      if (widget.uploadImage != null) {
        url = await widget.uploadImage!(path, bytes);
      } else {
        final ref = FirebaseStorage.instance.ref(path);
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        if (!_canAct) throw AuthException('The review session changed.');
        url = await ref.getDownloadURL();
      }
      if (!_canAct) throw AuthException('The review session changed.');
      if (url.isEmpty) {
        throw DatabaseException('The photo upload was not confirmed.');
      }
      urls.add(url);
    }
    return urls;
  }

  Future<void> _submitReview() async {
    if (!_canAct ||
        _isLoading ||
        _picking ||
        !_formKey.currentState!.validate()) {
      return;
    }
    final title = _titleController.text.trim();
    final comment = _commentController.text.trim();
    final rating = _rating;
    final images = List<XFile>.unmodifiable(_pickedImages);
    final oldImages = List<String>.unmodifiable(_edit?.imageUrls ?? const []);
    setState(() => _isLoading = true);
    bool uploading = false;
    try {
      final user = await _openingService.getUserData(_owner!);
      if (!_canAct) return;
      if (user.uid != _owner) {
        throw AuthException('The review profile is unavailable.');
      }
      uploading = images.isNotEmpty;
      final urls = await _uploadReviewImages(images);
      uploading = false;
      if (!_canAct) return;
      final review = ReviewModel(
        reviewId: _edit?.reviewId ?? '',
        productId: _product,
        userId: _owner,
        userName: user.name,
        userAvatar: user.photoUrl ?? '',
        rating: rating,
        title: title,
        comment: comment,
        createdAt: _edit?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        imageUrls: [...urls, ...oldImages],
        // Advisory only: the shared content writer excludes this trust field.
        isVerifiedPurchase: _hasPurchased,
      );
      final service = widget.databaseFactory?.call(() => _canAct) ??
          DatabaseService(isReviewSessionCurrent: () => _canAct);
      if (!_canAct) return;
      if (_edit != null) {
        await service.updateReview(review);
      } else {
        final savedId = await service.addReview(review);
        if (savedId != _owner) {
          throw DatabaseException('The review save was not confirmed.');
        }
      }
      if (mounted && _canAct) Navigator.pop(context, true);
    } catch (error) {
      debugPrint('Review submit failed: ${error.runtimeType}');
      if (mounted && _canAct) {
        SnackbarHelper.showError(
            context,
            uploading
                ? 'Could not upload review photos. Try again or remove the photos.'
                : 'Could not save your review. Please try again.');
      }
    } finally {
      if (_owns) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<app_auth.AuthProvider>();
    context.watch<AuthService>();
    if (!_owns) {
      _expire();
      return Dialog(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      'Your session changed. Reopen the review to continue.'),
                  TextButton(
                      onPressed: _closeExpired, child: const Text('Close')),
                ],
              )));
    }
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
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
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
                        widget.reviewToEdit != null
                            ? 'Edit Your Review'
                            : 'Write a Review',
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
                            onTap: () {
                              if (_canAct && !_isLoading) {
                                setState(() => _rating = index + 1);
                              }
                            },
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
                                widget.reviewToEdit != null
                                    ? 'Update Review'
                                    : 'Submit Review',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
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
                  onTap: _close,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color:
                          isDark ? const Color(0xFF2C2C2C) : Colors.grey[200],
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
                        color: (isDark ? const Color(0xFF1E1E1E) : Colors.white)
                            .withValues(alpha: 0.9),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: accentColor),
                            const SizedBox(height: 16),
                            Text(
                              'Loading...',
                              style: TextStyle(
                                  color:
                                      isDark ? Colors.white70 : Colors.black87),
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
          enabled: !_isLoading,
          validator: validator,
          maxLines: maxLines,
          style: TextStyle(
              color: isDark ? Colors.white : Colors.black87, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[500]),
            prefixIcon: Icon(icon,
                color: isDark ? Colors.grey[400] : Colors.grey[600], size: 20),
            filled: true,
            fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: isDark ? AppColors.primaryLight : AppColors.primary,
                  width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.red[600]!, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.red[600]!, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                  Icon(Icons.add_a_photo_outlined,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      size: 30),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to add photos',
                    style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w600),
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
          final image = _pickedImages[index];
          return Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: Stack(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
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
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
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
                      if (_canAct && !_isLoading) {
                        setState(() => _pickedImages.remove(image));
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 16),
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
