import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import 'dart:io';

class UserProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();

  UserModel? _user;
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  String get userName => _user?.name ?? 'User';
  String get userEmail => _user?.email ?? '';
  String? get userPhoto => _user?.photoUrl;
  String get userInitials => _user?.initials ?? 'U';

  UserProvider() {
    _loadCurrentUser();
  }

  // Load current user
  Future<void> _loadCurrentUser() async {
    try {
      if (_authService.currentUser != null) {
        _user = await _authService.getUserData(_authService.currentUser!.uid);
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Refresh user data
  Future<void> refreshUser() async {
    try {
      if (_authService.currentUser != null) {
        _isLoading = true;
        notifyListeners();

        _user = await _authService.getUserData(_authService.currentUser!.uid);

        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update user profile
  Future<bool> updateProfile({
    String? name,
    String? phone,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _authService.updateProfile(
        name: name,
        phone: phone,
      );

      // Reload user data
      await refreshUser();

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

  // Update profile photo
  Future<bool> updateProfilePhoto(File imageFile) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Upload image to storage
      final photoUrl = await _storageService.uploadUserProfileImage(
        imageFile,
        _user!.uid,
      );

      // Update user profile with new photo URL
      await _authService.updateProfile(photoUrl: photoUrl);

      // Reload user data
      await refreshUser();

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

  // Change password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

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

  // Delete account
  Future<bool> deleteAccount() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _authService.deleteAccount();

      _user = null;
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

  // Sign out
  Future<void> signOut() async {
    try {
      await _authService.signOut();
      _user = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Set user (for auth updates)
  void setUser(UserModel? user) {
    _user = user;
    notifyListeners();
  }
}
