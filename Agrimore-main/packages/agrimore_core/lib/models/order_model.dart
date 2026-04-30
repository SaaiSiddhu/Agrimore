import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_item_model.dart';
import 'address_model.dart';
import 'delivery_partner_model.dart';

class OrderModel {
  final String id;
  final String userId;
  final String orderNumber;
  final List<CartItemModel> items;
  final AddressModel deliveryAddress;
  final double subtotal;
  final double discount;
  final double deliveryCharge;
  final double tax;
  final double total;
  final String paymentMethod;
  final String paymentStatus;
  final String orderStatus;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final String? razorpaySignature;
  final String? couponCode;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deliveryDate;
  final String? orderType; // 'One Time' or 'Auto Delivery'
  final String? autoFrequency; // 'Daily' or 'Weekly'
  final String? deliverySlot;
  
  // ✅ NEW: Live tracking fields
  final String? deliveryPartnerId;
  final DeliveryPartnerModel? deliveryPartner;
  final DateTime? estimatedDeliveryTime;
  final double? pickupLat;
  final double? pickupLng;
  final String? liveTrackingId;

  // ✅ Delivery verification code (shown to customer only)
  final String? deliveryVerificationCode;

  OrderModel({
    required this.id,
    required this.userId,
    required this.orderNumber,
    required this.items,
    required this.deliveryAddress,
    required this.subtotal,
    this.discount = 0,
    this.deliveryCharge = 0,
    this.tax = 0,
    required this.total,
    required this.paymentMethod,
    this.paymentStatus = 'pending',
    this.orderStatus = 'pending',
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.razorpaySignature,
    this.couponCode,
    this.notes,
    DateTime? createdAt,
    this.updatedAt,
    this.deliveryDate,
    this.orderType,
    this.autoFrequency,
    this.deliverySlot,
    // ✅ NEW: Live tracking
    this.deliveryPartnerId,
    this.deliveryPartner,
    this.estimatedDeliveryTime,
    this.pickupLat,
    this.pickupLng,
    this.liveTrackingId,
    this.deliveryVerificationCode,
  }) : createdAt = createdAt ?? DateTime.now();

  // ============================================
  // HELPER: Convert Timestamp/DateTime to DateTime
  // ============================================
  static DateTime _parseDateTime(dynamic value) {
    try {
      if (value == null) return DateTime.now();

      // ✅ Direct Timestamp check
      if (value is Timestamp) {
        return value.toDate();
      }

      // ✅ Already a DateTime
      if (value is DateTime) {
        return value;
      }

      // ✅ Check for toDate method (catches Timestamp without import)
      if (value.runtimeType.toString().contains('Timestamp')) {
        try {
          return value.toDate();
        } catch (_) {}
      }

      // ✅ Int milliseconds
      if (value is int) {
        if (value > 10000000000) {
          return DateTime.fromMillisecondsSinceEpoch(value);
        }
        return DateTime.fromMillisecondsSinceEpoch(value * 1000);
      }

      // ✅ Double seconds
      if (value is double) {
        return DateTime.fromMillisecondsSinceEpoch((value * 1000).toInt());
      }

      return DateTime.now();
    } catch (e) {
      debugPrint('⚠️ DateTime parse failed for value: $value, error: $e');
      return DateTime.now();
    }
  }

  static String _normalizeOrderStatus(dynamic value) {
    final raw = (value ?? 'pending').toString().trim().toLowerCase();
    switch (raw) {
      case 'placed':
        return 'pending';
      case 'out_for_delivery':
        return 'outfordelivery';
      default:
        return raw.isEmpty ? 'pending' : raw;
    }
  }

