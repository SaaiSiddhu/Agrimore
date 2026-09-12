// lib/providers/home_product_section_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_core/agrimore_core.dart';

/// Admin provider for HOME-3's `home_product_sections` collection — mirrors
/// CategorySectionProvider's own add/update/delete/reorder shape exactly
/// (same position-renumbering batch write on delete/reorder).
class HomeProductSectionProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<HomeProductSectionConfigModel> _sections = [];
  bool _isLoading = false;
  String? _error;

  List<HomeProductSectionConfigModel> get sections => _sections;
  bool get isLoading => _isLoading;
  String? get error => _error;

  CollectionReference get _collection =>
      _firestore.collection('home_product_sections');

  Future<void> loadSections() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _collection.orderBy('position').get();
      _sections = snapshot.docs
          .map((doc) => HomeProductSectionConfigModel.fromFirestore(doc))
          .toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading home product sections: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addSection(HomeProductSectionConfigModel section) async {
    try {
      final nextPosition = _sections.isEmpty
          ? 1
          : _sections.map((s) => s.position).reduce((a, b) => a > b ? a : b) + 1;

      final newSection = section.copyWith(position: nextPosition);
      final docRef = await _collection.add(newSection.toFirestore());

      _sections.add(newSection.copyWith(id: docRef.id));
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSection(HomeProductSectionConfigModel section) async {
    try {
      await _collection.doc(section.id).update(section.toFirestore());
      final index = _sections.indexWhere((s) => s.id == section.id);
      if (index >= 0) _sections[index] = section;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSection(String sectionId) async {
    try {
      await _collection.doc(sectionId).delete();
      _sections.removeWhere((s) => s.id == sectionId);
      await _updatePositions();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> reorderSections(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _sections.removeAt(oldIndex);
    _sections.insert(newIndex, item);
    notifyListeners();
    await _updatePositions();
  }

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
      debugPrint('Error updating home product section positions: $e');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
