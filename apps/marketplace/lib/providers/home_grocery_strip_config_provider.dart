import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads `settings/home_grocery_strip_config` so `GroceryKitchenHomeStrip`'s
/// title and category selection are admin-editable instead of a hardcoded
/// Dart string and a hardcoded name/slug substring match.
///
/// Falls back to the pre-HOME-5 hardcoded title (`categoryIds` stays empty)
/// if the document doesn't exist yet, has no categories configured, or a
/// read fails -- mirrors `LocationSettingsProvider`'s exact "never leave the
/// UI broken" fallback shape. `GroceryKitchenHomeStrip` itself decides what
/// to render when `categoryIds` is empty (its own existing hardcoded
/// name/slug match), since that fallback needs live `CategoryModel` data
/// this provider has no reason to duplicate.
class HomeGroceryStripConfigProvider with ChangeNotifier {
  static const String _fallbackTitle = 'Grocery & Kitchen';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot>? _subscription;

  bool _isLoading = false;
  bool _hasLoadedOnce = false;
  List<String> _categoryIds = [];
  String _effectiveTitle = _fallbackTitle;

  bool get isLoading => _isLoading;
  bool get hasLoadedOnce => _hasLoadedOnce;

  /// Admin-picked category ids, in the admin's own chosen order. Empty means
  /// "not configured" -- the caller should fall back to its own default
  /// selection, not treat this as "show zero categories".
  List<String> get categoryIds => _categoryIds;

  /// Always a usable, non-empty title: the admin's override, or the
  /// pre-HOME-5 hardcoded default.
  String get effectiveTitle => _effectiveTitle;

  Future<void> loadConfig({bool forceRefresh = false}) async {
    if (_hasLoadedOnce && !forceRefresh) return;
    _isLoading = true;
    if (!_hasLoadedOnce) notifyListeners();

    try {
      final doc = await _firestore
          .collection('settings')
          .doc('home_grocery_strip_config')
          .get();
      _applySnapshot(doc);
      _startRealtimeListener();
    } catch (e) {
      debugPrint('⚠️ HomeGroceryStripConfigProvider load error: $e');
      // Keep the fallback defaults already set -- never break the strip
      // because this one read failed.
    } finally {
      _isLoading = false;
      _hasLoadedOnce = true;
      notifyListeners();
    }
  }

  void _startRealtimeListener() {
    _subscription?.cancel();
    _subscription = _firestore
        .collection('settings')
        .doc('home_grocery_strip_config')
        .snapshots()
        .listen((doc) {
      _applySnapshot(doc);
      notifyListeners();
    }, onError: (e) {
      debugPrint('⚠️ HomeGroceryStripConfigProvider listener error: $e');
    });
  }

  void _applySnapshot(DocumentSnapshot doc) {
    if (!doc.exists) return;
    final data = doc.data() as Map<String, dynamic>? ?? {};

    _categoryIds = List<String>.from(data['categoryIds'] ?? const []);

    final rawTitle = data['titleOverride'];
    _effectiveTitle = (rawTitle is String && rawTitle.trim().isNotEmpty)
        ? rawTitle.trim()
        : _fallbackTitle;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
