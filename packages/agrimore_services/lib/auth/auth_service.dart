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
  int _restoreRead = 0;
  bool _signInInFlight = false;

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
    return _runOwnedSignIn((session) async {
      try {

        session.allowSignIn();
        final UserCredential result =
            await _auth.createUserWithEmailAndPassword(
          email: email.trim().toLowerCase(),
          password: password,
        );

        final User? user = result.user;
        if (user == null) throw AuthException('Registration failed');
        session.bindResult(user.uid);


        // Update display name
        await user.updateDisplayName(name.trim());
        _requireCurrentSession(session.isCurrent);

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
          _requireCurrentSession(session.isCurrent);
          debugPrint('✅ User saved to Firestore successfully!');
        } catch (firestoreError) {
          _requireCurrentSession(session.isCurrent);
            throw AuthException('Could not save your profile. Please try again.');
        }

        final synced = await _readOwnedUserData(user.uid, session.isCurrent);
        _requireCurrentSession(session.isCurrent);
        await _savePersistentSession(synced,
            isSessionCurrent: session.isCurrent);
        _requireCurrentSession(session.isCurrent);

        debugPrint('✅ Registration complete!');
        return synced;
      } on FirebaseAuthException catch (e) {
        throw _handleSignInException(e);
      } catch (e) {
        if (e is AuthException) rethrow;
        throw AuthException('Registration failed. Please try again.');
      }
    });
  }

  // ✅ Sign in with email and password
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _runOwnedSignIn((session) async {
      try {

        session.allowSignIn();
        final UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email.trim().toLowerCase(),
          password: password,
        );

        final User? user = result.user;
        if (user == null) throw AuthException('Sign in failed');
        session.bindResult(user.uid);


        try {
          await _firestore.collection('users').doc(user.uid).update({
            'lastLogin': FieldValue.serverTimestamp(),
            'loginCount': FieldValue.increment(1),
          }).timeout(const Duration(seconds: 4));
          _requireCurrentSession(session.isCurrent);
          debugPrint('✅ Last login updated');
        } catch (e) {
          _requireCurrentSession(session.isCurrent);
          }

        debugPrint('🔥 Fetching user data from Firestore...');
        UserModel userModel;
        try {
          userModel =
              await _readOwnedUserData(user.uid, session.isCurrent).timeout(const Duration(seconds: 6));
          _requireCurrentSession(session.isCurrent);
        } catch (e) {
          _requireCurrentSession(session.isCurrent);
          if (e is UserNotFoundException ||
              e.toString().contains('User not found')) {
            debugPrint('📝 User document missing, creating new one...');
            // ✅ SECURITY FIX: Never auto-assign admin role. Default to 'user'.
            // Privileged roles are provisioned by server/admin tools.
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
            _requireCurrentSession(session.isCurrent);
          } else {
            rethrow;
          }
        }

        await _savePersistentSession(userModel,
            isSessionCurrent: session.isCurrent);
        _requireCurrentSession(session.isCurrent);

        debugPrint('✅ Login complete!');
        return userModel;
      } on FirebaseAuthException catch (e) {
        throw _handleSignInException(e);
      } catch (e) {
        if (e is AuthException) rethrow;
        throw AuthException('Sign in failed. Please try again.');
      }
    });
  }

  // ============================================
  // ✅ GOOGLE SIGN-IN — FIX FOR WEB (401 invalid_client)
  // Web: Uses Firebase Auth signInWithPopup (no OAuth client ID needed)
  // Mobile: Uses google_sign_in package
  // ============================================
  Future<UserModel> signInWithGoogle() async {
    return _runOwnedSignIn((session) async {
      try {
        debugPrint('Starting Google sign in');

        UserCredential result;

        if (kIsWeb) {
          // ✅ WEB: Use Firebase Auth's built-in popup — no OAuth client ID required
          final googleProvider = GoogleAuthProvider();
          googleProvider.addScope('email');
          googleProvider.addScope('profile');
          googleProvider.setCustomParameters({'prompt': 'select_account'});

          session.allowSignIn();
          result = await _auth.signInWithPopup(googleProvider);
          debugPrint('✅ Firebase Web popup sign-in successful');
        } else {
          // ✅ MOBILE: Use google_sign_in package (works with google-services.json)
          final GoogleSignInAccount? googleUser =
              await _mobileGoogleSignIn.signIn();
          _requireCurrentSession(session.isCurrent);
          if (googleUser == null) {
            throw AuthException('Google sign in cancelled');
          }


          final GoogleSignInAuthentication googleAuth =
              await googleUser.authentication;
          _requireCurrentSession(session.isCurrent);
          if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
            throw AuthException(
              'Google sign in could not complete. Please try again.',
            );
          }

          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );

          session.allowSignIn();
          result = await _auth.signInWithCredential(credential);
        }

        final User? user = result.user;
        if (user == null) throw AuthException('Google sign in failed');
        session.bindResult(user.uid);


        // Check if user document exists in Firestore
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        _requireCurrentSession(session.isCurrent);

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
            _requireCurrentSession(session.isCurrent);
            debugPrint('✅ User document created!');
          } catch (e) {
            _requireCurrentSession(session.isCurrent);
                throw AuthException(
                'Could not save your profile. Please try again.');
          }
        } else {
          debugPrint('✅ User document exists, updating last login...');

          await _firestore.collection('users').doc(user.uid).update({
            'lastLogin': FieldValue.serverTimestamp(),
            'loginCount': FieldValue.increment(1),
          });
          _requireCurrentSession(session.isCurrent);
        }

        final synced = await _readOwnedUserData(user.uid, session.isCurrent);
        _requireCurrentSession(session.isCurrent);
        await _savePersistentSession(synced,
            isSessionCurrent: session.isCurrent);
        _requireCurrentSession(session.isCurrent);

        debugPrint('✅ Google sign in complete!');
        return synced;
      } on FirebaseAuthException catch (e) {
        throw _handleSignInException(e);
      } catch (e) {
        if (e is AuthException) rethrow;
        throw AuthException('Google sign in failed. Please try again.');
      }
    });
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
    return _runOwnedSignIn((session) async {
      try {
        session.allowSignIn();
        final result = await _auth.signInWithCredential(pending.credential);
        final user = result.user;
        if (user == null) throw AuthException('Google sign in failed');
        session.bindResult(user.uid);

        if (expectedUid != null && user.uid != expectedUid) {
          // Firebase resolved this credential to a different uid than the
          // resolver predicted — a race between the two calls. Fail safely
          // rather than trust either side blindly.
          throw AuthException(
              'Google account details changed. Please try again.');
        }

        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        _requireCurrentSession(session.isCurrent);
        if (userDoc.exists) {
          await _firestore.collection('users').doc(user.uid).update({
            'lastLogin': FieldValue.serverTimestamp(),
            'loginCount': FieldValue.increment(1),
          });
          _requireCurrentSession(session.isCurrent);
        }

        final synced = await _readOwnedUserData(user.uid, session.isCurrent);
        _requireCurrentSession(session.isCurrent);
        await _savePersistentSession(synced,
            isSessionCurrent: session.isCurrent);
        _requireCurrentSession(session.isCurrent);
        return synced;
      } on FirebaseAuthException catch (e) {
        throw _handleSignInException(e);
      } catch (e) {
        if (e is AuthException) rethrow;
        throw AuthException('Google sign in failed. Please try again.');
      }
    });
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
    return _runOwnedSignIn((session) async {
      try {

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
        _requireCurrentSession(session.isCurrent);
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (response.statusCode != 200 || data['success'] != true) {
          throw AuthException('Invalid OTP. Please try again.');
        }

        final token = data['token'] as String;
        final isNewUser = data['isNewUser'] == true;

        session.allowSignIn();
        final result = await _auth
            .signInWithCustomToken(token)
            .timeout(_phoneVerifyTimeout);
        final user = result.user;
        if (user == null) throw AuthException('Sign in failed');
        session.bindResult(user.uid);


        final userModel =
            await _readOwnedUserData(user.uid, session.isCurrent).timeout(_phoneVerifyTimeout);
        _requireCurrentSession(session.isCurrent);
        await _savePersistentSession(userModel,
            isSessionCurrent: session.isCurrent);
        _requireCurrentSession(session.isCurrent);

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
        throw AuthException('Failed to verify OTP. Please try again.');
      }
    });
  }

  // ============================================
  // PROFILE COMPLETION (Phase 16)
  // ============================================

  /// Sends an email-verification OTP to [email] via sendEmailOTP.ts
  /// (Resend-backed). Used only during profile completion — this endpoint
  /// does not sign anyone in or touch Firebase Auth.
  Future<void> sendEmailOtpForProfile(String email) async {
    final session = _OwnedAuthSession(_auth);
    bool current() => session.isCurrent();
    const fallback = 'Failed to send verification code. Please try again.';
    const rateFallback =
        'Too many verification requests. Please try again later.';
    // Only these existing, explicitly user-facing server sentences may be
    // shown. Unknown HTTP text and provider/transport diagnostics stay out.
    const allowedErrors = <int, Set<String>>{
      400: {'Email is required', 'Invalid email format'},
      429: {
        'Please wait before requesting another code',
        'Too many code requests for this address today. Please try again later.',
        'Too many code requests from this network today. Please try again later.',
      },
      502: {
        'Could not deliver the verification code. Please try again shortly.',
      },
      500: {fallback},
    };
    try {
      if (session.owner == null) throw UnauthorizedException();
      _requireCurrentSession(current);
      final response = await http
          .post(
            Uri.parse('$_functionsBaseUrl/sendEmailOTP'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(_requestTimeout);
      _requireCurrentSession(current);
      var data = <String, dynamic>{};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {
        debugPrint('Email verification response could not be decoded');
      }
      final rawError = data['error'];
      final message = rawError is String &&
              (allowedErrors[response.statusCode]?.contains(rawError) ?? false)
          ? rawError
          : response.statusCode == 429
              ? rateFallback
              : fallback;
      if (response.statusCode == 429) {
        final retry = data['retryAfterMs'];
        throw PhoneOtpRateLimitException(
          message,
          retryAfterMs: retry is num && retry.isFinite && retry >= 0
              ? retry.toInt()
              : null,
        );
      }
      if (response.statusCode != 200 || data['success'] != true) {
        throw AuthException(message);
      }
      _requireCurrentSession(current);
    } on AuthException {
      _requireCurrentSession(current);
      rethrow;
    } on TimeoutException {
      _requireCurrentSession(current);
      throw AuthException('Network is too slow right now. Please try again.');
    } catch (_) {
      _requireCurrentSession(current);
      debugPrint('Email verification request failed');
      throw AuthException(fallback);
    } finally {
      await session.cancel();
    }
  }

  // Capture before dispatch: the native Functions SDK may obtain an auth
  // token after the account changes. The server can only reject this hint;
  // request.auth.uid remains the sole actor and target of every callable.
  Future<T> _runOwnedProfileCommand<T>({
    required String command,
    required Map<String, dynamic> parameters,
    required String failureMessage,
    required Future<T> Function(String, bool Function()) confirmed,
  }) async {
    final session = _OwnedAuthSession(_auth);
    final owner = session.owner;
    bool current() => session.isCurrent();
    try {
      if (owner == null) throw UnauthorizedException();
      _requireCurrentSession(current);
      final result = await FirebaseFunctions.instance
          .httpsCallable(command)
          .call<Map<String, dynamic>>({
            ...parameters,
            'expectedOwnerId': owner,
          });
      _requireCurrentSession(current);
      if (result.data['success'] != true) {
        throw AuthException(
          'Profile change could not be confirmed. Please try again.',
          code: 'unconfirmed',
        );
      }
      final value = await confirmed(owner, current);
      _requireCurrentSession(current);
      return value;
    } on FirebaseFunctionsException catch (e) {
      _requireCurrentSession(current);
      throw AuthException(e.message ?? failureMessage, code: e.code);
    } on AuthException {
      rethrow;
    } catch (e) {
      _requireCurrentSession(current);
      debugPrint('Profile command failed: $e');
      throw AuthException(failureMessage);
    } finally {
      await session.cancel();
    }
  }

  Future<UserModel> _refreshOwnedProfile(
    String owner,
    bool Function() current,
  ) async {
    _requireCurrentSession(current);
    final updated = await getUserData(owner);
    _requireCurrentSession(current);
    await _savePersistentSession(updated, isSessionCurrent: current);
    _requireCurrentSession(current);
    return updated;
  }

  /// Verifies [otp] for [email] via the authenticated verifyEmailForProfile
  /// callable — proves ownership without minting a second Firebase Auth
  /// identity (see that function's header comment for why it's not
  /// verifyEmailOTP.ts). Must be called while already signed in (phone
  /// OTP happens first in the real flow).
  Future<void> verifyEmailOtpForProfile({
    required String email,
    required String otp,
  }) async {
    await _runOwnedProfileCommand<void>(
      command: 'verifyEmailForProfile',
      parameters: {'email': email, 'otp': otp},
      failureMessage: 'Invalid verification code',
      confirmed: (owner, current) async {},
    );
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
    return _runOwnedProfileCommand<UserModel>(
      command: 'completeUserProfile',
      parameters: {
        'name': name,
        'email': email,
        'dateOfBirth': dateOfBirth.toIso8601String(),
        'gender': gender,
      },
      failureMessage: 'Failed to complete profile',
      confirmed: _refreshOwnedProfile,
    );
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
    return _runOwnedProfileCommand<UserModel>(
      command: 'changePhoneNumber',
      parameters: {'phone': phone, 'otp': otp},
      failureMessage: 'Failed to update mobile number',
      confirmed: _refreshOwnedProfile,
    );
  }

  /// Changes the caller's OWN email address via the changeEmailAddress
  /// callable. [email] must already have been proven via
  /// verifyEmailOtpForProfile — this callable only checks that marker and
  /// writes; it does not accept or re-check an OTP itself (see
  /// changeEmailAddress.ts's header comment). Returns the refreshed
  /// UserModel on success.
  Future<UserModel> changeEmailAddress({required String email}) async {
    return _runOwnedProfileCommand<UserModel>(
      command: 'changeEmailAddress',
      parameters: {'email': email},
      failureMessage: 'Failed to update email address',
      confirmed: _refreshOwnedProfile,
    );
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
    return _runOwnedProfileCommand<UserModel>(
      command: 'changeDateOfBirth',
      parameters: {'dateOfBirth': dateOfBirth.toIso8601String()},
      failureMessage: 'Failed to update date of birth',
      confirmed: _refreshOwnedProfile,
    );
  }

  Future<T> _runOwnedSignIn<T>(
    Future<T> Function(_OwnedAuthSignIn session) command,
  ) async {
    if (_signInInFlight) {
      throw AuthException(
          'A sign-in request is already in progress. Please wait.',
          code: 'sign-in-in-progress');
    }
    _signInInFlight = true;
    _OwnedAuthSignIn? session;
    try {
      session = _OwnedAuthSignIn(_auth);
      // Deliver the initial SDK snapshot/stream failure before acquiring credentials.
      await Future<void>.delayed(Duration.zero);
      _requireCurrentSession(session.isCurrent);
      return await command(session);
    } finally {
      await session?.cancel();
      _signInInFlight = false;
    }
  }

  AuthException _handleSignInException(FirebaseAuthException error) {
    const mapped = {
      'weak-password',
      'email-already-in-use',
      'user-not-found',
      'wrong-password',
      'invalid-email',
      'user-disabled',
      'too-many-requests',
      'operation-not-allowed',
      'requires-recent-login',
      'invalid-credential',
      'account-exists-with-different-credential',
      'popup-closed-by-user',
      'cancelled-popup-request',
      'popup-blocked',
      'network-request-failed',
    };
    return mapped.contains(error.code)
        ? _handleAuthException(error)
        : AuthException('Sign in failed. Please try again.');
  }

  // ✅ Save persistent session
  void _requireCurrentSession(bool Function() current) {
    if (!current()) {
      throw AuthException(
        'Your account session changed. Please try again.',
        code: 'session-changed',
      );
    }
  }

  Future<void> _savePersistentSession(
    UserModel userModel, {
    bool Function()? isSessionCurrent,
  }) async {
    final session = _OwnedAuthSession(_auth);
    bool current() =>
        session.owner == userModel.uid &&
        session.isCurrent() &&
        (isSessionCurrent == null || isSessionCurrent());
    try {
      _requireCurrentSession(current);
      await SharedPreferencesService.saveUserSession(
        userId: userModel.uid,
        email: userModel.email,
        name: userModel.name,
        role: userModel.role,
        isSessionCurrent: current,
      );
      _requireCurrentSession(current);
    } on AuthException {
      rethrow;
    } catch (e) {
      debugPrint('Could not save session: $e');
    } finally {
      await session.cancel();
    }
  }

  // ✅ Get user data from Firestore
  Future<UserModel> getUserData(String uid) async {
    final session = _OwnedAuthSession(_auth);
    try {
      return await _readOwnedUserData(
          uid, () => session.owner == uid && session.isCurrent());
    } finally {
      await session.cancel();
    }
  }

  Future<UserModel> _readOwnedUserData(
      String uid, bool Function() current) async {
    try {
      _requireCurrentSession(current);
      debugPrint('Loading owned account profile');

      // Role is read from the owned server record. Email/build-time hints
      // cannot grant or revoke a role, and profile reads never write roles.
      final doc = await _firestore.collection('users').doc(uid).get();
      _requireCurrentSession(current);

      if (!doc.exists) {
        debugPrint('❌ User document does not exist!');
        throw UserNotFoundException('User not found');
      }

      debugPrint('✅ User document found');
      final raw = doc.data()!;
      final user = UserModel.fromMap(raw, doc.id);

      return user;
    } catch (e) {
      _requireCurrentSession(current);
      if (e is AuthException && e.code == 'session-changed') rethrow;
      debugPrint('Owned account profile could not be loaded');
      throw DatabaseException(e is UserNotFoundException
          ? 'Failed to get user: User not found'
          : 'Could not load your profile. Please try again.');
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
    final session = _OwnedAuthSession(_auth);
    void requireCurrent() {
      if (session.owner == null || !session.isCurrent()) {
        throw AuthException(
          'Your account session changed. Please try again.',
          code: 'session-changed',
        );
      }
    }
    try {
      final user = currentUser;
      if (user == null || user.email == null) throw UnauthorizedException();
      requireCurrent();
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      requireCurrent();
      await user.updatePassword(newPassword);
      requireCurrent();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw AuthException('Could not change your password. Please try again.');
    } finally {
      await session.cancel();
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
    final session = _OwnedAuthSession(_auth);
    final owner = session.owner;
    try {
      if (owner == null || !session.isCurrent()) return;
      if (!kIsWeb) {
        try {
          await _mobileGoogleSignIn.signOut();
        } catch (_) {}
      }
      if (!session.isCurrent()) return;
      await _auth.signOut();
      bool current() => session.isCurrent(allowSignedOut: true);
      if (!current()) return;
      await SharedPreferencesService.clearUserSession(
        expectedUserId: owner,
        isSessionCurrent: current,
      );
    } catch (e) {
      if (!session.isCurrent(allowSignedOut: true)) return;
      debugPrint('Error signing out: $e');
      throw AuthException('Sign out failed: ${e.toString()}');
    } finally {
      await session.cancel();
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
    final read = ++_restoreRead;
    final user = currentUser;
    if (user == null) return null;
    final session = _OwnedAuthSession(_auth);
    bool current() =>
        read == _restoreRead &&
        session.owner == user.uid &&
        session.isCurrent();
    try {
      if (!current()) return null;
      await user.reload();
      if (!current()) return null;
      final userModel = await getUserData(user.uid);
      if (!current()) return null;
      await _savePersistentSession(userModel, isSessionCurrent: current);
      if (!current()) return null;
      return userModel;
    } catch (e) {
      if (!current()) return null;
      debugPrint('Could not fetch current profile: $e');
      return UserModel(
        uid: user.uid,
        email: user.email ?? '',
        name: user.displayName ?? 'User',
        role: 'user',
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );
    } finally {
      await session.cancel();
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

/// A short-lived SDK session ticket. Native auth streams first yield their
/// current snapshot; later events, even for the same UID, revoke this ticket.
/// Cancellation releases the listener on every operation completion path.
class _OwnedAuthSession {
  _OwnedAuthSession(this._auth) : owner = _auth.currentUser?.uid {
    final subscription = _auth.authStateChanges().listen(
      (user) {
        if (_closed) return;
        final uid = user?.uid;
        if (_first && uid == owner) {
          _first = false;
          return;
        }
        _first = false;
        _changes++;
        _lastOwner = uid;
      },
      onError: (Object error) => _revoke(),
      onDone: _revoke,
    );
    _subscription = subscription;
    // A stream may close synchronously inside listen before it returns.
    if (!_healthy) unawaited(cancel());
  }

  final FirebaseAuth _auth;
  final String? owner;
  StreamSubscription<User?>? _subscription;
  bool _first = true, _healthy = true, _closed = false;
  int _changes = 0;
  String? _lastOwner;

  void _revoke() {
    _healthy = false;
    unawaited(cancel());
  }

  bool isCurrent({bool allowSignedOut = false}) {
    if (_closed || !_healthy) return false;
    final uid = _auth.currentUser?.uid;
    if (_changes == 0 && uid == owner) return true;
    return allowSignedOut &&
        owner != null &&
        uid == null &&
        (_changes == 0 || (_changes == 1 && _lastOwner == null));
  }

  Future<void> cancel() async {
    _closed = true;
    final subscription = _subscription;
    _subscription = null;
    try {
      await subscription?.cancel();
    } catch (e) {
      debugPrint('Auth session listener cancellation failed: $e');
    }
  }
}

/// Owns a sign-in episode, allowing exactly one intended SDK transition after
/// credential acquisition. Profile reads and persistence share this same ticket.
class _OwnedAuthSignIn {
  _OwnedAuthSignIn(this._auth) : _openingOwner = _auth.currentUser?.uid {
    final subscription = _auth.authStateChanges().listen((user) {
      if (_closed || !_healthy) return;
      final uid = user?.uid;
      if (_first && uid == _openingOwner) {
        _first = false;
        return;
      }
      _first = false;
      // A later event from another owner revokes this episode even when
      // the current SDK owner has already returned before delivery.
      if (uid != _auth.currentUser?.uid) {
        _revoke();
        return;
      }
      if (!_allowed ||
          _transitionSeen ||
          uid == null ||
          (_bound && uid != _owner)) {
        _revoke();
        return;
      }
      _transitionSeen = true;
      _owner = uid;
    }, onError: (Object error) => _revoke(), onDone: _revoke);
    _subscription = subscription;
    if (!_healthy) unawaited(cancel());
  }

  final FirebaseAuth _auth;
  final String? _openingOwner;
  StreamSubscription<User?>? _subscription;
  String? _owner;
  bool _first = true, _healthy = true, _closed = false;
  bool _allowed = false, _transitionSeen = false, _bound = false;

  bool isCurrent() =>
      !_closed &&
      _healthy &&
      _auth.currentUser?.uid ==
          (_bound || _transitionSeen ? _owner : _openingOwner);

  void _requireCurrent() {
    if (!isCurrent()) {
      throw AuthException('Your account session changed. Please try again.',
          code: 'session-changed');
    }
  }

  void allowSignIn() {
    _requireCurrent();
    _allowed = true;
  }

  void bindResult(String uid) {
    if (!_healthy ||
        _closed ||
        !_allowed ||
        _auth.currentUser?.uid != uid ||
        (_transitionSeen && _owner != uid)) {
      _revoke();
      throw AuthException('Your account session changed. Please try again.',
          code: 'session-changed');
    }
    _owner = uid;
    _bound = true;
  }

  void _revoke() {
    _healthy = false;
    unawaited(cancel());
  }

  Future<void> cancel() async {
    _closed = true;
    final subscription = _subscription;
    _subscription = null;
    try {
      await subscription?.cancel();
    } catch (_) {
      debugPrint('Sign-in listener could not be released');
    }
  }
}
