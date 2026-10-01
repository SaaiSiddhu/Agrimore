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
enum SellerAuthError { none, network, rateLimited, unavailable, invalidCode, conflict, generic }

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
  }) : _authServiceOverride = authService,
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
  }) : _authServiceOverride = null,
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

  UserModel? get currentUser =>
      _ownsProjection &&
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
  String? get pendingPhone => _pendingPhone;
  String get otpChannel => _otpChannel;
  String? get testOtp => _testOtp;
  bool get isTestMode => _testOtp != null;
  PendingGoogleIdentity? get pendingGoogle => _pendingGoogle;
  bool get googleLinkConflict => _googleLinkConflict;

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
          if (_disposed ||
              version != _authVersion ||
              user?.uid != _auth.currentUser?.uid) {
            return;
          }
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
  Future<bool> sendOtp(String phone, {String channel = 'sms'}) async {
    _startBusy();
    try {
      final result = await _authService.sendPhoneOTP(phone, channel: channel);
      _pendingPhone = phone;
      _otpChannel = result.channel;
      _testOtp = result.testOtp;
      return true;
    } on PhoneOtpRateLimitException catch (e) {
      _fail(SellerAuthError.rateLimited, e.message);
      _retryAfterMs = e.retryAfterMs;
      return false;
    } on PhoneOtpUnavailableException catch (e) {
      _fail(SellerAuthError.unavailable, e.message);
      return false;
    } on AuthException catch (e) {
      _fail(_classify(e.message), e.message);
      return false;
    } catch (e) {
      _fail(SellerAuthError.generic, null);
      return false;
    } finally {
      _endBusy();
    }
  }

  /// Verifies [otp] for the pending phone. On success the auth listener
  /// resolves [access]; a pending Google identity is then linked (Scenario B).
  Future<bool> verifyOtp(String otp) async {
    final phone = _pendingPhone;
    if (phone == null) return false;
    _startBusy();
    try {
      await _authService.verifyPhoneOTP(phone: phone, otp: otp);
      _testOtp = null;
      final google = _pendingGoogle;
      if (google != null) {
        final linked = await _authService.linkPendingGoogleCredential(google);
        _googleLinkConflict = !linked;
        _pendingGoogle = null;
      }
      return true;
    } on AuthException catch (e) {
      _fail(_classify(e.message, fallback: SellerAuthError.invalidCode), e.message);
      return false;
    } catch (e) {
      _fail(SellerAuthError.generic, null);
      return false;
    } finally {
      _endBusy();
    }
  }

  /// Back to the phone step.
  void resetOtp() {
    _pendingPhone = null;
    _testOtp = null;
    _clearError();
    notifyListeners();
  }

  // ── Google (secondary, phone-gated) ────────────────────────────────────────

  /// Returns true when signed in straight away (a linked identity). Returns
  /// false with [pendingGoogle] set when the phone must be verified first,
  /// or false with [lastError] set on failure / cancellation.
  Future<bool> continueWithGoogle() async {
    _startBusy();
    try {
      final pending = await _authService.acquireGoogleCredential();
      if (pending == null) return false; // cancelled by the user
      final resolution = await _authService.resolveGoogleIdentity(pending);
      if (resolution.linked) {
        await _authService.signInWithLinkedGoogleCredential(
          pending,
          expectedUid: resolution.expectedUid,
        );
        return true;
      }
      _pendingGoogle = pending;
      return false;
    } on AuthException catch (e) {
      _fail(_classify(e.message), e.message);
      return false;
    } catch (e) {
      _fail(SellerAuthError.generic, null);
      return false;
    } finally {
      _endBusy();
    }
  }

  void cancelGoogleLink() {
    _pendingGoogle = null;
    notifyListeners();
  }

  void acknowledgeGoogleConflict() {
    _googleLinkConflict = false;
    notifyListeners();
  }

  // ── Email (legacy) ─────────────────────────────────────────────────────────

  Future<bool> signInWithEmail(String email, String password) async {
    _startBusy();
    try {
      await _authService.signInWithEmail(email: email, password: password);
      return true;
    } on AuthException catch (e) {
      _fail(_classify(e.message), e.message);
      return false;
    } catch (e) {
      _fail(SellerAuthError.generic, null);
      return false;
    } finally {
      _endBusy();
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    _startBusy();
    try {
      await _authService.sendPasswordResetEmail(email);
      return true;
    } on AuthException catch (e) {
      _fail(_classify(e.message), e.message);
      return false;
    } catch (e) {
      _fail(SellerAuthError.generic, null);
      return false;
    } finally {
      _endBusy();
    }
  }

  Future<void> signOut() async {
    _pendingPhone = null;
    _testOtp = null;
    _pendingGoogle = null;
    await _authService.signOut();
  }

  void clearError() {
    _clearError();
    notifyListeners();
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

  void _startBusy() {
    _busy = true;
    _clearError();
    notifyListeners();
  }

  void _endBusy() {
    _busy = false;
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
      final token =
          await (_readPushToken?.call() ??
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
    ++_sessionEpoch;
    ++_accessRead;
    ++_authVersion;
    _currentUser = null;
    _cancelAuthSubscription();
    super.dispose();
  }
}
