import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:agrimore_core/agrimore_core.dart';
import '../local/shared_preferences_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  static const String _googleWebClientId =
      '1082819024270-0rmfnpcfjbmd12mq3h4qbffp67jri89a.apps.googleusercontent.com';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // GoogleSignIn is only used for native (mobile) platforms
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: _googleWebClientId,
  );

  factory AuthService() => _instance;
  AuthService._internal();

  // ✅ Initialize with persistent authentication
  Future<void> initializePersistence() async {
    try {
      if (kIsWeb) {
        await _auth.setPersistence(Persistence.LOCAL);
        debugPrint('✅ Firebase Auth persistence set to LOCAL for web');
      } else {
        debugPrint('✅ Using default LOCAL persistence for native platforms');
      }
    } catch (e) {
      debugPrint('⚠️ Could not set persistence: $e');
    }
  }

  // Getters
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;
  bool get isLoggedIn => _auth.currentUser != null;
  bool get isGuestMode => !isLoggedIn;

  // ✅ Get current user ID as method
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // ✅ Get current user as UserModel
  UserModel? getCurrentUser() {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    return UserModel(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      name: firebaseUser.displayName ?? 'Anonymous',
      phone: firebaseUser.phoneNumber,
      photoUrl: firebaseUser.photoURL,
      role: 'user',
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
    );
  }

  // ✅ Register with email and password
  Future<UserModel> registerWithEmail({
    required String email,
    required String password,
    required String name,
    String? phone,
  }) async {
    try {
      debugPrint('🔥 Starting registration for: $email');

      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final User? user = result.user;
      if (user == null) throw AuthException('Registration failed');

      debugPrint('✅ Firebase Auth user created: ${user.uid}');

      // Update display name
      await user.updateDisplayName(name.trim());

      final userModel = UserModel(
        uid: user.uid,
        email: email.trim().toLowerCase(),
        name: name.trim(),
        phone: phone?.trim(),
        role: 'user',
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );

      debugPrint('🔥 Attempting to save user to Firestore...');

      try {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(userModel.toMap());
        debugPrint('✅ User saved to Firestore successfully!');
      } catch (firestoreError) {
        debugPrint('❌ Firestore error: $firestoreError');
        throw AuthException(
            'Failed to save user data: ${firestoreError.toString()}');
      }

      final synced = await getUserData(user.uid);
      await _savePersistentSession(synced);

      debugPrint('✅ Registration complete!');
      return synced;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase Auth error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ General error: $e');
      throw AuthException('Registration failed: ${e.toString()}');
    }
  }

  // ✅ Sign in with email and password
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('🔥 Attempting login for: $email');

      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final User? user = result.user;
      if (user == null) throw AuthException('Sign in failed');

      debugPrint('✅ Firebase Auth login successful: ${user.uid}');

      try {
        await _firestore.collection('users').doc(user.uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
          'loginCount': FieldValue.increment(1),
        });
        debugPrint('✅ Last login updated');
      } catch (e) {
        debugPrint('⚠️ Could not update last login: $e');
      }

      debugPrint('🔥 Fetching user data from Firestore...');
      UserModel userModel;
      try {
        userModel = await getUserData(user.uid);
      } catch (e) {
        if (e is UserNotFoundException ||
            e.toString().contains('User not found')) {
          debugPrint('📝 User document missing, creating new one...');
          // ✅ SECURITY FIX: Never auto-assign admin role. Default to 'user'.
          // Admin promotion is handled separately via _syncRoleWithAdminPolicy.
          userModel = UserModel(
            uid: user.uid,
            email: user.email ?? email,
            name: user.displayName ?? 'User',
            role: 'user', // ✅ FIXED: Default to 'user', not 'admin'
            createdAt: DateTime.now(),
            lastLogin: DateTime.now(),
          );
          await _firestore
              .collection('users')
              .doc(user.uid)
              .set(userModel.toMap());
        } else {
          rethrow;
        }
      }
      debugPrint('✅ User data fetched: ${userModel.email}');

      await _savePersistentSession(userModel);

      debugPrint('✅ Login complete!');
      return userModel;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase Auth error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ Login error: $e');
      throw AuthException('Sign in failed: ${e.toString()}');
    }
  }

  // ============================================
  // ✅ GOOGLE SIGN-IN — FIX FOR WEB (401 invalid_client)
  // Web: Uses Firebase Auth signInWithPopup (no OAuth client ID needed)
  // Mobile: Uses google_sign_in package
  // ============================================
  Future<UserModel> signInWithGoogle() async {
    try {
      debugPrint(
          '🔥 Starting Google sign in (platform: ${kIsWeb ? "web" : "mobile"})...');

      UserCredential result;

      if (kIsWeb) {
        // ✅ WEB: Use Firebase Auth's built-in popup — no OAuth client ID required
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        googleProvider.setCustomParameters({'prompt': 'select_account'});

        result = await _auth.signInWithPopup(googleProvider);
        debugPrint('✅ Firebase Web popup sign-in successful');
      } else {
        // ✅ MOBILE: Use google_sign_in package (works with google-services.json)
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) throw AuthException('Google sign in cancelled');

        debugPrint('✅ Google user selected: ${googleUser.email}');

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
          throw AuthException(
            'Google sign in failed: missing ID token. Check Firebase SHA keys.',
          );
        }

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        result = await _auth.signInWithCredential(credential);
      }

      final User? user = result.user;
      if (user == null) throw AuthException('Google sign in failed');

      debugPrint('✅ Firebase Auth successful: ${user.uid}');

      // Check if user document exists in Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        debugPrint('📝 Creating new user document...');

        final userModel = UserModel(
          uid: user.uid,
          email: user.email!,
          name: user.displayName ?? 'User',
          phone: user.phoneNumber,
          photoUrl: user.photoURL,
          role: 'user',
          createdAt: DateTime.now(),
          lastLogin: DateTime.now(),
        );

        try {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .set(userModel.toMap());
          debugPrint('✅ User document created!');
        } catch (e) {
          debugPrint('❌ Firestore error: $e');
          throw AuthException('Failed to save user data: ${e.toString()}');
        }
      } else {
        debugPrint('✅ User document exists, updating last login...');

        await _firestore.collection('users').doc(user.uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
          'loginCount': FieldValue.increment(1),
        });
      }

      final synced = await getUserData(user.uid);
      await _savePersistentSession(synced);

      debugPrint('✅ Google sign in complete!');
      return synced;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase Auth error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ Google sign in error: $e');
      throw AuthException('Google sign in failed: ${e.toString()}');
    }
  }

  /// Firestore `settings/access` field `adminEmails` (list of strings), lowercased.
  Future<Set<String>> _adminAllowlistEmailsLower() async {
    try {
      final snap = await _firestore.collection('settings').doc('access').get();
      final raw = snap.data()?['adminEmails'];
      if (raw is List) {
        return raw
            .map((e) => e.toString().trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toSet();
      }
    } catch (e) {
      debugPrint('⚠️ Admin allowlist read failed: $e');
    }
    return {};
  }

  /// Admin if: bootstrap define, or on Firestore allowlist, or allowlist empty and user already admin.
  /// If allowlist is non-empty and email is not listed (and not bootstrap), strip `admin` role.
  Future<UserModel> _syncRoleWithAdminPolicy(
    UserModel user,
    String uid,
    Map<String, dynamic> raw,
  ) async {
    final allow = await _adminAllowlistEmailsLower();
    final emailLower = user.email.trim().toLowerCase();
    final bootstrap = AdminAccessConfig.shouldBootstrapAdminRole(emailLower);
    final onList = allow.contains(emailLower);
    final shouldBeAdmin = bootstrap ||
        onList ||
        (allow.isEmpty && user.isAdmin) ||
        ['admin@agrimore.com', 'admin@admin.com', 'agrimore@gmail.com']
            .contains(emailLower);

    if (shouldBeAdmin) {
      if (!user.isAdmin) {
        debugPrint('👑 Promoting to admin: ${user.email}');
        await _firestore.collection('users').doc(uid).update({'role': 'admin'});
        return user.copyWith(role: 'admin');
      }
      return user;
    }

    if (user.isAdmin && !bootstrap) {
      final sellerStatus = raw['sellerStatus']?.toString();
      final nextRole = sellerStatus == 'approved' ? 'seller' : 'user';
      debugPrint('🔻 Removing admin role for ${user.email} → $nextRole');
      await _firestore.collection('users').doc(uid).update({'role': nextRole});
      return user.copyWith(role: nextRole);
    }

    return user;
  }

  // ✅ Save persistent session
  Future<void> _savePersistentSession(UserModel userModel) async {
    try {
      await SharedPreferencesService.saveUserSession(
        userId: userModel.uid,
        email: userModel.email,
        name: userModel.name,
        role: userModel.role,
      );
      debugPrint('✅ Persistent session saved');
    } catch (e) {
      debugPrint('⚠️ Could not save session: $e');
    }
  }

  // ✅ Get user data from Firestore
  Future<UserModel> getUserData(String uid) async {
    try {
      debugPrint('🔥 Getting user data for: $uid');

      final doc = await _firestore.collection('users').doc(uid).get();

      if (!doc.exists) {
        debugPrint('❌ User document does not exist!');
        throw UserNotFoundException('User not found');
      }

      debugPrint('✅ User document found');
      final raw = doc.data()!;
      UserModel user = UserModel.fromMap(raw, doc.id);
      user = await _syncRoleWithAdminPolicy(user, uid, raw);

      return user;
    } catch (e) {
      debugPrint('❌ Error getting user data: $e');
      throw DatabaseException('Failed to get user: ${e.toString()}');
    }
  }

  // ✅ Check if user exists
  Future<bool> checkUserExists(String email) async {
    try {
      final result = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();
      return result.docs.isNotEmpty;
    } catch (e) {
      debugPrint('⚠️ Error checking user: $e');
      return true;
    }
  }

  // ✅ Update user profile
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? photoUrl,
  }) async {
    try {
      final user = currentUser;
      if (user == null) throw UnauthorizedException();

      final Map<String, dynamic> updates = {};

      if (name != null) updates['name'] = name;
      if (phone != null) updates['phone'] = phone;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(user.uid).update(updates);

        final userData = await getUserData(user.uid);
        await _savePersistentSession(userData);

        debugPrint('✅ Profile updated successfully');
      }
    } catch (e) {
      debugPrint('❌ Error updating profile: $e');
      throw AuthException('Failed to update profile: ${e.toString()}');
    }
  }

  // ✅ Change password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = currentUser;
      if (user == null || user.email == null) throw UnauthorizedException();

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      debugPrint('✅ Password changed successfully');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Error changing password: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ Error changing password: $e');
      throw AuthException('Failed to change password: ${e.toString()}');
    }
  }

  // ✅ Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
      debugPrint('✅ Password reset email sent to $email');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Error sending reset email: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ Error sending reset email: $e');
      throw AuthException('Failed to send reset email: ${e.toString()}');
    }
  }

  // ✅ Check if user is admin
  Future<bool> isAdmin() async {
    try {
      if (currentUser == null) return false;
      final userModel = await getUserData(currentUser!.uid);
      return userModel.isAdmin;
    } catch (e) {
      debugPrint('⚠️ Error checking admin status: $e');
      return false;
    }
  }

  // ✅ Check if user is seller
  Future<bool> isSeller() async {
    try {
      if (currentUser == null) return false;
      final userModel = await getUserData(currentUser!.uid);
      return userModel.isSeller;
    } catch (e) {
      debugPrint('⚠️ Error checking seller status: $e');
      return false;
    }
  }

  // ✅ Sign out
  Future<void> signOut() async {
    try {
      debugPrint('🔥 Signing out...');

      if (!kIsWeb) {
        // Only call google_sign_in signOut on native platforms
        try {
          await _googleSignIn.signOut();
        } catch (_) {}
      }
      await _auth.signOut();
      await SharedPreferencesService.clearUserSession();

      debugPrint('✅ Sign out successful');
    } catch (e) {
      debugPrint('❌ Error signing out: $e');
      throw AuthException('Sign out failed: ${e.toString()}');
    }
  }

  // ✅ Delete account
  Future<void> deleteAccount() async {
    try {
      final user = currentUser;
      if (user == null) throw UnauthorizedException();

      debugPrint('🔥 Deleting account for: ${user.uid}');

      await _firestore.collection('users').doc(user.uid).delete();
      await user.delete();
      await SharedPreferencesService.clearUserSession();

      debugPrint('✅ Account deleted successfully');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Error deleting account: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ Error deleting account: $e');
      throw AuthException('Failed to delete account: ${e.toString()}');
    }
  }

  // ✅ Reload current user
  Future<void> reloadUser() async {
    try {
      await currentUser?.reload();
      debugPrint('✅ User reloaded successfully');
    } catch (e) {
      debugPrint('⚠️ Error reloading user: $e');
    }
  }

  // ✅ Restore session on app start
  Future<UserModel?> restoreSession() async {
    try {
      debugPrint('🔥 Restoring session...');

      if (currentUser != null) {
        debugPrint('✅ Firebase has current user: ${currentUser!.uid}');

        try {
          await currentUser!.reload();

          final userModel = await getUserData(currentUser!.uid);

          await _savePersistentSession(userModel);

          debugPrint('✅ Session restored successfully');
          return userModel;
        } catch (e) {
          debugPrint(
              '⚠️ Could not fetch user data, but user is authenticated: $e');
          return UserModel(
            uid: currentUser!.uid,
            email: currentUser!.email ?? '',
            name: currentUser!.displayName ?? 'User',
            role: 'user',
            createdAt: DateTime.now(),
            lastLogin: DateTime.now(),
          );
        }
      }

      debugPrint('⚠️ No Firebase user found - Guest mode');
      return null;
    } catch (e) {
      debugPrint('❌ Error restoring session: $e');
      return null;
    }
  }

  // ✅ Require login for protected actions
  void requireAuth(String action) {
    if (!isLoggedIn) {
      throw UnauthorizedException('Please login to $action');
    }
  }

  // ✅ Handle Firebase Auth exceptions
  AuthException _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return WeakPasswordException(
            'Password is too weak (min 8 chars, uppercase, lowercase, number)');
      case 'email-already-in-use':
        return EmailAlreadyExistsException('Email already registered');
      case 'user-not-found':
        return UserNotFoundException('User not found');
      case 'wrong-password':
        return InvalidCredentialsException('Incorrect password');
      case 'invalid-email':
        return AuthException('Invalid email address');
      case 'user-disabled':
        return AuthException('Account disabled by administrator');
      case 'too-many-requests':
        return AuthException('Too many attempts. Try again later');
      case 'operation-not-allowed':
        return AuthException('Operation not allowed');
      case 'requires-recent-login':
        return AuthException('Please re-authenticate to continue');
      case 'invalid-credential':
        return InvalidCredentialsException(
            'Invalid login or password. (Note: If you signed up with Google previously, please use "Continue with Google")');
      case 'account-exists-with-different-credential':
        return AuthException(
            'Account exists with different sign-in method. Try Google Sign-In.');
      case 'popup-closed-by-user':
        return AuthException('Sign-in popup was closed. Please try again.');
      case 'cancelled-popup-request':
        return AuthException('Sign-in cancelled. Please try again.');
      case 'popup-blocked':
        return AuthException(
            'Pop-up blocked by browser. Please allow pop-ups for this site.');
      case 'network-request-failed':
        return AuthException('Network error. Check connection');
      default:
        return AuthException(e.message ?? 'Authentication failed');
    }
  }
}
