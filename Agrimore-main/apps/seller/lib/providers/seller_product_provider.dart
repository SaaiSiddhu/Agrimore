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
  int get lowStockProducts =>
      _products.where((p) => p.stock > 0 && p.stock < 10).length;

  List<ProductModel> get _filteredProducts {
    if (_searchQuery.isEmpty) return _products;
    return _products
        .where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
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
          .get();

      _products = snapshot.docs
          .map((doc) => ProductModel.fromMap(doc.data(), doc.id))
          .toList();
      _products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
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

      final docRef =
          await _firestore.collection('products').add(product.toMap());
      await _saveCenterPriceMapping(product, docRef.id);

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

      await _firestore
          .collection('products')
          .doc(product.id)
          .update(product.toMap());
      await _saveCenterPriceMapping(product, product.id);

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
  Future<bool> toggleProductActive(
      String productId, bool isActive, String sellerId) async {
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
  Future<bool> updateStock(
      String productId, int newStock, String sellerId) async {
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

  Future<List<Map<String, dynamic>>> searchMasterProducts(String query) async {
    final term = query.trim();
    if (term.length < 2) return [];

    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _firestore
          .collection('masterProducts')
          .orderBy('name')
          .startAt([term])
          .endAt(['$term\uf8ff'])
          .limit(8)
          .get();
    } catch (_) {
      snapshot = await _firestore.collection('masterProducts').limit(30).get();
    }

    final lower = term.toLowerCase();
    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .where((data) =>
            (data['name'] ?? '').toString().toLowerCase().contains(lower))
        .take(8)
        .toList();
  }

  Future<List<Map<String, dynamic>>> loadCenters() async {
    final snapshot = await _firestore.collection('centers').limit(50).get();
    final centers = snapshot.docs.map((doc) {
      final data = doc.data();
      final name = (data['name'] ??
              data['areaName'] ??
              data['hubName'] ??
              data['title'] ??
              doc.id)
          .toString();
      return {'id': doc.id, 'name': name, ...data};
    }).toList();

    if (centers.isNotEmpty) return centers;
    return const [
      {'id': 'tamil_nadu', 'name': 'Tamil Nadu'},
      {'id': 'theni', 'name': 'Theni'},
      {'id': 'chennai', 'name': 'Chennai'},
      {'id': 'coimbatore', 'name': 'Coimbatore'},
    ];
  }

  Future<double?> getCenterPrice({
    required String masterProductId,
    required String centerId,
    String? sellerId,
  }) async {
    final candidateIds = [
      if (sellerId != null && sellerId.isNotEmpty)
        '${masterProductId}_${centerId}_$sellerId',
      '${masterProductId}_$centerId',
    ];

    for (final id in candidateIds) {
      final doc =
          await _firestore.collection('product_price_mappings').doc(id).get();
      final data = doc.data();
      final price = (data?['manualPrice'] ??
          data?['areaPrice'] ??
          data?['price'] ??
          data?['effectivePrice']) as num?;
      if (price != null) return price.toDouble();
    }

    return null;
  }

  Future<void> _saveCenterPriceMapping(
      ProductModel product, String productId) async {
    final masterId = product.masterProductRef;
    final centerId = product.centerId;
    if (masterId == null ||
        masterId.trim().isEmpty ||
        centerId == null ||
        centerId.trim().isEmpty) {
      return;
    }

    final mappingId =
        '${masterId.trim()}_${centerId.trim()}_${product.sellerId}';
    await _firestore.collection('product_price_mappings').doc(mappingId).set({
      'productId': productId,
      'masterProductRef': masterId.trim(),
      'centerId': centerId.trim(),
      'centerName': product.centerName,
      'sellerId': product.sellerId,
      'basePrice': product.basePrice,
      'areaPrice': product.areaPrice,
      'manualPrice': product.manualPriceOverride ? product.salePrice : null,
      'effectivePrice': product.salePrice,
      'priceSource': product.priceSource,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
