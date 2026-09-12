import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agrimore_core/agrimore_core.dart';

// ============================================
// CACHE CONFIGURATION
// ============================================
const String _kBannersCacheKey = 'cached_banners_v1';
const String _kBannersCacheTimeKey = 'cached_banners_time';
const int _kCacheTTLMinutes = 10;

class BannerProvider with ChangeNotifier {
  // Shared by every banners query in this provider (loadBanners,
  // _startRealtimeListener, bannersStream) so they can never drift apart.
  // Production currently has 1 banner; a promotional carousel realistically
  // shows a handful (confirmed via banner_slider.dart's plain
  // CarouselSlider.builder over the full list, no pagination) — 20 is
  // generous headroom without being unbounded.
  static const int _bannerQueryLimit = 20;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  List<BannerModel> _banners = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<QuerySnapshot>? _subscription;
  bool _isCacheLoaded = false; // ✅ NEW: Track if we showed cached data

  List<BannerModel> get banners => _banners;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // activeBanners filtered & sorted locally (works with subscription updates).
  // Scoped to the Home placement so a CATEGORY_HERO banner never leaks onto
  // Home — every banner written before `placement` existed parses as
  // HOME_HERO (BannerModel.fromFirestore's own default), so this is not a
  // behavior change for any banner that exists today.
  List<BannerModel> get activeBanners {
    final list = _banners
        .where((banner) =>
            banner.isActive && banner.placement == BannerModel.placementHomeHero)
        .toList();
    list.sort((a, b) => a.priority.compareTo(b.priority));
    return list;
  }

  /// Eligible CATEGORY_HERO banners for [categoryId]: active, targeted at
  /// this category, and currently within their schedule window (unset bounds
  /// = unbounded on that side). Sorted by priority for a carousel's page
  /// order. Filters the same already-subscribed list `activeBanners` reads —
  /// no separate Firestore query or index.
  List<BannerModel> categoryHeroBanners(String categoryId) {
    final now = DateTime.now();
    final list = _banners
        .where((banner) =>
            banner.isActive &&
            banner.placement == BannerModel.placementCategoryHero &&
            banner.categoryId == categoryId &&
            banner.isWithinSchedule(now))
        .toList();
    list.sort((a, b) => a.priority.compareTo(b.priority));
    return list;
  }

  BannerProvider() {
    _startRealtimeListener();
  }

  // ============================================
  // ENHANCED CACHE-FIRST LOADING
  // ============================================
  Future<void> loadBanners({bool forceRefresh = false}) async {
    // ✅ If forceRefresh, reset cache flag to force Firebase fetch
    if (forceRefresh) {
      _isCacheLoaded = false;
      debugPrint('🔄 Force refreshing banners from Firebase...');
    }
    
    // ============================================
    // STEP 1: INSTANT - Load from local cache first
    // ============================================
    if (!_isCacheLoaded) {
      final cached = await _loadFromCache();
      if (cached.isNotEmpty) {
        _banners = cached;
        _isCacheLoaded = true;
        debugPrint('⚡ INSTANT: Loaded ${_banners.length} banners from cache');
        notifyListeners(); // Show cached data immediately!
      }
    } else if (!forceRefresh) {
      // Already have cache loaded and not forcing refresh
      debugPrint('🎯 Banners in-memory cached, skipping...');
      return;
    }

    // ============================================
    // STEP 2: BACKGROUND - Fetch fresh data from network
    // ============================================
    _isLoading = !_isCacheLoaded;
    _error = null;
    if (!_isCacheLoaded) notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('banners')
          .orderBy('priority')
          .limit(_bannerQueryLimit)
          .get();
      _banners = snapshot.docs.map((doc) => BannerModel.fromFirestore(doc)).toList();
      await _saveToCache(_banners);
      debugPrint('✅ NETWORK: Loaded ${_banners.length} banners');
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error loading banners: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================
  // CACHE HELPERS
  // ============================================
  Future<List<BannerModel>> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_kBannersCacheKey);
      if (cachedJson == null || cachedJson.isEmpty) return [];

      final List<dynamic> decoded = jsonDecode(cachedJson);
      return decoded.map((json) {
        final map = json as Map<String, dynamic>;
        return BannerModel(
          id: map['id'] ?? '',
          imageUrl: map['imageUrl'] ?? '',
          title: map['title'] ?? '',
          subtitle: map['subtitle'] ?? '',
          iconName: map['iconName'] ?? 'info',
          targetRoute: map['targetRoute'],
          colorHex: map['colorHex'] ?? '#4CAF50',
          isActive: map['isActive'] ?? true,
          priority: map['priority'] ?? 0,
          createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
          updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt']) : null,
          placement: map['placement'] ?? BannerModel.placementHomeHero,
          categoryId: map['categoryId'],
          startsAt: map['startsAt'] != null ? DateTime.tryParse(map['startsAt']) : null,
          endsAt: map['endsAt'] != null ? DateTime.tryParse(map['endsAt']) : null,
        );
      }).toList();
    } catch (e) {
      debugPrint('⚠️ Banner cache load error: $e');
      return [];
    }
  }

  Future<void> _saveToCache(List<BannerModel> banners) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = banners.map((b) => {
        'id': b.id,
        'imageUrl': b.imageUrl,
        'title': b.title,
        'subtitle': b.subtitle,
        'iconName': b.iconName,
        'targetRoute': b.targetRoute,
        'colorHex': b.colorHex,
        'isActive': b.isActive,
        'priority': b.priority,
        'createdAt': b.createdAt.toIso8601String(),
        'updatedAt': b.updatedAt?.toIso8601String(),
        'placement': b.placement,
        'categoryId': b.categoryId,
        'startsAt': b.startsAt?.toIso8601String(),
        'endsAt': b.endsAt?.toIso8601String(),
      }).toList();
      await prefs.setString(_kBannersCacheKey, jsonEncode(jsonList));
      await prefs.setString(_kBannersCacheTimeKey, DateTime.now().toIso8601String());
      debugPrint('💾 Saved ${banners.length} banners to cache');
    } catch (e) {
      debugPrint('⚠️ Banner cache save error: $e');
    }
  }

  void _startRealtimeListener() {
    _subscription?.cancel();

    try {
      _subscription = _firestore
          .collection('banners')
          .orderBy('priority')
          .limit(_bannerQueryLimit)
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
          ai.priority != bi.priority ||
          ai.placement != bi.placement ||
          ai.categoryId != bi.categoryId ||
          ai.startsAt != bi.startsAt ||
          ai.endsAt != bi.endsAt) {
        return false;
      }
    }
    return true;
  }

  Stream<List<BannerModel>> bannersStream() {
    return _firestore
        .collection('banners')
        .orderBy('priority')
        .limit(_bannerQueryLimit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => BannerModel.fromFirestore(doc)).toList());
  }

  /// Upload image bytes (web-compatible)
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

  /// Create banner with image bytes (web-compatible)
  Future<void> createBannerWithBytes({
    required Uint8List imageBytes,
    required String title,
    required String subtitle,
    required String iconName,
    String? targetRoute,
    required String colorHex,
    required int priority,
  }) async {
    try {
      final fileName = 'banner_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final imageUrl = await uploadImageBytes(imageBytes, fileName);

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