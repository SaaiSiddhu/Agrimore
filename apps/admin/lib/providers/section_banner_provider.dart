import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'dart:typed_data';

/// Provider for managing section banners in admin app
class SectionBannerProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  List<SectionBannerModel> _banners = [];
  bool _isLoading = false;
  String? _error;

  List<SectionBannerModel> get banners => _banners;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all section banners
  Future<void> loadBanners() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('section_banners')
          .orderBy('position')
          .get();

      _banners = snapshot.docs
          .map((doc) => SectionBannerModel.fromFirestore(doc))
          .toList();
      
      _error = null;
    } catch (e) {
      debugPrint('Error loading section banners: $e');
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Upload image to Firebase Storage
  Future<String> uploadImage(Uint8List imageBytes, String fileName) async {
    final ref = _storage.ref().child('section_banners/$fileName');
    final uploadTask = ref.putData(imageBytes);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  /// Create a new section banner
  Future<void> createBanner({
    required String imageUrl,
    String? title,
    String? subtitle,
    String? shopNowUrl,
    String? buttonText,
    required int position,
    required int displayAfterSection,
    bool isActive = true,
    bool showAdBadge = false,
  }) async {
    try {
      final doc = _firestore.collection('section_banners').doc();
      final banner = SectionBannerModel(
        id: doc.id,
        imageUrl: imageUrl,
        title: title,
        subtitle: subtitle,
        shopNowUrl: shopNowUrl,
        buttonText: buttonText,
        position: position,
        displayAfterSection: displayAfterSection,
        isActive: isActive,
        showAdBadge: showAdBadge,
        createdAt: DateTime.now(),
      );
      
      await doc.set(banner.toFirestore());
      await loadBanners();
    } catch (e) {
      debugPrint('Error creating section banner: $e');
      rethrow;
    }
  }

  /// Update an existing section banner
  Future<void> updateBanner({
    required String id,
    String? imageUrl,
    String? title,
    String? subtitle,
    String? shopNowUrl,
    String? buttonText,
    int? position,
    int? displayAfterSection,
    bool? isActive,
    bool? showAdBadge,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (imageUrl != null) updates['imageUrl'] = imageUrl;
      if (title != null) updates['title'] = title;
      if (subtitle != null) updates['subtitle'] = subtitle;
      if (shopNowUrl != null) updates['shopNowUrl'] = shopNowUrl;
      if (buttonText != null) updates['buttonText'] = buttonText;
      if (position != null) updates['position'] = position;
      if (displayAfterSection != null) updates['displayAfterSection'] = displayAfterSection;
      if (isActive != null) updates['isActive'] = isActive;
      if (showAdBadge != null) updates['showAdBadge'] = showAdBadge;
      
      await _firestore.collection('section_banners').doc(id).update(updates);
      await loadBanners();
    } catch (e) {
      debugPrint('Error updating section banner: $e');
      rethrow;
    }
  }

  /// Toggle banner active status
  Future<void> toggleBannerStatus(String id, bool isActive) async {
    try {
      await _firestore.collection('section_banners').doc(id).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await loadBanners();
    } catch (e) {
      debugPrint('Error toggling section banner status: $e');
      rethrow;
    }
  }

  /// Delete a section banner
  Future<void> deleteBanner(String id, String? imageUrl) async {
    try {
      // Delete image from storage if exists
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          final ref = _storage.refFromURL(imageUrl);
          await ref.delete();
        } catch (e) {
          debugPrint('Could not delete image: $e');
        }
      }
      
      await _firestore.collection('section_banners').doc(id).delete();
      await loadBanners();
    } catch (e) {
      debugPrint('Error deleting section banner: $e');
      rethrow;
    }
  }
}
