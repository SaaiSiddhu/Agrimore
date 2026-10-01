import 'dart:async';

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
  final AuthService _authService;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  // ============================================
  // STATE VARIABLES
  // ============================================
  StreamSubscription<User?>? _authSubscription;
  int _authListenVersion = 0;
  int _authEpoch = 0;
  int _profileRead = 0;
  String? _profileOwner;
  String? _pendingRefusal;
  bool _disposed = false;
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
  UserModel? get currentUser {
    final owner = _authService.currentUserId;
    return !_disposed &&
            owner != null &&
            owner == _profileOwner &&
            _currentUser?.uid == owner
        ? _currentUser
        : null;
  }

  bool get isLoading =>
      !_disposed && _profileOwner == _authService.currentUserId && _isLoading;
  bool get isInitializing =>
      !_disposed &&
      (_profileOwner != _authService.currentUserId
          ? _authService.currentUserId != null
          : _isInitializing);
  String? get error =>
      !_disposed && _profileOwner == _authService.currentUserId ? _error : null;
  bool get isLoggedIn => currentUser != null;
  bool get isAdmin => currentUser?.isAdmin ?? false;
  bool get isSeller => currentUser?.isSeller ?? false;
  bool get isBuyer => currentUser?.isBuyer ?? false;
  bool get isLocked =>
      _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);
  bool get rememberMe => _rememberMe;
  String? get userEmail => currentUser?.email;
  String? get userName => currentUser?.name;
  String? get userPhone => currentUser?.phone;
  String? get userPhotoUrl => currentUser?.photoUrl;
  String? get userUid => currentUser?.uid;

  // ============================================
  // CONSTRUCTOR
  // ============================================
  AuthProvider({
    AuthService? authService,
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _authService = authService ?? AuthService(),
       _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance {
    _profileOwner = _authService.currentUserId;
    _initialize();
  }

  // ============================================
  // INITIALIZE AUTH STATE
  // ============================================
  void _initialize() {
    _listenForAuth();
    unawaited(_loadStoredPreferences());
  }

  void _listenForAuth() {
    if (_disposed || _authSubscription != null) return;
    final version = ++_authListenVersion;
    try {
      final subscription = _authService.authStateChanges.listen(
        (user) {
          if (_disposed ||
              version != _authListenVersion ||
              user?.uid != _authService.currentUserId) {
            return;
          }
          _bindProfileOwner(user?.uid, renew: true);
          unawaited(_loadOwnedProfile(lastLogin: user != null));
        },
        onError: (Object error) => _stopAuthUpdates(version),
        onDone: () => _stopAuthUpdates(version),
      );
      if (_disposed || version != _authListenVersion) {
        unawaited(
          subscription.cancel().catchError((Object error) {
            debugPrint('Admin auth listener cleanup failed');
          }),
        );
      } else {
        _authSubscription = subscription;
      }
    } catch (_) {
      _stopAuthUpdates(version);
    }
  }

  void _cancelAuthSubscription() {
    final subscription = _authSubscription;
    _authSubscription = null;
    if (subscription != null) {
      unawaited(
        subscription.cancel().catchError((Object error) {
          debugPrint('Admin auth listener cleanup failed');
        }),
      );
    }
  }

  void _stopAuthUpdates(int version) {
    if (_disposed || version != _authListenVersion) return;
    ++_authListenVersion;
    _cancelAuthSubscription();
    ++_authEpoch;
    ++_profileRead;
    _profileOwner = _authService.currentUserId;
    _currentUser = null;
    _pendingRefusal = null;
    _isInitializing = false;
    _isLoading = false;
    _error = 'Account updates paused. Please refresh your account.';
    notifyListeners();
  }

  void _bindProfileOwner(String? owner, {bool renew = false}) {
    if (_disposed || (!renew && owner == _profileOwner)) return;
    final refusal = owner == null ? _pendingRefusal : null;
    _pendingRefusal = null;
    _profileOwner = owner;
    ++_authEpoch;
    ++_profileRead;
    _currentUser = null;
    _error = refusal;
    _isLoading = false;
    _isInitializing = owner != null;
  }

  bool _profileReadIsCurrent(String? owner, int epoch, int read) =>
      !_disposed &&
      owner == _profileOwner &&
      owner == _authService.currentUserId &&
      epoch == _authEpoch &&
      read == _profileRead;

  Future<void> _loadOwnedProfile({
    bool restore = false,
    bool lastLogin = false,
  }) async {
    if (_disposed) return;
    final owner = _authService.currentUserId;
    _bindProfileOwner(owner);
    final epoch = _authEpoch, read = ++_profileRead;
    if (restore) _isInitializing = owner != null;
    if (owner != null) _error = null;
    notifyListeners();
    if (!_profileReadIsCurrent(owner, epoch, read)) return;
    try {
      final user = owner == null
          ? null
          : restore
          ? await _authService.restoreSession()
          : lastLogin
          ? await _authService
                .getUserData(owner)
                .timeout(const Duration(seconds: 6))
          : await _authService.getUserData(owner);
      if (!_profileReadIsCurrent(owner, epoch, read)) return;
      if (user != null && user.uid != owner) {
        throw StateError('Admin profile ownership mismatch');
      }
      if (user != null && user.role != 'admin') {
        _currentUser = null;
        _error = 'Access denied. You are not an admin.';
        _pendingRefusal = _error;
        if (_firebaseAuth.currentUser?.uid == owner &&
            _profileReadIsCurrent(owner, epoch, read)) {
          await _firebaseAuth.signOut();
        }
        return;
      }
      _currentUser = user;
      if (lastLogin && user != null && owner != null) {
        unawaited(_updateLastLogin(owner, epoch: epoch));
      }
    } catch (_) {
      if (!_profileReadIsCurrent(owner, epoch, read)) return;
      _currentUser = null;
      _error = 'Unable to load your account. Please try again.';
    } finally {
      if (_profileReadIsCurrent(owner, epoch, read)) {
        _isInitializing = false;
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> restoreSession() async {
    if (_disposed) return;
    _listenForAuth();
    await _loadOwnedProfile(restore: true);
  }

  // ============================================
  // LOAD STORED PREFERENCES
  // ============================================
  Future<void> _loadStoredPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_disposed) return;
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
  Future<void> _updateLastLogin(String uid, {int? epoch}) async {
    if (_disposed ||
        uid != _authService.currentUserId ||
        (epoch != null && epoch != _authEpoch)) {
      return;
    }
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
    } finally {
      _isLoading = false;
      notifyListeners();
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
    if (_disposed) return;
    _listenForAuth();
    await _loadOwnedProfile();
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
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_authEpoch;
    ++_profileRead;
    ++_authListenVersion;
    _cancelAuthSubscription();
    _currentUser = null;
    super.dispose();
  }

}
