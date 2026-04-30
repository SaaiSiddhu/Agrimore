import 'package:flutter/foundation.dart';

/// Drives the Shop tab + optional category filter from anywhere (e.g. home category chips).
class ShopEntryProvider extends ChangeNotifier {
  String? _categoryId;
  String? _categoryName;
  int _shopTabRequest = 0;

  String? get categoryId => _categoryId;
  String? get categoryName => _categoryName;
  int get shopTabRequestCount => _shopTabRequest;

  /// Switch main shell to Shop (tab index 1) and optionally filter by category.
  void openShopWithCategory({String? categoryId, String? categoryName}) {
    _categoryId = categoryId;
    _categoryName = categoryName;
    _shopTabRequest++;
    notifyListeners();
  }

  void clearCategoryFilter() {
    _categoryId = null;
    _categoryName = null;
    notifyListeners();
  }
}
