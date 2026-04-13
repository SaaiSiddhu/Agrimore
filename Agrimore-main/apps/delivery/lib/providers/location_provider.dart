// lib/providers/location_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/distance_service.dart';

class LocationProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Position? _currentPosition;
  bool _isTracking = false;
  bool _hasPermission = false;
  String? _error;
  
  StreamSubscription<Position>? _positionSubscription;
  Timer? _uploadTimer;
  String? _partnerId;
  
  // Getters
  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;
  bool get hasPermission => _hasPermission;
  String? get error => _error;
  double? get latitude => _currentPosition?.latitude;
  double? get longitude => _currentPosition?.longitude;
  
  // Check and request permissions
  Future<bool> checkPermissions() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.deniedForever) {
        _error = 'Location permission permanently denied';
        _hasPermission = false;
        notifyListeners();
        return false;
      }
      
      if (permission == LocationPermission.denied) {
        _error = 'Location permission denied';
        _hasPermission = false;
        notifyListeners();
        return false;
      }
      
      _hasPermission = true;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error checking permissions: $e';
      notifyListeners();
      return false;
    }
  }
  
  // Start location tracking
  Future<void> startTracking(String partnerId) async {
    if (_isTracking) return;
    
    _partnerId = partnerId;
    
    final hasPermission = await checkPermissions();
    if (!hasPermission) return;
    
    // Get initial position
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      notifyListeners();
    } catch (e) {
      _error = 'Failed to get location';
      notifyListeners();
      return;
    }
    
    // Start position stream
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((position) {
      _currentPosition = position;
      notifyListeners();
    });
    
    // Upload location to Firestore every 30 seconds
    _uploadTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _uploadLocation();
    });
    
    // Upload initial location
    await _uploadLocation();
    
    _isTracking = true;
    notifyListeners();
  }
  
  // Stop tracking
  void stopTracking() {
    _positionSubscription?.cancel();
    _uploadTimer?.cancel();
    _isTracking = false;
    notifyListeners();
  }
  
  // Upload location to Firestore
  Future<void> _uploadLocation() async {
    if (_currentPosition == null || _partnerId == null) return;
    
    try {
      await _firestore.collection('delivery_partners').doc(_partnerId).update({
        'currentLat': _currentPosition!.latitude,
        'currentLng': _currentPosition!.longitude,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error uploading location: $e');
    }
  }
  
  // Update online status
  Future<void> setOnlineStatus(String partnerId, bool isOnline) async {
    try {
      debugPrint('🚚 Setting online status: $isOnline for partner: $partnerId');
      // Use set with merge to create doc if it doesn't exist
      await _firestore.collection('delivery_partners').doc(partnerId).set({
        'isOnline': isOnline,
        'lastStatusUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('✅ Online status updated');
    } catch (e) {
      debugPrint('❌ Error updating online status: $e');
    }
  }
  
  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
  
  /// Calculate distance from current position to target coordinates
  /// Returns distance in kilometers, or null if current position not available
  double? calculateDistanceTo(double targetLat, double targetLng) {
    if (_currentPosition == null) return null;
    
    return DistanceService.calculateDistance(
      startLat: _currentPosition!.latitude,
      startLng: _currentPosition!.longitude,
      endLat: targetLat,
      endLng: targetLng,
    );
  }
  
  /// Get delivery details including distance and earnings
  Map<String, dynamic>? getDeliveryDetails(double targetLat, double targetLng) {
    if (_currentPosition == null) return null;
    
    return DistanceService.calculateDeliveryDetails(
      partnerLat: _currentPosition!.latitude,
      partnerLng: _currentPosition!.longitude,
      customerLat: targetLat,
      customerLng: targetLng,
    );
  }
}
