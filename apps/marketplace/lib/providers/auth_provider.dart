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
      if (_currentUser != null) await _updateFCMToken(_currentUser!.uid);

      if (_rememberMe) {
        await _storeCredentials(email);
      }

      debugPrint('✅ Registration successful: ${_currentUser?.uid}');

      _resetFailedAttempts();
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint(
          '❌ Firebase Auth Registration error: ${e.code} - ${e.message}');
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

      await _logAuthEvent('login', true, email);
      if (_currentUser != null) await _updateFCMToken(_currentUser!.uid);

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
  Future<bool> verifyPhoneOTP({
    required String phone,
    required String otp,
    String? name,
  }) async {
    try {
      if (isLocked) {
        _error = 'Too many attempts. Please try again later.';
        notifyListeners();
        return false;
      }

      _isLoading = true;
      _error = null;
      _errorCode = null;
      notifyListeners();

      debugPrint('🔐 Verifying OTP for: $phone');

      final result = await _authService.verifyPhoneOTP(
        phone: phone,
        otp: otp,
        name: name,
      );

      _currentUser = result.user;
      _isNewUser = result.isNewUser;

      await _logAuthEvent('phone_login', true, phone);
      if (_currentUser != null) await _updateFCMToken(_currentUser!.uid);

      debugPrint(
          '✅ Phone login successful: ${_currentUser?.uid} (new: $_isNewUser)');

      _resetFailedAttempts();
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      debugPrint('❌ Verify OTP error: ${e.message}');
      _error = e.message;
      _errorCode = e.code;
      // A client-side timeout isn't evidence of a wrong code — the request
      // may still be completing server-side (observed: sign-in landing tens
      // of seconds after the client gave up). Don't count it toward lockout.
      if (e.code != 'TIMEOUT') _incrementFailedAttempts();
      await _logAuthEvent('phone_login', false, phone, error: e.message);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('❌ Verify OTP error: $e');
      _error = e.toString().replaceAll('Exception: ', '');
      _errorCode = null;
      _incrementFailedAttempts();
      await _logAuthEvent('phone_login', false, phone, error: e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

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

      await _logAuthEvent(
          'google_login', true, _currentUser?.email ?? 'unknown');
      if (_currentUser != null) await _updateFCMToken(_currentUser!.uid);

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
      await _logAuthEvent('google_login', false, 'unknown',
          error: e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ============================================
  // AUTH-3: GOOGLE AS A PHONE-VERIFICATION-GATED LINKED PROVIDER
  // ============================================
  // Thin wrappers over AuthService's own additive methods, mirroring the
  // existing signInWithGoogle()/verifyPhoneOTP() pattern above: set
  // loading/error, delegate, update _currentUser, notify. The screen owns
  // which sheet state to show (phone / OTP / google-needs-phone) — this
  // provider only ever holds the RESULT of each step, never that UI state,
  // matching how phone/OTP already divide the work between login_screen.dart
  // and this class.

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
      {String? expectedUid}) async {
    try {
      if (isLocked) {
        _error = 'Too many attempts. Please try again later.';
        notifyListeners();
        return false;
      }

      _isLoading = true;
      _error = null;
      notifyListeners();

      _currentUser = await _authService.signInWithLinkedGoogleCredential(
        pending,
        expectedUid: expectedUid,
      );
      // A returning, already-linked Google identity is never a new
      // customer by definition — unlike verifyPhoneOTP(), this path has no
      // server-reported isNewUser to read, so it must be stated explicitly
      // rather than left at whatever _isNewUser last held.
      _isNewUser = false;

      await _logAuthEvent('google_returning_signin_success', true,
          _currentUser?.email ?? 'unknown');
      if (_currentUser != null) await _updateFCMToken(_currentUser!.uid);

      _resetFailedAttempts();
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      _incrementFailedAttempts();
      await _logAuthEvent('google_returning_signin_failed', false, 'unknown',
          error: e.message);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _incrementFailedAttempts();
      await _logAuthEvent('google_returning_signin_failed', false, 'unknown',
          error: e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

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

      await _logAuthEvent(
          'password_change', true, _currentUser?.email ?? 'unknown');

      debugPrint('✅ Password changed successfully');

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase Auth Password change error: ${e.code}');
      _error = _getFirebaseErrorMessage(e.code);
      await _logAuthEvent(
          'password_change', false, _currentUser?.email ?? 'unknown',
          error: e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('❌ Error changing password: $e');
      _error = 'Failed to change password. Please try again.';
      await _logAuthEvent(
          'password_change', false, _currentUser?.email ?? 'unknown',
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
  // FIX-10 (finding N-16). FCMService().initialize() in main.dart saves a
  // token only once, at app cold-start, and only when a user is ALREADY
  // signed in at that exact moment — a returning customer who was signed in
  // before relaunching is fine, but a customer's FIRST sign-in within a
  // given app session (the common case: fresh install, or signing in again
  // after a logout without restarting the app) never gets a token saved,
  // because initialize() already ran with no user before the login screen
  // even rendered. Mirrors apps/delivery/lib/providers/auth_provider.dart's
  // own _updateFCMToken(uid) exactly — same field shape, same arrayUnion —
  // called explicitly right after every genuine new-session success below,
  // independent of FCMService's app-startup timing.
  Future<void> _updateFCMToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(uid).set({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('✅ FCM token saved for user: $uid');
      }
    } catch (e) {
      debugPrint('⚠️ FCM token save skipped: $e');
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
