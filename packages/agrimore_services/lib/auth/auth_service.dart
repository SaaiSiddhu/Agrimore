import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
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

/// Result of a successful phone OTP *send* request — carries whether an
/// account already exists AND which channel actually delivered the code.
/// Phase 22: the server may deliver by voice even when SMS was requested
/// (see sendPhoneOTP.ts's channel resolution, gated on
/// PHONE_OTP_SMS_ENABLED) — [channel] is always the EFFECTIVE channel used,
/// straight from the response, never just an echo of what was requested.
class PhoneOtpSendResult {
  final bool userExists;
  final String channel; // 'sms' or 'voice'
  /// Set only when the server's phone-OTP test mode is active for this
  /// number (sendPhoneOTP.ts, Phase SEC-P0); null for every real delivery.
  final String? testOtp;
  PhoneOtpSendResult({
    required this.userExists,
    required this.channel,
    this.testOtp,
  });
}

/// AUTH-3: a Google credential acquired but not yet used to sign in —
/// held only in memory (never persisted to SharedPreferences, Hive,
/// Firestore, secure storage, logs, or analytics) while the caller decides
/// between the linked-returning path and the first-time-phone-verification
/// path. Cleared by the caller on success, failure, cancellation, or the
/// user backing out of the flow entirely.
class PendingGoogleIdentity {
  final AuthCredential credential;
  final String idToken;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final DateTime createdAt;
  PendingGoogleIdentity({
    required this.credential,
    required this.idToken,
    this.email,
    this.displayName,
    this.photoUrl,
  }) : createdAt = DateTime.now();
}

