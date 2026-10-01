// lib/providers/auth_provider.dart
//
// Phase DLV-C1 — one rider session at a time.
//   - The profile is loaded ONCE per sign-in, by the auth-change listener;
//     signIn() waits for that load instead of loading again (it used to load
//     twice: authStateChanges + signIn).
//   - Every auth change starts a new session number; an answer that arrives
//     for an older session (sign-out, or another rider signed in meanwhile)
//     is dropped, so rider A's data never lands in rider B's session.
//   - Problems are typed ([RiderAuthProblem]) and worded by the screen from
//     the ARB file — never a raw FirebaseAuthException message.
//   - This device's push token is added to users/{uid}.fcmTokens while the
//     rider may work, moved on refresh, and removed — then invalidated on the
//     device — at sign-out. Before, a signed-out rider's offers kept ringing
//     on the phone for whoever signed in next.
//   - An admin changing the rider's status refreshes the ID token so
//     claim-based rules see it now, not at the next hourly refresh.
//   - A read that only reached the device cache is "unavailable", never
//     "does not exist" (the web SDK reports cached misses when offline).
//   - DLV-A1: an account with no rider record yet (mid-registration, or a
//     registration that failed after the account was created) is NOT signed
//     out: it is [needsRegistration], and the gate resumes registration.
// Firebase lives behind lib/auth/rider_account_source.dart; the logic here
// is covered by test/auth_session_test.dart.
import 'dart:async';

import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter/foundation.dart';

import '../auth/rider_account_source.dart';

/// Why the rider is not (fully) signed in. Worded by the UI.
enum RiderAuthProblem {
  wrongCredentials,
  invalidEmail,
  tooManyAttempts,
  network,
  accountDisabled,
  notDeliveryPartner,
  profileUnavailable,
  unknown,
}

/// Sign-in error code → [RiderAuthProblem].
RiderAuthProblem authProblemOf(String code) => switch (code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' ||
      'INVALID_LOGIN_CREDENTIALS' =>
        RiderAuthProblem.wrongCredentials,
      'invalid-email' => RiderAuthProblem.invalidEmail,
      'too-many-requests' => RiderAuthProblem.tooManyAttempts,
      'network-request-failed' => RiderAuthProblem.network,
      'user-disabled' => RiderAuthProblem.accountDisabled,
      _ => RiderAuthProblem.unknown,
    };

class DeliveryAuthProvider extends ChangeNotifier {
  DeliveryAuthProvider(
      {RiderAuthGateway? gateway,
      RiderAccountStore? store,
      RiderPushTokens? pushTokens})
      : _gateway = gateway ?? FirebaseRiderAuthGateway(),
        _store = store ?? FirestoreRiderAccountStore(),
        _push = pushTokens ?? FcmPushTokens() {
    _authSub =
        _gateway.uidChanges.listen(_onAuthChanged, onError: _onAuthError);
  }

  final RiderAuthGateway _gateway;
  final RiderAccountStore _store;
  final RiderPushTokens _push;

  StreamSubscription<String?>? _authSub;
  StreamSubscription<ProfileRead>? _partnerSub;
  StreamSubscription<String>? _tokenSub;

  int _session = 0;
  int _tokenWork = 0;
  String? _sessionOwner;
  bool _disposed = false;
  Completer<void>? _sessionReady;

  UserModel? _user;
  bool _isLoading = true;
  // A sign-in in flight: the button spins, the form stays (a failed attempt
  // must not wipe what the rider typed).
  bool _signingIn = false;
  bool _needsRegistration = false;
  RiderAuthProblem? _problem;
  // Why the previous session was refused; kept across the sign-out it causes.
  RiderAuthProblem? _carryProblem;

