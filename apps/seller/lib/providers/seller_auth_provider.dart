import 'dart:async';

import 'package:agrimore_services/agrimore_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../app/emulator.dart';

/// Where a signed-in (or signed-out) person stands with the seller app.
/// The auth gate routes on this and nothing else (ADR §9, "Auth gate states").
enum SellerAccess {
  /// Resolving the Firebase session and seller records.
  loading,

  /// No Firebase user.
  signedOut,

  /// Signed in, but no seller application or seller account exists.
  noApplication,

  /// An application is in progress (or reopened after a rejection).
  draft,

  /// Application submitted, waiting for an admin decision.
  pending,

  /// Application rejected.
  rejected,

  /// Seller account suspended.
  suspended,

  /// Approved seller — the workspace opens.
  approved,
}

/// Outcome of a sign-in step, for screens to map onto localised copy.
enum SellerAuthError {
  none,
  network,
  rateLimited,
  unavailable,
  invalidCode,
  conflict,
  generic
}

/// Seller-app session: phone OTP (primary), Google linked to a verified phone
/// (secondary) and email + password (legacy admin-created accounts only).
///
/// All sign-in mechanics live in the shared [AuthService]; this provider only
/// sequences them and resolves [access]. The OTP is never generated on the
/// device — in the server's test mode the code arrives in the send response
/// (Phase SEC-P0) and is exposed as [testOtp].
class SellerAuthProvider with ChangeNotifier {
  SellerAuthProvider({
    AuthService? authService,
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    Future<String?> Function()? readPushToken,
    Future<void> Function(String)? savePendingPushToken,
  })  : _authServiceOverride = authService,
        _readPushToken = readPushToken,
        _savePendingPushToken = savePendingPushToken,
        _auth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance {
    _sessionOwner = _auth!.currentUser?.uid;
    _listenForAuth();
  }

  /// A provider frozen in one state, with no Firebase behind it — for widget
  /// tests and previews of the auth screens only.
  @visibleForTesting
  SellerAuthProvider.preview({
    SellerAccess access = SellerAccess.signedOut,
    String? pendingPhone,
    String otpChannel = 'sms',
    String? testOtp,
    PendingGoogleIdentity? pendingGoogle,
    SellerAuthError error = SellerAuthError.none,
    String? phone,
    UserModel? user,
  })  : _authServiceOverride = null,
        _readPushToken = null,
        _savePendingPushToken = null,
        _auth = null,
        _firestore = null,
        _previewPhone = phone {
    _access = access;
    _pendingPhone = pendingPhone;
    _otpChannel = otpChannel;
    _testOtp = testOtp;
    _pendingGoogle = pendingGoogle;
    _lastError = error;
    _currentUser = user;
  }

  final AuthService? _authServiceOverride;
  AuthService get _authService => _authServiceOverride ?? AuthService();
  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;
  final Future<String?> Function()? _readPushToken;
  final Future<void> Function(String)? _savePendingPushToken;
  String? _previewPhone;
  StreamSubscription<User?>? _subscription;
  String? _sessionOwner;
  int _sessionEpoch = 0;
  int _accessRead = 0;
  int _authVersion = 0;
  bool _disposed = false;
  bool _observedAuth = false;
  int _commandSerial = 0;
  _SellerAuthAction? _activeCommand;

  bool get _ownsProjection =>
      !_disposed && (_auth == null || _sessionOwner == _auth.currentUser?.uid);

  SellerAccess _access = SellerAccess.loading;
  UserModel? _currentUser;
  bool _busy = false;
  SellerAuthError _lastError = SellerAuthError.none;
  String? _lastErrorMessage;
  int? _retryAfterMs;

  // Phone OTP flow state
  String? _pendingPhone;
  String _otpChannel = 'sms';
  String? _testOtp;

  // Google linking state (Scenario B: verify phone first, then link)
  PendingGoogleIdentity? _pendingGoogle;
  bool _googleLinkConflict = false;

