import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:agrimore_services/agrimore_services.dart';

class CartProvider with ChangeNotifier {
  CartProvider({DatabaseService? databaseService, AuthService? authService})
      : _databaseService = databaseService ?? DatabaseService(),
        _authService = authService ?? AuthService();

  final DatabaseService _databaseService;
  final AuthService _authService;
  final Uuid _uuid = const Uuid();

  CartModel? _cart;
  bool _isLoading = false;
  String? _error;
  bool _isListening = false;
  StreamSubscription<CartModel?>? _cartSubscription;
  StreamSubscription<dynamic>? _authSubscription;
  String? _boundOwner;
  int _sessionEpoch = 0;
  bool _hasBound = false, _disposed = false;

  bool get _currentSession =>
      !_disposed && _hasBound && _boundOwner == _authService.currentUserId;
  bool _live(String? owner, int epoch) =>
      _currentSession && _boundOwner == owner && _sessionEpoch == epoch;
  bool _ownedCart(CartModel value, String owner) =>
      value.userId == owner &&
      value.items.every((item) => item.userId == owner);
  CartModel? get _visibleCart {
    if (!_currentSession) return null;
    final value = _cart;
    final owner = _boundOwner ?? 'guest_user';
    return value != null && _ownedCart(value, owner) ? value : null;
  }

  void _invalidate() {
    _sessionEpoch++;
    final subscription = _cartSubscription;
    _cartSubscription = null;
    if (subscription != null)
      unawaited(subscription.cancel().catchError((Object _) {}));
    _isListening = false;
  }

  Future<void> _persistCart(String owner, CartModel value, int epoch) async {
    if (!_live(owner, epoch)) return;
    try {
      await _databaseService.updateCart(owner, value);
    } catch (_) {
      if (_live(owner, epoch)) {
        _error = 'Your cart could not be saved. Refresh it before checkout.';
        notifyListeners();
      }
    }
  }

  /// In-memory checkout hint from product detail (not stored on the cart document).
  String? _checkoutOrderType;
  String? _checkoutAutoFrequency;

  static const String _cartModeKey = 'cart_mode_state';

  /// Cart mode hint ('B2C' or 'B2B'). Persisted via SharedPreferencesService
  /// so that app reloads / restarts retain the B2B mode for items in the cart.
  /// Set on addItem, cleared on clearCart() or when cart becomes empty.
  String? _cartMode;
  String? get cartMode {
    if (!_currentSession) return null;
    if (_cartMode != null) return _cartMode;
    if (_cart == null || _cart!.items.isEmpty) return null;
    final saved = SharedPreferencesService.getString(_cartModeKey);
    if (saved != null && saved.isNotEmpty) {
      _cartMode = saved;
      return saved;
    }
    return null;
  }

  void _setCartMode(String? mode) {
    _cartMode = mode;
    if (mode == null) {
      SharedPreferencesService.remove(_cartModeKey);
    } else {
      SharedPreferencesService.setString(_cartModeKey, mode);
    }
  }

  String? get checkoutOrderType => _currentSession ? _checkoutOrderType : null;
  String? get checkoutAutoFrequency =>
      _currentSession ? _checkoutAutoFrequency : null;

  void setCheckoutSubscriptionIntent(String orderType, String autoFrequency) {
    if (_disposed) return;
    loadCart();
    _checkoutOrderType = orderType;
    _checkoutAutoFrequency = autoFrequency;
    notifyListeners();
  }

  void clearCheckoutSubscriptionIntent() {
    if (_disposed) return;
    _checkoutOrderType = null;
    _checkoutAutoFrequency = null;
    notifyListeners();
  }

  CartModel? get cart => _visibleCart;
  bool get isLoading => _currentSession && _isLoading;
  String? get error => _currentSession ? _error : null;

  int get itemCount => cart?.totalItems ?? 0;
  double get subtotal => cart?.subtotal ?? 0.0;
  bool get isEmpty => cart?.isEmpty ?? true;
  List<CartItemModel> get items => cart?.items ?? [];