  // Phase DLV-1B: onboarding status of delivery_partners/{uid}, kept live so
  // a suspension takes effect while the app is open.
  RiderKycStatus? _kycStatus;
  String? _statusReason;
  // DLV-3A: the server's view of duty (the silent-rider sweep can set it false).
  bool? _partnerOnline;
  String? _offlineReason;
  String? _registeredToken;

  bool get _stateCurrent => !_disposed && _sessionOwner == _gateway.currentUid;

  /// Capture with [sessionUid] before an asynchronous account action.
  int get sessionVersion => _session;

  /// A queued SDK event must not leave the previous owner actionable.
  /// A confirmed deletion may complete after its own single sign-out event.
  bool isCurrentSession(String? uid, int version,
      {bool allowSignedOut = false}) {
    if (_disposed) return false;
    if (_session == version && _gateway.currentUid == uid) return true;
    return allowSignedOut &&
        uid != null &&
        _gateway.currentUid == null &&
        ((_session == version && _sessionOwner == uid) ||
            (_session == version + 1 && _sessionOwner == null));
  }

  UserModel? get user =>
      _stateCurrent && _user?.uid == _gateway.currentUid ? _user : null;

  /// The gate also waits when the SDK changed before its event arrived.
  bool get isLoading =>
      !_disposed && (_stateCurrent ? _isLoading : _gateway.currentUid != null);
  bool get signingIn => !_disposed && _signingIn;
  bool get needsRegistration =>
      _stateCurrent && _needsRegistration && _gateway.currentUid != null;
  RiderAuthProblem? get problem => _stateCurrent ? _problem : null;
  bool get isAuthenticated =>
      user != null && problem == null && (kycStatus?.canOperate ?? false);
  bool get isDeliveryPartner => user?.isDeliveryPartner ?? false;
  RiderKycStatus? get kycStatus => _stateCurrent ? _kycStatus : null;
  String? get statusReason => _stateCurrent ? _statusReason : null;
  bool? get partnerOnline => _stateCurrent ? _partnerOnline : null;
  String? get offlineReason => _stateCurrent ? _offlineReason : null;
  bool get isBlocked =>
      user != null && kycStatus != null && !kycStatus!.canOperate;
  bool get profileUnavailable =>
      problem == RiderAuthProblem.profileUnavailable && sessionUid != null;
  String? get sessionUid => _disposed ? null : _gateway.currentUid;

  @visibleForTesting
  String? get registeredToken => _stateCurrent ? _registeredToken : null;

  void _cancel(StreamSubscription<dynamic>? subscription) {
    if (subscription == null) return;
    unawaited(subscription.cancel().catchError((Object error) {
      debugPrint('Rider listener cancellation failed');
    }));
  }

  void _onAuthError(Object error) {
    if (_disposed) return;
    ++_session;
    _sessionOwner = _gateway.currentUid;
    _endSessionState();
    _isLoading = false;
    _problem =
        _sessionOwner == null ? null : RiderAuthProblem.profileUnavailable;
    notifyListeners();
    _completeReady();
  }

  Future<void> _onAuthChanged(String? uid) async {
    if (_disposed || uid != _gateway.currentUid) return;
    final session = ++_session;
    _sessionOwner = uid;
    _endSessionState();
    if (uid == null) {
      _user = null;
      _problem = _carryProblem;
      _carryProblem = null;
      _isLoading = false;
      notifyListeners();
      _completeReady();
      return;
    }
    _carryProblem = null;
    _isLoading = true;
    notifyListeners();
    if (!isCurrentSession(uid, session)) return;
    await _loadUserData(uid, session);
    if (!isCurrentSession(uid, session)) return;
    _isLoading = false;
    notifyListeners();
    _completeReady();
  }

  void _completeReady() {
    final r = _sessionReady;
    if (r != null && !r.isCompleted) r.complete();
  }

  void _endSessionState() {
    ++_tokenWork;
    _cancel(_partnerSub);
    _partnerSub = null;
    _cancel(_tokenSub);
    _tokenSub = null;
    _registeredToken = null;
    _user = null;
    _kycStatus = null;
    _statusReason = null;
    _partnerOnline = null;
    _offlineReason = null;
    _problem = null;
    _needsRegistration = false;
  }

