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
  bool _observedAuth = false;
  int _commandSerial = 0;
  _EmployeeAuthAction? _activeCommand;
  bool _approved = false;
  String? _gateError;
  String? _pendingRefusal;
  UserModel? _user;
  bool _isLoading = true;
  String? _error;
  int? _retryAfterMs;
  AssociateSignInMethod _signInMethod = AssociateSignInMethod.unknown;

  // Cached identity never grants access without its completed approval decision.
  bool get _ownsProjection =>
      !_disposed && _profileOwner == _auth.currentUser?.uid;
  UserModel? get user =>
      _ownsProjection && _user?.uid == _auth.currentUser?.uid ? _user : null;
  bool get isLoading =>
      !_disposed &&
      (_activeCommand != null ||
          (!_ownsProjection ? _auth.currentUser != null : _isLoading));
  bool get isAuthenticated =>
      user?.isEmployee == true && _approved && error == null;
  bool get isEmployee => user?.isEmployee ?? false;
  String? get error => _ownsProjection ? _gateError ?? _error : null;
  int? get retryAfterMs => _ownsProjection ? _retryAfterMs : null;

  EmployeeAuthProvider({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    AuthService? authService,
  })  : _auth = firebaseAuth ?? FirebaseAuth.instance,
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
          _activeCommand?.observe(firebaseUser?.uid);
          _observedAuth = true;
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
    _observedAuth = false;
    _retireCommand();
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
    if (owner == null && refusal == null) {
      _signInMethod = AssociateSignInMethod.unknown;
    }
    _profileOwner = owner;
    ++_sessionEpoch;
    ++_profileRead;
    _user = null;
    _approved = false;
    _gateError = refusal;
    _error = null;
    _retryAfterMs = null;
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
    _retryAfterMs = null;
    _isLoading = true;
    notifyListeners();
    if (!_readIsCurrent(uid, epoch, read)) return;
    try {
      // Preserve the bounded cache fallback, but do not publish a user while
      // the corresponding approval check is still in flight.
      final document = await _readDocument('users', uid, epoch, read);
      if (!_readIsCurrent(uid, epoch, read)) return;
      final profile =
          document.exists ? UserModel.fromFirestore(document) : null;
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
    final action = _activeCommand;
    // A sign-in callback may resolve the profile before the SDK call returns
    // its credential. Defer destructive cleanup until that command binds the
    // exact resulting UID; otherwise a queued callback can sign out a new user.
    if (action != null && action.transitioned && !action.bound) return;
    await _signOutRefusedOwner(uid, epoch, read);
  }

  Future<void> _signOutRefusedOwner(String uid, int epoch, int read) async {
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
    return await _runAuthCommand<bool>((action) async {
          action.allowTransition();
          _signInMethod = AssociateSignInMethod.email;
          final credential = await _auth.signInWithEmailAndPassword(
              email: email, password: password);
          final uid = credential.user?.uid;
          if (uid == null || !action.bindResult(uid)) return false;
          await _loadUserData(uid);
          if (!action.isCurrent) return false;
          if (_pendingRefusal != null && _auth.currentUser?.uid == uid) {
            await _signOutRefusedOwner(uid, _sessionEpoch, _profileRead);
          }
          return action.isCurrent && user?.uid == uid;
        }, fallback: 'Authentication failed. Please try again.') ??
        false;
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
    return _runAuthCommand<PhoneOtpSendResult?>((action) async {
      final result = await _authService.sendPhoneOTP(phone, channel: channel);
      return action.isCurrent ? result : null;
    }, fallback: 'Failed to send OTP. Please try again.');
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
    return await _runAuthCommand<bool>((action) async {
          try {
            await _authService.sendPasswordResetEmail(email);
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
            if (e.code == 'USER_NOT_FOUND') return action.isCurrent;
            rethrow;
          }
          return action.isCurrent;
        }, fallback: 'Failed to send reset email. Please try again.') ??
        false;
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
    return await _runAuthCommand<bool>((action) async {
          _signInMethod = AssociateSignInMethod.phone;
          action.allowTransition();
          final result =
              await _authService.verifyPhoneOTP(phone: phone, otp: otp);
          final uid = result.user.uid;
          if (!action.bindResult(uid)) return false;
          await _loadUserData(uid);
          if (!action.isCurrent &&
              _auth.currentUser == null &&
              _gateError != null) {
            action.phoneRefused = true;
            return true;
          }
          if (!action.isCurrent) return false;
          if (_pendingRefusal != null && _auth.currentUser?.uid == uid) {
            await _signOutRefusedOwner(uid, _sessionEpoch, _profileRead);
            action.phoneRefused = true;
          }
          return action.isCurrent && user?.uid == uid || action.phoneRefused;
        }, fallback: 'Failed to verify OTP. Please try again.') ??
        false;
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
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid != _profileOwner) return;
    await _runAuthCommand<bool>((action) async {
      action.allowTransition(signingOut: true);
      await _auth.signOut();
      return action.isCurrent;
    }, fallback: 'Could not sign out. Please try again.');
  }

  Future<T?> _runAuthCommand<T>(Future<T> Function(_EmployeeAuthAction) run,
      {required String fallback}) async {
    if (_disposed ||
        !_observedAuth ||
        _authSubscription == null ||
        _activeCommand != null ||
        !_ownsProjection) {
      return null;
    }
    final action = _EmployeeAuthAction(this, ++_commandSerial);
    _activeCommand = action;
    _isLoading = true;
    _error = null;
    _retryAfterMs = null;
    notifyListeners();
    try {
      if (!action.isCurrent) return null;
      final result = await run(action);
      return action.isCurrent || action.phoneRefused ? result : null;
    } catch (error) {
      if (!action.isCurrent || (action.transitioned && !action.bound)) {
        return null;
      }
      if (error is PhoneOtpRateLimitException) {
        _error = 'Too many verification requests. Please try again later.';
        _retryAfterMs = error.retryAfterMs;
      } else if (error is PhoneOtpUnavailableException) {
        _error =
            'Phone verification is currently unavailable. Please try again later.';
      } else {
        _error = fallback;
      }
      debugPrint('Associate authentication command failed');
      return null;
    } finally {
      if (identical(_activeCommand, action)) {
        _activeCommand = null;
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _retireCommand() {
    ++_commandSerial;
    _activeCommand = null;
    _isLoading = false;
  }

  void clearError() {
    if (_disposed) return;
    _error = null;
    _retryAfterMs = null;
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
    _observedAuth = false;
    _retireCommand();
    ++_authVersion;
    ++_sessionEpoch;
    ++_profileRead;
    _approved = false;
    _user = null;
    _cancelAuthSubscription();
    super.dispose();
  }
}

class _EmployeeAuthAction {
  _EmployeeAuthAction(this.provider, this.serial)
      : observer = provider._authVersion,
        epoch = provider._sessionEpoch,
        owner = provider._profileOwner;
  final EmployeeAuthProvider provider;
  final int serial, observer;
  int epoch;
  String? owner;
  bool allowed = false, signingOut = false, transitioned = false, bound = false;
  bool phoneRefused = false;
  bool get isCurrent =>
      !provider._disposed &&
      provider._observedAuth &&
      provider._authSubscription != null &&
      observer == provider._authVersion &&
      serial == provider._commandSerial &&
      identical(provider._activeCommand, this) &&
      epoch == provider._sessionEpoch &&
      owner == provider._profileOwner &&
      owner == provider._auth.currentUser?.uid;
  void allowTransition({bool signingOut = false}) {
    if (!isCurrent) return;
    allowed = true;
    this.signingOut = signingOut;
  }

  void observe(String? uid) {
    if (!allowed ||
        transitioned ||
        (signingOut ? uid != null : uid == null) ||
        (bound && owner != uid)) {
      provider._retireCommand();
      return;
    }
    transitioned = true;
    owner = uid;
    epoch = provider._sessionEpoch + 1;
  }

  bool bindResult(String uid) {
    if (provider._disposed ||
        !provider._observedAuth ||
        !allowed ||
        observer != provider._authVersion ||
        serial != provider._commandSerial ||
        !identical(provider._activeCommand, this) ||
        provider._auth.currentUser?.uid != uid ||
        (transitioned && owner != uid)) {
      return false;
    }
    owner = uid;
    bound = true;
    provider._bindOwner(uid);
    epoch = provider._sessionEpoch;
    return isCurrent;
  }
}
