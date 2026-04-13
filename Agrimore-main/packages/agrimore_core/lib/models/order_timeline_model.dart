import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'order_status.dart';

class OrderTimelineModel {
  final OrderStatus status;
  final String title;
  final String description;
  final DateTime timestamp;
  final String? trackingNumber; // ✅ ADDED
  final String? location; // ✅ ADDED
  final String? updatedBy; // ✅ ADDED

  OrderTimelineModel({
    required this.status,
    required this.title,
    required this.description,
    required this.timestamp,
    this.trackingNumber,
    this.location,
    this.updatedBy,
  });

  factory OrderTimelineModel.fromMap(Map<String, dynamic> map) {
    try {
      // ✅ Parse timestamp safely
      DateTime parsedTimestamp = DateTime.now();
      try {
        final tsValue = map['timestamp'];
        if (tsValue is Timestamp) {
          parsedTimestamp = tsValue.toDate();
        } else if (tsValue is DateTime) {
          parsedTimestamp = tsValue;
        } else if (tsValue is int) {
          parsedTimestamp = DateTime.fromMillisecondsSinceEpoch(tsValue);
        } else if (tsValue != null &&
            tsValue.runtimeType.toString().contains('Timestamp')) {
          parsedTimestamp = tsValue.toDate();
        }
      } catch (e) {
        debugPrint('⚠️ Error parsing timeline timestamp: $e');
        parsedTimestamp = DateTime.now();
      }

      // ✅ Parse status safely
      OrderStatus parsedStatus = OrderStatus.pending;
      try {
        final statusStr = map['status'] ?? 'pending';
        parsedStatus = OrderStatus.values.firstWhere(
          (e) => e.toString().split('.').last == statusStr,
          orElse: () => OrderStatus.pending,
        );
      } catch (e) {
        debugPrint('⚠️ Error parsing timeline status: $e');
      }

      return OrderTimelineModel(
        status: parsedStatus,
        title: map['title'] ?? 'Order Updated',
        description: map['description'] ?? '',
        timestamp: parsedTimestamp,
        trackingNumber: map['trackingNumber'] as String?, // ✅ ADDED
        location: map['location'] as String?, // ✅ ADDED
        updatedBy: map['updatedBy'] as String?, // ✅ ADDED
      );
    } catch (e) {
      debugPrint('❌ Error parsing OrderTimelineModel: $e');
      return OrderTimelineModel(
        status: OrderStatus.pending,
        title: 'Order Updated',
        description: '',
        timestamp: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status.toString().split('.').last,
      'title': title,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
      'trackingNumber': trackingNumber, // ✅ ADDED
      'location': location, // ✅ ADDED
      'updatedBy': updatedBy, // ✅ ADDED
    };
  }

  // Get status display name
  String get statusDisplayName {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.processing:
        return 'Processing';
      case OrderStatus.shipped:
        return 'Shipped';
      case OrderStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.returned:
        return 'Returned';
      case OrderStatus.refunded:
        return 'Refunded';
    }
  }

  @override
  String toString() {
    return 'OrderTimelineModel(status: $status, title: $title, timestamp: $timestamp)';
  }
}
