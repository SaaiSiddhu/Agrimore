// lib/providers/category_section_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_core/agrimore_core.dart';

/// Provider for fetching Category Sections in Marketplace app
class CategorySectionProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<CategorySectionSlotModel> _sections = [];
  bool _isLoading = false;
  String? _error;
  bool _isLoaded = false;  // ✅ Cache flag

  List<CategorySectionSlotModel> get sections => _sections;
  List<CategorySectionSlotModel> get activeSections => 
      _sections.where((s) => s.isActive && s.categoryIds.isNotEmpty).toList();
  
  // Alias for widget compatibility
  List<CategorySectionSlotModel> get activeSlots => activeSections;
  
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Collection reference
  CollectionReference get _collection => 
      _firestore.collection('category_section_slots');
  
  /// Alias for loadSections (for widget compatibility)
  Future<void> loadSlots() => loadSections();

  /// Load all active sections ordered by position
  Future<void> loadSections({bool forceRefresh = false}) async {
    // ✅ If forceRefresh, reset cache flag
    if (forceRefresh) {
      _isLoaded = false;
      debugPrint('🔄 Force refreshing category sections from Firebase...');
    }
    
    // ✅ Skip if already loaded (in-memory cache)
    if (_isLoaded && !forceRefresh) {
      debugPrint('📂 Category sections in-memory cached, skipping...');
      return;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _collection
          .where('isActive', isEqualTo: true)
          .orderBy('position')
          .get();

      _sections = snapshot.docs
          .map((doc) => CategorySectionSlotModel.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
          .where((s) => s.categoryIds.isNotEmpty)
          .toList();

      debugPrint('✅ Loaded ${_sections.length} active category sections');
      _isLoaded = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading category sections: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
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
