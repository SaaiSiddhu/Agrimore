import 'dart:async';

import 'package:agrimore_services/agrimore_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Where a signed-in (or signed-out) person stands with the seller app.
/// The auth gate routes on this and nothing else (ADR §9, "Auth gate states").
enum SellerAccess {
  /// Resolving the Firebase session and seller records.
  loading,

  /// No Firebase user.
  signedOut,

  /// Signed in, but no seller application or seller account exists.
  noApplication,

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
  })  : _authServiceOverride = authService,
        _auth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance {
    _subscription = _auth!.authStateChanges().listen(_onAuthChanged);
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
  })  : _authServiceOverride = null,
        _auth = null,
        _firestore = null,
        _previewPhone = phone {
    _access = access;
    _pendingPhone = pendingPhone;
    _otpChannel = otpChannel;
    _testOtp = testOtp;
    _pendingGoogle = pendingGoogle;
    _lastError = error;
  }

  final AuthService? _authServiceOverride;
  AuthService get _authService => _authServiceOverride ?? AuthService();
  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;
  String? _previewPhone;
  StreamSubscription<User?>? _subscription;

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

  SellerAccess get access => _access;
  UserModel? get currentUser => _currentUser;
  bool get isBusy => _busy;
  SellerAuthError get lastError => _lastError;

  /// Server-provided message for [SellerAuthError.generic]/rate limits, when
  /// the server gave one; screens prefer their own localised copy.
  String? get lastErrorMessage => _lastErrorMessage;
  int? get retryAfterMs => _retryAfterMs;
  String? get pendingPhone => _pendingPhone;
  String get otpChannel => _otpChannel;
  String? get testOtp => _testOtp;
  bool get isTestMode => _testOtp != null;
  PendingGoogleIdentity? get pendingGoogle => _pendingGoogle;
  bool get googleLinkConflict => _googleLinkConflict;

  /// Phone on the signed-in account, for "no seller account on this number".
  String? get signedInPhone => _previewPhone ?? _currentUser?.phone ?? _auth?.currentUser?.phoneNumber;

  // ── Session ────────────────────────────────────────────────────────────────

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      _currentUser = null;
      _setAccess(SellerAccess.signedOut);
      return;
    }
    _setAccess(SellerAccess.loading);
    await _resolveAccess(user.uid);
  }

  /// Re-reads the seller records (the "Check status" action).
  Future<void> refresh() async {
    final uid = _auth?.currentUser?.uid;
    if (uid == null) return;
    await _resolveAccess(uid);
  }

  Future<void> _resolveAccess(String uid) async {
    final db = _firestore;
    if (db == null) return;
    try {
      final results = await Future.wait([
        db.collection('users').doc(uid).get(),
        db.collection('sellers').doc(uid).get(),
        db.collection('sellerRequests').doc(uid).get(),
      ]);
      final userDoc = results[0];
      final sellerDoc = results[1];
      final requestDoc = results[2];

      _currentUser = userDoc.exists ? UserModel.fromMap(userDoc.data()!, userDoc.id) : null;
      final role = _currentUser?.role;
      final userSellerStatus = userDoc.data()?['sellerStatus']?.toString();
      final sellerStatus = sellerDoc.data()?['status']?.toString();
      final requestStatus = requestDoc.data()?['status']?.toString();

      final access = resolveSellerAccess(
        role: role,
        sellerStatus: sellerStatus,
        sellerDocExists: sellerDoc.exists,
        userSellerStatus: userSellerStatus,
        requestStatus: requestStatus,
      );
      if (access == SellerAccess.approved) {
        unawaited(_updateFcmToken(uid));
      }
      _setAccess(access);
    } catch (e) {
      debugPrint('Seller access could not be resolved: $e');
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

  Future<void> _updateFcmToken(String uid) async {
    final db = _firestore;
    if (db == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await db.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await NotificationService.savePendingToken(uid);
    } catch (e) {
      debugPrint('FCM token update skipped for seller: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
