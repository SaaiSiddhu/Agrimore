// lib/services/firestore_data_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreDataService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Get user profile by UID
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      print('⚠️ getUserProfile error: $e');
      return null;
    }
  }

  /// Get all addresses for a user
  Future<List<Map<String, dynamic>>> getUserAddresses(String uid) async {
    try {
      final snap = await _firestore
          .collection('addresses')
          .where('userId', isEqualTo: uid)
          .get();

      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      print('⚠️ getUserAddresses error: $e');
      return [];
    }
  }
}