import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:agrimore_core/constants/storage_constants.dart';

class AuthProvider with ChangeNotifier {
  // ============================================
  // SERVICES & FIREBASE
  // ============================================
  final AuthService _authService;
  final FirebaseFirestore _firestore;
  StreamSubscription<User?>? _authSubscription;
  String? _profileOwner;
  int _authEpoch = 0;
  int _profileRead = 0;
  int _authListenVersion = 0;
  bool _disposed = false;
  bool _signOutInFlight = false;
  bool _loginInFlight = false;
  String? _loginObservedOwner;
  bool _loginSuperseded = false;
  int _deletionRead = 0;
  bool _deletionInFlight = false;

  // ============================================
  // STATE VARIABLES
  // ============================================
  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isInitializing = true;
  String? _error;
  // Phase 17, Workstream 3: carries the original AuthException.code (e.g.
  // 'failed-precondition' from deleteUserData's refusal cases) alongside
  // the human-readable _error message, so a caller like
  // DeleteAccountScreen can distinguish "you need to do something first"
  // from a generic failure without parsing message text.
  String? _errorCode;
  DateTime? _lastAuthCheck;
  bool _rememberMe = false;
  int _failedLoginAttempts = 0;
  DateTime? _lockoutUntil;
  bool _isNewUser = false;

