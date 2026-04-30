import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_core/agrimore_core.dart';

class VendorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'vendors';

  // Get all vendors
  Stream<List<VendorModel>> getVendors() {
    return _firestore.collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VendorModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get single vendor
  Future<VendorModel?> getVendor(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists && doc.data() != null) {
        return VendorModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw ServerException('Failed to fetch vendor: ${e.toString()}');
    }
  }

  // Add vendor
  Future<void> addVendor(VendorModel vendor) async {
    try {
      final docRef = _firestore.collection(_collection).doc();
      final data = vendor.toMap();
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();
      
      await docRef.set(data);
    } catch (e) {
      throw ServerException('Failed to add vendor: ${e.toString()}');
    }
  }

  // Update vendor
  Future<void> updateVendor(VendorModel vendor) async {
    try {
      final data = vendor.toMap();
      data['updatedAt'] = FieldValue.serverTimestamp();
      
      await _firestore.collection(_collection).doc(vendor.id).update(data);
    } catch (e) {
      throw ServerException('Failed to update vendor: ${e.toString()}');
    }
  }

  // Delete vendor
  Future<void> deleteVendor(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      throw ServerException('Failed to delete vendor: ${e.toString()}');
    }
  }
}