/// Result of asking resolveGoogleIdentity.ts whether a Google identity is
/// already linked to an existing AgriMore Firebase user.
class GoogleIdentityResolution {
  final bool linked;
  final String? expectedUid;
  GoogleIdentityResolution({required this.linked, this.expectedUid});
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
        }).timeout(const Duration(seconds: 4));
        debugPrint('✅ Last login updated');
      } catch (e) {
        debugPrint('⚠️ Could not update last login: $e');
      }

      debugPrint('🔥 Fetching user data from Firestore...');
      UserModel userModel;
      try {
        userModel = await getUserData(user.uid).timeout(const Duration(seconds: 6));
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
              .set(userModel.toMap())
              .timeout(const Duration(seconds: 4));
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
  // AUTH-3: GOOGLE AS A PHONE-VERIFICATION-GATED LINKED PROVIDER
  // ============================================
  // Additive to signInWithGoogle() above, which is left untouched for
  // whatever else in the app still calls it directly. These methods back
  // the marketplace auth sheet's "Continue with Google" button and never
  // let a first-time Google identity reach a usable AgriMore session
  // without a successful phone OTP verification in between — see
  // docs/auth/AUTH_UI_REDESIGN.md for the full flow.

  /// Acquires a Google credential WITHOUT completing a Firebase sign-in.
  /// Returns null if the user cancelled the account picker.
  ///
  /// Mobile: google_sign_in's own flow never touches Firebase Auth by
  /// itself — signIn() + .authentication only ever returns tokens; nothing
  /// is "signed in" to Firebase until signInWithCredential/linkWithCredential
  /// is called separately, so this already satisfies "acquire before sign
  /// in" with no special handling needed.
  ///
  /// Web: this installed google_sign_in_web version has no token-only flow
  /// — the only way to obtain a Google credential is Firebase Auth's own
  /// signInWithPopup, which completes a sign-in as a side effect. Accepted
  /// mitigation: complete the popup, capture the credential from the
  /// result, then immediately sign out again before anything else runs —
  /// no Firestore read or write happens in between, so no account or
  /// document is ever created for an identity that turns out unlinked.
  Future<PendingGoogleIdentity?> acquireGoogleCredential() async {
    try {
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        googleProvider.setCustomParameters({'prompt': 'select_account'});

        final result = await _auth.signInWithPopup(googleProvider);
        // UserCredential.credential is the documented way to recover the
        // AuthCredential used for a sign-in result (there is no separate
        // GoogleAuthProvider.credentialFromResult in this installed
        // firebase_auth version — verified against the platform interface
        // source before writing this, not guessed).
        final credential = result.credential as OAuthCredential?;
        final user = result.user;

        // Immediately undo the sign-in this popup performed as a side
        // effect — see this method's own doc comment for why.
        await _auth.signOut();

        if (credential == null || credential.idToken == null) {
          throw AuthException('Google sign in failed: missing ID token.');
        }

        return PendingGoogleIdentity(
          credential: credential,
          idToken: credential.idToken!,
          email: user?.email,
          displayName: user?.displayName,
          photoUrl: user?.photoURL,
        );
      }

      final GoogleSignInAccount? googleUser = await _mobileGoogleSignIn.signIn();
      if (googleUser == null) return null; // user cancelled — not an error

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
        throw AuthException(
          'Google sign in failed: missing ID token. Check Firebase SHA keys.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return PendingGoogleIdentity(
        credential: credential,
        idToken: googleAuth.idToken!,
        email: googleUser.email,
        displayName: googleUser.displayName,
        photoUrl: googleUser.photoUrl,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Google sign in failed: ${e.toString()}');
    }
  }

  /// Asks resolveGoogleIdentity.ts whether [pending]'s Google identity is
  /// already linked to an existing AgriMore Firebase user. A pure lookup —
  /// never creates a user, never writes Firestore, never signs anyone in.
  Future<GoogleIdentityResolution> resolveGoogleIdentity(PendingGoogleIdentity pending) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_functionsBaseUrl/resolveGoogleIdentity'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'idToken': pending.idToken}),
          )
          .timeout(_requestTimeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || data['success'] != true) {
        throw AuthException(data['error']?.toString() ?? 'Could not verify Google account');
      }
      return GoogleIdentityResolution(
        linked: data['linked'] == true,
        expectedUid: data['expectedUid']?.toString(),
      );
    } on AuthException {
      rethrow;
    } on TimeoutException {
      throw AuthException('Network is too slow right now. Please try again.');
    } catch (e) {
      throw AuthException('Could not verify Google account: ${e.toString()}');
    }
  }

  /// Scenario A (returning, linked): signs in directly with the
  /// credential. Firebase Auth resolves it to the SAME existing uid — no
  /// new code needed for that resolution, it is native provider-linking
  /// behaviour. If the resolver supplied an expectedUid, the result is
  /// sanity-checked against it rather than trusted blindly.
  Future<UserModel> signInWithLinkedGoogleCredential(
    PendingGoogleIdentity pending, {
    String? expectedUid,
  }) async {
    try {
      final result = await _auth.signInWithCredential(pending.credential);
      final user = result.user;
      if (user == null) throw AuthException('Google sign in failed');

      if (expectedUid != null && user.uid != expectedUid) {
        // Firebase resolved this credential to a different uid than the
        // resolver predicted — a race between the two calls. Fail safely
        // rather than trust either side blindly.
        throw AuthException('Google account details changed. Please try again.');
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        await _firestore.collection('users').doc(user.uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
          'loginCount': FieldValue.increment(1),
        });
      }

      final synced = await getUserData(user.uid);
      await _savePersistentSession(synced);
      return synced;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Google sign in failed: ${e.toString()}');
    }
  }

  /// Scenario B (first-time, called only after phone verification has
  /// already succeeded): attaches [pending]'s Google credential to the
  /// CURRENTLY signed-in (phone-verified) user. Never signs that user out
  /// first, never signs in with Google first.
  ///
  /// Returns true on success. Returns false (not an exception) for
  /// credential-already-in-use / provider-already-linked and any other
  /// failure — the phone login has already succeeded by the time this is
  /// called and must never be undone by a linking failure; the caller
  /// keeps the phone session authenticated and may show a soft
  /// "already connected to another account" message.
  Future<bool> linkPendingGoogleCredential(PendingGoogleIdentity pending) async {
    final user = currentUser;
    if (user == null) throw UnauthorizedException();

    try {
      await user.linkWithCredential(pending.credential);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('⚠️ Google link failed (${e.code}) — phone session remains authenticated');
      return false;
    } catch (e) {
      debugPrint('⚠️ Google link failed: $e — phone session remains authenticated');
      return false;
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
  // verifyPhoneOTP's own three awaits get a longer budget than the shared
  // _requestTimeout: a voice-channel OTP plus a cold Cloud Function call has
  // been observed taking >12s server-side while still succeeding — the old
  // 12s budget was firing a false "Network is too slow" before the actual
  // sign-in completed.
  static const Duration _phoneVerifyTimeout = Duration(seconds: 25);

  /// Requests an OTP for [phone] (10-digit Indian number or +91-prefixed),
  /// delivered via SMS by default or, when [channel] is `'voice'`, as a
  /// voice call — server-side, a voice request for a number with a live,
  /// unexpired OTP redelivers the SAME code rather than issuing a new one
  /// (see sendPhoneOTP.ts), so requesting voice never invalidates a
  /// pending SMS.
  ///
  /// [channel] here is the REQUESTED channel. The server may deliver by a
  /// different, EFFECTIVE channel (Phase 22: while PHONE_OTP_SMS_ENABLED is
  /// off, every request is delivered by voice regardless of what was
  /// requested) — the returned [PhoneOtpSendResult.channel] always reflects
  /// what actually happened, straight from the response, so callers can
  /// tell the user the truth instead of assuming the request was honoured.
  ///
  /// A 503 (no SMS provider configured) or 429 (rate limited) response is
  /// surfaced as a specific, distinguishable [AuthException] message rather
  /// than a generic failure — see PhoneOtpRateLimitException/
  /// PhoneOtpUnavailableException.
  Future<PhoneOtpSendResult> sendPhoneOTP(String phone, {String channel = 'sms'}) async {
    try {
      debugPrint('🔥 Requesting phone OTP for: $phone (channel: $channel)');

      final response = await http
          .post(
            Uri.parse('$_functionsBaseUrl/sendPhoneOTP'),
            headers: {'Content-Type': 'application/json'},
            // SEC-P0b (OWNER_DECISION D-DEBUG-MOCK-OTP): debug builds ask the
            // server for the code instead of an SMS; release builds never do.
            body: jsonEncode({'phone': phone, 'channel': channel, if (kDebugMode) 'debugMock': true}),
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

      final effectiveChannel = data['channel']?.toString() ?? channel;
      debugPrint('✅ Phone OTP requested successfully (channel: $effectiveChannel)');
      // Phase SEC-P0: the server returns the code only in its allow-listed,
      // expiring test mode (sendPhoneOTP.ts) — never generated on the device.
      final testOtp = (data['testMode'] == true || data['testOtp'] != null)
          ? data['testOtp']?.toString()
          : null;
      return PhoneOtpSendResult(
        userExists: data['userExists'] == true,
        channel: effectiveChannel,
        testOtp: testOtp,
      );
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
              if (kDebugMode) 'debugMock': true,
            }),
          )
          .timeout(_phoneVerifyTimeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200 || data['success'] != true) {
        throw AuthException(data['error']?.toString() ?? 'Invalid OTP. Please try again.');
      }

      final token = data['token'] as String;
      final isNewUser = data['isNewUser'] == true;

      final result = await _auth.signInWithCustomToken(token).timeout(_phoneVerifyTimeout);
      final user = result.user;
      if (user == null) throw AuthException('Sign in failed');

      debugPrint('✅ Firebase Auth sign-in via phone successful: ${user.uid}');

      final userModel = await getUserData(user.uid).timeout(_phoneVerifyTimeout);
      await _savePersistentSession(userModel);

      debugPrint('✅ Phone login complete!');
      return PhoneAuthResult(user: userModel, isNewUser: isNewUser);
    } on AuthException {
      rethrow;
    } on TimeoutException {
      debugPrint('❌ Timed out verifying phone OTP');
      throw AuthException(
        'Still verifying — this is taking longer than usual. Please wait a moment.',
        code: 'TIMEOUT',
      );
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

  /// Changes the caller's OWN phone number via the changePhoneNumber
  /// callable — the OTP for [phone] must already have been requested via
  /// sendPhoneOTP. Verification happens server-side against the same
  /// phone_otp_codes/{phone} document sendPhoneOTP.ts writes; this never
  /// touches Firebase Auth (see changePhoneNumber.ts's header comment for
  /// why it deliberately doesn't reuse the login-purpose verifyPhoneOTP).
  /// Returns the refreshed UserModel on success.
  Future<UserModel> changePhoneNumber({
    required String phone,
    required String otp,
  }) async {
    final user = currentUser;
    if (user == null) throw UnauthorizedException();

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('changePhoneNumber');
      await callable.call<Map<String, dynamic>>({'phone': phone, 'otp': otp});

      final updated = await getUserData(user.uid);
      await _savePersistentSession(updated);
      return updated;
    } on FirebaseFunctionsException catch (e) {
      throw AuthException(e.message ?? 'Failed to update mobile number');
    } catch (e) {
      throw AuthException('Failed to update mobile number: ${e.toString()}');
    }
  }

  /// Changes the caller's OWN email address via the changeEmailAddress
  /// callable. [email] must already have been proven via
  /// verifyEmailOtpForProfile — this callable only checks that marker and
  /// writes; it does not accept or re-check an OTP itself (see
  /// changeEmailAddress.ts's header comment). Returns the refreshed
  /// UserModel on success.
  Future<UserModel> changeEmailAddress({required String email}) async {
    final user = currentUser;
    if (user == null) throw UnauthorizedException();

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('changeEmailAddress');
      await callable.call<Map<String, dynamic>>({'email': email});

      final updated = await getUserData(user.uid);
      await _savePersistentSession(updated);
      return updated;
    } on FirebaseFunctionsException catch (e) {
      throw AuthException(e.message ?? 'Failed to update email address');
    } catch (e) {
      throw AuthException('Failed to update email address: ${e.toString()}');
    }
  }

  /// Changes the caller's OWN date of birth via the changeDateOfBirth
  /// callable. Unlike phone/email there is no OTP to prove a birthdate —
  /// the server-side safeguard is re-validating the same 18+ age bound
  /// completeUserProfile.ts enforces at signup, not a verification marker.
  /// firestore.rules blanket-blocks a client from writing this field
  /// directly at any value (Phase 16, Workstream 5) — this callable is the
  /// one authorised, Admin-SDK path around that block. Returns the
  /// refreshed UserModel on success.
  Future<UserModel> changeDateOfBirth({required DateTime dateOfBirth}) async {
    final user = currentUser;
    if (user == null) throw UnauthorizedException();

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('changeDateOfBirth');
      await callable.call<Map<String, dynamic>>({
        'dateOfBirth': dateOfBirth.toIso8601String(),
      });

      final updated = await getUserData(user.uid);
      await _savePersistentSession(updated);
      return updated;
    } on FirebaseFunctionsException catch (e) {
      throw AuthException(e.message ?? 'Failed to update date of birth');
    } catch (e) {
      throw AuthException('Failed to update date of birth: ${e.toString()}');
    }
  }

  /// Firestore `settings/access` field `adminEmails` (list of strings), lowercased.
  Future<Set<String>> _adminAllowlistEmailsLower() async {
    try {
      final snap = await _firestore
          .collection('settings')
          .doc('access')
          .get()
          .timeout(const Duration(seconds: 4));
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
    Set<String> allow,
  ) async {
    final emailLower = user.email.trim().toLowerCase();
    final bootstrap = AdminAccessConfig.shouldBootstrapAdminRole(emailLower);
    final onList = allow.contains(emailLower);
    final shouldBeAdmin = bootstrap || onList || (allow.isEmpty && user.isAdmin);

    if (shouldBeAdmin) {
      if (user.role != 'admin') {
        debugPrint('👑 Promoting user to admin based on admin policy: ${user.email}');
        try {
          await _firestore
              .collection('users')
              .doc(uid)
              .update({'role': 'admin'})
              .timeout(const Duration(seconds: 4));
          debugPrint('👑 Persisted role: admin to Firestore for ${user.email}');
        } catch (e) {
          debugPrint('⚠️ Could not persist role: admin to Firestore: $e');
        }
        return user.copyWith(role: 'admin');
      }
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

      // PERF-2: the user-doc read and the admin-allowlist read
      // (_adminAllowlistEmailsLower, consumed by _syncRoleWithAdminPolicy
      // below) are independent of each other -- the allowlist read needs
      // nothing from the user doc -- so both Firestore round trips are
      // started here and run concurrently instead of sequentially (the
      // second one used to only start once the first had fully resolved,
      // inside _syncRoleWithAdminPolicy). Every logged-in app launch goes
      // through this method while AuthWrapper shows a blocking spinner, so
      // this halves that wait rather than just shortening it.
      final docFuture = _firestore.collection('users').doc(uid).get();
      final allowFuture = _adminAllowlistEmailsLower();
      final doc = await docFuture;

      if (!doc.exists) {
        debugPrint('❌ User document does not exist!');
        throw UserNotFoundException('User not found');
      }

      debugPrint('✅ User document found');
      final raw = doc.data()!;
      UserModel user = UserModel.fromMap(raw, doc.id);
      user = await _syncRoleWithAdminPolicy(user, uid, raw, await allowFuture);

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

  // Phase 17, Workstream 3: routes through the deleteUserData callable
  // instead of a client-side Firestore delete. The old
  // `_firestore.collection('users').doc(user.uid).delete()` here could
  // never have worked — firestore.rules has said
  // `allow delete: if isAdmin();` on users/{userId} since before this
  // engagement started — and `await user.delete()` right after it deleted
  // the AUTH user regardless, leaving an orphaned users/ doc (which itself
  // never actually happened, since the Firestore delete always threw
  // first). The callable now does the real work — Firestore tiering AND
  // the Auth user deletion, server-side, in that order — so this method
  // no longer touches `user.delete()` or `_firestore` at all; it is a
  // sign-in-required precondition check plus a single callable call.
  Future<void> deleteAccount({String? expectedOwnerId}) async {
    final user = currentUser;
    if (user == null) throw UnauthorizedException();
    final owner = user.uid;
    if (expectedOwnerId != null && expectedOwnerId != owner) {
      throw AuthException(
        'Your account session changed. Please try again.',
        code: 'session-changed',
      );
    }
    bool current() => currentUser == null || currentUser!.uid == owner;
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'deleteUserData',
      );
      final result = await callable.call<Map<String, dynamic>>({
        'expectedOwnerId': owner,
      });
      if (result.data['success'] != true) {
        throw AuthException(
          'Account deletion could not be confirmed. Please try again.',
          code: 'unconfirmed',
        );
      }
      if (!current()) {
        throw AuthException(
          'Your account session changed. Please review your current account.',
          code: 'session-changed',
        );
      }
      await SharedPreferencesService.clearUserSession(
        expectedUserId: owner,
        isSessionCurrent: current,
      );
      if (!current()) {
        throw AuthException(
          'Your account session changed. Please review your current account.',
          code: 'session-changed',
        );
      }
    } on FirebaseFunctionsException catch (e) {
      // Preserve actionable refusal codes used by DeleteAccountScreen.
      throw AuthException(
        e.message ?? 'Failed to delete account',
        code: e.code,
      );
    } on AuthException {
      rethrow;
    } catch (_) {
      throw AuthException(
        'Account deletion could not be confirmed. Please try again.',
        code: 'unconfirmed',
      );
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
