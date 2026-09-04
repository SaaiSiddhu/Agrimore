// lib/providers/bestseller_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_core/agrimore_core.dart';

/// Provider for fetching Bestseller slots in Marketplace app
class BestsellerProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<BestsellerSlotModel> _slots = [];
  bool _isLoading = false;
  bool _isLoaded = false;

  List<BestsellerSlotModel> get slots => _slots;
  List<BestsellerSlotModel> get activeSlots => 
      _slots.where((s) => s.isActive && s.categoryId.isNotEmpty).toList();
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;

  /// Load all bestseller slots (filter client-side to avoid index)
  Future<void> loadSlots() async {
    if (_isLoaded) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      // Simple query - just order by position, filter active client-side
      final snapshot = await _firestore
          .collection('bestseller_slots')
          .orderBy('position')
          .get();

      _slots = snapshot.docs
          .map((doc) => BestsellerSlotModel.fromMap(
              doc.data(), doc.id))
          .where((slot) => slot.isActive && slot.categoryId.isNotEmpty)
          .toList();
      
      debugPrint('✅ Loaded ${_slots.length} active bestseller slots');
      
      _isLoaded = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading bestseller slots: $e');
      _isLoading = false;
      _isLoaded = true;
      notifyListeners();
    }
  }

  /// Force reload slots
  Future<void> refresh() async {
    _isLoaded = false;
    await loadSlots();
  }

  /// Get slot by position
  BestsellerSlotModel? getSlotByPosition(int position) {
    try {
      return _slots.firstWhere((s) => s.position == position);
    } catch (e) {
      return null;
    }
  }
}
