import 'dart:async';
import 'dart:math';
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
  // STREAM: the rider leg and the rider's live position (Phase DLV-3B)
  // ============================================

  /// delivery_tasks/{orderId} — status, pickup and drop points (readable by
  /// the order's customer; written only by the syncDeliveryTask function).
  Stream<DeliveryTaskModel?> streamTask(String orderId) => _firestore
      .collection('delivery_tasks')
      .doc(orderId)
      .snapshots()
      .map((d) => d.exists ? DeliveryTaskModel.fromFirestore(d) : null);

  /// delivery_tasks/{orderId}/live/rider — where the rider's phone last was
  /// (DLV-3A/3A2). Replaces order.deliveryPartner.currentLat/Lng, a copy
  /// written once at assignment that never moved.
  Stream<RiderLivePoint?> streamLivePoint(String orderId) => _firestore
      .collection('delivery_tasks')
      .doc(orderId)
      .collection('live')
      .doc('rider')
      .snapshots()
      .map((d) => RiderLivePoint.fromMap(d.data()));

  /// Order statuses with something to track: confirmed through out for
  /// delivery, including the rider-leg statuses (the pre-DLV-3B lists knew
  /// only confirmed/processing/shipped/out_for_delivery, so the banner and the
  /// Track Live button vanished once a rider had the order).
  static const Set<String> trackableStatuses = {
    'confirmed', 'processing', 'ready_for_pickup', 'delivery_accepted',
    'arrived_at_store', 'reached_pickup', 'picked_up', 'parcel_picked',
    'shipped', 'out_for_delivery', 'outfordelivery',
  };

  static bool isTrackable(String status) =>
      trackableStatuses.contains(status.trim().toLowerCase());

  /// What the customer is told about the delivery leg. Reads the rider leg
  /// when there is one (it knows 'at the store', 'picked up'), else the
  /// order status.
  static String stageMessage(DeliveryTaskStatus? task, String orderStatus) {
    switch (task) {
      case DeliveryTaskStatus.searching:
        return 'Packed — finding a delivery partner';
      case DeliveryTaskStatus.assigned:
        return 'Delivery partner is on the way to the store';
      case DeliveryTaskStatus.atPickup:
        return 'Delivery partner is at the store, picking up your order';
      case DeliveryTaskStatus.pickedUp:
      case DeliveryTaskStatus.enRoute:
        return 'On the way to you';
      case DeliveryTaskStatus.atDrop:
        return 'Your delivery partner has arrived';
      case DeliveryTaskStatus.delivered:
        return 'Delivered';
      case DeliveryTaskStatus.failedAttempt:
        return 'Delivery attempt failed — we will contact you';
      case DeliveryTaskStatus.returningToSeller:
      case DeliveryTaskStatus.returned:
        return 'Order is being returned to the store';
      case DeliveryTaskStatus.cancelled:
        return 'Order cancelled';
      case null:
        break;
    }
    switch (orderStatus.toLowerCase()) {
      case 'pending':
        return 'Order placed — waiting for the store to confirm';
      case 'confirmed':
        return 'Order confirmed — preparing your items';
      case 'processing':
        return 'Your order is being packed';
      case 'ready_for_pickup':
        return 'Packed — finding a delivery partner';
      case 'delivery_accepted':
        return 'Delivery partner is on the way to the store';
      case 'arrived_at_store':
      case 'reached_pickup':
        return 'Delivery partner is at the store, picking up your order';
      case 'picked_up':
      case 'parcel_picked':
      case 'shipped':
      case 'out_for_delivery':
      case 'outfordelivery':
        return 'On the way to you';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Order cancelled';
      default:
        return 'Order in progress';
    }
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
  String getStatusMessage(String orderStatus) => stageMessage(null, orderStatus);

  // ============================================
  // CLEANUP
  // ============================================
  
  void dispose() {
    _locationSubscription?.cancel();
    _orderSubscription?.cancel();
  }
}

/// Phase DLV-3B — shown under the ETA when the rider's last position is more
/// than 2 minutes old (RiderLivePoint.staleAfter).
String locationAgeMessage(Duration? age) {
  if (age == null) return "Waiting for the delivery partner's location";
  final m = age.inMinutes;
  if (m < 1) return 'Location updated just now';
  if (m < 60) return 'Location updated $m min ago';
  return 'Location updated over an hour ago';
}
