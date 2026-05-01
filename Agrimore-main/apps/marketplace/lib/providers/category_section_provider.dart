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
      final snapshot = await _collection.get();

      _sections = snapshot.docs
          .map((doc) => CategorySectionSlotModel.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
          .where((s) => s.isActive && s.categoryIds.isNotEmpty)
          .toList();
      _sections.sort((a, b) => a.position.compareTo(b.position));

      if (snapshot.docs.isEmpty) {
        debugPrint('⚠️ No category sections found. Seeding default sections...');
        final defaultSections = [
          {
            'title': 'Fresh Arrivals',
            'subtitle': 'Newly added products',
            'position': 1,
            'isActive': true,
            'categoryIds': ['general', 'dairy', 'bakery'],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'displayStyle': 'list',
          },
          {
            'title': 'Trending Now',
            'subtitle': 'Most popular items',
            'position': 2,
            'isActive': true,
            'categoryIds': ['general', 'offers'],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'displayStyle': 'grid',
          }
        ];
        
        for (var section in defaultSections) {
          try {
            await _collection.add(section);
          } catch (e) {
             debugPrint('Failed to seed section: $e');
          }
        }
        
        // Reload after seeding
        final newSnapshot = await _collection.get();
        _sections = newSnapshot.docs
            .map((doc) => CategorySectionSlotModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .where((s) => s.isActive && s.categoryIds.isNotEmpty)
            .toList();
        _sections.sort((a, b) => a.position.compareTo(b.position));
      }

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
