import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agrimore_services/agrimore_services.dart';

class WishlistProvider with ChangeNotifier {
  WishlistProvider({
    String? Function()? currentUserId,
    Stream<String?> Function()? authChanges,
    Stream<WishlistModel?> Function(String)? snapshots,
    Future<WishlistModel?> Function(String)? read,
    Future<void> Function(String, WishlistModel)? write,
  })  : _currentUserId = currentUserId ?? (() => AuthService().currentUserId),
        _authChanges = authChanges ??
            (() => AuthService().authStateChanges.map((u) => u?.uid)),
        _snapshots = snapshots,
        _read = read,
        _write = write;
  late final DatabaseService _databaseService = DatabaseService();
  final String? Function() _currentUserId;
  final Stream<String?> Function() _authChanges;
  final Stream<WishlistModel?> Function(String)? _snapshots;
  final Future<WishlistModel?> Function(String)? _read;
  final Future<void> Function(String, WishlistModel)? _write;
  Stream<WishlistModel?> _stream(String uid) =>
      _snapshots?.call(uid) ?? _databaseService.getUserWishlist(uid);
  Future<void> _save(String uid, WishlistModel value) =>
      _write?.call(uid, value) ?? _databaseService.updateWishlist(uid, value);
  StreamSubscription<WishlistModel?>? _wishlistSubscription;
  StreamSubscription<String?>? _authSubscription;
  WishlistModel? _wishlist;
  String? _ownerId;
  String? _error;
  int _sessionGeneration = 0, _listGeneration = 0, _operations = 0;
  bool _disposed = false, _listStarted = false;
  Future<void> _writeQueue = Future<void>.value();

  bool get _hasOwner =>
      !_disposed && _ownerId != null && _ownerId == _currentUserId();
  bool _owns(String uid, int generation) =>
      _hasOwner && _ownerId == uid && generation == _sessionGeneration;
  bool _valid(WishlistModel value, String uid) =>
      value.id == uid && value.userId == uid;
  WishlistModel _snapshot(WishlistModel value) =>
      value.copyWith(productIds: List.unmodifiable(value.productIds));
  WishlistModel? get wishlist =>
      _hasOwner && _wishlist != null ? _snapshot(_wishlist!) : null;
  bool get isLoading => _hasOwner && _operations > 0;
  String? get error =>
      !_disposed && _ownerId == _currentUserId() ? _error : null;
  int get itemCount => wishlist?.totalItems ?? 0;
  bool get isEmpty => wishlist?.isEmpty ?? true;
  List<String> get productIds => wishlist?.productIds ?? const [];

  bool _syncOwner() {
    final uid = _currentUserId();
    if (_ownerId == uid) return false;
    _ownerId = uid;
    ++_sessionGeneration;
    ++_listGeneration;
    _wishlistSubscription?.cancel();
    _wishlistSubscription = null;
    _wishlist = null;
    _error = null;
    _operations = 0;
    // A new owner need not wait for an old owner's dispatched write.
    // Already queued old work still carries the old generation and refuses.
    _writeQueue = Future<void>.value();
    return true;
  }

  bool _bindSession() {
    if (_disposed) return false;
    _authSubscription ??= _authChanges().listen((uid) {
      if (_disposed || uid != _currentUserId() || uid == _ownerId) return;
      _syncOwner();
      notifyListeners();
      if (_listStarted && uid != null) loadWishlist();
    });
    return _syncOwner();
  }

  void loadWishlist() {
    if (_disposed) return;
    _listStarted = true;
    _bindSession();
    _wishlistSubscription?.cancel();
    _wishlistSubscription = null;
    final listGeneration = ++_listGeneration;
    final uid = _ownerId;
    _error = null;
    if (uid == null) {
      _wishlist = null;
      notifyListeners();
      return;
    }
    final generation = _sessionGeneration;
    bool ownsList() =>
        _owns(uid, generation) && listGeneration == _listGeneration;
    _wishlistSubscription = _stream(uid).listen((value) {
      if (!ownsList()) return;
      if (value != null && !_valid(value, uid)) {
        _wishlist = null;
        _error = 'Could not load your wishlist.';
      } else {
        _wishlist = value == null ? null : _snapshot(value);
        _error = null;
      }
      notifyListeners();
    }, onError: (Object e) {
      if (!ownsList()) return;
      _error = 'Could not load your wishlist. Please try again.';
      notifyListeners();
    });
  }

  Future<bool> _mutate(void Function(List<String>) change,
      {bool loginMessage = false}) async {
    if (_disposed) return false;
    final ownerChanged = _bindSession();
    if (ownerChanged && _listStarted && _ownerId != null) loadWishlist();
    final uid = _ownerId;
    if (uid == null) {
      if (loginMessage) {
        _error = 'Please login to add items to wishlist';
        notifyListeners();
      }
      return false;
    }
    final generation = _sessionGeneration;
    ++_operations;
    _error = null;
    notifyListeners();
    final result = _writeQueue.then((_) async {
      try {
        if (!_owns(uid, generation)) return false;
        // Cached IDs may belong to an earlier session or predate another
        // local write. Read this owner's document before constructing it.
        final current = await (_read?.call(uid) ?? _stream(uid).first);
        if (!_owns(uid, generation)) return false;
        if (current != null && !_valid(current, uid)) {
          throw StateError('Wishlist owner mismatch.');
        }
        final ids = List<String>.of(current?.productIds ?? []);
        change(ids);
        final updated = WishlistModel(
            id: uid,
            userId: uid,
            productIds: List.unmodifiable(ids),
            updatedAt: DateTime.now());
        if (!_owns(uid, generation)) return false;
        await _save(uid, updated);
        if (!_owns(uid, generation)) return false;
        _wishlist = updated;
        return true;
      } catch (_) {
        if (_owns(uid, generation)) {
          _error = 'Could not update your wishlist. Please try again.';
        }
        return false;
      } finally {
        if (_owns(uid, generation)) {
          --_operations;
          notifyListeners();
        }
      }
    });
    _writeQueue = result.then((_) {});
    return result;
  }

  Future<bool> addItem(ProductModel product) => _mutate((ids) {
        if (!ids.contains(product.id)) ids.add(product.id);
      }, loginMessage: true);
  Future<void> addToWishlist(ProductModel product) async {
    await addItem(product);
  }

  Future<bool> removeItem(String productId) =>
      _mutate((ids) => ids.remove(productId));
  Future<void> removeFromWishlist(String productId) async {
    await removeItem(productId);
  }

  Future<bool> toggleItem(ProductModel product) => _mutate((ids) {
        if (ids.contains(product.id)) {
          ids.remove(product.id);
        } else {
          ids.add(product.id);
        }
      }, loginMessage: true);
  Future<bool> toggleItemById(String productId, ProductModel product) =>
      toggleItem(product);
  bool isInWishlist(String productId) => wishlist?.contains(productId) ?? false;
  Future<bool> clearWishlist() => _mutate((ids) => ids.clear());
  Future<void> refreshWishlist() async {
    loadWishlist();
  }

  void clearError() {
    if (_disposed) return;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_sessionGeneration;
    ++_listGeneration;
    _authSubscription?.cancel();
    _wishlistSubscription?.cancel();
    _wishlist = null;
    _error = null;
    _operations = 0;
    super.dispose();
  }
}
