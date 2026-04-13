import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:agrimore_services/agrimore_services.dart';

class CartProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();
  final Uuid _uuid = const Uuid();

  CartModel? _cart;
  bool _isLoading = false;
  String? _error;
  bool _isListening = false; // ✅ Prevent duplicate stream subscriptions

  CartModel? get cart => _cart;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  int get itemCount => _cart?.totalItems ?? 0;
  double get subtotal => _cart?.subtotal ?? 0.0;
  bool get isEmpty => _cart?.isEmpty ?? true;
  List<CartItemModel> get items => _cart?.items ?? [];

  void loadCart() {
    // ✅ Skip if already listening
    if (_isListening) {
      debugPrint('📦 Cart already listening, skipping...');
      return;
    }
    
    final userId = _authService.currentUserId;
    if (userId == null) {
      debugPrint('❌ CartProvider.loadCart: No user logged in');
      _error = 'Please login';
      notifyListeners();
      return;
    }

    debugPrint('📦 CartProvider.loadCart: Loading for user $userId');
    _isListening = true; // ✅ Mark as listening
    
    _databaseService.getUserCart(userId).listen(
      (cart) {
        if (cart != null) {
          debugPrint('✅ CartProvider.loadCart: Cart loaded with ${cart.items.length} items');
          _cart = cart;
        } else {
          debugPrint('✅ CartProvider.loadCart: Cart is empty, initializing new cart');
          _cart = CartModel(
            id: userId,
            userId: userId,
            items: [],
            updatedAt: DateTime.now(),
          );
        }
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('❌ CartProvider.loadCart error: $error');
        _error = error.toString();
        _isListening = false; // ✅ Reset on error
        notifyListeners();
      },
    );
  }

  // ✅ UPDATED: Now accepts variant price parameters
  Future<bool> addItem(
    ProductModel product, {
    int quantity = 1,
    String? variant,
    double? variantPrice,         // ✅ NEW: Variant-specific price
    double? variantOriginalPrice, // ✅ NEW: Variant-specific original price
  }) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) {
        _error = 'Please login to add items to cart';
        notifyListeners();
        return false;
      }

      _isLoading = true;
      notifyListeners();

      // ✅ Use variant price if provided, otherwise fall back to base product price
      final effectivePrice = variantPrice ?? product.salePrice;
      final effectiveOriginalPrice = variantOriginalPrice ?? product.originalPrice;

      print('🛒 Adding to cart: ${product.name}, variant: $variant, price: $effectivePrice, qty: $quantity');

      final cartItem = CartItemModel(
        id: _uuid.v4(),
        productId: product.id,
        productName: product.name,
        productImage: product.primaryImage,
        price: effectivePrice,
        quantity: quantity,
        userId: userId,
        addedAt: DateTime.now(),
        variant: variant,
        originalPrice: effectiveOriginalPrice,
        discountPercentage: effectiveOriginalPrice != null && effectiveOriginalPrice > effectivePrice
            ? ((effectiveOriginalPrice - effectivePrice) / effectiveOriginalPrice * 100)
            : 0.0,
      );

      List<CartItemModel> updatedItems = _cart?.items ?? [];
      
      // ✅ UPDATED: Check both productId AND variant
      final existingIndex = updatedItems.indexWhere(
        (item) => item.productId == product.id && item.variant == variant,
      );

      if (existingIndex != -1) {
        // Same product with same variant - increase quantity
        updatedItems[existingIndex] = updatedItems[existingIndex].copyWith(
          quantity: updatedItems[existingIndex].quantity + quantity,
        );
        print('✅ Updated existing item quantity: ${updatedItems[existingIndex].quantity}');
      } else {
        // New product or different variant - add as new item
        updatedItems.add(cartItem);
        print('✅ Added new item to cart');
      }

      final updatedCart = CartModel(
        id: userId,
        userId: userId,
        items: updatedItems,
        updatedAt: DateTime.now(),
      );

      await _databaseService.updateCart(userId, updatedCart);

      _isLoading = false;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      print('❌ addItem error: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ✅ UPDATED: addOrderItems now supports variants
  Future<bool> addOrderItems(List<CartItemModel> orderItems) async {
    try {
      final userId = _authService.currentUserId;
      print('📦 [addOrderItems] Starting - userId: $userId, items: ${orderItems.length}');
      
      if (userId == null) {
        _error = 'Please login to add items to cart';
        print('❌ [addOrderItems] Error: User not logged in');
        notifyListeners();
        return false;
      }

      if (orderItems.isEmpty) {
        _error = 'No items to add';
        print('❌ [addOrderItems] Error: Empty items list');
        notifyListeners();
        return false;
      }

      _isLoading = true;
      notifyListeners();

      print('📦 [addOrderItems] Fetching current cart from database...');
      List<CartItemModel> updatedItems = [];
      
      try {
        final currentCart = await _databaseService.getUserCart(userId).first;
        if (currentCart != null) {
          updatedItems = List.from(currentCart.items);
          print('✅ [addOrderItems] Retrieved ${updatedItems.length} existing items');
        } else {
          print('📦 [addOrderItems] No existing cart, starting fresh');
          updatedItems = [];
        }
      } catch (e) {
        print('⚠️  [addOrderItems] Could not fetch current cart, starting fresh: $e');
        updatedItems = [];
      }
      
      int addedCount = 0;
      List<String> addedProductNames = [];

      for (var orderItem in orderItems) {
        try {
          final cartItem = CartItemModel(
            id: _uuid.v4(),
            productId: orderItem.productId,
            productName: orderItem.productName,
            productImage: orderItem.productImage,
            price: orderItem.price,
            quantity: orderItem.quantity,
            userId: userId,
            addedAt: DateTime.now(),
            variant: orderItem.variant, // ✅ PRESERVE VARIANT
            originalPrice: orderItem.originalPrice,
            discountPercentage: orderItem.discountPercentage,
          );

          print('📦 [addOrderItems] Processing: ${cartItem.productName} (variant: ${cartItem.variant}, Qty: ${cartItem.quantity})');

          // ✅ UPDATED: Check both productId AND variant
          final existingIndex = updatedItems.indexWhere(
            (item) => item.productId == cartItem.productId && item.variant == cartItem.variant,
          );

          if (existingIndex != -1) {
            final oldQty = updatedItems[existingIndex].quantity;
            updatedItems[existingIndex] = updatedItems[existingIndex].copyWith(
              quantity: oldQty + cartItem.quantity,
            );
            print('✅ [addOrderItems] Updated existing item: +${cartItem.quantity} qty (was $oldQty)');
          } else {
            updatedItems.add(cartItem);
            print('✅ [addOrderItems] Added new item to cart');
          }

          addedCount++;
          addedProductNames.add(cartItem.productName);
        } catch (itemError) {
          print('❌ [addOrderItems] Error processing item: $itemError');
          continue;
        }
      }

      print('📦 [addOrderItems] Processed $addedCount items successfully');
      print('📦 [addOrderItems] Final cart size: ${updatedItems.length} items');

      if (addedCount == 0) {
        _error = 'No valid items to add';
        _isLoading = false;
        notifyListeners();
        print('❌ [addOrderItems] Error: No valid items were processed');
        return false;
      }

      final updatedCart = CartModel(
        id: userId,
        userId: userId,
        items: updatedItems,
        updatedAt: DateTime.now(),
      );

      print('📦 [addOrderItems] Saving to database...');
      await _databaseService.updateCart(userId, updatedCart);
      
      print('✅ [addOrderItems] Successfully saved ${addedProductNames.length} items: $addedProductNames');

      _cart = updatedCart;
      _isLoading = false;
      _error = null;
      notifyListeners();
      
      return true;
    } catch (e) {
      print('❌ [addOrderItems] FATAL ERROR: $e');
      _error = 'Error adding items: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ✅ UPDATED: addToCart now supports variant with prices
  Future<void> addToCart(
    ProductModel product, {
    int quantity = 1,
    String? variant,
    double? variantPrice,
    double? variantOriginalPrice,
  }) async {
    await addItem(
      product,
      quantity: quantity,
      variant: variant,
      variantPrice: variantPrice,
      variantOriginalPrice: variantOriginalPrice,
    );
  }

  // ✅ UPDATED: removeItem now supports variant - NO LOADING STATE for instant update
  Future<bool> removeItem(String productId, {String? variant}) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) return false;

      // ✅ Immediate local update (no shimmer)
      List<CartItemModel> updatedItems = List.from(_cart?.items ?? []);
      
      // ✅ UPDATED: Remove based on productId AND variant
      if (variant != null && variant.isNotEmpty) {
        updatedItems.removeWhere(
          (item) => item.productId == productId && item.variant == variant,
        );
      } else {
        updatedItems.removeWhere(
          (item) => item.productId == productId && (item.variant == null || item.variant!.isEmpty),
        );
      }

      final updatedCart = CartModel(
        id: userId,
        userId: userId,
        items: updatedItems,
        updatedAt: DateTime.now(),
      );

      // ✅ Update local state immediately
      _cart = updatedCart;
      _error = null;
      notifyListeners();

      // ✅ Sync with database in background
      await _databaseService.updateCart(userId, updatedCart);

      return true;
    } catch (e) {
      print('❌ removeItem error: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ✅ UPDATED: updateQuantity now supports variant - NO LOADING STATE for instant update
  Future<bool> updateQuantity(String productId, int quantity, {String? variant}) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) return false;

      if (quantity <= 0) {
        return await removeItem(productId, variant: variant);
      }

      // ✅ Immediate local update (no shimmer)
      List<CartItemModel> updatedItems = List.from(_cart?.items ?? []);
      
      // ✅ UPDATED: Find item by productId AND variant
      int index = -1;
      if (variant != null && variant.isNotEmpty) {
        index = updatedItems.indexWhere(
          (item) => item.productId == productId && item.variant == variant,
        );
      } else {
        index = updatedItems.indexWhere(
          (item) => item.productId == productId && (item.variant == null || item.variant!.isEmpty),
        );
      }

      if (index != -1) {
        updatedItems[index] = updatedItems[index].copyWith(quantity: quantity);
      }

      final updatedCart = CartModel(
        id: userId,
        userId: userId,
        items: updatedItems,
        updatedAt: DateTime.now(),
      );

      // ✅ Update local state immediately
      _cart = updatedCart;
      _error = null;
      notifyListeners();

      // ✅ Sync with database in background
      await _databaseService.updateCart(userId, updatedCart);

      return true;
    } catch (e) {
      print('❌ updateQuantity error: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ✅ UPDATED: incrementQuantity now supports variant
  Future<bool> incrementQuantity(String productId, {String? variant}) async {
    final currentQuantity = getItemQuantity(productId, variant: variant);
    return await updateQuantity(productId, currentQuantity + 1, variant: variant);
  }

  // ✅ UPDATED: decrementQuantity now supports variant
  Future<bool> decrementQuantity(String productId, {String? variant}) async {
    final currentQuantity = getItemQuantity(productId, variant: variant);
    if (currentQuantity <= 1) {
      return await removeItem(productId, variant: variant);
    }
    return await updateQuantity(productId, currentQuantity - 1, variant: variant);
  }

  Future<bool> clearCart() async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) return false;

      _isLoading = true;
      notifyListeners();

      await _databaseService.clearCart(userId);

      _cart = null;
      _isLoading = false;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      print('❌ clearCart error: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  double calculateTotal({
    double discount = 0.0,
    double deliveryCharge = 0.0,
    double tax = 0.0,
  }) {
    return subtotal - discount + deliveryCharge + tax;
  }

  double getTotalSavings() {
    double savings = 0.0;
    for (final item in items) {
      if (item.originalPrice != null && item.originalPrice! > item.price) {
        savings += (item.originalPrice! - item.price) * item.quantity;
      }
    }
    return savings;
  }

  // ✅ UPDATED: isInCart now checks variant
  bool isInCart(String productId, {String? variant}) {
    if (variant != null && variant.isNotEmpty) {
      return _cart?.items.any(
        (item) => item.productId == productId && item.variant == variant,
      ) ?? false;
    }
    return _cart?.items.any(
      (item) => item.productId == productId && (item.variant == null || item.variant!.isEmpty),
    ) ?? false;
  }

  // ✅ UPDATED: getItemQuantity now checks variant
  int getItemQuantity(String productId, {String? variant}) {
    try {
      CartItemModel? item;
      if (variant != null && variant.isNotEmpty) {
        item = _cart?.items.firstWhere(
          (item) => item.productId == productId && item.variant == variant,
        );
      } else {
        item = _cart?.items.firstWhere(
          (item) => item.productId == productId && (item.variant == null || item.variant!.isEmpty),
        );
      }
      return item?.quantity ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // ✅ UPDATED: getCartItem now checks variant
  CartItemModel? getCartItem(String productId, {String? variant}) {
    try {
      if (variant != null && variant.isNotEmpty) {
        return _cart?.items.firstWhere(
          (item) => item.productId == productId && item.variant == variant,
        );
      }
      return _cart?.items.firstWhere(
        (item) => item.productId == productId && (item.variant == null || item.variant!.isEmpty),
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> refreshCart() async {
    loadCart();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