  SellerAccess get access {
    if (_disposed) return SellerAccess.signedOut;
    if (!_ownsProjection) {
      return _auth?.currentUser == null
          ? SellerAccess.signedOut
          : SellerAccess.loading;
    }
    return _access;
  }

  UserModel? get currentUser => _ownsProjection &&
          (_auth == null || _currentUser?.uid == _auth.currentUser?.uid)
      ? _currentUser
      : null;
  bool get isBusy => !_disposed && _busy;
  SellerAuthError get lastError =>
      _ownsProjection ? _lastError : SellerAuthError.none;

  /// Server-provided message for [SellerAuthError.generic]/rate limits, when
  /// the server gave one; screens prefer their own localised copy.
  String? get lastErrorMessage => _ownsProjection ? _lastErrorMessage : null;
  int? get retryAfterMs => _ownsProjection ? _retryAfterMs : null;
  String? get pendingPhone => _ownsProjection ? _pendingPhone : null;
  String get otpChannel => _otpChannel;
  String? get testOtp => _ownsProjection ? _testOtp : null;
  bool get isTestMode => testOtp != null;
  PendingGoogleIdentity? get pendingGoogle =>
      _ownsProjection ? _pendingGoogle : null;
  bool get googleLinkConflict => _ownsProjection && _googleLinkConflict;

  /// Phone on the signed-in account, for "no seller account on this number".
  String? get signedInPhone => _disposed
      ? null
      : _auth == null
          ? _previewPhone ?? _currentUser?.phone
          : currentUser?.phone ?? _auth.currentUser?.phoneNumber;

  // ── Session ────────────────────────────────────────────────────────────────

  void _listenForAuth() {
    if (_disposed || _auth == null || _subscription != null) return;
    final version = ++_authVersion;
    try {
      final subscription = _auth.authStateChanges().listen(
        (user) {
          if (_disposed || version != _authVersion) return;
          if (user?.uid != _auth.currentUser?.uid) {
            // Do not project a queued old owner, but revoke its command episode.
            _retireCommand();
            return;
          }
          _activeCommand?.observe(user?.uid);
          _observedAuth = true;
          _bindOwner(user?.uid, renew: true);
          final epoch = _sessionEpoch, read = _accessRead;
          notifyListeners();
          if (user != null && _readIsCurrent(user.uid, epoch, read)) {
            unawaited(_resolveAccess(user.uid));
          }
        },
        onError: (Object error) => _stopAuthUpdates(version),
        onDone: () => _stopAuthUpdates(version),
      );
      // A stream can close synchronously before listen returns its subscription.
      if (_disposed || version != _authVersion) {
        unawaited(
          subscription.cancel().catchError((Object error) {
            debugPrint('Seller auth listener cleanup failed');
          }),
        );
      } else {
        _subscription = subscription;
      }
    } catch (_) {
      _stopAuthUpdates(version);
    }
  }