  void _applyPartnerData(Map<String, dynamic>? data) {
    _partnerOnline = data?['isOnline'] == true;
    final off = data?['offlineReason'];
    _offlineReason = off is String && off.isNotEmpty ? off : null;
    _kycStatus = RiderKycStatus.fromWire(data?['status'] as String?);
    final reason = switch (_kycStatus) {
      RiderKycStatus.rejected => data?['rejectionReason'],
      RiderKycStatus.suspended => data?['suspensionReason'],
      _ => null,
    };
    _statusReason =
        (reason is String && reason.trim().isNotEmpty) ? reason.trim() : null;
  }

  Future<void> _loadUserData(String uid, int session) async {
    try {
      final userRead = await _store.user(uid);
      if (!isCurrentSession(uid, session)) return;
      if (!userRead.exists) {
        if (userRead.missing) {
          _needsRegistration = true;
        } else {
          _problem = RiderAuthProblem.profileUnavailable;
        }
        return;
      }
      final role = userRead.data?['role'];
      final user = UserModel.fromMap(userRead.data!, uid);
      // A profile with no role yet may still register; any other role
      // belongs to another app.
      final unregistered = role == null || (role is String && role.isEmpty);
      if (!unregistered && !user.isDeliveryPartner) {
        return _refuse(RiderAuthProblem.notDeliveryPartner, uid, session);
      }
      final partner = await _store.partner(uid);
      if (!isCurrentSession(uid, session)) return;
      if (!partner.exists) {
        if (partner.missing) {
          _needsRegistration = true;
        } else {
          _problem = RiderAuthProblem.profileUnavailable;
        }
        return;
      }
      if (unregistered) {
        _needsRegistration = true;
        return;
      }
      _user = user;
      _applyPartnerData(partner.data);
      if (_kycStatus!.canOperate) unawaited(_registerToken(uid, session));
      _watchPartner(uid, session);
    } catch (e) {
      if (!isCurrentSession(uid, session)) return;
      debugPrint('Rider profile load failed: $e');
      _problem = RiderAuthProblem.profileUnavailable;
    }
  }

  /// Signs out a user who may not use this app; the reason survives the
  /// sign-out so the sign-in screen can say why.
  Future<void> _refuse(
      RiderAuthProblem problem, String uid, int session) async {
    if (!isCurrentSession(uid, session)) return;
    _carryProblem = problem;
    _user = null;
    await _gateway.signOut();
  }

  void _watchPartner(String uid, int session) {
    _cancel(_partnerSub);
    _partnerSub = _store.watchPartner(uid).listen((read) {
      if (!isCurrentSession(uid, session) || user == null) return;
      if (!read.exists && read.fromCache) return; // not an answer
      final before = _kycStatus;
      _applyPartnerData(read.data);
      if (before != _kycStatus) {
        // Claims follow status (roleClaims.ts): fetch them now.
        unawaited(_gateway.refreshClaims());
        final operating = _kycStatus?.canOperate ?? false;
        if (operating && !(before?.canOperate ?? false)) {
          unawaited(_registerToken(uid, session));
        } else if (!operating && _registeredToken != null) {
          unawaited(_unregisterToken(uid, session));
        }
      }
      notifyListeners();
    }, onError: (Object e) {
      debugPrint('Partner status listener error: $e');
    });
  }

  bool _canRegister(String uid, int session, int work) =>
      isCurrentSession(uid, session) &&
      work == _tokenWork &&
      user?.uid == uid &&
      (kycStatus?.canOperate ?? false);

