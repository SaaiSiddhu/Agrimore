// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// agrimore_services re-exports agrimore_core, so this single import supplies
// AuthService, UserModel and AuthException together (importing agrimore_core
// as well trips unnecessary_import, and this app's analyze baseline is zero
// issues).
import 'package:agrimore_services/agrimore_services.dart';

/// Phase 18, Workstream 3 — how the current sign-in attempt reached us.
///
/// Used for exactly ONE thing: phrasing the "this isn't an associate account"
/// rejection accurately. Telling someone who just typed a mobile number that
/// "this account" is not an associate is vague; naming the number is not.
/// It deliberately does NOT gate any check — both methods run the identical
/// post-authentication gate in [_applyAssociateGate].
enum AssociateSignInMethod { unknown, phone, email }

class EmployeeAuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Phase 18, Workstream 2: the SHARED phone-OTP implementation, already used
  // by apps/marketplace. AuthService is a singleton (factory AuthService() =>
  // _instance), so this costs nothing and adds no second OTP code path.
  final AuthService _authService = AuthService();

  UserModel? _user;
  bool _isLoading = true;
  String? _error;
  AssociateSignInMethod _signInMethod = AssociateSignInMethod.unknown;

  // Getters
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null && _error == null;
  bool get isEmployee => _user?.isEmployee ?? false;
  String? get error => _error;

  void _init() {
    _auth.authStateChanges().listen((firebaseUser) async {
      if (firebaseUser != null) {
        await _loadUserData(firebaseUser.uid);
      } else {
        _user = null;
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  EmployeeAuthProvider() {
    _init();
  }

  Future<void> _loadUserData(String uid) async {
    // Phase 18: authStateChanges ALSO drives this method, so a single sign-in
    // runs it TWICE — once from the listener, once from the explicit call in
    // signIn()/verifyPhoneOtpAndSignIn() — and the two passes overlap.
    //
    // That matters because a rejecting pass signs the user out. Whichever
    // pass loses the race then finds itself unauthenticated, its
    // users/{uid} read is denied by firestore.rules, and without this guard
    // it would land in the catch below and replace a specific, honest
    // explanation ("this number isn't registered as an associate") with a
    // useless generic one ("Failed to load user data").
    //
    // So: if the signed-in user is no longer the one this pass was started
    // for, another pass has already resolved the outcome. Abort, and leave
    // its verdict alone.
    if (_auth.currentUser?.uid != uid) return;
    try {
      _error = null;
      final doc = await _firestore.collection('users').doc(uid).get();
      if (_auth.currentUser?.uid != uid) return;
      if (doc.exists) {
        _user = UserModel.fromFirestore(doc);
        await _applyAssociateGate(uid);
      } else {
        // Phase 18, Workstream 3: previously this branch did nothing at all —
        // _user stayed null, _error stayed null, and the user was bounced to
        // a login screen showing no explanation whatsoever. verifyPhoneOTP.ts
        // always creates users/{uid}, so this should be unreachable on the
        // phone path, but "should be unreachable" is not a reason to leave a
        // silent dead end in an auth flow.
        await _rejectNonAssociate(uid);
      }
    } catch (e) {
      // Being signed out mid-flight by the other pass is an EXPECTED way to
      // land here, and it is not a load failure worth reporting — see the
      // guard note above.
      if (_auth.currentUser?.uid != uid) return;
      _error = 'Failed to load user data';
      debugPrint('Error loading user: $e');
    }
  }

  /// Phase 18, Workstream 3 — the ONE post-authentication gate.
  ///
  /// Both sign-in paths (email/password and phone OTP) run this identical
  /// check. It is deliberately a single implementation rather than one copy
  /// per path: a divergence here would mean one door into the app enforced
  /// approval and the other did not.
  ///
  /// Assumes [_user] has just been populated from users/{uid}.
  Future<void> _applyAssociateGate(String uid) async {
    // STRICT ROLE CHECK FOR THE SALES ASSOCIATE APP
    if (!_user!.isEmployee) {
      debugPrint(
          '⛔ Unauthorized access attempt by non-associate: ${_user!.email}');
      await _rejectNonAssociate(uid);
      return;
    }

    final employeeDoc = await _firestore.collection('employees').doc(uid).get();
    // Same overlapping-pass guard as _loadUserData — a concurrent pass may
    // have signed this user out while the read above was in flight.
    if (_auth.currentUser?.uid != uid) return;
    if (!employeeDoc.exists) {
      await _auth.signOut();
      _user = null;
      _error = 'We could not find your Sales Associate profile. '
          'Please contact support.';
      return;
    }

    final status = employeeDoc.data()?['status'] ?? 'pending';
    // Phase 16C, Workstream 5: previously ANY non-approved status —
    // including 'suspended' — produced this exact same "pending
    // approval" message, so a suspended associate (who may have
    // been approved and working for months) was told they were
    // still under initial review. Distinguishing the two is the
    // ONLY change here — the check that gates FCM registration on
    // status == 'approved' is untouched, and this still does not
    // touch signIn()/OTP/the auth mechanism itself.
    //
    // ⚠️ app.dart's _AuthGate routes on error!.contains('suspended') and
    // error!.contains('pending'). These two strings are load-bearing — do
    // not reword them without updating that routing.
    if (status == 'suspended') {
      _error = 'Your associate account has been suspended.';
    } else if (status != 'approved') {
      _error = 'Your account is pending approval by an administrator.';
    } else {
      await _updateFCMToken(uid);
    }
  }

  /// Signs out and explains why, in words that are true for the method the
  /// user actually used.
  ///
  /// ⚠️ Neither message may contain the substrings 'pending' or 'suspended'
  /// — app.dart's _AuthGate routes on those, and a stray match here would
  /// send a total stranger to the "pending approval" screen.
  Future<void> _rejectNonAssociate(String uid) async {
    // CTO review, 2026-09-03: the same overlapping-pass guard the other
    // three read/write sites in this file already carry, added here too —
    // this call site was the one gap in the "identity guard before every
    // _error write" claim. If the current Firebase Auth session is no
    // longer this pass's target uid, another pass already resolved (and
    // signed out) this same sign-in attempt, or a brand-new attempt has
    // superseded it entirely; either way this pass's verdict is stale and
    // must not sign out again or overwrite whatever _error is now current.
    if (_auth.currentUser?.uid != uid) return;
    await _auth.signOut();
    _user = null;
    final subject = _signInMethod == AssociateSignInMethod.phone
        ? "This mobile number isn't registered"
        : "This account isn't registered";
    _error = '$subject as an Agrimore Sales Associate. To become one, apply '
        'from the Agrimore customer app under Profile.';
  }

  // ============================================
  // EMAIL + PASSWORD (admin-created associates)
  // ============================================
  // Retained deliberately. createEmployeeByAdmin.ts creates associates with
  // real email/password credentials, and that is the ONLY population that
  // could sign in before Phase 18 — removing this to make phone OTP "the"
  // path would have locked out every associate who can currently get in.
  Future<bool> signIn(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      _signInMethod = AssociateSignInMethod.email;
      notifyListeners();

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        await _loadUserData(credential.user!.uid);
        // The role checks and approval checks are now handled in _loadUserData

        // If _user is null after _loadUserData, it means they were rejected and signed out
        if (_user == null) {
          _isLoading = false;
          notifyListeners();
          return false;
        }

        // Update FCM token
        await _updateFCMToken(credential.user!.uid);

        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      _error = e.message ?? 'Authentication failed';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================
  // PHONE OTP (Phase 18, Workstream 2)
  // ============================================
  // The path that finally lets a SELF-APPLIED associate in. Such an associate
  // signed up in apps/marketplace by phone OTP, so verifyPhoneOTP.ts created
  // their Auth record with `phoneNumber` only — no email, no password. They
  // have never had a credential this app could accept until now.

  /// Requests an OTP for [phone] (expects the +91-prefixed E.164 form).
  ///
  /// Returns the send result on success — whose `channel` is the EFFECTIVE
  /// channel the server actually used, which is NOT necessarily the one
  /// requested (in production today SMS is disabled and every code is
  /// delivered by voice call). Returns null on failure, with [error] set.
  Future<PhoneOtpSendResult?> sendPhoneOtp(String phone,
      {String channel = 'sms'}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      return await _authService.sendPhoneOTP(phone, channel: channel);
    } on AuthException catch (e) {
      // Covers PhoneOtpUnavailableException and PhoneOtpRateLimitException
      // too — both extend AuthException and both already carry a specific,
      // user-appropriate message from the service layer.
      _error = e.message;
      return null;
    } catch (e) {
      debugPrint('Error sending associate OTP: $e');
      _error = 'Failed to send OTP. Please try again.';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================
  // PASSWORD RESET (Phase 21, Workstream 3)
  // ============================================
  // Only relevant to the email+password path — an admin-created associate
  // has a real password to forget. A self-applied associate signs in by
  // phone OTP and has never had one; this method is simply never reachable
  // for them (the UI only offers it on the email tab).

  /// Sends a Firebase password-reset email to [email] via the shared
  /// AuthService (already used by apps/admin's own "Forgot password?" for
  /// exactly this purpose). Returns true once the request has been handled
  /// in a way that is indistinguishable, from the caller's side, between a
  /// real account and no account at all — see the `USER_NOT_FOUND` branch
  /// below for why that isn't automatic.
  Future<bool> sendPasswordReset(String email) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.sendPasswordResetEmail(email);
      return true;
    } on AuthException catch (e) {
      // Verified directly against a real Auth emulator while building this
      // phase: Firebase's sendOobCode endpoint genuinely DOES return a
      // distinguishable EMAIL_NOT_FOUND for a non-existent account (a real,
      // documented Firebase quirk, not the leak-proof behaviour it's often
      // assumed to have) — AuthService surfaces this as
      // UserNotFoundException, code 'USER_NOT_FOUND'. Treating it as a
      // FAILURE like every other AuthException would let an attacker
      // enumerate real associate emails by watching which ones "succeed"
      // vs. "fail" here — exactly what this phase's own security invariant
      // forbids. So this ONE code is deliberately normalised to success;
      // every other AuthException still fails honestly.
      if (e.code == 'USER_NOT_FOUND') {
        return true;
      }
      _error = e.message;
      return false;
    } catch (e) {
      debugPrint('Error sending associate password reset: $e');
      _error = 'Failed to send reset email. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Verifies [otp] and, on success, signs in and runs the same associate
  /// gate the email path runs.
  ///
  /// Returns true when the OTP ITSELF verified — not when the user turned out
  /// to be an approved associate. That distinction is deliberate: a pending,
  /// suspended or non-associate user has still authenticated successfully, so
  /// the OTP screen should close and let _AuthGate route them to the screen
  /// that explains their actual situation. Returning false here would strand
  /// them on the OTP screen with a correct code and no way forward.
  Future<bool> verifyPhoneOtpAndSignIn({
    required String phone,
    required String otp,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      _signInMethod = AssociateSignInMethod.phone;
      notifyListeners();

      await _authService.verifyPhoneOTP(phone: phone, otp: otp);

      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        _error = 'Sign in failed. Please try again.';
        return false;
      }

      // Same gate as the email path — one implementation, not two.
      await _loadUserData(uid);
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      debugPrint('Error verifying associate OTP: $e');
      _error = 'Failed to verify OTP. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _updateFCMToken(String uid) async {
    try {
      // Dynamically import to avoid issues on unsupported platforms
      final messaging = await _getMessagingInstance();
      if (messaging == null) return;

      final token = await messaging.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(uid).update({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ FCM token updated for associate: $uid');
      }
    } catch (e) {
      debugPrint('⚠️ FCM token update skipped: $e');
    }
  }

  /// Safe accessor for FirebaseMessaging (returns null if unavailable)
  Future<dynamic> _getMessagingInstance() async {
    try {
      // ignore: depend_on_referenced_packages
      final firebaseMessaging = await Future(() {
        return FirebaseMessaging.instance;
      });
      return firebaseMessaging;
    } catch (e) {
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _user = null;
    _signInMethod = AssociateSignInMethod.unknown;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
