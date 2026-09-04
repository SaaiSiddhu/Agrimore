import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Seller Provider - Manages seller state and operations
class SellerProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isLoading = false;
  bool _isSeller = false;
  String? _sellerStatus; // 'pending', 'approved', 'rejected'
  Map<String, dynamic>? _sellerData;
  List<Map<String, dynamic>> _sellerProducts = [];
  List<Map<String, dynamic>> _sellerOrders = [];

  bool get isLoading => _isLoading;
  bool get isSeller => _isSeller;
  String? get sellerStatus => _sellerStatus;
  Map<String, dynamic>? get sellerData => _sellerData;
  List<Map<String, dynamic>> get sellerProducts => _sellerProducts;
  List<Map<String, dynamic>> get sellerOrders => _sellerOrders;
  bool get isApproved => _sellerStatus == 'approved';
  bool get isPending => _sellerStatus == 'pending';

  /// Loads seller state from `users` (sellerStatus / sellerProfile) and `sellers` (legacy).
  Future<void> checkSellerStatus() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      final userDoc = await _firestore.collection('users').doc(userId).get();
      final u = userDoc.data() ?? {};
      final sellerStatus = u['sellerStatus'] as String?;
      final role = (u['role'] as String?) ?? 'user';
      final profile = u['sellerProfile'] as Map<String, dynamic>?;

      if (sellerStatus == 'approved' && role == 'seller') {
        _isSeller = true;
        _sellerStatus = 'approved';
        _sellerData = profile ?? {};
        final sDoc = await _firestore.collection('sellers').doc(userId).get();
        if (sDoc.exists && sDoc.data() != null) {
          _sellerData = {...?_sellerData, ...?sDoc.data()};
        }
      } else if (sellerStatus == 'pending') {
        _isSeller = false;
        _sellerStatus = 'pending';
        _sellerData = profile;
      } else if (sellerStatus == 'rejected') {
        _isSeller = false;
        _sellerStatus = 'rejected';
        _sellerData = profile;
      } else {
        final doc = await _firestore.collection('sellers').doc(userId).get();
        if (doc.exists) {
          _sellerData = doc.data();
          _sellerStatus = (_sellerData?['status'] as String?) ?? 'pending';
          _isSeller = _sellerStatus == 'approved';
        } else {
          _isSeller = false;
          _sellerData = null;
          _sellerStatus = null;
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking seller status: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Apply to become a seller
  Future<bool> applyAsSeller(Map<String, dynamic> applicationData) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return false;

    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('sellers').doc(userId).set({
        ...applicationData,
        'userId': userId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _isSeller = true;
      _sellerStatus = 'pending';
      _sellerData = applicationData;
      
      debugPrint('✅ Seller application submitted');
      return true;
    } catch (e) {
      debugPrint('❌ Error applying as seller: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load seller's products
  Future<void> loadSellerProducts() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await _firestore
          .collection('products')
          .where('sellerId', isEqualTo: userId)
          .get();

      _sellerProducts = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      _sellerProducts.sort((a, b) => _compareCreatedAtDesc(a['createdAt'], b['createdAt']));

      debugPrint('✅ Loaded ${_sellerProducts.length} seller products');
    } catch (e) {
      debugPrint('❌ Error loading seller products: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load seller's orders
  Future<void> loadSellerOrders() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await _firestore
          .collection('orders')
          .where('sellerId', isEqualTo: userId)
          .get();

      _sellerOrders = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      _sellerOrders.sort((a, b) => _compareCreatedAtDesc(a['createdAt'], b['createdAt']));

      debugPrint('✅ Loaded ${_sellerOrders.length} seller orders');
    } catch (e) {
      debugPrint('❌ Error loading seller orders: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new product as seller
  Future<String?> addProduct(Map<String, dynamic> productData) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return null;

    try {
      _isLoading = true;
      notifyListeners();

      final docRef = await _firestore.collection('products').add({
        ...productData,
        'sellerId': userId,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Seller product added: ${docRef.id}');
      await loadSellerProducts();
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error adding seller product: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  int _compareCreatedAtDesc(dynamic a, dynamic b) {
    DateTime asDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return asDate(b).compareTo(asDate(a));
  }

  /// Update seller profile
  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return false;

    try {
      await _firestore.collection('sellers').doc(userId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _sellerData = {...?_sellerData, ...updates};
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Error updating seller profile: $e');
      return false;
    }
  }

  /// Reset seller state
  void reset() {
    _isLoading = false;
    _isSeller = false;
    _sellerStatus = null;
    _sellerData = null;
    _sellerProducts = [];
    _sellerOrders = [];
    notifyListeners();
  }
}