  void _cancelAuthSubscription() {
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      unawaited(
        subscription.cancel().catchError((Object error) {
          debugPrint('Seller auth listener cleanup failed');
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
    _bindOwner(_auth?.currentUser?.uid, renew: true);
    if (_sessionOwner != null) {
      _access = SellerAccess.noApplication;
      _lastError = SellerAuthError.network;
    }
    notifyListeners();
  }

  void _bindOwner(String? uid, {bool renew = false}) {
    if (_disposed || (!renew && uid == _sessionOwner)) return;
    _sessionOwner = uid;
    _clearPendingIdentity();
    ++_sessionEpoch;
    ++_accessRead;
    _currentUser = null;
    _clearError();
    _access = uid == null ? SellerAccess.signedOut : SellerAccess.loading;
  }

  bool _readIsCurrent(String uid, int epoch, int read) =>
      !_disposed &&
      uid == _sessionOwner &&
      uid == _auth?.currentUser?.uid &&
      epoch == _sessionEpoch &&
      read == _accessRead;

  /// Re-reads the seller records (the "Check status" action).
  Future<void> refresh() async {
    if (_disposed || _auth == null) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    _listenForAuth();
    _bindOwner(uid);
    await _resolveAccess(uid);
  }

  Future<void> _resolveAccess(String uid) async {
    final db = _firestore;
    final epoch = _sessionEpoch, read = ++_accessRead;
    if (db == null || !_readIsCurrent(uid, epoch, read)) return;
    _clearError();
    notifyListeners();
    if (!_readIsCurrent(uid, epoch, read)) return;
    try {
      final results = await Future.wait([
        db.collection('users').doc(uid).get(),
        db.collection('sellers').doc(uid).get(),
        db.collection('sellerRequests').doc(uid).get(),
      ]);
      if (!_readIsCurrent(uid, epoch, read)) return;
      if (results.any((document) => document.id != uid)) {
        throw StateError('Seller record ownership mismatch');
      }
      final userDoc = results[0];
      final sellerDoc = results[1];
      final requestDoc = results[2];
      final user = userDoc.exists
          ? UserModel.fromMap(userDoc.data()!, userDoc.id)
          : null;
      final access = resolveSellerAccess(
        role: user?.role,
        sellerStatus: sellerDoc.data()?['status']?.toString(),
        sellerDocExists: sellerDoc.exists,
        userSellerStatus: userDoc.data()?['sellerStatus']?.toString(),
        requestStatus: requestDoc.data()?['status']?.toString(),
      );
      _currentUser = user;
      _setAccess(access);
      // Listeners can change the SDK session while receiving the access update.
      if (access == SellerAccess.approved && _readIsCurrent(uid, epoch, read)) {
        unawaited(_updateFcmToken(uid, epoch, read));
      }
    } catch (_) {
      if (!_readIsCurrent(uid, epoch, read)) return;
      debugPrint('Seller access could not be resolved');
      _currentUser = null;
      _lastError = SellerAuthError.network;
      _setAccess(SellerAccess.noApplication);
    }
  }

  /// Pure routing decision — unit-tested without Firebase.
  ///
  /// Order matters: an explicit suspension or rejection wins over a role;
  /// an approved `sellers` record needs the `seller` role too (the role is
  /// what firestore.rules trust); a legacy seller (role set, no status
  /// recorded anywhere) keeps working as before this phase.
  @visibleForTesting
  static SellerAccess resolveSellerAccess({
    required String? role,
    required String? sellerStatus,
    required bool sellerDocExists,
    required String? userSellerStatus,
    required String? requestStatus,
  }) {
    if (sellerStatus == 'suspended') return SellerAccess.suspended;
    if (role == 'seller' && (sellerStatus == null || sellerStatus == 'approved')) return SellerAccess.approved;
    // A reopened application (rejected → draft) wins over the stale
    // users.sellerStatus 'rejected' left by the earlier review.
    if (requestStatus == 'draft') return SellerAccess.draft;
    if (sellerStatus == 'rejected' || userSellerStatus == 'rejected' || requestStatus == 'rejected') {
      return SellerAccess.rejected;
    }
    if (role == 'seller') {
      if (sellerStatus == null || sellerStatus == 'approved') return SellerAccess.approved;
      if (sellerStatus == 'pending') return SellerAccess.pending;
    }
    if (sellerStatus == 'pending' || userSellerStatus == 'pending' || requestStatus == 'pending') {
      return SellerAccess.pending;
    }
    if (sellerStatus == 'approved') {
      // Approved record but the role has not landed yet (claims sync lag).
      return SellerAccess.pending;
    }
    return SellerAccess.noApplication;
  }

  // ── Phone OTP ──────────────────────────────────────────────────────────────

  /// Sends a code to [phone] (`+91XXXXXXXXXX`). Returns true when the OTP
  /// step should open.
  Future<bool> sendOtp(String phone, {String channel = 'sms'}) =>
      _runAuthCommand((action) async {
        final result = await _authService.sendPhoneOTP(phone, channel: channel);
        if (!action.isCurrent) return false;
        _pendingPhone = phone;
        _otpChannel = result.channel;
        _testOtp = result.testOtp;
        return true;
      }, fallback: 'Could not send a verification code. Please try again.');

  Future<bool> verifyOtp(String otp) async {
    final phone = _pendingPhone, google = _pendingGoogle;
    if (phone == null) return false;
    return _runAuthCommand((action) async {
      action.allowTransition();
      final result = await _authService.verifyPhoneOTP(phone: phone, otp: otp);
      if (!action.bindResult(result.user.uid)) return false;
      _testOtp = null;
      if (google != null) {
        try {
          final linked = await _authService.linkPendingGoogleCredential(google);
          if (!action.isCurrent) return false;
          _googleLinkConflict = !linked;
        } catch (_) {
          if (!action.isCurrent) return false;
          // Linking cannot undo a confirmed phone sign-in.
          _googleLinkConflict = true;
        }
        _pendingGoogle = null;
      }
      return action.isCurrent;
    },
        fallback: 'Could not verify the code. Please try again.',
        fallbackError: SellerAuthError.invalidCode);
  }

  void resetOtp() {
    if (_disposed) return;
    _retireCommand();
    _clearPendingIdentity();
    _clearError();
    notifyListeners();
  }

  Future<bool> continueWithGoogle() => _runAuthCommand((action) async {
        final pending = await _authService.acquireGoogleCredential();
        if (!action.isCurrent || pending == null) return false;
        final resolution = await _authService.resolveGoogleIdentity(pending);
        if (!action.isCurrent) return false;
        if (resolution.linked) {
          action.allowTransition();
          final result = await _authService.signInWithLinkedGoogleCredential(
              pending,
              expectedUid: resolution.expectedUid);
          return action.bindResult(result.uid);
        }
        _pendingGoogle = pending;
        return false;
      }, fallback: 'Google sign in could not complete. Please try again.');

  void cancelGoogleLink() {
    if (_disposed) return;
    _retireCommand();
    _pendingGoogle = null;
    notifyListeners();
  }

  void acknowledgeGoogleConflict() {
    if (_disposed) return;
    _googleLinkConflict = false;
    notifyListeners();
  }

  Future<bool> signInWithEmail(String email, String password) =>
      _runAuthCommand((action) async {
        action.allowTransition();
        final result = await _authService.signInWithEmail(
            email: email, password: password);
        return action.bindResult(result.uid);
      }, fallback: 'Sign in failed. Please try again.');

  Future<bool> sendPasswordReset(String email) =>
      _runAuthCommand((action) async {
        try {
          await _authService.sendPasswordResetEmail(email);
        } on AuthException catch (error) {
          // Known and unknown addresses have the same reset result.
          if (error.code != 'USER_NOT_FOUND') rethrow;
        }
        return action.isCurrent;
      }, fallback: 'Could not send a reset link. Please try again.');

  Future<void> signOut() async {
    await _runAuthCommand((action) async {
      action.allowTransition(signingOut: true);
      _clearPendingIdentity();
      await _authService.signOut();
      return action.isCurrent;
    }, fallback: 'Could not sign out. Please try again.');
  }

  void clearError() {
    if (_disposed) return;
    _clearError();
    notifyListeners();
  }

  Future<bool> _runAuthCommand(
    Future<bool> Function(_SellerAuthAction action) command, {
    required String fallback,
    SellerAuthError fallbackError = SellerAuthError.generic,
  }) async {
    if (_disposed ||
        !_observedAuth ||
        _subscription == null ||
        _auth == null ||
        !_ownsProjection ||
        _activeCommand != null) {
      return false;
    }
    final action = _SellerAuthAction(this, ++_commandSerial);
    _activeCommand = action;
    _busy = true;
    _clearError();
    notifyListeners();
    try {
      if (!action.isCurrent) return false;
      final result = await command(action);
      return action.isCurrent && result;
    } catch (error) {
      if (!action.isCurrent || (action.transitioned && !action.bound)) {
        return false;
      }
      if (error is PhoneOtpRateLimitException) {
        _fail(SellerAuthError.rateLimited,
            'Too many verification requests. Please try again later.');
        _retryAfterMs = error.retryAfterMs;
      } else if (error is PhoneOtpUnavailableException) {
        _fail(SellerAuthError.unavailable,
            'Phone verification is currently unavailable. Please try again later.');
      } else {
        final kind = error is AuthException
            ? _classify(error.message, fallback: fallbackError)
            : fallbackError;
        _fail(kind, fallback);
      }
      return false;
    } finally {
      // A retired command must not stop the spinner of its replacement.
      if (identical(_activeCommand, action)) {
        _activeCommand = null;
        _busy = false;
        notifyListeners();
      }
    }
  }

  void _clearPendingIdentity() {
    _pendingPhone = null;
    _testOtp = null;
    _pendingGoogle = null;
    _googleLinkConflict = false;
  }

  void _retireCommand() {
    ++_commandSerial;
    _activeCommand = null;
    _busy = false;
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  SellerAuthError _classify(String message, {SellerAuthError fallback = SellerAuthError.generic}) {
    final m = message.toLowerCase();
    if (m.contains('network') || m.contains('timed out') || m.contains('too slow')) {
      return SellerAuthError.network;
    }
    if (m.contains('invalid otp') || m.contains('expired') || m.contains('no otp')) {
      return SellerAuthError.invalidCode;
    }
    if (m.contains('already') && m.contains('account')) return SellerAuthError.conflict;
    return fallback;
  }

  void _setAccess(SellerAccess value) {
    _access = value;
    notifyListeners();
  }

  void _fail(SellerAuthError kind, String? message) {
    _lastError = kind;
    _lastErrorMessage = message;
  }

  void _clearError() {
    _lastError = SellerAuthError.none;
    _lastErrorMessage = null;
    _retryAfterMs = null;
  }

  Future<void> _updateFcmToken(String uid, int epoch, int read) async {
    final db = _firestore;
    // D13: an emulator run registers no push token — a real device token in
    // emulator data makes every server notification try live FCM.
    if (db == null ||
        kSellerUsesEmulator ||
        !_readIsCurrent(uid, epoch, read) ||
        _access != SellerAccess.approved) {
      return;
    }
    try {
      final token = await (_readPushToken?.call() ??
          FirebaseMessaging.instance.getToken());
      if (token == null || !_readIsCurrent(uid, epoch, read)) return;
      await db.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!_readIsCurrent(uid, epoch, read)) return;
      await (_savePendingPushToken?.call(uid) ??
          NotificationService.savePendingToken(uid));
    } catch (_) {
      debugPrint('FCM token update skipped for seller');
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
    _observedAuth = false;
    _retireCommand();
    _clearPendingIdentity();
    ++_sessionEpoch;
    ++_accessRead;
    ++_authVersion;
    _currentUser = null;
    _cancelAuthSubscription();
    super.dispose();
  }
}

/// A provider-owned command episode. Only its explicitly allowed first SDK
/// transition can move ownership; later callbacks revoke it even for one UID.
class _SellerAuthAction {
  _SellerAuthAction(this.provider, this.serial)
      : observer = provider._authVersion,
        epoch = provider._sessionEpoch,
        owner = provider._sessionOwner;
  final SellerAuthProvider provider;
  final int serial, observer;
  int epoch;
  String? owner;
  bool allowed = false, signingOut = false, transitioned = false, bound = false;

  bool get isCurrent =>
      !provider._disposed &&
      provider._observedAuth &&
      provider._subscription != null &&
      observer == provider._authVersion &&
      serial == provider._commandSerial &&
      identical(provider._activeCommand, this) &&
      epoch == provider._sessionEpoch &&
      owner == provider._sessionOwner &&
      owner == provider._auth?.currentUser?.uid;

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
        provider._auth?.currentUser?.uid != uid ||
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
