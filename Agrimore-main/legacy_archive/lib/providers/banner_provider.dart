import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/banner_model.dart';

class BannerProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  List<BannerModel> _banners = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<QuerySnapshot>? _subscription;

  List<BannerModel> get banners => _banners;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // activeBanners filtered & sorted locally (works with subscription updates)
  List<BannerModel> get activeBanners {
    final list = _banners.where((banner) => banner.isActive).toList();
    list.sort((a, b) => a.priority.compareTo(b.priority));
    return list;
  }

  BannerProvider() {
    _startRealtimeListener();
  }

  Future<void> loadBanners() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _firestore.collection('banners').orderBy('priority').get();

      _banners = snapshot.docs.map((doc) => BannerModel.fromFirestore(doc)).toList();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading banners: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startRealtimeListener() {
    _subscription?.cancel();

    try {
      _subscription = _firestore
          .collection('banners')
          .orderBy('priority')
          .snapshots()
          .listen((snapshot) {
        final newList = snapshot.docs.map((doc) => BannerModel.fromFirestore(doc)).toList();

        final oldIds = _banners.map((e) => e.id).join(',');
        final newIds = newList.map((e) => e.id).join(',');
        final hasDifference = oldIds != newIds || newList.length != _banners.length || !_areContentsEqual(_banners, newList);

        _banners = newList;

        if (hasDifference) {
          notifyListeners();
        }
      }, onError: (err) {
        debugPrint('Banner realtime listener error: $err');
      });
    } catch (e) {
      debugPrint('Failed to start banner realtime listener: $e');
    }
  }

  bool _areContentsEqual(List<BannerModel> a, List<BannerModel> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      final ai = a[i];
      final bi = b[i];
      if (ai.id != bi.id ||
          ai.imageUrl != bi.imageUrl ||
          ai.title != bi.title ||
          ai.subtitle != bi.subtitle ||
          ai.iconName != bi.iconName ||
          ai.colorHex != bi.colorHex ||
          ai.isActive != bi.isActive ||
          ai.priority != bi.priority) {
        return false;
      }
    }
    return true;
  }

  Stream<List<BannerModel>> bannersStream() {
    return _firestore.collection('banners').orderBy('priority').snapshots().map(
        (snapshot) => snapshot.docs.map((doc) => BannerModel.fromFirestore(doc)).toList());
  }

  Future<String> uploadImageFile(File imageFile) async {
    try {
      final fileName = 'banner_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = _storage.ref().child('banners/$fileName');

      final uploadTask = storageRef.putFile(imageFile);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      rethrow;
    }
  }

  Future<String> uploadImageBytes(Uint8List imageBytes, String fileName) async {
    try {
      final storageRef = _storage.ref().child('banners/$fileName');
      final uploadTask = storageRef.putData(imageBytes);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading image bytes: $e');
      rethrow;
    }
  }

  Future<void> createBannerWithFile({
    required File imageFile,
    required String title,
    required String subtitle,
    required String iconName,
    String? targetRoute,
    required String colorHex,
    required int priority,
  }) async {
    try {
      final imageUrl = await uploadImageFile(imageFile);

      await _firestore.collection('banners').add({
        'imageUrl': imageUrl,
        'title': title,
        'subtitle': subtitle,
        'iconName': iconName,
        'targetRoute': targetRoute,
        'colorHex': colorHex,
        'isActive': true,
        'priority': priority,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error creating banner: $e');
      rethrow;
    }
  }

  Future<void> createBannerWithUrl({
    required String imageUrl,
    required String title,
    required String subtitle,
    required String iconName,
    String? targetRoute,
    required String colorHex,
    required int priority,
  }) async {
    try {
      await _firestore.collection('banners').add({
        'imageUrl': imageUrl,
        'title': title,
        'subtitle': subtitle,
        'iconName': iconName,
        'targetRoute': targetRoute,
        'colorHex': colorHex,
        'isActive': true,
        'priority': priority,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error creating banner: $e');
      rethrow;
    }
  }

  Future<void> updateBanner(String bannerId, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('banners').doc(bannerId).update(data);
    } catch (e) {
      debugPrint('Error updating banner: $e');
      rethrow;
    }
  }

  Future<void> deleteBanner(String bannerId, String imageUrl) async {
    try {
      if (imageUrl.contains('firebasestorage.googleapis.com')) {
        try {
          final storageRef = _storage.refFromURL(imageUrl);
          await storageRef.delete();
        } catch (e) {
          debugPrint('Error deleting image from storage: $e');
        }
      }

      await _firestore.collection('banners').doc(bannerId).delete();
    } catch (e) {
      debugPrint('Error deleting banner: $e');
      rethrow;
    }
  }

  Future<void> toggleBannerStatus(String bannerId, bool isActive) async {
    try {
      await updateBanner(bannerId, {'isActive': isActive});
    } catch (e) {
      debugPrint('Error toggling banner status: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}