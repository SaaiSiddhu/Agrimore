import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// BUSINESS-NETWORK-2 (slice 2 of 2): creates a business_posts/{postId} doc
/// on behalf of the current seller. Mirrors add_product_screen.dart's own
/// image-upload flow exactly (same Storage path convention, same
/// content-type normalization) rather than inventing a new one.
class SellerPostProvider with ChangeNotifier {
  bool _isPosting = false;
  bool get isPosting => _isPosting;

  Future<String> _uploadPostImage(String sellerId, Uint8List bytes, String fileName) async {
    final ext = fileName.split('.').last.toLowerCase();
    final normalizedExt = ['jpg', 'jpeg', 'png', 'webp'].contains(ext) ? ext : 'jpg';
    final contentType = normalizedExt == 'jpg'
        ? 'image/jpeg'
        : normalizedExt == 'webp'
            ? 'image/webp'
            : 'image/$normalizedExt';

    final ref = FirebaseStorage.instance.ref().child(
          'business_posts/${sellerId}_${DateTime.now().millisecondsSinceEpoch}.$normalizedExt',
        );
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  /// Returns true on success. `text`/`productId` are trimmed and treated as
  /// absent if empty; firestore.rules itself requires at least one of
  /// text/imageUrl/productId to be present, matched here so a doomed
  /// all-empty create is never even attempted.
  Future<bool> createPost({
    required String sellerId,
    String? text,
    Uint8List? imageBytes,
    String? imageFileName,
    String? productId,
  }) async {
    final trimmedText = text?.trim();
    final hasText = trimmedText != null && trimmedText.isNotEmpty;
    final hasImage = imageBytes != null && imageFileName != null;
    final hasProduct = productId != null && productId.isNotEmpty;
    if (!hasText && !hasImage && !hasProduct) return false;

    _isPosting = true;
    notifyListeners();
    try {
      String? imageUrl;
      if (hasImage) {
        imageUrl = await _uploadPostImage(sellerId, imageBytes, imageFileName);
      }

      final data = <String, dynamic>{
        'sellerId': sellerId,
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (hasText) data['text'] = trimmedText;
      if (imageUrl != null) data['imageUrl'] = imageUrl;
      if (hasProduct) data['productId'] = productId;

      await FirebaseFirestore.instance.collection('business_posts').add(data);
      return true;
    } catch (e) {
      debugPrint('❌ Error creating business post: $e');
      return false;
    } finally {
      _isPosting = false;
      notifyListeners();
    }
  }
}
