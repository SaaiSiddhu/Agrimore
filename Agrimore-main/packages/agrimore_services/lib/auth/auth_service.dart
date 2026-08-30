import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:agrimore_core/agrimore_core.dart';
import '../local/shared_preferences_service.dart';

/// Result of a successful phone OTP verification — carries whether the
/// account was just created so the caller can route to onboarding.
class PhoneAuthResult {
  final UserModel user;
  final bool isNewUser;
  PhoneAuthResult({required this.user, required this.isNewUser});
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  static const String _googleWebClientId =
      '1082819024270-0rmfnpcfjbmd12mq3h4qbffp67jri89a.apps.googleusercontent.com';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Lazily create GoogleSignIn only on native platforms. Constructing it with
  // serverClientId on web crashes google_sign_in_web during app startup.
  GoogleSignIn? _googleSignIn;

  GoogleSignIn get _mobileGoogleSignIn {
    if (kIsWeb) {
      throw AuthException('GoogleSignIn plugin is native-only in this app.');
    }
    return _googleSignIn ??= GoogleSignIn(
      scopes: ['email', 'profile'],
      serverClientId: _googleWebClientId,
    );
  }

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
        final GoogleSignInAccount? googleUser =
            await _mobileGoogleSignIn.signIn();
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

  // ============================================
  // PHONE OTP LOGIN / SIGNUP
  // ============================================
  static const String _functionsBaseUrl =
      'https://us-central1-agrimore-66a4e.cloudfunctions.net';
  // Without a timeout, a stalled connection leaves the caller awaiting
  // forever — the UI would just sit on "Sending OTP" with no way out.
  static const Duration _requestTimeout = Duration(seconds: 12);

  /// Requests an OTP for [phone] (10-digit Indian number or +91-prefixed),
  /// delivered via SMS by default or, when [channel] is `'voice'`, as a
  /// voice call — server-side, a voice request for a number with a live,
  /// unexpired OTP redelivers the SAME code rather than issuing a new one
  /// (see sendPhoneOTP.ts), so requesting voice never invalidates a
  /// pending SMS.
  /// Returns whether an account already exists for this number.
  ///
  /// A 503 (no SMS provider configured) or 429 (rate limited) response is
  /// surfaced as a specific, distinguishable [AuthException] message rather
  /// than a generic failure — see PhoneOtpRateLimitException/
  /// PhoneOtpUnavailableException.
  Future<bool> sendPhoneOTP(String phone, {String channel = 'sms'}) async {
    try {
      debugPrint('🔥 Requesting phone OTP for: $phone (channel: $channel)');

      final response = await http
          .post(
            Uri.parse('$_functionsBaseUrl/sendPhoneOTP'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phone': phone, 'channel': channel}),
          )
          .timeout(_requestTimeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 503) {
        throw PhoneOtpUnavailableException(
          data['error']?.toString() ?? 'Phone login is currently unavailable',
        );
      }
      if (response.statusCode == 429) {
        throw PhoneOtpRateLimitException(
          data['error']?.toString() ?? 'Too many requests. Please try again later.',
          retryAfterMs: data['retryAfterMs'] is num ? (data['retryAfterMs'] as num).toInt() : null,
        );
      }
      if (response.statusCode != 200 || data['success'] != true) {
        throw AuthException(data['error']?.toString() ?? 'Failed to send OTP');
      }

      debugPrint('✅ Phone OTP requested successfully');
      return data['userExists'] == true;
    } on AuthException {
      rethrow;
    } on TimeoutException {
      debugPrint('❌ Timed out sending phone OTP');
      throw AuthException('Network is too slow right now. Please try again.');
    } catch (e) {
      debugPrint('❌ Error sending phone OTP: $e');
      throw AuthException('Failed to send OTP: ${e.toString()}');
    }
  }

  /// Verifies [otp] for [phone], signs the user into Firebase Auth via a
  /// custom token minted by the cloud function, and syncs the Firestore
  /// user document.
  Future<PhoneAuthResult> verifyPhoneOTP({
    required String phone,
    required String otp,
    String? name,
  }) async {
    try {
      debugPrint('🔥 Verifying phone OTP for: $phone');

      final response = await http
          .post(
            Uri.parse('$_functionsBaseUrl/verifyPhoneOTP'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'phone': phone,
              'otp': otp,
              if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
            }),
          )
          .timeout(_requestTimeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200 || data['success'] != true) {
        throw AuthException(data['error']?.toString() ?? 'Invalid OTP. Please try again.');
      }

      final token = data['token'] as String;
      final isNewUser = data['isNewUser'] == true;

      final result = await _auth.signInWithCustomToken(token).timeout(_requestTimeout);
      final user = result.user;
      if (user == null) throw AuthException('Sign in failed');

      debugPrint('✅ Firebase Auth sign-in via phone successful: ${user.uid}');

      final userModel = await getUserData(user.uid).timeout(_requestTimeout);
      await _savePersistentSession(userModel);

      debugPrint('✅ Phone login complete!');
      return PhoneAuthResult(user: userModel, isNewUser: isNewUser);
    } on AuthException {
      rethrow;
    } on TimeoutException {
      debugPrint('❌ Timed out verifying phone OTP');
      throw AuthException('Network is too slow right now. Please try again.');
    } catch (e) {
      debugPrint('❌ Error verifying phone OTP: $e');
      throw AuthException('Failed to verify OTP: ${e.toString()}');
    }
  }