  void loadCart() {
    if (_disposed) return;
    _authSubscription ??= _authService.authStateChanges.listen((_) {
      if (!_disposed) loadCart();
    }, onError: (_) {
      if (_currentSession) {
        _error = 'Your session needs attention. Sign in again to continue.';
        notifyListeners();
      }
    });
    final owner = _authService.currentUserId;
    if (!_hasBound || _boundOwner != owner) {
      final changingOwner = _hasBound && _boundOwner != owner;
      _invalidate();
      _hasBound = true;
      _boundOwner = owner;
      _cart = null;
      _isLoading = false;
      _error = null;
      _checkoutOrderType = null;
      _checkoutAutoFrequency = null;
      if (changingOwner) {
        _setCartMode(null);
      } else {
        _cartMode = null;
      }
    }
    if (owner == null) {
      _cart ??= CartModel(
          id: 'guest_cart',
          userId: 'guest_user',
          items: [],
          updatedAt: DateTime.now());
      notifyListeners();
      return;
    }
    if (_isListening) return;
    final epoch = _sessionEpoch;
    _isListening = true;
    try {
      _cartSubscription = _databaseService.getUserCart(owner).listen((value) {
        if (!_live(owner, epoch)) return;
        if (value != null && !_ownedCart(value, owner)) {
          _cart = null;
          _error = 'Your cart needs attention. Refresh it before checkout.';
          notifyListeners();
          return;
        }
        _cart = value ??
            CartModel(
                id: owner, userId: owner, items: [], updatedAt: DateTime.now());
        if (_cart!.items.isEmpty) {
          _setCartMode(null);
        } else {
          _cartMode ??= SharedPreferencesService.getString(_cartModeKey);
        }
        _error = null;
        notifyListeners();
      }, onError: (_) {
        if (!_live(owner, epoch)) return;
        _invalidate();
        _error = 'Your cart could not be loaded. Please refresh it.';
        notifyListeners();
      }, onDone: () {
        if (_live(owner, epoch)) _invalidate();
      });
    } catch (_) {
      if (_live(owner, epoch)) {
        _invalidate();
        _error = 'Your cart could not be loaded. Please refresh it.';
        notifyListeners();
      }
    }
  }

