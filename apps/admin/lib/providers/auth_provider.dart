import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_services/agrimore_services.dart';

class AuthProvider with ChangeNotifier {
  // ============================================
  // SERVICES & FIREBASE
  // ============================================
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // ============================================
  // STATE VARIABLES
  // ============================================
  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isInitializing = true;
  String? _error;
  DateTime? _lastAuthCheck;
  bool _rememberMe = false;
  int _failedLoginAttempts = 0;
  DateTime? _lockoutUntil;

  // ============================================
  // GETTERS
  // ============================================
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isSeller => _currentUser?.isSeller ?? false;
  bool get isBuyer => _currentUser?.isBuyer ?? false;
  bool get isLocked =>
      _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);
  bool get rememberMe => _rememberMe;
  String? get userEmail => _currentUser?.email;
  String? get userName => _currentUser?.name;
  String? get userPhone => _currentUser?.phone;
  String? get userPhotoUrl => _currentUser?.photoUrl;
  String? get userUid => _currentUser?.uid;

  // ============================================
  // CONSTRUCTOR
  // ============================================
  AuthProvider() {
    _initialize();
  }

  // ============================================
  // INITIALIZE AUTH STATE
  // ============================================
  void _initialize() {
    debugPrint('🔄 AuthProvider initializing...');

    _authService.authStateChanges.listen((User? user) async {
      if (user != null) {
        try {
          debugPrint('🔐 Firebase user detected: ${user.uid}');
          _currentUser = await _authService.getUserData(user.uid);
          
          // STRICT ROLE CHECK FOR ADMIN APP
          if (_currentUser != null && _currentUser!.role != 'admin') {
            debugPrint('⛔ Unauthorized access attempt by non-admin: ${_currentUser!.email}');
            await _firebaseAuth.signOut();
            _currentUser = null;
            _error = 'Access denied. You are not an admin.';
          } else if (_currentUser != null) {
            await _updateLastLogin(user.uid);
            debugPrint('✅ User loaded: ${_currentUser?.email}');
          }
        } catch (e) {
          debugPrint('❌ Error loading user data: $e');
          _error = e.toString();
        }
      } else {
        debugPrint('👤 No Firebase user logged in');
        _currentUser = null;
      }
      
      // Mark initialization complete after first auth state change
      if (_isInitializing) {
        _isInitializing = false;
        debugPrint('✅ Auth initialization complete');
      }
      notifyListeners();
    });

    // Load stored preferences
    _loadStoredPreferences();
  }

  // ============================================
  // RESTORE SESSION ON APP START
  // ============================================
  Future<void> restoreSession() async {
    try {
      _isInitializing = true;
      notifyListeners();

      debugPrint('🔄 Restoring session...');

      final userModel = await _authService.restoreSession();

      if (userModel != null) {
        if (userModel.role != 'admin') {
          debugPrint('⛔ Restored non-admin session blocked: ${userModel.email}');
          await _firebaseAuth.signOut();
          _currentUser = null;
          _error = 'Access denied. You are not an admin.';
        } else {
          _currentUser = userModel;
          debugPrint('✅ Session restored: ${userModel.email}');
        }
      } else {
        debugPrint('⚠️ No session to restore');
        _currentUser = null;
      }

      _isInitializing = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error restoring session: $e');
      _isInitializing = false;
      notifyListeners();
    }
  }

  // ============================================
  // LOAD STORED PREFERENCES
  // ============================================
  Future<void> _loadStoredPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _rememberMe = prefs.getBool(StorageConstants.keyRememberMe) ?? false;
      debugPrint('💾 Loaded preferences: rememberMe=$_rememberMe');
    } catch (e) {
      debugPrint('⚠️ Error loading preferences: $e');
    }
  }

  // ============================================
  // CHECK IF USER EXISTS
  // ============================================
  Future<bool> checkUserExists(String email) async {
    try {
      debugPrint('🔍 Checking if user exists: $email');

      final exists = await _authService.checkUserExists(email);
      _lastAuthCheck = DateTime.now();

      debugPrint(
          '${exists ? '✅' : '❌'} User ${exists ? 'EXISTS' : 'NOT FOUND'}: $email');

      return exists;
    } catch (e) {
      debugPrint('⚠️ Error checking user: $e');
      return true;
    }
  }

  // ============================================
  // UPDATE LAST LOGIN TIMESTAMP
  // ============================================
  Future<void> _updateLastLogin(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
        'loginCount': FieldValue.increment(1),
      });
      debugPrint('✅ Updated last login for: $uid');
    } catch (e) {
      debugPrint('⚠️ Error updating last login: $e');
    }
  }

  // ============================================
  // HANDLE LOGIN ATTEMPTS (Rate Limiting)
  // ============================================
  void _incrementFailedAttempts() {
    _failedLoginAttempts++;
    if (_failedLoginAttempts >= 5) {
      _lockoutUntil = DateTime.now().add(const Duration(minutes: 15));
      debugPrint('🔒 Account locked for 15 minutes');
      _error = 'Too many failed attempts. Try again in 15 minutes.';
    }
    notifyListeners();
  }

  void _resetFailedAttempts() {
    _failedLoginAttempts = 0;
    _lockoutUntil = null;
    debugPrint('✅ Failed attempts reset');
  }

  // ============================================
  // REGISTER WITH EMAIL
  // ============================================
  Future<bool> registerWithEmail({
    required String email,
    required String password,
    required String name,
    String? phone,
  }) async {
    try {
      if (isLocked) {
        _error = 'Too many attempts. Please try again later.';
        notifyListeners();
        return false;
      }

      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('📝 Registering user: $email');

      _currentUser = await _authService.registerWithEmail(
        email: email.trim(),
        password: password,
        name: name.trim(),
        phone: phone?.trim(),
      );

      await _logAuthEvent('registration', true, email);

      if (_rememberMe) {
        await _storeCredentials(email);
      }

      debugPrint('✅ Registration successful: ${_currentUser?.uid}');

      _resetFailedAttempts();
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase Auth Registration error: ${e.code} - ${e.message}');
      _error = _getFirebaseErrorMessage(e.code);
      _incrementFailedAttempts();
      await _logAuthEvent('registration', false, email, error: e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } on AuthException catch (e) {
      debugPrint('❌ Registration error: ${e.message}');
      _error = e.message;
      _incrementFailedAttempts();
      await _logAuthEvent('registration', false, email, error: e.message);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('❌ Registration error: $e');
      _error = 'Registration failed. Please try again.';
      _incrementFailedAttempts();
      await _logAuthEvent('registration', false, email, error: e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ============================================
  // SIGN IN WITH EMAIL
  // ============================================
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      if (isLocked) {
        _error = 'Too many attempts. Please try again later.';
        notifyListeners();
        return false;
      }

      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('🔐 Signing in user: $email');

      _currentUser = await _authService.signInWithEmail(
        email: email.trim(),
        password: password,
      );

      // STRICT ROLE CHECK FOR ADMIN APP
      if (_currentUser != null && _currentUser!.role != 'admin') {
        debugPrint('⛔ Unauthorized sign in attempt by non-admin: $email');
        await _firebaseAuth.signOut();
        _currentUser = null;
        _error = 'Access denied. You are not an admin. Please use the appropriate app.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await _logAuthEvent('login', true, email);

      if (_rememberMe) {
        await _storeCredentials(email);
      }

      debugPrint('✅ Sign in successful: ${_currentUser?.uid}');

      _resetFailedAttempts();
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase Auth Sign in error: ${e.code} - ${e.message}');
      _error = _getFirebaseErrorMessage(e.code);
      _incrementFailedAttempts();
      await _logAuthEvent('login', false, email, error: e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } on AuthException catch (e) {
      debugPrint('❌ Sign in error: ${e.message}');
      _error = e.message;
      _incrementFailedAttempts();
      await _logAuthEvent('login', false, email, error: e.message);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('❌ Sign in error: $e');
      _error = 'Sign in failed. Please try again.';
      _incrementFailedAttempts();
      await _logAuthEvent('login', false, email, error: e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ============================================
  // SIGN IN WITH GOOGLE
  // ============================================
  Future<bool> signInWithGoogle() async {
    try {
      if (isLocked) {
        _error = 'Too many attempts. Please try again later.';
        notifyListeners();
        return false;
      }

      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('🔐 Signing in with Google...');

      _currentUser = await _authService.signInWithGoogle();

      // STRICT ROLE CHECK FOR ADMIN APP
      if (_currentUser != null && _currentUser!.role != 'admin') {
        debugPrint('⛔ Unauthorized Google sign in attempt by non-admin: ${_currentUser!.email}');
        await _firebaseAuth.signOut();
        _currentUser = null;
        _error = 'Access denied. You are not an admin. Please use the appropriate app.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await _logAuthEvent('google_login', true, _currentUser?.email ?? 'unknown');

      debugPrint('✅ Google sign in successful: ${_currentUser?.uid}');

      _resetFailedAttempts();
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      debugPrint('❌ Google sign in error: ${e.message}');
      _error = e.message;
      _incrementFailedAttempts();
      await _logAuthEvent('google_login', false, 'unknown', error: e.message);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('❌ Google sign in error: $e');
      if (e.toString().contains('PlatformException')) {
        _error = 'Google sign in cancelled';
      } else {
        _error = 'Google sign in failed. Please try again.';
      }
      _incrementFailedAttempts();
      await _logAuthEvent('google_login', false, 'unknown', error: e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ============================================
  // ✅ UPDATE USER PROFILE (FIXED - NEW METHOD)
  // ============================================
  Future<bool> updateUserProfile({
    String? name,
    String? phone,
    String? photoUrl,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('📝 Updating user profile...');

      if (_currentUser == null) {
        _error = 'No user logged in';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Create updated user model using copyWith
      final updatedUser = _currentUser!.copyWith(
        name: name ?? _currentUser!.name,
        phone: phone ?? _currentUser!.phone,
        photoUrl: photoUrl ?? _currentUser!.photoUrl,
      );

      // Update in Firestore
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .update(updatedUser.toMap());

      // Update local state
      _currentUser = updatedUser;
      _error = null;

      await _logAuthEvent('profile_update', true, _currentUser!.email);

      debugPrint('✅ User profile updated successfully');

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Error updating profile: $e');
      _error = 'Failed to update profile: $e';
      await _logAuthEvent('profile_update', false,
          _currentUser?.email ?? 'unknown',
          error: e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ============================================
  // UPDATE PROFILE (Original Method - Kept for compatibility)
  // ============================================
  Future<bool> updateProfile({
    String? name,
    String? phone,
    String? photoUrl,
  }) async {
    return updateUserProfile(
      name: name,
      phone: phone,
      photoUrl: photoUrl,
    );
  }

  // ============================================
  // CHANGE PASSWORD
  // ============================================
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('🔐 Changing password...');

      await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      await _logAuthEvent('password_change', true, _currentUser?.email ?? 'unknown');

      debugPrint('✅ Password changed successfully');

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase Auth Password change error: ${e.code}');
      _error = _getFirebaseErrorMessage(e.code);
      await _logAuthEvent('password_change', false,
          _currentUser?.email ?? 'unknown',
          error: e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('❌ Error changing password: $e');
      _error = 'Failed to change password. Please try again.';
      await _logAuthEvent('password_change', false,
          _currentUser?.email ?? 'unknown',
          error: e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ============================================
  // SEND PASSWORD RESET EMAIL
  // ============================================
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('📧 Sending password reset email to: $email');

      await _authService.sendPasswordResetEmail(email.trim());

      await _logAuthEvent('password_reset_request', true, email);

      debugPrint('✅ Password reset email sent successfully');

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase Auth Password reset error: ${e.code}');
      _error = _getFirebaseErrorMessage(e.code);
      await _logAuthEvent('password_reset_request', false, email, error: e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('❌ Error sending password reset email: $e');
      _error = 'Failed to send reset email. Please try again.';
      await _logAuthEvent('password_reset_request', false, email,
          error: e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ============================================
  // SIGN OUT
  // ============================================
  Future<void> signOut() async {
    try {
      debugPrint('🚪 Signing out...');

      await _authService.signOut();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(StorageConstants.keyRememberEmail);

      _currentUser = null;
      _error = null;
      _resetFailedAttempts();

      await _logAuthEvent('logout', true, 'user');

      debugPrint('✅ Sign out successful');

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error signing out: $e');
      _error = e.toString();
      notifyListeners();
    }
  }

  // ============================================
  // DELETE ACCOUNT
  // ============================================
  Future<bool> deleteAccount() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('🗑️ Deleting account...');

      final email = _currentUser?.email ?? 'unknown';

      await _authService.deleteAccount();

      _currentUser = null;
      _resetFailedAttempts();

      await _logAuthEvent('account_deletion', true, email);

      debugPrint('✅ Account deleted successfully');

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting account: $e');
      _error = 'Failed to delete account. Please try again.';
      await _logAuthEvent('account_deletion', false,
          _currentUser?.email ?? 'unknown',
          error: e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ============================================
  // STORE CREDENTIALS (Remember Me)
  // ============================================
  Future<void> _storeCredentials(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StorageConstants.keyRememberEmail, email);
      await prefs.setBool(StorageConstants.keyRememberMe, true);
      debugPrint('💾 Stored credentials for remember me: $email');
    } catch (e) {
      debugPrint('⚠️ Error storing credentials: $e');
    }
  }

  // ============================================
  // LOG AUTH EVENTS (Analytics)
  // ============================================
  Future<void> _logAuthEvent(
    String eventType,
    bool success,
    String email, {
    String? error,
  }) async {
    try {
      await _firestore.collection('auth_logs').add({
        'event': eventType,
        'success': success,
        'email': email,
        'error': error,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': 'flutter',
        'uid': _currentUser?.uid,
      });
      debugPrint('📊 Logged auth event: $eventType ($success)');
    } catch (e) {
      debugPrint('⚠️ Error logging auth event: $e');
    }
  }

  // ============================================
  // REFRESH USER DATA
  // ============================================
  Future<void> refreshUserData() async {
    try {
      if (_currentUser == null) return;

      debugPrint('🔄 Refreshing user data...');

      _currentUser = await _authService.getUserData(_currentUser!.uid);
      notifyListeners();

      debugPrint('✅ User data refreshed');
    } catch (e) {
      debugPrint('❌ Error refreshing user data: $e');
      _error = 'Failed to refresh user data';
      notifyListeners();
    }
  }

  // ============================================
  // CLEAR ERROR
  // ============================================
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ============================================
  // SET REMEMBER ME
  // ============================================
  void setRememberMe(bool value) {
    _rememberMe = value;
    notifyListeners();
  }

  // ============================================
  // HELPER: Firebase Error Messages
  // ============================================
  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return '📧 Email already registered. Please login instead.';
      case 'weak-password':
        return '🔐 Password too weak. Use 8+ chars with uppercase, lowercase, and numbers.';
      case 'user-not-found':
        return '👤 Email not registered. Please sign up.';
      case 'wrong-password':
        return '🔑 Wrong password. Please try again.';
      case 'invalid-email':
        return '✉️ Invalid email address. Please check and try again.';
      case 'too-many-requests':
        return '⏰ Too many login attempts. Try again later.';
      case 'network-request-failed':
        return '🌐 Network error. Check your internet connection.';
      case 'operation-not-allowed':
        return '❌ Operation not allowed. Please contact support.';
      case 'invalid-credential':
        return '🔓 Invalid credentials. Please try again.';
      case 'user-disabled':
        return '🚫 This account has been disabled.';
      case 'requires-recent-login':
        return '🔑 Please re-authenticate to continue.';
      default:
        return '⚠️ Authentication failed. Please try again.';
    }
  }

  // ============================================
  // DEBUG: Print User Info
  // ============================================
  void printUserInfo() {
    if (_currentUser != null) {
      debugPrint(_currentUser!.debugInfo);
    } else {
      debugPrint('❌ No user logged in');
    }
  }
}
