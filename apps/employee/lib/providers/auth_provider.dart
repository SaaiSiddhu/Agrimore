import 'dart:async';
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
/// post-authentication gate in [_loadUserData].
enum AssociateSignInMethod { unknown, phone, email }

class EmployeeAuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  // Phase 18, Workstream 2: the SHARED phone-OTP implementation, already used
  // by apps/marketplace. AuthService is a singleton (factory AuthService() =>
  // _instance), so this costs nothing and adds no second OTP code path.
  final AuthService _authService;

  StreamSubscription<User?>? _authSubscription;
  String? _profileOwner;
  int _sessionEpoch = 0;
  int _profileRead = 0;
  int _authVersion = 0;
  bool _disposed = false;
  bool _approved = false;
  String? _gateError;
  String? _pendingRefusal;
  UserModel? _user;
  bool _isLoading = true;
  String? _error;
  AssociateSignInMethod _signInMethod = AssociateSignInMethod.unknown;

  // Cached identity never grants access without its completed approval decision.
  bool get _ownsProjection =>
      !_disposed && _profileOwner == _auth.currentUser?.uid;
  UserModel? get user =>
      _ownsProjection && _user?.uid == _auth.currentUser?.uid ? _user : null;
  bool get isLoading =>
      !_disposed && (!_ownsProjection ? _auth.currentUser != null : _isLoading);
  bool get isAuthenticated =>
      user?.isEmployee == true && _approved && error == null;
  bool get isEmployee => user?.isEmployee ?? false;
  String? get error => _ownsProjection ? _gateError ?? _error : null;

  EmployeeAuthProvider({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    AuthService? authService,
  }) : _auth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _authService = authService ?? AuthService() {
    _profileOwner = _auth.currentUser?.uid;
    _listenForAuth();
  }

  void _listenForAuth() {
    if (_disposed || _authSubscription != null) return;
    final version = ++_authVersion;
    try {
      final subscription = _auth.authStateChanges().listen(
        (firebaseUser) {
          if (_disposed ||
              version != _authVersion ||
              firebaseUser?.uid != _auth.currentUser?.uid) {
            return;
          }
          _bindOwner(firebaseUser?.uid, renew: true);
          final epoch = _sessionEpoch, read = _profileRead;
          notifyListeners();
          if (firebaseUser != null &&
              _readIsCurrent(firebaseUser.uid, epoch, read)) {
            unawaited(_loadUserData(firebaseUser.uid));
          }
        },
        onError: (Object error) => _stopAuthUpdates(version),
        onDone: () => _stopAuthUpdates(version),
      );
      if (_disposed || version != _authVersion) {
        unawaited(
          subscription.cancel().catchError((Object error) {
            debugPrint('Associate auth listener cleanup failed');
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
          debugPrint('Associate auth listener cleanup failed');
        }),
      );
    }
  }

  void _stopAuthUpdates(int version) {
    if (_disposed || version != _authVersion) return;
    ++_authVersion;
    _cancelAuthSubscription();
    _pendingRefusal = null;
    _bindOwner(_auth.currentUser?.uid, renew: true);
    _isLoading = false;
    if (_profileOwner != null) {
      _gateError = 'Account updates paused. Please refresh your account.';
    }
    notifyListeners();
  }

  void _bindOwner(String? owner, {bool renew = false}) {
    if (_disposed || (!renew && owner == _profileOwner)) return;
    final refusal = owner == null ? _pendingRefusal : null;
    _pendingRefusal = null;
    _profileOwner = owner;
    ++_sessionEpoch;
    ++_profileRead;
    _user = null;
    _approved = false;
    _gateError = refusal;
    _error = null;
    _isLoading = owner != null;
  }

  bool _readIsCurrent(String uid, int epoch, int read) =>
      !_disposed &&
      uid == _profileOwner &&
      uid == _auth.currentUser?.uid &&
      epoch == _sessionEpoch &&
      read == _profileRead;

  Future<void> refreshUserData() async {
    if (_disposed) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    _listenForAuth();
    await _loadUserData(uid);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _readDocument(
    String collection,
    String uid,
    int epoch,
    int read,
  ) {
    final reference = _firestore.collection(collection).doc(uid);
    return reference.get().timeout(
      const Duration(milliseconds: 2500),
      onTimeout: () {
        if (!_readIsCurrent(uid, epoch, read)) {
          throw StateError('Associate read superseded');
        }
        return reference.get(const GetOptions(source: Source.cache));
      },
    );
  }

  Future<void> _loadUserData(String uid) async {
    if (_disposed || _auth.currentUser?.uid != uid) return;
    _bindOwner(uid);
    final epoch = _sessionEpoch, read = ++_profileRead;
    _user = null;
    _approved = false;
    _gateError = null;
    _error = null;
    _isLoading = true;
    notifyListeners();
    if (!_readIsCurrent(uid, epoch, read)) return;
    try {
      // Preserve the bounded cache fallback, but do not publish a user while
      // the corresponding approval check is still in flight.
      final document = await _readDocument('users', uid, epoch, read);
      if (!_readIsCurrent(uid, epoch, read)) return;
      final profile = document.exists
          ? UserModel.fromFirestore(document)
          : null;
      if (profile == null || !profile.isEmployee) {
        final subject = _signInMethod == AssociateSignInMethod.phone
            ? "This mobile number isn't registered"
            : "This account isn't registered";
        await _refuse(
          uid,
          epoch,
          read,
          '$subject as an Agrimore Sales Associate. To become one, apply '
          'from the Agrimore customer app under Profile.',
        );
        return;
      }
      final employee = await _readDocument('employees', uid, epoch, read);
      if (!_readIsCurrent(uid, epoch, read)) return;
      if (!employee.exists) {
        await _refuse(
          uid,
          epoch,
          read,
          'We could not find your Sales Associate profile. '
          'Please contact support.',
        );
        return;
      }
      final status = employee.data()?['status'] ?? 'pending';
      _user = profile;
      if (status == 'suspended') {
        _gateError = 'Your associate account has been suspended.';
      } else if (status != 'approved') {
        _gateError = 'Your account is pending approval by an administrator.';
      } else {
        _approved = true;
      }
      _isLoading = false;
      notifyListeners();
      if (_approved && _readIsCurrent(uid, epoch, read)) {
        await _updateFCMToken(uid, epoch: epoch, read: read);
      }
    } catch (_) {
      if (!_readIsCurrent(uid, epoch, read)) return;
      _user = null;
      _approved = false;
      _gateError = 'Failed to load user data';
      debugPrint('Associate profile could not be resolved');
    } finally {
      if (_readIsCurrent(uid, epoch, read)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _refuse(String uid, int epoch, int read, String message) async {
    if (!_readIsCurrent(uid, epoch, read)) return;
    _pendingRefusal = message;
    _gateError = message;
    _user = null;
    _approved = false;
    notifyListeners();
    if (!_readIsCurrent(uid, epoch, read)) return;
    await _auth.signOut();
    // The owned null callback normally carries the refusal. Accommodate the
    // SDK updating currentUser before delivering that callback as well.
    if (!_disposed &&
        _profileOwner == uid &&
        epoch == _sessionEpoch &&
        read == _profileRead &&
        _auth.currentUser == null) {
      _bindOwner(null);
      notifyListeners();
    }
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

  Future<void> _updateFCMToken(String uid, {int? epoch, int? read}) async {
    final capturedEpoch = epoch ?? _sessionEpoch,
        capturedRead = read ?? _profileRead;
    if (const bool.fromEnvironment(
      'USE_FIREBASE_EMULATOR',
      defaultValue: false,
    )) {
      return;
    }
    bool current() =>
        _approved &&
        user?.isEmployee == true &&
        _readIsCurrent(uid, capturedEpoch, capturedRead);
    if (!current()) return;
    try {
      final messaging = await _getMessagingInstance();
      if (messaging == null || !current()) return;
      final token = await messaging.getToken();
      if (token == null || !current()) return;
      await _firestore.collection('users').doc(uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      debugPrint('Associate push registration skipped');
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
    if (_disposed) return;
    final uid = _auth.currentUser?.uid, epoch = _sessionEpoch;
    if (uid == null || uid != _profileOwner) return;
    await _auth.signOut();
    if (_disposed ||
        epoch != _sessionEpoch ||
        _profileOwner != uid ||
        (_auth.currentUser != null && _auth.currentUser?.uid != uid)) {
      return;
    }
    _user = null;
    _approved = false;
    _signInMethod = AssociateSignInMethod.unknown;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_authVersion;
    ++_sessionEpoch;
    ++_profileRead;
    _approved = false;
    _user = null;
    _cancelAuthSubscription();
    super.dispose();
  }


}
