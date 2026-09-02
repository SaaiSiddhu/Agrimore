// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:agrimore_core/agrimore_core.dart';

class EmployeeAuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _user;
  bool _isLoading = true;
  String? _error;

  EmployeeAuthProvider() {
    _init();
  }

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

  Future<void> _loadUserData(String uid) async {
    try {
      _error = null;
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _user = UserModel.fromFirestore(doc);

        // STRICT ROLE CHECK FOR EMPLOYEE APP
        if (!_user!.isEmployee) {
          debugPrint(
              '⛔ Unauthorized access attempt by non-employee: ${_user!.email}');
          await _auth.signOut();
          _user = null;
          _error = 'Access denied. You are not an employee.';
        } else {
          // Check if approved
          final employeeDoc =
              await _firestore.collection('employees').doc(uid).get();
          if (employeeDoc.exists) {
            final status = employeeDoc.data()?['status'] ?? 'pending';
            // Phase 16C, Workstream 5: previously ANY non-approved status —
            // including 'suspended' — produced this exact same "pending
            // approval" message, so a suspended associate (who may have
            // been approved and working for months) was told they were
            // still under initial review. Distinguishing the two is the
            // ONLY change here — the check that gates FCM registration on
            // status == 'approved' is untouched, and this still does not
            // touch signIn()/OTP/the auth mechanism itself.
            if (status == 'suspended') {
              _error = 'Your associate account has been suspended.';
            } else if (status != 'approved') {
              _error = 'Your account is pending approval by an administrator.';
            } else {
              await _updateFCMToken(uid);
            }
          } else {
            await _auth.signOut();
            _user = null;
            _error = 'Could not find employee details.';
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
        debugPrint('✅ FCM token updated for employee: $uid');
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
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
