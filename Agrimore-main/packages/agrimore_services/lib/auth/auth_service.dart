import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:agrimore_core/agrimore_core.dart';
import '../local/shared_preferences_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  factory AuthService() => _instance;
  AuthService._internal();

  // ✅ Initialize with persistent authentication
  Future<void> initializePersistence() async {
    try {
      if (kIsWeb) {
        await _auth.setPersistence(Persistence.LOCAL);
        print('✅ Firebase Auth persistence set to LOCAL for web');
      } else {
        print('✅ Using default LOCAL persistence for native platforms');
      }
    } catch (e) {
      print('⚠️ Could not set persistence: $e');
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
      print('🔥 Starting registration for: $email');

      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final User? user = result.user;
      if (user == null) throw AuthException('Registration failed');

      print('✅ Firebase Auth user created: ${user.uid}');

      final userModel = UserModel(
        uid: user.uid,
        email: email.trim().toLowerCase(),
        name: name.trim(),
        phone: phone?.trim(),
        role: 'user',
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );

      print('🔥 Attempting to save user to Firestore...');

      try {
        await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
        print('✅ User saved to Firestore successfully!');
      } catch (firestoreError) {
        print('❌ Firestore error: $firestoreError');
        throw AuthException(
            'Failed to save user data: ${firestoreError.toString()}');
      }

      await _savePersistentSession(userModel);

      print('✅ Registration complete!');
      return userModel;
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ General error: $e');
      throw AuthException('Registration failed: ${e.toString()}');
    }
  }

  // ✅ Sign in with email and password
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      print('🔥 Attempting login for: $email');

      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final User? user = result.user;
      if (user == null) throw AuthException('Sign in failed');

      print('✅ Firebase Auth login successful: ${user.uid}');

      try {
        await _firestore.collection('users').doc(user.uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
          'loginCount': FieldValue.increment(1),
        });
        print('✅ Last login updated');
      } catch (e) {
        print('⚠️ Could not update last login: $e');
      }

      print('🔥 Fetching user data from Firestore...');
      final userModel = await getUserData(user.uid);
      print('✅ User data fetched: ${userModel.email}');

      await _savePersistentSession(userModel);

      print('✅ Login complete!');
      return userModel;
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ Login error: $e');
      throw AuthException('Sign in failed: ${e.toString()}');
    }
  }

  // ✅ Sign in with Google
  Future<UserModel> signInWithGoogle() async {
    try {
      print('🔥 Starting Google sign in...');

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw AuthException('Google sign in cancelled');

      print('✅ Google user selected: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential result = await _auth.signInWithCredential(credential);

      final User? user = result.user;
      if (user == null) throw AuthException('Google sign in failed');

      print('✅ Firebase Auth successful: ${user.uid}');

      final userDoc =
          await _firestore.collection('users').doc(user.uid).get();

      UserModel userModel;

      if (!userDoc.exists) {
        print('📝 Creating new user document...');

        userModel = UserModel(
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
          await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
          print('✅ User document created!');
        } catch (e) {
          print('❌ Firestore error: $e');
          throw AuthException('Failed to save user data: ${e.toString()}');
        }
      } else {
        print('✅ User document exists, updating last login...');

        await _firestore.collection('users').doc(user.uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
          'loginCount': FieldValue.increment(1),
        });

        userModel = await getUserData(user.uid);
      }

      await _savePersistentSession(userModel);

      print('✅ Google sign in complete!');
      return userModel;
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ Google sign in error: $e');
      throw AuthException('Google sign in failed: ${e.toString()}');
    }
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
      print('✅ Persistent session saved');
    } catch (e) {
      print('⚠️ Could not save session: $e');
    }
  }

  // ✅ Get user data from Firestore
  Future<UserModel> getUserData(String uid) async {
    try {
      print('🔥 Getting user data for: $uid');

      final doc = await _firestore.collection('users').doc(uid).get();

      if (!doc.exists) {
        print('❌ User document does not exist!');
        throw UserNotFoundException('User not found');
      }

      print('✅ User document found');
      return UserModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      print('❌ Error getting user data: $e');
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
      print('⚠️ Error checking user: $e');
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

        print('✅ Profile updated successfully');
      }
    } catch (e) {
      print('❌ Error updating profile: $e');
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

      print('✅ Password changed successfully');
    } on FirebaseAuthException catch (e) {
      print('❌ Error changing password: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ Error changing password: $e');
      throw AuthException('Failed to change password: ${e.toString()}');
    }
  }

  // ✅ Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
      print('✅ Password reset email sent to $email');
    } on FirebaseAuthException catch (e) {
      print('❌ Error sending reset email: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ Error sending reset email: $e');
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
      print('⚠️ Error checking admin status: $e');
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
      print('⚠️ Error checking seller status: $e');
      return false;
    }
  }

  // ✅ Sign out
  Future<void> signOut() async {
    try {
      print('🔥 Signing out...');

      await _googleSignIn.signOut();
      await _auth.signOut();
      await SharedPreferencesService.clearUserSession();

      print('✅ Sign out successful');
    } catch (e) {
      print('❌ Error signing out: $e');
      throw AuthException('Sign out failed: ${e.toString()}');
    }
  }

  // ✅ Delete account
  Future<void> deleteAccount() async {
    try {
      final user = currentUser;
      if (user == null) throw UnauthorizedException();

      print('🔥 Deleting account for: ${user.uid}');

      await _firestore.collection('users').doc(user.uid).delete();
      await user.delete();
      await SharedPreferencesService.clearUserSession();

      print('✅ Account deleted successfully');
    } on FirebaseAuthException catch (e) {
      print('❌ Error deleting account: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ Error deleting account: $e');
      throw AuthException('Failed to delete account: {{e.toString()}');
    }
  }

  // ✅ Reload current user
  Future<void> reloadUser() async {
    try {
      await currentUser?.reload();
      print('✅ User reloaded successfully');
    } catch (e) {
      print('⚠️ Error reloading user: $e');
    }
  }

  // ✅ Restore session on app start
  Future<UserModel?> restoreSession() async {
    try {
      print('🔥 Restoring session...');

      if (currentUser != null) {
        print('✅ Firebase has current user: ${currentUser!.uid}');

        try {
          await currentUser!.reload();

          final userModel = await getUserData(currentUser!.uid);

          await _savePersistentSession(userModel);

          print('✅ Session restored successfully');
          return userModel;
        } catch (e) {
          print(
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

      print('⚠️ No Firebase user found - Guest mode');
      return null;
    } catch (e) {
      print('❌ Error restoring session: $e');
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
        return InvalidCredentialsException('Invalid credentials');
      case 'account-exists-with-different-credential':
        return AuthException('Account exists with different sign-in method');
      case 'network-request-failed':
        return AuthException('Network error. Check connection');
      default:
        return AuthException(e.message ?? 'Authentication failed');
    }
  }
}
