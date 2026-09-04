// lib/providers/category_section_provider.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:agrimore_core/agrimore_core.dart';

/// Provider for managing Category Sections in Admin app
/// Supports unlimited sections with up to 8 category slots each
class CategorySectionProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  List<CategorySectionSlotModel> _sections = [];
  bool _isLoading = false;
  String? _error;

  List<CategorySectionSlotModel> get sections => _sections;
  List<CategorySectionSlotModel> get activeSections => 
      _sections.where((s) => s.isActive && s.categoryIds.isNotEmpty).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Collection reference
  CollectionReference get _collection => 
      _firestore.collection('category_section_slots');

  /// Load all sections ordered by position
  Future<void> loadSections() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _collection
          .orderBy('position')
          .get();

      _sections = snapshot.docs
          .map((doc) => CategorySectionSlotModel.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      debugPrint('✅ Loaded ${_sections.length} category sections');
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading category sections: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new section
  Future<bool> addSection(CategorySectionSlotModel section) async {
    try {
      // Get next position
      final nextPosition = _sections.isEmpty 
          ? 1 
          : _sections.map((s) => s.position).reduce((a, b) => a > b ? a : b) + 1;
      
      final newSection = section.copyWith(position: nextPosition);
      final docRef = await _collection.add(newSection.toMap());
      
      _sections.add(newSection.copyWith(id: docRef.id));
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Update an existing section
  Future<bool> updateSection(CategorySectionSlotModel section) async {
    try {
      await _collection.doc(section.id).update(section.toMap());
      
      final index = _sections.indexWhere((s) => s.id == section.id);
      if (index >= 0) {
        _sections[index] = section;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete a section
  Future<bool> deleteSection(String sectionId) async {
    try {
      await _collection.doc(sectionId).delete();
      _sections.removeWhere((s) => s.id == sectionId);
      
      // Reorder remaining sections
      await _updatePositions();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Reorder sections
  Future<void> reorderSections(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
    final item = _sections.removeAt(oldIndex);
    _sections.insert(newIndex, item);
    notifyListeners();
    
    await _updatePositions();
  }

  /// Update positions in Firestore
  Future<void> _updatePositions() async {
    try {
      final batch = _firestore.batch();
      for (int i = 0; i < _sections.length; i++) {
        final section = _sections[i];
        if (section.id.isNotEmpty) {
          batch.update(_collection.doc(section.id), {'position': i + 1});
          _sections[i] = section.copyWith(position: i + 1);
        }
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error updating positions: $e');
    }
  }

  /// Upload image for a category slot (1-8)
  Future<String?> uploadCategoryImage({
    required String sectionId,
    required int slotPosition,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      final path = 'category_sections/$sectionId/slot_$slotPosition.jpg';
      final ref = _storage.ref().child(path);
      
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = await ref.putData(imageBytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      _error = 'Failed to upload image: $e';
      notifyListeners();
      return null;
    }
  }

  /// Delete an image from storage
  Future<bool> deleteCategoryImage({
    required String sectionId,
    required int slotPosition,
  }) async {
    try {
      final path = 'category_sections/$sectionId/slot_$slotPosition.jpg';
      final ref = _storage.ref().child(path);
      await ref.delete();
      return true;
    } catch (e) {
      // Image might not exist, that's okay
      return true;
    }
  }

  /// Refresh data
  Future<void> refresh() async {
    await loadSections();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