  // ============================================
  // GETTERS
  // ============================================
  UserModel? get currentUser {
    final owner = _authService.currentUserId;
    final user = _currentUser;
    return !_disposed &&
            owner != null &&
            _profileOwner == owner &&
            user?.uid == owner
        ? user
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
  String? get errorCode =>
      !_disposed && _profileOwner == _authService.currentUserId
          ? _errorCode
          : null;
  /// Mounted account forms can retain this version and owner across awaits.
  int get sessionVersion => _authEpoch;
  bool isSessionCurrent(String owner, int version) =>
      !_disposed &&
      _authSubscription != null &&
      owner == _profileOwner &&
      owner == _authService.currentUserId &&
      version == _authEpoch;

  // Missing profile data may also mean an account is still loading. Deletion
  // forms must distinguish that from an observed signed-out SDK session.
  bool get hasSignedOutSession => !_disposed &&
      _authSubscription != null && _authService.currentUserId == null;

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
  bool get isNewUser => currentUser != null && _isNewUser;

  // ============================================
  // CONSTRUCTOR
  // ============================================
  AuthProvider({
    AuthService? authService,
    FirebaseFirestore? firestore,
  })  : _authService = authService ?? AuthService(),
        _firestore = firestore ?? FirebaseFirestore.instance {
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
      // A stream may close synchronously while listen returns its handle.
      if (_disposed || version != _authListenVersion) {
        unawaited(subscription.cancel().catchError((Object _) {
          debugPrint('Auth subscription cleanup failed');
        }));
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
      unawaited(subscription.cancel().catchError((Object _) {
        debugPrint('Auth subscription cleanup failed');
      }));
    }
  }

  void _stopAuthUpdates(int version) {
    if (_disposed || version != _authListenVersion) return;
    _authListenVersion++;
    _cancelAuthSubscription();
    _authEpoch++;
    _profileRead++;
    _profileOwner = _authService.currentUserId;
    _currentUser = null;
    _isNewUser = false;
    _isInitializing = false;
    _isLoading = false;
    _error = 'Account updates paused. Please refresh your account.';
    _errorCode = null;
    notifyListeners();
  }

  void _bindProfileOwner(String? owner, {bool renew = false}) {
    if (_disposed || (!renew && owner == _profileOwner)) return;
    if (renew && _loginInFlight) {
      if (_loginObservedOwner != null) {
        _loginSuperseded = true;
      } else if (owner != null) {
        _loginObservedOwner = owner;
      }
    }
    _profileOwner = owner;
    _authEpoch++;
    _profileRead++;
    _currentUser = null;
    _isNewUser = false;
    _isLoading = false;
    _error = null;
    _errorCode = null;
    _isInitializing = owner != null;
  }

  bool _profileReadIsCurrent(String? owner, int epoch, int read) =>
      !_disposed &&
      owner == _profileOwner &&
      owner == _authService.currentUserId &&
      epoch == _authEpoch &&
      read == _profileRead;

  Future<void> _loadOwnedProfile(
      {bool restore = false, bool lastLogin = false}) async {
    if (_disposed) return;
    final owner = _authService.currentUserId;
    _bindProfileOwner(owner);
    final epoch = _authEpoch, read = ++_profileRead;
    if (restore) _isInitializing = owner != null;
    _isLoading = false;
    _error = null;
    _errorCode = null;
    notifyListeners();
    if (!_profileReadIsCurrent(owner, epoch, read)) return;
    try {
      final user = owner == null
          ? null
          : restore
              ? await _authService.restoreSession()
              : await _authService.getUserData(owner);
      if (!_profileReadIsCurrent(owner, epoch, read)) return;
      if (user != null && user.uid != owner) {
        throw StateError('Account profile ownership mismatch');
      }
      _currentUser = user;
      if (lastLogin && owner != null && user != null) {
        unawaited(_updateLastLogin(owner, epoch: epoch));
      }
    } catch (_) {
      if (!_profileReadIsCurrent(owner, epoch, read)) return;
      _currentUser = null;
      _isNewUser = false;
      _error = 'Unable to load your account. Please try again.';
      _errorCode = null;
    } finally {
      if (_profileReadIsCurrent(owner, epoch, read)) {
        _isInitializing = false;
        notifyListeners();
      }
    }
  }

  // ============================================
  // RESTORE SESSION ON APP START
  // ============================================
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
  }) =>
      _runOwnedSignIn(
          () async => PhoneAuthResult(
              user: await _authService.registerWithEmail(
                  email: email.trim(),
                  password: password,
                  name: name.trim(),
                  phone: phone?.trim()),
              isNewUser: false),
          event: 'registration',
          auditEmail: email,
          fallback: 'Registration failed. Please try again.',
          rememberEmail: email);

  // ============================================
  // SIGN IN WITH EMAIL
  // ============================================
  Future<bool> signInWithEmail(
          {required String email, required String password}) =>
      _runOwnedSignIn(
          () async => PhoneAuthResult(
              user: await _authService.signInWithEmail(
                  email: email.trim(), password: password),
              isNewUser: false),
          event: 'login',
          auditEmail: email,
          fallback: 'Sign in failed. Please try again.',
          rememberEmail: email);

  Future<bool> _runOwnedSignIn(
    Future<PhoneAuthResult> Function() command, {
    required String event,
    required String fallback,
    String? failureEvent,
    String? auditEmail,
    String? rememberEmail,
  }) async {
    final openingOwner = _authService.currentUserId;
    final openingEpoch = _authEpoch, openingRead = _profileRead;
    final observer = _authListenVersion;
    bool observing() =>
        !_disposed &&
        _authSubscription != null &&
        observer == _authListenVersion &&
        !_loginSuperseded;
    bool openingCurrent() =>
        observing() &&
        _profileReadIsCurrent(openingOwner, openingEpoch, openingRead);
    if (_loginInFlight ||
        _signOutInFlight ||
        _deletionInFlight ||
        !openingCurrent()) {
      return false;
    }
    if (isLocked) {
      _error = 'Too many attempts. Please try again later.';
      notifyListeners();
      return false;
    }
    _loginInFlight = true;
    _loginObservedOwner = openingOwner;
    _loginSuperseded = false;
    _isLoading = true;
    _error = null;
    _errorCode = null;
    notifyListeners();
    bool Function() current = openingCurrent;
    try {
      if (!current()) {
        return false;
      }
      final result = await command();
      if (!observing() || result.user.uid != _authService.currentUserId) {
        return false;
      }
      final owner = result.user.uid;
      _bindProfileOwner(owner);
      final epoch = _authEpoch, read = _profileRead + 1;
      current = () => observing() && _profileReadIsCurrent(owner, epoch, read);
      await _loadOwnedProfile();
      if (!current() || currentUser == null) {
        return false;
      }
      final user = currentUser!;
      _isNewUser = result.isNewUser;
      await _logAuthEvent(event, true, auditEmail ?? user.email,
          ownerId: owner);
      if (!current()) {
        return false;
      }
      await _updateFCMToken(owner, isSessionCurrent: current);
      if (!current()) {
        return false;
      }
      if (rememberEmail != null && _rememberMe) {
        await _storeCredentials(rememberEmail, isSessionCurrent: current);
        if (!current()) {
          return false;
        }
      }
      _resetFailedAttempts();
      _isLoading = false;
      notifyListeners();
      return current() && currentUser != null;
    } catch (failure) {
      if (!openingCurrent()) {
        return false;
      }
      final timedOut = failure is AuthException && failure.code == 'TIMEOUT';
      _errorCode = timedOut ? 'TIMEOUT' : null;
      _error = timedOut
          ? 'Still verifying — this is taking longer than usual. Please wait a moment.'
          : failure is FirebaseAuthException
              ? _getFirebaseErrorMessage(failure.code)
              : fallback;
      if (!timedOut) {
        _incrementFailedAttempts();
      }
      if (!openingCurrent()) {
        return false;
      }
      await _logAuthEvent(failureEvent ?? event, false, auditEmail ?? 'unknown',
          error: timedOut ? 'sign-in-timeout' : 'sign-in-failed',
          ownerId: openingOwner);
      if (!openingCurrent()) {
        return false;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } finally {
      if (current() && _isLoading) {
        _isLoading = false;
        notifyListeners();
      }
      _loginObservedOwner = null;
      _loginSuperseded = false;
      _loginInFlight = false;
    }
  }

  // ============================================
  // SEND PHONE OTP
  // ============================================
  /// Returns the [PhoneOtpSendResult] (including the EFFECTIVE delivery
  /// channel — see auth_service.dart) on success, or `null` on failure —
  /// callers should read [error] for the failure message.
  Future<PhoneOtpSendResult?> sendPhoneOTP(String phone,
      {String channel = 'sms'}) async {
    try {
      if (isLocked) {
        _error = 'Too many attempts. Please try again later.';
        notifyListeners();
        return null;
      }

      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('📱 Sending OTP to: $phone (channel: $channel)');

      final result = await _authService.sendPhoneOTP(phone, channel: channel);

      debugPrint('✅ OTP sent via ${result.channel}');

      _isLoading = false;
      notifyListeners();
      return result;
    } on AuthException catch (e) {
      debugPrint('❌ Send OTP error: ${e.message}');
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('❌ Send OTP error: $e');
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // ============================================
  // VERIFY PHONE OTP (LOGIN / SIGNUP)
  // ============================================
  Future<bool> verifyPhoneOTP(
          {required String phone, required String otp, String? name}) =>
      _runOwnedSignIn(
          () => _authService.verifyPhoneOTP(phone: phone, otp: otp, name: name),
          event: 'phone_login',
          auditEmail: phone,
          fallback: 'Unable to verify the code. Please try again.');

  // ============================================
  // PROFILE COMPLETION (Phase 16)
  // ============================================
  bool get needsProfileCompletion =>
      isLoggedIn && currentUser?.profileCompleted != true;

  Future<bool> _runOwnedProfileCommand(
    Future<UserModel?> Function() command, {
    String? auditEvent,
    String? auditEmail,
  }) async {
    final owner = _authService.currentUserId;
    final user = currentUser;
    final epoch = _authEpoch;
    if (owner == null || user == null || !isSessionCurrent(owner, epoch)) {
      return false;
    }
    // Profile reads and commands share a latest-intent ticket. This controls
    // presentation; already-issued server mutations cannot be cancelled.
    final read = ++_profileRead;
    bool current() =>
        isSessionCurrent(owner, epoch) && read == _profileRead;
    _isLoading = true;
    _error = null;
    _errorCode = null;
    notifyListeners();
    if (!current()) return false;

    UserModel? updated;
    String? failure;
    String? code;
    var confirmed = false;
    try {
      updated = await command();
      if (!current()) return false;
      if (updated != null && updated.uid != owner) {
        throw StateError('Account profile ownership mismatch');
      }
      confirmed = true;
    } on AuthException catch (error) {
      if (!current()) return false;
      failure = error.message;
      code = error.code;
    } catch (_) {
      if (!current()) return false;
      failure = 'Unable to update your profile. Please try again.';
    }
    if (!current()) return false;
    if (auditEvent != null) {
      await _logAuthEvent(auditEvent, confirmed, auditEmail ?? user.email,
          error: failure, ownerId: owner);
      if (!current()) return false;
    }
    if (confirmed && updated != null) _currentUser = updated;
    _error = failure;
    _errorCode = code;
    _isLoading = false;
    notifyListeners();
    return current() && confirmed;
  }

  Future<bool> sendEmailOtpForProfile(String email) =>
      _runOwnedProfileCommand(() async {
        await _authService.sendEmailOtpForProfile(email);
        return null;
      });

  Future<bool> verifyEmailOtpForProfile(
          {required String email, required String otp}) =>
      _runOwnedProfileCommand(() async {
        await _authService.verifyEmailOtpForProfile(email: email, otp: otp);
        return null;
      });

  Future<bool> completeUserProfile({
    required String name,
    required String email,
    required DateTime dateOfBirth,
    required String gender,
  }) =>
      _runOwnedProfileCommand(
        () => _authService.completeUserProfile(
          name: name,
          email: email,
          dateOfBirth: dateOfBirth,
          gender: gender,
        ),
        auditEvent: 'profile_completion',
        auditEmail: email,
      );

  // ============================================
  // CHANGE PHONE / EMAIL (post-completion profile edit)
  // ============================================

  /// [otp] must have been requested against [phone] via sendPhoneOTP first.
  Future<bool> changePhoneNumber(
          {required String phone, required String otp}) =>
      _runOwnedProfileCommand(
          () => _authService.changePhoneNumber(phone: phone, otp: otp));

  /// [email] must already be verified via verifyEmailOtpForProfile first.
  Future<bool> changeEmailAddress({required String email}) =>
      _runOwnedProfileCommand(
          () => _authService.changeEmailAddress(email: email));

  /// Date of birth remains server-only; ordinary profile fields use the
  /// existing Firestore edit path below.
  Future<bool> changeDateOfBirth({required DateTime dateOfBirth}) =>
      _runOwnedProfileCommand(
          () => _authService.changeDateOfBirth(dateOfBirth: dateOfBirth));

  // ============================================
  // SIGN IN WITH GOOGLE
  // ============================================
  Future<bool> signInWithGoogle() => _runOwnedSignIn(
      () async => PhoneAuthResult(
          user: await _authService.signInWithGoogle(), isNewUser: false),
      event: 'google_login',
      fallback: 'Google sign in failed. Please try again.');

  // ============================================
  // AUTH-3: GOOGLE AS A PHONE-VERIFICATION-GATED LINKED PROVIDER
  // ============================================
  // The screen owns the phone/OTP/Google-needs-phone sheet state and holds
  // a pending credential in memory. Returning Google and phone sign-in use
  // the same session-owned result path; acquisition/resolution and linking
  // are separate steps in that journey.

  /// Acquires a Google credential without signing in yet. Returns null on
  /// cancellation OR failure — [error] distinguishes them for the caller
  /// (null with no [error] set means the user simply cancelled).
  Future<PendingGoogleIdentity?> acquireGoogleCredential() async {
    try {
      _error = null;
      final pending = await _authService.acquireGoogleCredential();
      notifyListeners();
      return pending;
    } on AuthException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  /// Pure lookup — never creates a user, never signs in. Returns null only
  /// on a genuine failure (network, server error); read [error] then.
  Future<GoogleIdentityResolution?> resolveGoogleIdentity(
      PendingGoogleIdentity pending) async {
    try {
      _error = null;
      final resolution = await _authService.resolveGoogleIdentity(pending);
      notifyListeners();
      return resolution;
    } on AuthException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  /// Scenario A (returning, already linked): signs in directly, no OTP.
  Future<bool> signInWithLinkedGoogle(PendingGoogleIdentity pending,
          {String? expectedUid}) =>
      _runOwnedSignIn(
          () async => PhoneAuthResult(
              user: await _authService.signInWithLinkedGoogleCredential(pending,
                  expectedUid: expectedUid),
              isNewUser: false),
          event: 'google_returning_signin_success',
          failureEvent: 'google_returning_signin_failed',
          fallback: 'Google sign in failed. Please try again.');

  /// Scenario B, final step — called only once verifyPhoneOTP has already
  /// signed the caller in as the canonical phone-verified user. Attaches
  /// the Google credential to THAT user; never signs anyone out, never
  /// signs in with Google first. Returns whether the LINK itself succeeded
  /// — the phone login this follows has already succeeded either way, so a
  /// `false` here means "show a soft already-connected message", never
  /// "the login failed".
  Future<bool> linkGoogleToCurrentUser(PendingGoogleIdentity pending) async {
    try {
      final linked = await _authService.linkPendingGoogleCredential(pending);
      await _logAuthEvent(
        linked ? 'google_account_linked' : 'google_link_conflict',
        linked,
        _currentUser?.email ?? 'unknown',
      );
      notifyListeners();
      return linked;
    } catch (e) {
      debugPrint('⚠️ Google link error: $e');
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
    // PROFILE-8: gender, unlike dateOfBirth, has no rules block — the
    // plain full-object Firestore write below is a legitimate path for it
    // (see firestore.rules' ownerCannotChangePrivilegedFields() comment).
    String? gender,
  }) async {
    final user = currentUser;
    if (user == null) return false;
    return _runOwnedProfileCommand(
      () async {
        final updatedUser = user.copyWith(
          name: name ?? user.name,
          phone: phone ?? user.phone,
          photoUrl: photoUrl ?? user.photoUrl,
          gender: gender ?? user.gender,
        );
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update(updatedUser.toMap());
        return updatedUser;
      },
      auditEvent: 'profile_update',
    );
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
  }) =>
      _runOwnedProfileCommand(() async {
        await _authService.changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
        return null;
      }, auditEvent: 'password_change');

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
      await _logAuthEvent('password_reset_request', false, email,
          error: e.code);
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
    final owner = _authService.currentUserId;
    final epoch = _authEpoch;
    if (_signOutInFlight || owner == null ||
        !isSessionCurrent(owner, epoch)) {
      return;
    }
    final observer = _authListenVersion;
    final read = ++_profileRead;
    _signOutInFlight = true;
    // Only the opening account or its immediately observed signed-out
    // transition belongs to this operation. A renewed account is a new session.
    bool signedOut() => !_disposed && _authSubscription != null &&
        observer == _authListenVersion && _authEpoch == epoch + 1 &&
        _profileOwner == null && _authService.currentUserId == null;
    try {
      await _authService.signOut();
      if (!signedOut()) {
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      if (!signedOut()) {
        return;
      }
      await prefs.remove(StorageConstants.keyRememberEmail);
      if (!signedOut()) {
        return;
      }
      _currentUser = null;
      _error = null;
      _errorCode = null;
      _isNewUser = false;
      _resetFailedAttempts();
      if (!signedOut()) {
        return;
      }
      await _logAuthEvent('logout', true, 'user', ownerId: owner);
      if (!signedOut()) {
        return;
      }
      notifyListeners();
    } catch (_) {
      if (!isSessionCurrent(owner, epoch) || observer != _authListenVersion ||
          read != _profileRead) {
        return;
      }
      _error = 'Unable to sign out. Please try again.';
      notifyListeners();
    } finally {
      _signOutInFlight = false;
    }
  }

  // ============================================
  // DELETE ACCOUNT
  // ============================================
  bool _deletionIsCurrent(String owner, int epoch, int read,
      {bool signedOut = false}) {
    if (_disposed || read != _deletionRead) return false;
    final current = _authService.currentUserId;
    return signedOut && current == null ||
        current == owner && _profileOwner == owner && epoch == _authEpoch;
  }

  Future<bool> deleteAccount() async {
    if (_disposed || _deletionInFlight) return false;
    final owner = _authService.currentUserId;
    final user = currentUser;
    if (owner == null || user == null || user.uid != owner) {
      _error = 'Sign in to your account before deleting it.';
      _errorCode = 'unauthenticated';
      notifyListeners();
      return false;
    }
    final epoch = _authEpoch, read = ++_deletionRead;
    _deletionInFlight = true;
    _profileRead++;
    try {
      _isLoading = true;
      _error = null;
      _errorCode = null;
      notifyListeners();
      if (!_deletionIsCurrent(owner, epoch, read)) return false;
      await _authService.deleteAccount(expectedOwnerId: owner);
      if (!_deletionIsCurrent(owner, epoch, read, signedOut: true)) {
        return false;
      }
      _profileRead++;
      _currentUser = null;
      _isNewUser = false;
      _isInitializing = false;
      _resetFailedAttempts();
      await _logAuthEvent('account_deletion', true, user.email);
      return _deletionIsCurrent(owner, epoch, read, signedOut: true);
    } catch (e) {
      if (!_deletionIsCurrent(owner, epoch, read)) return false;
      if (e is AuthException) {
        _error = e.message;
        _errorCode = e.code;
      } else {
        _error = 'Failed to delete account. Please try again.';
        _errorCode = null;
      }
      await _logAuthEvent('account_deletion', false, user.email);
      return false;
    } finally {
      if (read == _deletionRead) _deletionInFlight = false;
      if (_deletionIsCurrent(owner, epoch, read, signedOut: true)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // ============================================
  // STORE CREDENTIALS (Remember Me)
  // ============================================
  Future<void> _storeCredentials(String email,
      {bool Function()? isSessionCurrent}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (isSessionCurrent != null && !isSessionCurrent()) {
        return;
      }
      await prefs.setString(StorageConstants.keyRememberEmail, email);
      if (isSessionCurrent != null && !isSessionCurrent()) {
        return;
      }
      await prefs.setBool(StorageConstants.keyRememberMe, true);
      debugPrint('Remember-email preference saved');
    } catch (e) {
      debugPrint('Unable to save remember-email preference');
    }
  }

  // ============================================
  // LOG AUTH EVENTS (Analytics)
  // ============================================
  // FIX-10 (finding N-16). FCMService().initialize() in main.dart saves a
  // token only once, at app cold-start, and only when a user is ALREADY
  // signed in at that exact moment — a returning customer who was signed in
  // before relaunching is fine, but a customer's FIRST sign-in within a
  // given app session (the common case: fresh install, or signing in again
  // after a logout without restarting the app) never gets a token saved,
  // because initialize() already ran with no user before the login screen
  // even rendered. Mirrors apps/delivery/lib/providers/auth_provider.dart's
  // token field shape and arrayUnion. The caller retains sign-in ownership
  // across token retrieval before dispatching a write for that same owner,
  // independent of FCMService's app-startup timing.
  Future<void> _updateFCMToken(String uid,
      {bool Function()? isSessionCurrent}) async {
    try {
      if (isSessionCurrent != null && !isSessionCurrent()) {
        return;
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (isSessionCurrent != null && !isSessionCurrent()) {
        return;
      }
      if (token != null) {
        await _firestore.collection('users').doc(uid).set({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (isSessionCurrent != null && !isSessionCurrent()) {
          return;
        }
        debugPrint('Notification token saved');
      }
    } catch (e) {
      debugPrint('Notification token save skipped');
    }
  }

  Future<void> _logAuthEvent(
    String eventType,
    bool success,
    String email, {
    String? error,
    String? ownerId,
  }) async {
    try {
      await _firestore.collection('auth_logs').add({
        'event': eventType,
        'success': success,
        'email': email,
        'error': error,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': 'flutter',
        'uid': ownerId ?? _currentUser?.uid,
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
    if (_disposed) return;
    _disposed = true;
    _authListenVersion++;
    _authEpoch++;
    _profileRead++;
    _cancelAuthSubscription();
    _currentUser = null;
    _isNewUser = false;
    super.dispose();
  }
}
