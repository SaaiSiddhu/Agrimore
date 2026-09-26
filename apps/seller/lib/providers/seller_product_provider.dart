import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_services/agrimore_services.dart';

/// Listing tabs (ADR §10.4 C-01, SELLER-CATALOGUE-1).
/// SELLER-CATALOGUE-3 (gap 17): catalogue order.
enum ProductSort { newest, nameAz, priceLow, priceHigh, stockLow }

enum ProductListFilter { all, active, draft, lowStock, outOfStock, inactive }

/// SELLER-OPS-1: low stock uses the product's own alert level.
const int kDefaultLowStockThreshold = 10;

bool _unitIsLow(int stock, int threshold) => stock > 0 && stock <= threshold;

/// Phase ADMR-4: previously checked only `p.stock` — the base field, which a
/// variant-line sale never moves (createOrder.ts decrements a variant's own
/// stock inside product.variants[]). A product whose only stock lives in its
/// variants therefore never showed as low/out of stock here, in either the
/// "Low stock" listing tab or the dashboard's lowStockProducts count. Now
/// true when the base stock is low OR any variant's own stock is.
bool isLowStock(ProductModel p) {
  if (p.isDraft || !p.isActive) return false;
  final threshold = p.lowStockThreshold ?? kDefaultLowStockThreshold;
  if (_unitIsLow(p.stock, threshold)) return true;
  return p.variants.any((v) => _unitIsLow(v.stock, threshold));
}

class SellerProductProvider with ChangeNotifier {
  SellerProductProvider() : _preview = false;

  /// Test constructor: a fixed product list, no Firebase.
  @visibleForTesting
  SellerProductProvider.preview(List<ProductModel> products) : _preview = true {
    _products = List.of(products);
  }

  final bool _preview;

  // A getter, not a field: nothing touches Firebase until it is used.
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  List<ProductModel> _products = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  ProductListFilter _filter = ProductListFilter.all;

  ProductListFilter get filter => _filter;

  ProductSort _sort = ProductSort.newest;
  ProductSort get sort => _sort;

  void setSort(ProductSort value) {
    _sort = value;
    notifyListeners();
  }

  /// Pure comparator; ties fall back to newest first.
  static int compareBy(ProductSort s, ProductModel a, ProductModel b) {
    final newest = b.createdAt.compareTo(a.createdAt);
    final c = switch (s) {
      ProductSort.newest => newest,
      ProductSort.nameAz => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      ProductSort.priceLow => a.salePrice.compareTo(b.salePrice),
      ProductSort.priceHigh => b.salePrice.compareTo(a.salePrice),
      ProductSort.stockLow => a.stock.compareTo(b.stock),
    };
    return c != 0 ? c : newest;
  }

  void setFilter(ProductListFilter value) {
    _filter = value;
    notifyListeners();
  }

  /// Pure: which tab a product belongs to. Drafts are only "draft"; an
  /// out-of-stock product that is live counts as out of stock.
  static bool matchesFilter(ProductModel p, ProductListFilter f) {
    switch (f) {
      case ProductListFilter.all:
        return true;
      case ProductListFilter.draft:
        return p.isDraft;
      case ProductListFilter.active:
        return !p.isDraft && p.isActive && p.stock > 0;
      case ProductListFilter.lowStock:
        return isLowStock(p);
      case ProductListFilter.outOfStock:
        return !p.isDraft && p.isActive && p.stock <= 0;
      case ProductListFilter.inactive:
        return !p.isDraft && !p.isActive;
    }
  }

  int countFor(ProductListFilter f) => _products.where((p) => matchesFilter(p, f)).length;

  List<ProductModel> get products => _filteredProducts;
  List<ProductModel> get allProducts => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;

  // Stats
  int get totalProducts => _products.length;
  int get activeProducts => _products.where((p) => p.isActive).length;
  int get outOfStockProducts => _products.where((p) => p.stock == 0).length;
  int get lowStockProducts => _products.where(isLowStock).length;

  List<ProductModel> get _filteredProducts {
    final q = _searchQuery.toLowerCase();
    return _products
        .where((p) => matchesFilter(p, _filter))
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => compareBy(_sort, a, b));
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
        // Publishing a draft makes it a normal listing.
        if (isActive) 'isDraft': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // Update local state immediately
      final index = _products.indexWhere((p) => p.id == productId);
      if (index != -1) {
        _products[index] = _products[index].copyWith(
          isActive: isActive,
          isDraft: isActive ? false : null,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = 'Failed to update: $e';
      notifyListeners();
      return false;
    }
  }

  /// Bulk publish / hide (SELLER-CATALOGUE-1). One batched write, at most
  /// [_batchLimit] products per batch (Firestore's limit is 500).
  static const int _batchLimit = 450;

  Future<bool> bulkSetActive(Set<String> productIds, bool isActive) async {
    if (productIds.isEmpty) return true;
    try {
      final ids = productIds.toList();
      for (var start = 0; start < ids.length; start += _batchLimit) {
        final batch = _firestore.batch();
        for (final id in ids.skip(start).take(_batchLimit)) {
          batch.update(_firestore.collection('products').doc(id), {
            'isActive': isActive,
            if (isActive) 'isDraft': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
      _products = [
        for (final p in _products)
          productIds.contains(p.id)
              ? p.copyWith(isActive: isActive, isDraft: isActive ? false : null)
              : p,
      ];
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update products: $e';
      notifyListeners();
      return false;
    }
  }

  /// Bulk publish / hide with a result per product (decision D8): each
  /// product is written on its own, so one failure never hides which others
  /// went through. Returns the ids that could NOT be updated.
  Future<Set<String>> bulkSetActiveEach(Set<String> productIds, bool isActive) async {
    final failed = <String>{};
    await Future.wait(productIds.map((id) async {
      try {
        await _firestore.collection('products').doc(id).update({
          'isActive': isActive,
          if (isActive) 'isDraft': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Bulk update failed for $id: $e');
        failed.add(id);
      }
    }));
    _products = [
      for (final p in _products)
        productIds.contains(p.id) && !failed.contains(p.id)
            ? p.copyWith(isActive: isActive, isDraft: isActive ? false : null)
            : p,
    ];
    notifyListeners();
    return failed;
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
    if (term.length < 2 || _preview) return [];

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

  /// The real centres; empty when there are none (no stand-in list — the
  /// seller app never shows invented data).
  Future<List<Map<String, dynamic>>> loadCenters() async {
    if (_preview) return const [];
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

    return centers;
  }

  Future<double?> getCenterPrice({
    required String masterProductId,
    required String centerId,
    String? sellerId,
  }) async {
    if (_preview) return null;
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
