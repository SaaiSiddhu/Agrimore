import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../services/database_service.dart';
import '../services/shared_preferences_service.dart';

class SearchProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();

  List<ProductModel> _searchResults = [];
  List<String> _searchHistory = [];
  String _searchQuery = '';
  bool _isSearching = false;
  String? _error;

  List<ProductModel> get searchResults => _searchResults;
  List<String> get searchHistory => _searchHistory;
  String get searchQuery => _searchQuery;
  bool get isSearching => _isSearching;
  String? get error => _error;
  
  bool get hasResults => _searchResults.isNotEmpty;
  bool get hasHistory => _searchHistory.isNotEmpty;

  SearchProvider() {
    _loadSearchHistory();
  }

  // Load search history
  void _loadSearchHistory() {
    _searchHistory = SharedPreferencesService.getSearchHistory();
    notifyListeners();
  }

  // Search products
  void searchProducts(String query) {
    if (query.isEmpty) {
      _searchResults = [];
      _searchQuery = '';
      notifyListeners();
      return;
    }

    _searchQuery = query;
    _isSearching = true;
    notifyListeners();

    _databaseService.searchProducts(query).listen(
      (products) {
        _searchResults = products;
        _isSearching = false;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        _isSearching = false;
        notifyListeners();
      },
    );

    // Add to search history
    _addToHistory(query);
  }

  // Add query to search history
  Future<void> _addToHistory(String query) async {
    await SharedPreferencesService.addSearchQuery(query);
    _searchHistory = SharedPreferencesService.getSearchHistory();
    notifyListeners();
  }

  // Clear search
  void clearSearch() {
    _searchResults = [];
    _searchQuery = '';
    _isSearching = false;
    notifyListeners();
  }

  // Clear search history
  Future<void> clearHistory() async {
    await SharedPreferencesService.clearSearchHistory();
    _searchHistory = [];
    notifyListeners();
  }

  // Remove item from history
  Future<void> removeFromHistory(String query) async {
    _searchHistory.remove(query);
    await SharedPreferencesService.setStringList(
      'search_history',
      _searchHistory,
    );
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
