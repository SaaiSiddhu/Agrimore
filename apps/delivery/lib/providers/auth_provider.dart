// lib/providers/auth_provider.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:agrimore_core/agrimore_core.dart';

class DeliveryAuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _user;
  bool _isLoading = true;
  String? _error;

  // Phase DLV-1B: the onboarding status of delivery_partners/{uid}, typed, and
  // the reason an admin gave for a rejection or suspension. Kept live by
  // [_partnerSubscription] so a suspension takes effect while the app is open
  // (the custom claim only reaches the ID token on its next refresh).
  RiderKycStatus? _kycStatus;
  String? _statusReason;
  // DLV-3A: the server's view of duty — the silent-rider sweep can set it
  // false (offlineReason 'no_location') while the app thinks it is online.
  bool? _partnerOnline;
  String? _offlineReason;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _partnerSubscription;

  DeliveryAuthProvider() {
    _init();
  }

  // Getters
  UserModel? get user => _user;
  bool get isLoading => _isLoading;

  /// Signed in AND allowed to work. A pending, rejected or suspended partner
  /// is signed in but not authenticated for the dashboard — see [isBlocked].
  bool get isAuthenticated =>
      _user != null && _error == null && (_kycStatus?.canOperate ?? false);
  bool get isDeliveryPartner => _user?.isDeliveryPartner ?? false;
  String? get error => _error;
  RiderKycStatus? get kycStatus => _kycStatus;
  String? get statusReason => _statusReason;
  /// delivery_partners.isOnline as last read; null before the first read.
  bool? get partnerOnline => _partnerOnline;
  String? get offlineReason => _offlineReason;

  /// Signed in as a delivery partner whose onboarding status does not allow
  /// work (pending, rejected, suspended, deactivated).
  bool get isBlocked =>
      _user != null && _kycStatus != null && !_kycStatus!.canOperate;

  void _init() {
    _auth.authStateChanges().listen((firebaseUser) async {
      if (firebaseUser != null) {
        await _loadUserData(firebaseUser.uid);
      } else {
        _clearPartnerState();
        _user = null;
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  void _clearPartnerState() {
    _partnerSubscription?.cancel();
    _partnerSubscription = null;
    _kycStatus = null;
    _statusReason = null;
    _partnerOnline = null;
    _offlineReason = null;
  }

  /// Reads status and reason from a delivery_partners document.
  /// An absent `status` reads as pending (RiderKycStatus.fromWire), matching
  /// roleClaims.ts, which never grants the claim without 'approved'.
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

  void _watchPartner(String uid) {
    _partnerSubscription?.cancel();
    _partnerSubscription = _firestore
        .collection('delivery_partners')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      if (_user == null) return;
      final wasOperating = _kycStatus?.canOperate ?? false;
      _applyPartnerData(snap.data());
      final nowOperating = _kycStatus?.canOperate ?? false;
      if (!wasOperating && nowOperating) {
        // Approved while the app was open: register for order pushes now.
        _updateFCMToken(uid);
      }
      notifyListeners();
    }, onError: (Object e) {
      // Keep the last known status; the next app start re-reads it.
      debugPrint('⚠️ Partner status listener error: $e');
    });
  }

  Future<void> _loadUserData(String uid) async {
    try {
      _error = null;
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _user = UserModel.fromFirestore(doc);

        // STRICT ROLE CHECK FOR DELIVERY APP
        if (!_user!.isDeliveryPartner) {
          debugPrint(
              '⛔ Unauthorized access attempt by non-delivery: ${_user!.email}');
          await _auth.signOut();
          _user = null;
          _clearPartnerState();
          _error = 'Access denied. You are not a delivery partner.';
        } else {
          final partnerDoc =
              await _firestore.collection('delivery_partners').doc(uid).get();
          if (partnerDoc.exists) {
            _applyPartnerData(partnerDoc.data());
            if (_kycStatus!.canOperate) {
              await _updateFCMToken(uid);
            }
            _watchPartner(uid);
          } else {
            await _auth.signOut();
            _user = null;
            _clearPartnerState();
            _error = 'Could not find delivery partner details.';
          }
        }
      }
    } catch (e) {
      _error = 'Failed to load user data';
      debugPrint('Error loading user: $e');
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        await _loadUserData(credential.user!.uid);
        // The role and onboarding-status checks are handled in _loadUserData.

        // If _user is null after _loadUserData, it means they were rejected and signed out
        if (_user == null) {
          _isLoading = false;
          notifyListeners();
          return false;
        }

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
        debugPrint('✅ FCM token updated for driver: $uid');
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
    _clearPartnerState();
    await _auth.signOut();
    _user = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _partnerSubscription?.cancel();
    super.dispose();
  }
}
