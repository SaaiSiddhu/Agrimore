// lib/providers/bestseller_provider.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:agrimore_core/agrimore_core.dart';

/// Provider for managing Bestseller slots in Admin app
class BestsellerProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  List<BestsellerSlotModel> _slots = [];
  bool _isLoading = false;
  String? _error;

  List<BestsellerSlotModel> get slots => _slots;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Collection reference
  CollectionReference get _slotsCollection => 
      _firestore.collection('bestseller_slots');

  /// Load all 9 slots
  Future<void> loadSlots() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _slotsCollection
          .orderBy('position')
          .get();

      if (snapshot.docs.isEmpty) {
        // Initialize 9 empty slots if none exist
        _slots = List.generate(9, (i) => BestsellerSlotModel.empty(i + 1));
      } else {
        _slots = snapshot.docs
            .map((doc) => BestsellerSlotModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList();
        
        // Ensure we have all 9 slots
        for (int i = 1; i <= 9; i++) {
          if (!_slots.any((s) => s.position == i)) {
            _slots.add(BestsellerSlotModel.empty(i));
          }
        }
        _slots.sort((a, b) => a.position.compareTo(b.position));
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save or update a slot
  Future<bool> saveSlot(BestsellerSlotModel slot) async {
    try {
      if (slot.id.isEmpty) {
        // Create new
        final docRef = await _slotsCollection.add(slot.toMap());
        final index = _slots.indexWhere((s) => s.position == slot.position);
        if (index >= 0) {
          _slots[index] = slot.copyWith(id: docRef.id);
        }
      } else {
        // Update existing
        await _slotsCollection.doc(slot.id).update(slot.toMap());
        final index = _slots.indexWhere((s) => s.id == slot.id);
        if (index >= 0) {
          _slots[index] = slot;
        }
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Upload image for a slot position
  /// [slotPosition] is 1-9, [imagePosition] is 1-4
  Future<String?> uploadImage({
    required int slotPosition,
    required int imagePosition,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      final path = 'bestsellers/slot_$slotPosition/image_$imagePosition.jpg';
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
  Future<bool> deleteImage({
    required int slotPosition,
    required int imagePosition,
  }) async {
    try {
      final path = 'bestsellers/slot_$slotPosition/image_$imagePosition.jpg';
      final ref = _storage.ref().child(path);
      await ref.delete();
      return true;
    } catch (e) {
      // Image might not exist, that's okay
      return true;
    }
  }

  /// Delete a slot
  Future<bool> deleteSlot(String slotId) async {
    try {
      await _slotsCollection.doc(slotId).delete();
      final index = _slots.indexWhere((s) => s.id == slotId);
      if (index >= 0) {
        final position = _slots[index].position;
        _slots[index] = BestsellerSlotModel.empty(position);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Get slot by position
  BestsellerSlotModel? getSlotByPosition(int position) {
    try {
      return _slots.firstWhere((s) => s.position == position);
    } catch (e) {
      return null;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