  Future<void> _registerToken(String uid, int session) async {
    if (!isCurrentSession(uid, session)) return;
    final work = ++_tokenWork;
    try {
      final token = await _push.current();
      if (token == null || !_canRegister(uid, session, work)) return;
      await _store.addToken(uid, token);
      if (!_canRegister(uid, session, work)) return;
      _registeredToken = token;
      _cancel(_tokenSub);
      _tokenSub = _push.refreshed.listen((fresh) async {
        if (!isCurrentSession(uid, session) ||
            !(kycStatus?.canOperate ?? false) ||
            fresh == _registeredToken) {
          return;
        }
        final refreshWork = ++_tokenWork;
        final old = _registeredToken;
        try {
          if (old != null) await _store.removeToken(uid, old);
          if (!_canRegister(uid, session, refreshWork)) return;
          await _store.addToken(uid, fresh);
          if (_canRegister(uid, session, refreshWork)) _registeredToken = fresh;
        } catch (e) {
          debugPrint('Refreshed push token not saved');
        }
      }, onError: (Object error) {
        debugPrint('Push token refresh listener failed');
      });
    } catch (e) {
      debugPrint('Push token not saved');
    }
  }

  /// Remove only the captured owner's token; never cancel a newer listener.
  Future<void> _unregisterToken(String uid, int session) async {
    if (!isCurrentSession(uid, session)) return;
    final work = ++_tokenWork;
    try {
      final token = registeredToken ?? await _push.current();
      if (!isCurrentSession(uid, session) || work != _tokenWork) return;
      _cancel(_tokenSub);
      _tokenSub = null;
      _registeredToken = null;
      if (token != null) await _store.removeToken(uid, token);
    } catch (e) {
      debugPrint('Push token not removed');
    }
  }

  /// Signs in. True when the account may use this app (working, or blocked
  /// with a reason to show). The profile is loaded by the auth listener.
  Future<bool> signIn(String email, String password) async {
    if (_disposed) return false;
    _problem = null;
    _carryProblem = null;
    _signingIn = true;
    notifyListeners();
    final ready = _sessionReady = Completer<void>();
    try {
      // The password is used exactly as typed — never trimmed.
      await _gateway.signIn(email.trim(), password);
      await ready.future
          .timeout(DeliveryTiming.signInAccountWait, onTimeout: () {});
      return _user != null;
    } on RiderAuthFailure catch (e) {
      debugPrint('Sign-in refused: ${e.code}');
      _problem = authProblemOf(e.code);
      return false;
    } finally {
      if (identical(_sessionReady, ready)) _sessionReady = null;
      _signingIn = false;
      notifyListeners();
    }
  }

  /// After a successful submitRiderApplication: read the new record.
  Future<void> registrationSubmitted() => _onAuthChanged(_gateway.currentUid);

  /// Reads the profile again (after "profile unavailable").
  Future<void> retryProfile() => _onAuthChanged(_gateway.currentUid);

  /// Requests a password-reset email. Null = "if an account exists, a link
  /// was sent" (the same for known and unknown emails); otherwise the problem
  /// with the request itself.
  Future<RiderAuthProblem?> sendPasswordReset(String email) async {
    try {
      await _gateway.sendPasswordReset(email.trim());
      return null;
    } on RiderAuthFailure catch (e) {
      return authProblemOf(e.code);
    }
  }

  /// Removes and invalidates this device's push token, then signs out.
  /// Callers stop location first; the session gate clears everything else.
  Future<void> signOut() async {
    final uid = sessionUid;
    final session = sessionVersion;
    if (!isCurrentSession(uid, session)) return;
    if (uid != null) await _unregisterToken(uid, session);
    if (!isCurrentSession(uid, session)) return;
    await _push.forget();
    if (!isCurrentSession(uid, session)) return;
    await _gateway.signOut();
  }

  void clearError() {
    if (_disposed) return;
    _problem = null;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_session;
    _cancel(_authSub);
    _authSub = null;
    _endSessionState();
    _completeReady();
    super.dispose();
  }
}