  // ✅ UPDATED: Now accepts variant price parameters
  Future<bool> addItem(
    ProductModel product, {
    int quantity = 1,
    String? variant,
    double? variantPrice, // ✅ NEW: Variant-specific price
    double? variantOriginalPrice, // ✅ NEW: Variant-specific original price
    bool isB2BMode = false,
  }) async {
    if (_disposed) return false;
    loadCart();
    final operationOwner = _authService.currentUserId;
    final epoch = _sessionEpoch;
    try {
      final userId = operationOwner;
      final effectiveUserId = userId ?? 'guest_user';

      int effectiveQuantity = quantity;
      double effectivePrice;
      double? effectiveOriginalPrice;

      if (isB2BMode) {
        if (!product.isB2BEnabled || product.b2bPrice == null) {
          _error = 'This product is not available for B2B ordering';
          notifyListeners();
          return false;
        }
        effectivePrice = product.b2bPrice!;
        effectiveOriginalPrice = null;
        final moq = product.b2bMoq ?? 1;
        if (effectiveQuantity < moq) effectiveQuantity = moq;
      } else {
        // ✅ Use variant price if provided, otherwise fall back to base product price
        effectivePrice = variantPrice ?? product.salePrice;
        effectiveOriginalPrice = variantOriginalPrice ?? product.originalPrice;
      }

      // Extract variant image if variant name is provided
      String effectiveImage = product.primaryImage;
      if (variant != null && variant.isNotEmpty) {
        final matchedVariant =
            product.variants.where((v) => v.name == variant).firstOrNull;
        if (matchedVariant != null && matchedVariant.images.isNotEmpty) {
          effectiveImage = matchedVariant.images.first;
        }
      }

      debugPrint(
          '🛒 Adding to cart: ${product.name}, variant: $variant, price: $effectivePrice, qty: $effectiveQuantity');

      final cartItem = CartItemModel(
        id: _uuid.v4(),
        productId: product.id,
        productName: product.name,
        productImage: effectiveImage,
        price: effectivePrice,
        quantity: effectiveQuantity,
        userId: effectiveUserId,
        sellerId: product.sellerId,
        addedAt: DateTime.now(),
        variant: variant,
        originalPrice: effectiveOriginalPrice,
        discountPercentage: effectiveOriginalPrice != null &&
                effectiveOriginalPrice > effectivePrice
            ? ((effectiveOriginalPrice - effectivePrice) /
                effectiveOriginalPrice *
                100)
            : 0.0,
      );

      List<CartItemModel> updatedItems =
          List<CartItemModel>.from(cart?.items ?? []);

      // ✅ UPDATED: Check both productId AND variant
      final existingIndex = updatedItems.indexWhere(
        (item) => item.productId == product.id && item.variant == variant,
      );

      if (existingIndex != -1) {
        // Same product with same variant - increase quantity
        updatedItems[existingIndex] = updatedItems[existingIndex].copyWith(
          quantity: updatedItems[existingIndex].quantity + effectiveQuantity,
        );
        debugPrint(
            '✅ Updated existing item quantity: ${updatedItems[existingIndex].quantity}');
      } else {
        // New product or different variant - add as new item
        updatedItems.add(cartItem);
        debugPrint('✅ Added new item to cart');
      }

      _setCartMode(isB2BMode ? 'B2B' : 'B2C');

      final updatedCart = CartModel(
        id: effectiveUserId,
        userId: effectiveUserId,
        items: updatedItems,
        updatedAt: DateTime.now(),
      );

      // Instant 0ms local state update
      _cart = updatedCart;
      _isLoading = false;
      _error = null;
      notifyListeners();

      if (!_live(operationOwner, epoch)) return false;
      // Sync with database non-blockingly if authenticated
      if (userId != null) {
        unawaited(_persistCart(userId, updatedCart, epoch));
      }

      return true;
    } catch (e) {
      if (!_live(operationOwner, epoch)) return false;
      debugPrint('❌ addItem error: $e');
      _error = 'Your cart could not be saved. Please refresh it.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ✅ UPDATED: addOrderItems now supports variants
  Future<bool> addOrderItems(List<CartItemModel> orderItems) async {
    orderItems = List<CartItemModel>.unmodifiable(orderItems);
    if (_disposed) return false;
    loadCart();
    final operationOwner = _authService.currentUserId;
    final epoch = _sessionEpoch;
    try {
      final userId = operationOwner;
      print(
          '📦 [addOrderItems] Starting - userId: $userId, items: ${orderItems.length}');

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
        if (!_live(userId, epoch)) return false;
        if (currentCart != null && !_ownedCart(currentCart, userId)) {
          throw StateError('Cart owner does not match.');
        }
        if (currentCart != null) {
          updatedItems = List.from(currentCart.items);
          print(
              '✅ [addOrderItems] Retrieved ${updatedItems.length} existing items');
        } else {
          print('📦 [addOrderItems] No existing cart, starting fresh');
          updatedItems = [];
        }
      } catch (_) {
        if (!_live(userId, epoch)) return false;
        _error =
            'Your cart could not be loaded. Refresh it before adding items.';
        _isLoading = false;
        notifyListeners();
        return false;
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
            sellerId: orderItem.sellerId,
            addedAt: DateTime.now(),
            variant: orderItem.variant, // ✅ PRESERVE VARIANT
            originalPrice: orderItem.originalPrice,
            discountPercentage: orderItem.discountPercentage,
          );

          print(
              '📦 [addOrderItems] Processing: ${cartItem.productName} (variant: ${cartItem.variant}, Qty: ${cartItem.quantity})');

          // ✅ UPDATED: Check both productId AND variant
          final existingIndex = updatedItems.indexWhere(
            (item) =>
                item.productId == cartItem.productId &&
                item.variant == cartItem.variant,
          );

          if (existingIndex != -1) {
            final oldQty = updatedItems[existingIndex].quantity;
            updatedItems[existingIndex] = updatedItems[existingIndex].copyWith(
              quantity: oldQty + cartItem.quantity,
            );
            print(
                '✅ [addOrderItems] Updated existing item: +${cartItem.quantity} qty (was $oldQty)');
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

      if (!_live(userId, epoch)) return false;
      print('📦 [addOrderItems] Saving to database...');
      await _databaseService.updateCart(userId, updatedCart);
      if (!_live(userId, epoch)) return false;

      print(
          '✅ [addOrderItems] Successfully saved ${addedProductNames.length} items: $addedProductNames');

      _cart = updatedCart;
      _isLoading = false;
      _error = null;
      notifyListeners();

      return true;
    } catch (e) {
      if (!_live(operationOwner, epoch)) return false;
      print('❌ [addOrderItems] FATAL ERROR: $e');
      _error = 'Your cart could not be saved. Please refresh it.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ✅ UPDATED: addToCart now supports variant with prices and B2B mode
  Future<void> addToCart(
    ProductModel product, {
    int quantity = 1,
    String? variant,
    double? variantPrice,
    double? variantOriginalPrice,
    bool isB2BMode = false,
  }) async {
    await addItem(
      product,
      quantity: quantity,
      variant: variant,
      variantPrice: variantPrice,
      variantOriginalPrice: variantOriginalPrice,
      isB2BMode: isB2BMode,
    );
  }

  // ✅ UPDATED: removeItem now supports variant - NO LOADING STATE for instant update
  Future<bool> removeItem(String productId, {String? variant}) async {
    if (_disposed) return false;
    loadCart();
    final operationOwner = _authService.currentUserId;
    final epoch = _sessionEpoch;
    try {
      final userId = operationOwner;
      final effectiveUserId = userId ?? 'guest_user';

      // ✅ Immediate local update (no shimmer)
      List<CartItemModel> updatedItems = List.from(cart?.items ?? []);

      // ✅ UPDATED: Remove based on productId AND variant
      if (variant != null && variant.isNotEmpty) {
        updatedItems.removeWhere(
          (item) => item.productId == productId && item.variant == variant,
        );
      } else {
        updatedItems.removeWhere(
          (item) =>
              item.productId == productId &&
              (item.variant == null || item.variant!.isEmpty),
        );
      }

      final updatedCart = CartModel(
        id: effectiveUserId,
        userId: effectiveUserId,
        items: updatedItems,
        updatedAt: DateTime.now(),
      );

      if (updatedItems.isEmpty) {
        _setCartMode(null);
      }

      // ✅ Update local state immediately
      _cart = updatedCart;
      _error = null;
      notifyListeners();

      if (!_live(operationOwner, epoch)) return false;
      // ✅ Sync with database in background
      if (userId != null) {
        unawaited(_persistCart(userId, updatedCart, epoch));
      }

      return true;
    } catch (e) {
      if (!_live(operationOwner, epoch)) return false;
      debugPrint('❌ removeItem error: $e');
      _error = 'Your cart could not be saved. Please refresh it.';
      notifyListeners();
      return false;
    }
  }

  // ✅ UPDATED: updateQuantity now supports variant - NO LOADING STATE for instant update
  Future<bool> updateQuantity(String productId, int quantity,
      {String? variant}) async {
    if (_disposed) return false;
    loadCart();
    final operationOwner = _authService.currentUserId;
    final epoch = _sessionEpoch;
    try {
      final userId = operationOwner;
      final effectiveUserId = userId ?? 'guest_user';

      if (quantity <= 0) {
        return await removeItem(productId, variant: variant);
      }

      // ✅ Immediate local update (no shimmer)
      List<CartItemModel> updatedItems = List.from(cart?.items ?? []);

      // ✅ UPDATED: Find item by productId AND variant
      int index = -1;
      if (variant != null && variant.isNotEmpty) {
        index = updatedItems.indexWhere(
          (item) => item.productId == productId && item.variant == variant,
        );
      } else {
        index = updatedItems.indexWhere(
          (item) =>
              item.productId == productId &&
              (item.variant == null || item.variant!.isEmpty),
        );
      }

      if (index != -1) {
        updatedItems[index] = updatedItems[index].copyWith(quantity: quantity);
      }

      final updatedCart = CartModel(
        id: effectiveUserId,
        userId: effectiveUserId,
        items: updatedItems,
        updatedAt: DateTime.now(),
      );

      // ✅ Update local state immediately
      _cart = updatedCart;
      _error = null;
      notifyListeners();

      if (!_live(operationOwner, epoch)) return false;
      // ✅ Sync with database in background
      if (userId != null) {
        unawaited(_persistCart(userId, updatedCart, epoch));
      }

      return true;
    } catch (e) {
      if (!_live(operationOwner, epoch)) return false;
      print('❌ updateQuantity error: $e');
      _error = 'Your cart could not be saved. Please refresh it.';
      notifyListeners();
      return false;
    }
  }

  // ✅ UPDATED: incrementQuantity now supports variant
  Future<bool> incrementQuantity(String productId, {String? variant}) async {
    final currentQuantity = getItemQuantity(productId, variant: variant);
    return await updateQuantity(productId, currentQuantity + 1,
        variant: variant);
  }

  // ✅ UPDATED: decrementQuantity now supports variant
  Future<bool> decrementQuantity(String productId, {String? variant}) async {
    final currentQuantity = getItemQuantity(productId, variant: variant);
    if (currentQuantity <= 1) {
      return await removeItem(productId, variant: variant);
    }
    return await updateQuantity(productId, currentQuantity - 1,
        variant: variant);
  }

  Future<bool> clearCart() async {
    if (_disposed) return false;
    loadCart();
    final owner = _authService.currentUserId;
    final epoch = _sessionEpoch;
    try {
      if (owner != null) await _databaseService.clearCart(owner);
      if (!_live(owner, epoch)) return false;
      _cart = null;
      _setCartMode(null);
      _isLoading = false;
      _error = null;
      notifyListeners();
      return true;
    } catch (_) {
      if (!_live(owner, epoch)) return false;
      _error = 'Your cart could not be cleared. Please try again.';
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
    final safeSubtotal = items.fold<double>(
      0.0,
      (sum, item) => sum + (item.price * item.quantity),
    );
    final safeDiscount = discount.clamp(0.0, safeSubtotal).toDouble();
    final total = safeSubtotal - safeDiscount + deliveryCharge + tax;
    return total.clamp(0.0, double.infinity).toDouble();
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
      return cart?.items.any(
            (item) => item.productId == productId && item.variant == variant,
          ) ??
          false;
    }
    return cart?.items.any(
          (item) =>
              item.productId == productId &&
              (item.variant == null || item.variant!.isEmpty),
        ) ??
        false;
  }

  // ✅ UPDATED: getItemQuantity now checks variant
  int getItemQuantity(String productId, {String? variant}) {
    try {
      CartItemModel? item;
      if (variant != null && variant.isNotEmpty) {
        item = cart?.items.firstWhere(
          (item) => item.productId == productId && item.variant == variant,
        );
      } else {
        item = cart?.items.firstWhere(
          (item) =>
              item.productId == productId &&
              (item.variant == null || item.variant!.isEmpty),
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
        return cart?.items.firstWhere(
          (item) => item.productId == productId && item.variant == variant,
        );
      }
      return cart?.items.firstWhere(
        (item) =>
            item.productId == productId &&
            (item.variant == null || item.variant!.isEmpty),
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> refreshCart() async {
    loadCart();
  }

  void reset() {
    if (_disposed) return;
    _invalidate();
    _hasBound = true;
    _boundOwner = _authService.currentUserId;
    _cart = null;
    _isListening = false;
    _isLoading = false;
    _error = null;
    _checkoutOrderType = null;
    _checkoutAutoFrequency = null;
    _setCartMode(null);
    notifyListeners();
  }

  void clearError() {
    if (_disposed) return;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _invalidate();
    final auth = _authSubscription;
    _authSubscription = null;
    if (auth != null) unawaited(auth.cancel().catchError((Object _) {}));
    super.dispose();
  }
}
