import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../services/database_service.dart';

class CategoryProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();

  List<CategoryModel> _categories = [];
  CategoryModel? _selectedCategory;
  bool _isLoading = false;
  String? _error;
  bool _disposed = false;

  List<CategoryModel> get categories => _categories;
  CategoryModel? get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get mounted => !_disposed;

  int get categoryCount => _categories.length;
  bool get hasCategories => _categories.isNotEmpty;

  // ✅ NEW - Alias method for compatibility
  Future<void> fetchCategories() async {
    return loadCategories();
  }

  // ✅ NEW - Safe notification method that prevents "setState during build" error
  void _notifySafely() {
    if (mounted) {
      Future.microtask(() {
        if (mounted) {
          notifyListeners();
        }
      });
    }
  }

  // ✅ FIXED - Safe state notification
  Future<void> loadCategories() async {
    try {
      _isLoading = true;
      _error = null;
      _notifySafely();

      _categories = await _databaseService.getAllCategories();

      _isLoading = false;
      _notifySafely();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _notifySafely();
      debugPrint('❌ Error loading categories: $e');
    }
  }

  // ✅ FIXED - Safe state notification
  Future<void> refreshCategories() async {
    await loadCategories();
  }

  // ✅ FIXED - Safe state notification
  void selectCategory(CategoryModel category) {
    _selectedCategory = category;
    _notifySafely();
  }

  // ✅ FIXED - Safe state notification
  void clearSelectedCategory() {
    _selectedCategory = null;
    _notifySafely();
  }

  // Get category by ID
  CategoryModel? getCategoryById(String categoryId) {
    try {
      return _categories.firstWhere((cat) => cat.id == categoryId);
    } catch (e) {
      return null;
    }
  }

  // ✅ NEW - Get category by name
  CategoryModel? getCategoryByName(String name) {
    try {
      return _categories.firstWhere(
        (cat) => cat.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  // ✅ NEW - Search categories
  List<CategoryModel> searchCategories(String query) {
    if (query.isEmpty) return _categories;
    
    final lowerQuery = query.toLowerCase();
    return _categories.where((category) {
      return category.name.toLowerCase().contains(lowerQuery) ||
             (category.description?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  // ✅ FIXED - Safe state notification
  void clearError() {
    _error = null;
    _notifySafely();
  }

  // ✅ FIXED - Safe state notification
  void clearAll() {
    _categories.clear();
    _selectedCategory = null;
    _error = null;
    _isLoading = false;
    _notifySafely();
  }

  @override
  void dispose() {
    _disposed = true;
    _categories.clear();
    _selectedCategory = null;
    super.dispose();
  }
}