  // ============================================
  // FROM JSON/MAP FACTORY
  // ============================================
  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel.fromMap(json, json['id'] ?? '');
  }

  factory OrderModel.fromMap(Map<String, dynamic> map, String id) {
    try {
      debugPrint('🔍 Parsing OrderModel: $id');

      // Parse items safely
      List<CartItemModel> parsedItems = [];
      try {
        if (map['items'] != null && map['items'] is List) {
          parsedItems = (map['items'] as List<dynamic>)
              .map((item) {
                try {
                  return CartItemModel.fromMap(item as Map<String, dynamic>);
                } catch (e) {
                  debugPrint('⚠️ Error parsing item: $e');
                  return null;
                }
              })
              .whereType<CartItemModel>()
              .toList();
        }
      } catch (e) {
        debugPrint('⚠️ Error parsing items list: $e');
      }

      // Parse delivery address safely
      AddressModel deliveryAddress = AddressModel.fromMap({});
      try {
        if (map['deliveryAddress'] != null &&
            map['deliveryAddress'] is Map<String, dynamic>) {
          deliveryAddress =
              AddressModel.fromMap(map['deliveryAddress'] as Map<String, dynamic>);
        } else if (map['address'] is String) {
          deliveryAddress = AddressModel.fromMap({
            'fullAddress': map['address'],
          });
        }
      } catch (e) {
        debugPrint('⚠️ Error parsing delivery address: $e');
      }

      // ✅ Parse delivery partner safely
      DeliveryPartnerModel? deliveryPartner;
      try {
        if (map['deliveryPartner'] != null &&
            map['deliveryPartner'] is Map<String, dynamic>) {
          deliveryPartner = DeliveryPartnerModel.fromMap(
              map['deliveryPartner'] as Map<String, dynamic>);
        }
      } catch (e) {
        debugPrint('⚠️ Error parsing delivery partner: $e');
      }

      final rawStatus = map['orderStatus'] ?? map['status'] ?? 'pending';

      final order = OrderModel(
        id: id,
        userId: map['userId'] ?? '',
        orderNumber: map['orderNumber'] ?? 'ORD${DateTime.now().millisecondsSinceEpoch}',
        items: parsedItems,
        deliveryAddress: deliveryAddress,
        subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
        discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
        deliveryCharge: ((map['deliveryCharge'] ?? map['deliveryFee']) as num?)
                ?.toDouble() ??
            0.0,
        tax: (map['tax'] as num?)?.toDouble() ?? 0.0,
        total: ((map['total'] ?? map['totalAmount']) as num?)?.toDouble() ?? 0.0,
        paymentMethod: map['paymentMethod'] ?? 'cod',
        paymentStatus: map['paymentStatus'] ?? 'pending',
        orderStatus: _normalizeOrderStatus(rawStatus),
        razorpayOrderId: map['razorpayOrderId'] as String?,
        razorpayPaymentId: map['razorpayPaymentId'] as String?,
        razorpaySignature: map['razorpaySignature'] as String?,
        couponCode: map['couponCode'] as String?,
        notes: map['notes'] as String?,
        createdAt: _parseDateTime(map['createdAt']),
        updatedAt: map['updatedAt'] != null ? _parseDateTime(map['updatedAt']) : null,
        deliveryDate: map['deliveryDate'] != null ? _parseDateTime(map['deliveryDate']) : null,
        orderType: map['orderType'] as String?,
        autoFrequency: map['autoFrequency'] as String?,
        deliverySlot: map['deliverySlot'] as String?,
        // ✅ NEW: Live tracking fields
        deliveryPartnerId: map['deliveryPartnerId'] as String?,
        deliveryPartner: deliveryPartner,
        estimatedDeliveryTime: map['estimatedDeliveryTime'] != null 
            ? _parseDateTime(map['estimatedDeliveryTime']) 
            : null,
        pickupLat: (map['pickupLat'] as num?)?.toDouble(),
        pickupLng: (map['pickupLng'] as num?)?.toDouble(),
        liveTrackingId: map['liveTrackingId'] as String?,
        deliveryVerificationCode: map['deliveryVerificationCode'] as String?,
      );

      debugPrint('✅ OrderModel parsed: ${order.orderNumber}, items: ${order.items.length}');
      return order;
    } catch (e) {
      debugPrint('❌ Error parsing OrderModel: $e');
      rethrow;
    }
  }

  // ============================================
  // TO MAP/JSON
  // ============================================
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'orderNumber': orderNumber,
      'items': items.map((item) => item.toMap()).toList(),
      'deliveryAddress': deliveryAddress.toMap(),
      'subtotal': subtotal,
      'discount': discount,
      'deliveryCharge': deliveryCharge,
      'tax': tax,
      'total': total,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'orderStatus': orderStatus,
      'status': orderStatus,
      'razorpayOrderId': razorpayOrderId,
      'razorpayPaymentId': razorpayPaymentId,
      'razorpaySignature': razorpaySignature,
      'couponCode': couponCode,
      'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'deliveryDate': deliveryDate?.millisecondsSinceEpoch,
      'orderType': orderType,
      'autoFrequency': autoFrequency,
      'deliverySlot': deliverySlot,
      // ✅ NEW: Live tracking fields
      'deliveryPartnerId': deliveryPartnerId,
      'deliveryPartner': deliveryPartner?.toMap(),
      'estimatedDeliveryTime': estimatedDeliveryTime != null 
          ? Timestamp.fromDate(estimatedDeliveryTime!) 
          : null,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'liveTrackingId': liveTrackingId,
      'deliveryVerificationCode': deliveryVerificationCode,
    };
  }

  Map<String, dynamic> toJson() => toMap();

  // ============================================
  // GETTERS & UTILITIES
  // ============================================
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  String get status => orderStatus;

  bool get isDelivered =>
      orderStatus.toLowerCase() == 'delivered' ||
      orderStatus.toLowerCase() == 'completed';

  bool get isCancelled => orderStatus.toLowerCase() == 'cancelled';

  bool get isPending =>
      orderStatus.toLowerCase() == 'pending' ||
      orderStatus.toLowerCase() == 'confirmed';

  bool get isInTransit =>
      orderStatus.toLowerCase() == 'shipped' ||
      orderStatus.toLowerCase() == 'processing';

  String getStatusDisplay() {
    switch (orderStatus.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'processing':
        return 'Processing';
      case 'shipped':
        return 'Shipped';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      case 'refunded':
        return 'Refunded';
      case 'returned':
        return 'Returned';
      default:
        return orderStatus;
    }
  }

  static String generateOrderNumber() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'ORD${timestamp.toString().substring(5)}';
  }

  /// Generate a 6-digit delivery verification code
  static String generateVerificationCode() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final code = (timestamp % 900000 + 100000); // Always 6 digits
    return code.toString();
  }

  OrderModel copyWith({
    String? id,
    String? userId,
    String? orderNumber,
    List<CartItemModel>? items,
    AddressModel? deliveryAddress,
    double? subtotal,
    double? discount,
    double? deliveryCharge,
    double? tax,
    double? total,
    String? paymentMethod,
    String? paymentStatus,
    String? orderStatus,
    String? razorpayOrderId,
    String? razorpayPaymentId,
    String? razorpaySignature,
    String? couponCode,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deliveryDate,
    String? orderType,
    String? autoFrequency,
    String? deliverySlot,
    // ✅ NEW: Live tracking
    String? deliveryPartnerId,
    DeliveryPartnerModel? deliveryPartner,
    DateTime? estimatedDeliveryTime,
    double? pickupLat,
    double? pickupLng,
    String? liveTrackingId,
    String? deliveryVerificationCode,
  }) {
    return OrderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      orderNumber: orderNumber ?? this.orderNumber,
      items: items ?? this.items,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      orderStatus: orderStatus ?? this.orderStatus,
      razorpayOrderId: razorpayOrderId ?? this.razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId ?? this.razorpayPaymentId,
      razorpaySignature: razorpaySignature ?? this.razorpaySignature,
      couponCode: couponCode ?? this.couponCode,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      orderType: orderType ?? this.orderType,
      autoFrequency: autoFrequency ?? this.autoFrequency,
      deliverySlot: deliverySlot ?? this.deliverySlot,
      // ✅ NEW: Live tracking
      deliveryPartnerId: deliveryPartnerId ?? this.deliveryPartnerId,
      deliveryPartner: deliveryPartner ?? this.deliveryPartner,
      estimatedDeliveryTime: estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      liveTrackingId: liveTrackingId ?? this.liveTrackingId,
      deliveryVerificationCode: deliveryVerificationCode ?? this.deliveryVerificationCode,
    );
  }

  @override
  String toString() {
    return 'OrderModel(id: $id, orderNumber: $orderNumber, status: $orderStatus, total: $total, items: ${items.length})';
  }
}