  // ============================================
  // PROFILE COMPLETION (Phase 16)
  // ============================================

  /// Sends an email-verification OTP to [email] via sendEmailOTP.ts
  /// (Resend-backed). Used only during profile completion — this endpoint
  /// does not sign anyone in or touch Firebase Auth.
  Future<void> sendEmailOtpForProfile(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_functionsBaseUrl/sendEmailOTP'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(_requestTimeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 429) {
        throw PhoneOtpRateLimitException(
          data['error']?.toString() ?? 'Too many requests. Please try again later.',
          retryAfterMs: data['retryAfterMs'] is num ? (data['retryAfterMs'] as num).toInt() : null,
        );
      }
      if (response.statusCode != 200 || data['success'] != true) {
        throw AuthException(data['error']?.toString() ?? 'Failed to send verification code');
      }
    } on AuthException {
      rethrow;
    } on TimeoutException {
      throw AuthException('Network is too slow right now. Please try again.');
    } catch (e) {
      throw AuthException('Failed to send verification code: ${e.toString()}');
    }
  }

  /// Verifies [otp] for [email] via the authenticated verifyEmailForProfile
  /// callable — proves ownership without minting a second Firebase Auth
  /// identity (see that function's header comment for why it's not
  /// verifyEmailOTP.ts). Must be called while already signed in (phone
  /// OTP happens first in the real flow).
  Future<void> verifyEmailOtpForProfile({required String email, required String otp}) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('verifyEmailForProfile');
      await callable.call<Map<String, dynamic>>({'email': email, 'otp': otp});
    } on FirebaseFunctionsException catch (e) {
      throw AuthException(e.message ?? 'Invalid verification code');
    } catch (e) {
      throw AuthException('Failed to verify code: ${e.toString()}');
    }
  }

  /// Completes the caller's profile via the completeUserProfile callable —
  /// server-validated, server-authoritative. Refreshes and returns the
  /// resulting UserModel.
  Future<UserModel> completeUserProfile({
    required String name,
    required String email,
    required DateTime dateOfBirth,
    required String gender,
  }) async {
    final user = currentUser;
    if (user == null) throw UnauthorizedException();

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('completeUserProfile');
      await callable.call<Map<String, dynamic>>({
        'name': name,
        'email': email,
        'dateOfBirth': dateOfBirth.toIso8601String(),
        'gender': gender,
      });

      final updated = await getUserData(user.uid);
      await _savePersistentSession(updated);
      return updated;
    } on FirebaseFunctionsException catch (e) {
      throw AuthException(e.message ?? 'Failed to complete profile');
    } catch (e) {
      throw AuthException('Failed to complete profile: ${e.toString()}');
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
  ///
  /// Phase 14, Workstream 3 fix: this used to also OR in a hardcoded
  /// three-address list (admin@agrimore.com / admin@admin.com /
  /// agrimore@gmail.com) — of which the latter two had no live Auth account
  /// and were claimable by anyone through open signup, making this an
  /// unconditional self-service admin-promotion path shipped in every app.
  /// That list is removed; AdminAccessConfig.shouldBootstrapAdminRole and
  /// the settings/access.adminEmails allowlist remain the only legitimate
  /// promotion mechanisms.
  ///
  /// Phase 14, Workstream 2 fix: the promotion write below (`role: 'admin'`)
  /// is also removed outright — firestore.rules now locks `role` on
  /// users/{uid} to admin/Cloud-Functions-only (see
  /// ownerCannotChangePrivilegedFields()), so this write could never
  /// succeed from the client regardless of email. An allowlisted/bootstrap
  /// email that isn't already admin in Firestore can no longer be
  /// auto-promoted by this method — promotion now requires a real
  /// server-side (Admin SDK) action. The remaining demotion write is now
  /// best-effort: it will also be rejected by the same rule once the
  /// caller isn't the actual document owner acting within policy, and a
  /// PermissionDenied here must never surface as a sign-in failure (this
  /// write sits inside getUserData()'s try block, which wraps any escaping
  /// exception as a DatabaseException).
  Future<UserModel> _syncRoleWithAdminPolicy(
    UserModel user,
    String uid,
    Map<String, dynamic> raw,
  ) async {
    final allow = await _adminAllowlistEmailsLower();
    final emailLower = user.email.trim().toLowerCase();
    final bootstrap = AdminAccessConfig.shouldBootstrapAdminRole(emailLower);
    final onList = allow.contains(emailLower);
    final shouldBeAdmin = bootstrap || onList || (allow.isEmpty && user.isAdmin);

    if (shouldBeAdmin) {
      // Can no longer write role: 'admin' onto our own doc (see above) —
      // this method can only detect that a user SHOULD be admin now, not
      // grant it. A real admin must promote this account server-side.
      return user;
    }

    if (user.isAdmin && !bootstrap) {
      final sellerStatus = raw['sellerStatus']?.toString();
      final nextRole = sellerStatus == 'approved' ? 'seller' : 'user';
      debugPrint('🔻 Removing admin role for ${user.email} → $nextRole');
      try {
        await _firestore.collection('users').doc(uid).update({'role': nextRole});
        return user.copyWith(role: nextRole);
      } catch (e) {
        debugPrint(
            '⚠️ Role-sync demotion write rejected (expected under the Phase '
            '14 rules lockdown — role is admin/Cloud-Functions-only now): $e');
        return user;
      }
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
          await _mobileGoogleSignIn.signOut();
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
