import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_core/agrimore_core.dart';

/// Service for real-time delivery tracking
/// Provides ETA calculation, partner location streaming, and status updates
class DeliveryTrackingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  StreamSubscription? _locationSubscription;
  StreamSubscription? _orderSubscription;
  
  // ============================================
  // STREAM: Delivery Partner Location
  // ============================================
  
  /// Stream the delivery partner's real-time location for an order
  Stream<DeliveryPartnerModel?> streamDeliveryPartnerLocation(String orderId) {
    return _firestore
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      
      final data = doc.data()!;
      if (data['deliveryPartner'] == null) return null;
      
      return DeliveryPartnerModel.fromMap(
        data['deliveryPartner'] as Map<String, dynamic>,
      );
    });
  }
  
  // ============================================
  // STREAM: Order Status Updates
  // ============================================
  
  /// Stream order status changes in real-time
  Stream<OrderModel?> streamOrderStatus(String orderId) {
    return _firestore
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return OrderModel.fromMap(doc.data()!, doc.id);
    });
  }
  
  // ============================================
  // CALCULATE: Estimated Time of Arrival
  // ============================================
  
  /// Calculate ETA based on partner location and destination
  /// Returns minutes remaining
  int? calculateETA({
    required double? partnerLat,
    required double? partnerLng,
    required double? destinationLat,
    required double? destinationLng,
  }) {
    if (partnerLat == null || partnerLng == null ||
        destinationLat == null || destinationLng == null) {
      return null;
    }

    // Calculate distance using Haversine formula (simplified)
    final distance = _calculateDistance(
      partnerLat, partnerLng,
      destinationLat, destinationLng,
    );

    // Assume average speed of 25 km/h in city traffic
    const averageSpeedKmH = 25.0;
    final etaMinutes = (distance / averageSpeedKmH) * 60;

    // Add buffer time (2-5 mins for traffic, stops, etc.)
    return (etaMinutes + 3).round().clamp(1, 120);
  }

  /// Calculate distance between two points in kilometers (Haversine formula)
  double _calculateDistance(
    double lat1, double lng1,
    double lat2, double lng2,
  ) {
    const earthRadiusKm = 6371.0;
    
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLng = _degreesToRadians(lng2 - lng1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (3.141592653589793 / 180);
  }

  // ============================================
  // FORMAT: ETA Display
  // ============================================
  
  /// Format ETA for display (e.g., "8 mins", "1 hr 15 mins")
  String formatETA(int minutes) {
    if (minutes < 60) {
      return '$minutes mins';
    }
    
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    
    if (remainingMinutes == 0) {
      return '$hours hr${hours > 1 ? 's' : ''}';
    }
    
    return '$hours hr $remainingMinutes mins';
  }

  /// Format ETA with "Arriving in" prefix
  String formatETAWithPrefix(int minutes) {
    return 'Arriving in ${formatETA(minutes)}';
  }

  // ============================================
  // GET: Delivery Status Message
  // ============================================
  
  /// Get user-friendly status message for order tracking
  String getStatusMessage(String orderStatus) {
    switch (orderStatus.toLowerCase()) {
      case 'pending':
        return 'Looking for a delivery partner...';
      case 'confirmed':
        return 'Order confirmed! Preparing your items...';
      case 'processing':
        return 'Your order is being packed';
      case 'shipped':
        return 'Your order is on the way!';
      case 'out_for_delivery':
        return 'Out for delivery - arriving soon!';
      case 'delivered':
        return 'Order delivered successfully!';
      case 'cancelled':
        return 'Order cancelled';
      default:
        return 'Order status: $orderStatus';
    }
  }

  // ============================================
  // CLEANUP
  // ============================================
  
  void dispose() {
    _locationSubscription?.cancel();
    _orderSubscription?.cancel();
  }
}
