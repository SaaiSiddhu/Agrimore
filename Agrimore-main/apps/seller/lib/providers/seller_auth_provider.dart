import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_services/agrimore_services.dart';

class SellerAuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  UserModel? _currentUser;
  bool _isLoading = true;
  String? _error;
  String _approvalStatus = 'unknown'; // unknown, pending, approved, rejected

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get approvalStatus => _approvalStatus;
  
  /// User is authenticated ONLY if they are a seller AND approved
  bool get isAuthenticated => _currentUser != null && _currentUser!.role == 'seller' && _approvalStatus == 'approved';
  
  /// User is a seller but pending approval
  bool get isPendingApproval => _currentUser != null && _currentUser!.role == 'seller' && _approvalStatus == 'pending';
  
  /// User is rejected
  bool get isRejected => _approvalStatus == 'rejected';

  SellerAuthProvider() {
    _init();
  }

  Future<void> _init() async {
    _auth.authStateChanges().listen((User? user) async {
      _isLoading = true;
      notifyListeners();

      if (user != null) {
        await _loadUserData(user.uid);
      } else {
        _currentUser = null;
        _approvalStatus = 'unknown';
      }

      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> _loadUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _currentUser = UserModel.fromMap(doc.data()!, doc.id);
        
        // STRICT ROLE CHECK FOR SELLER APP
        if (_currentUser!.role != 'seller') {
          debugPrint('⛔ Unauthorized access attempt by non-seller: ${_currentUser!.email}');
          await _auth.signOut();
          _currentUser = null;
          _approvalStatus = 'unknown';
          _error = 'Access denied. You are not a seller.';
          return;
        }
        
        // Check approval status from sellerRequests or users collection
        final sellerStatus = doc.data()?['sellerStatus'] ?? 'pending';
        final metadataStatus = _currentUser!.metadata?['status'];
        
        // Also check the sellers collection for approval
        try {
          final sellerDoc = await _firestore.collection('sellers').doc(uid).get();
          if (sellerDoc.exists) {
            final sellerCollectionStatus = sellerDoc.data()?['status'] ?? 'pending';
            _approvalStatus = sellerCollectionStatus;
          } else {
            _approvalStatus = metadataStatus ?? sellerStatus;
          }
        } catch (e) {
          _approvalStatus = metadataStatus ?? sellerStatus;
        }
        
        // If status is 'approved' or not explicitly set (legacy sellers), allow
        if (_approvalStatus != 'approved' && _approvalStatus != 'unknown') {
          debugPrint('⏳ Seller ${_currentUser!.email} is $_approvalStatus');
        } else {
          _approvalStatus = 'approved';
        }
        
        _error = null;
      } else {
        _currentUser = null;
        _approvalStatus = 'unknown';
      }
    } catch (e) {
      _error = 'Failed to load user data: $e';
      debugPrint('❌ Error loading seller data: $e');
    }
  }

  /// Refresh user data (check if approval status changed)
  Future<void> refreshUser() async {
    if (_auth.currentUser != null) {
      _isLoading = true;
      notifyListeners();
      
      await _loadUserData(_auth.currentUser!.uid);
      
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signInWithEmailPassword(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _loadUserData(userCredential.user!.uid);
      
      if (_currentUser == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      return isAuthenticated || isPendingApproval;
    } on FirebaseAuthException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    
    await _auth.signOut();
    _currentUser = null;
    _approvalStatus = 'unknown';
    _error = null;
    
    _isLoading = false;
    notifyListeners();
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
