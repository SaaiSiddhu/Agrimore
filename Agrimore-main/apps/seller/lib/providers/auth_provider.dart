// lib/providers/auth_provider.dart
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
  
  DeliveryAuthProvider() {
    _init();
  }
  
  // Getters
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  bool get isDeliveryPartner => _user?.isDeliveryPartner ?? false;
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
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _user = UserModel.fromFirestore(doc);
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
        
        // Verify user is a delivery partner
        if (!isDeliveryPartner) {
          await signOut();
          _error = 'This account is not registered as a delivery partner';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        // Check if the delivery partner is APPROVED
        final partnerDoc = await _firestore.collection('delivery_partners').doc(credential.user!.uid).get();
        if (partnerDoc.exists) {
          final status = partnerDoc.data()?['status'] ?? 'pending';
          if (status != 'approved') {
            await signOut();
            _error = 'Your account is pending approval by an administrator.';
            _isLoading = false;
            notifyListeners();
            return false;
          }
        } else {
          await signOut();
          _error = 'Could not find delivery partner details.';
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
    await _auth.signOut();
    _user = null;
    notifyListeners();
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
