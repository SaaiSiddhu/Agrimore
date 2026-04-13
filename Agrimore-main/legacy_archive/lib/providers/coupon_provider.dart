import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/coupon_model.dart';
import '../models/cart_item_model.dart';

class CouponProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<CouponModel> _availableCoupons = [];
  List<CouponModel> _coupons = [];
  CouponModel? _appliedCoupon;
  bool _isLoading = false;
  String? _error;

  List<CouponModel> get availableCoupons => _availableCoupons;
  List<CouponModel> get coupons => _coupons;
  CouponModel? get appliedCoupon => _appliedCoupon;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasCouponApplied => _appliedCoupon != null;

  // ============================================
  // USER METHODS
  // ============================================

  Future<void> fetchAvailableCoupons() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final now = DateTime.now();

      final querySnapshot = await _firestore
          .collection('coupons')
          .where('isActive', isEqualTo: true)
          .where('validTo', isGreaterThan: now)
          .orderBy('validTo')
          .orderBy('createdAt', descending: true)
          .get();

      _availableCoupons = querySnapshot.docs
          .map((doc) => CouponModel.fromMap(doc.data(), doc.id))
          .where((coupon) => coupon.isValid)
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Error fetching coupons: $e');
    }
  }

  Future<bool> applyCouponByCode(String code, double orderAmount) async {
    try {
      _isLoading = true;
      notifyListeners();

      final querySnapshot = await _firestore
          .collection('coupons')
          .where('code', isEqualTo: code.toUpperCase())
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        _error = 'Invalid coupon code';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final coupon = CouponModel.fromMap(
        querySnapshot.docs.first.data(),
        querySnapshot.docs.first.id,
      );

      if (!coupon.isValid) {
        _error = 'This coupon has expired or reached usage limit';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (coupon.minOrderAmount > orderAmount) {
        _error = 'Minimum order amount is ₹${coupon.minOrderAmount}';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _appliedCoupon = coupon;
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to apply coupon';
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Error applying coupon: $e');
      return false;
    }
  }

  void applyCoupon(CouponModel coupon) {
    _appliedCoupon = coupon;
    notifyListeners();
  }

  void removeCoupon() {
    _appliedCoupon = null;
    notifyListeners();
  }

  /// Calculate discount for given order amount and optional cart items.
  /// Delegates to the applied coupon, or returns 0 if none applied.
  double calculateDiscount({double orderAmount = 0, List<CartItemModel>? items}) {
    if (_appliedCoupon == null) return 0;
    try {
      return _appliedCoupon!.calculateDiscount(orderAmount, cartItems: items);
    } catch (e) {
      debugPrint('❌ calculateDiscount error: $e');
      return 0;
    }
  }

  bool validateCoupon(double orderAmount) {
    if (_appliedCoupon == null) return false;
    return _appliedCoupon!.isValid &&
        orderAmount >= _appliedCoupon!.minOrderAmount;
  }

  Future<void> incrementUsageCount(String couponId) async {
    try {
      await _firestore.collection('coupons').doc(couponId).update({
        'usedCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('❌ Error incrementing coupon usage: $e');
    }
  }

  // ============================================
  // ADMIN METHODS
  // ============================================

  Future<void> loadCoupons() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final querySnapshot = await _firestore
          .collection('coupons')
          .orderBy('createdAt', descending: true)
          .get();

      _coupons = querySnapshot.docs
          .map((doc) => CouponModel.fromMap(doc.data(), doc.id))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Error loading coupons: $e');
    }
  }

  Future<void> addCoupon(CouponModel coupon) async {
    try {
      _isLoading = true;
      notifyListeners();

      final docRef = await _firestore.collection('coupons').add(coupon.toMap());
      final newCoupon = coupon.copyWith(id: docRef.id);
      _coupons.insert(0, newCoupon);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Error adding coupon: $e');
      rethrow;
    }
  }

  Future<void> updateCoupon(CouponModel coupon) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore
          .collection('coupons')
          .doc(coupon.id)
          .update(coupon.toMap());

      final index = _coupons.indexWhere((c) => c.id == coupon.id);
      if (index != -1) _coupons[index] = coupon;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Error updating coupon: $e');
      rethrow;
    }
  }

  Future<void> deleteCoupon(String couponId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('coupons').doc(couponId).delete();
      _coupons.removeWhere((c) => c.id == couponId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Error deleting coupon: $e');
      rethrow;
    }
  }

  Future<void> toggleCouponStatus(String couponId) async {
    try {
      final index = _coupons.indexWhere((c) => c.id == couponId);
      if (index == -1) return;

      final coupon = _coupons[index];
      final newStatus = !coupon.isActive;

      await _firestore.collection('coupons').doc(couponId).update({
        'isActive': newStatus,
      });

      _coupons[index] = coupon.copyWith(isActive: newStatus);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('❌ Error toggling coupon status: $e');
      rethrow;
    }
  }

  CouponModel? getCouponById(String id) {
    try {
      return _coupons.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  int get activeCouponsCount =>
      _coupons.where((c) => c.isActive && c.isValid).length;

  int get expiredCouponsCount {
    final now = DateTime.now();
    return _coupons.where((c) => c.validTo.isBefore(now)).length;
  }

  int get totalUsageCount =>
      _coupons.fold(0, (sum, coupon) => sum + coupon.usedCount);
}