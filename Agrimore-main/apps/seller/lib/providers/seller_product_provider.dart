import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_services/agrimore_services.dart';

class SellerProductProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<ProductModel> _products = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  List<ProductModel> get products => _filteredProducts;
  List<ProductModel> get allProducts => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;

  // Stats
  int get totalProducts => _products.length;
  int get activeProducts => _products.where((p) => p.isActive).length;
  int get outOfStockProducts => _products.where((p) => p.stock == 0).length;
  int get lowStockProducts => _products.where((p) => p.stock > 0 && p.stock < 10).length;

  List<ProductModel> get _filteredProducts {
    if (_searchQuery.isEmpty) return _products;
    return _products.where((p) =>
        p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> loadSellerProducts(String sellerId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final snapshot = await _firestore
          .collection('products')
          .where('sellerId', isEqualTo: sellerId)
          .orderBy('createdAt', descending: true)
          .get();

      _products = snapshot.docs.map((doc) => ProductModel.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      _error = 'Failed to load products: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addProduct(ProductModel product) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('products').add(product.toMap());
      
      await loadSellerProducts(product.sellerId);
      return true;
    } catch (e) {
      _error = 'Failed to add product: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProduct(ProductModel product) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('products').doc(product.id).update(product.toMap());
      
      await loadSellerProducts(product.sellerId);
      return true;
    } catch (e) {
      _error = 'Failed to update product: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProduct(String productId, String sellerId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('products').doc(productId).delete();
      
      await loadSellerProducts(sellerId);
      return true;
    } catch (e) {
      _error = 'Failed to delete product: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Toggle product active/inactive status
  Future<bool> toggleProductActive(String productId, bool isActive, String sellerId) async {
    try {
      await _firestore.collection('products').doc(productId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // Update local state immediately
      final index = _products.indexWhere((p) => p.id == productId);
      if (index != -1) {
        _products[index] = _products[index].copyWith(isActive: isActive);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = 'Failed to update: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update stock count
  Future<bool> updateStock(String productId, int newStock, String sellerId) async {
    try {
      await _firestore.collection('products').doc(productId).update({
        'stock': newStock,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final index = _products.indexWhere((p) => p.id == productId);
      if (index != -1) {
        _products[index] = _products[index].copyWith(stock: newStock);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = 'Failed to update stock: $e';
      notifyListeners();
      return false;
    }
  }
}
