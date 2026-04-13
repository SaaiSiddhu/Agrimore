import 'package:flutter/material.dart';
import '../models/wishlist_model.dart';
import '../models/product_model.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';

class WishlistProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();

  WishlistModel? _wishlist;
  bool _isLoading = false;
  String? _error;

  WishlistModel? get wishlist => _wishlist;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  int get itemCount => _wishlist?.totalItems ?? 0;
  bool get isEmpty => _wishlist?.isEmpty ?? true;
  List<String> get productIds => _wishlist?.productIds ?? [];

  // Load user wishlist
  void loadWishlist() {
    final userId = _authService.currentUserId;
    if (userId == null) return;

    _databaseService.getUserWishlist(userId).listen(
      (wishlist) {
        _wishlist = wishlist;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        notifyListeners();
      },
    );
  }

  // Add item to wishlist
  Future<bool> addItem(ProductModel product) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) {
        _error = 'Please login to add items to wishlist';
        notifyListeners();
        return false;
      }

      _isLoading = true;
      notifyListeners();

      List<String> updatedIds = _wishlist?.productIds ?? [];
      
      if (!updatedIds.contains(product.id)) {
        updatedIds.add(product.id);
      }

      final updatedWishlist = WishlistModel(
        id: userId,
        userId: userId,
        productIds: updatedIds,
        updatedAt: DateTime.now(),
      );

      await _databaseService.updateWishlist(userId, updatedWishlist);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ✅ NEW - Alias method for compatibility (addToWishlist)
  Future<void> addToWishlist(ProductModel product) async {
    await addItem(product);
  }

  // Remove item from wishlist
  Future<bool> removeItem(String productId) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) return false;

      _isLoading = true;
      notifyListeners();

      List<String> updatedIds = _wishlist?.productIds ?? [];
      updatedIds.remove(productId);

      final updatedWishlist = WishlistModel(
        id: userId,
        userId: userId,
        productIds: updatedIds,
        updatedAt: DateTime.now(),
      );

      await _databaseService.updateWishlist(userId, updatedWishlist);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ✅ NEW - Alias method for compatibility (removeFromWishlist)
  Future<void> removeFromWishlist(String productId) async {
    await removeItem(productId);
  }

  // Toggle wishlist item
  Future<bool> toggleItem(ProductModel product) async {
    if (isInWishlist(product.id)) {
      return await removeItem(product.id);
    } else {
      return await addItem(product);
    }
  }

  // ✅ NEW - Toggle with product ID only
  Future<bool> toggleItemById(String productId, ProductModel product) async {
    return await toggleItem(product);
  }

  // Check if product is in wishlist
  bool isInWishlist(String productId) {
    return _wishlist?.contains(productId) ?? false;
  }

  // Clear wishlist
  Future<bool> clearWishlist() async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) return false;

      _isLoading = true;
      notifyListeners();

      final emptyWishlist = WishlistModel(
        id: userId,
        userId: userId,
        productIds: [],
        updatedAt: DateTime.now(),
      );

      await _databaseService.updateWishlist(userId, emptyWishlist);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ✅ NEW - Refresh wishlist
  Future<void> refreshWishlist() async {
    loadWishlist();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
