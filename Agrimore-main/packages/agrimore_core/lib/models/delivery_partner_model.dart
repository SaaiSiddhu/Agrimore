import 'package:cloud_firestore/cloud_firestore.dart';

/// Delivery Partner Model for live order tracking
/// Contains partner information, vehicle details, and real-time location
class DeliveryPartnerModel {
  final String id;
  final String name;
  final String phone;
  final String? photoUrl;
  final String vehicleNumber;
  final String vehicleType; // bike, scooter, car, bicycle
  final double? currentLat;
  final double? currentLng;
  final DateTime? lastLocationUpdate;
  final double? rating;
  final int totalDeliveries;
  final bool isOnline;

  DeliveryPartnerModel({
    required this.id,
    required this.name,
    required this.phone,
    this.photoUrl,
    required this.vehicleNumber,
    this.vehicleType = 'bike',
    this.currentLat,
    this.currentLng,
    this.lastLocationUpdate,
    this.rating,
    this.totalDeliveries = 0,
    this.isOnline = true,
  });

  /// Check if location is available
  bool get hasLocation => currentLat != null && currentLng != null;

  /// Get vehicle icon name
  String get vehicleIcon {
    switch (vehicleType.toLowerCase()) {
      case 'ev':
        return 'electric_moped';
      case 'bike':
      default:
        return 'two_wheeler';
    }
  }

  /// Get formatted rating
  String get formattedRating => rating?.toStringAsFixed(1) ?? 'New';

  factory DeliveryPartnerModel.fromMap(Map<String, dynamic> map, [String? id]) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    }

    return DeliveryPartnerModel(
      id: id ?? map['id'] ?? '',
      name: map['name'] ?? 'Delivery Partner',
      phone: map['phone'] ?? '',
      photoUrl: map['photoUrl'],
      vehicleNumber: map['vehicleNumber'] ?? '',
      vehicleType: map['vehicleType'] ?? 'bike',
      currentLat: (map['currentLat'] as num?)?.toDouble(),
      currentLng: (map['currentLng'] as num?)?.toDouble(),
      lastLocationUpdate: parseDateTime(map['lastLocationUpdate']),
      rating: (map['rating'] as num?)?.toDouble(),
      totalDeliveries: (map['totalDeliveries'] as num?)?.toInt() ?? 0,
      isOnline: map['isOnline'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'photoUrl': photoUrl,
      'vehicleNumber': vehicleNumber,
      'vehicleType': vehicleType,
      'currentLat': currentLat,
      'currentLng': currentLng,
      'lastLocationUpdate': lastLocationUpdate != null
          ? Timestamp.fromDate(lastLocationUpdate!)
          : null,
      'rating': rating,
      'totalDeliveries': totalDeliveries,
      'isOnline': isOnline,
    };
  }

  DeliveryPartnerModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? photoUrl,
    String? vehicleNumber,
    String? vehicleType,
    double? currentLat,
    double? currentLng,
    DateTime? lastLocationUpdate,
    double? rating,
    int? totalDeliveries,
    bool? isOnline,
  }) {
    return DeliveryPartnerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
      rating: rating ?? this.rating,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  String toString() {
    return 'DeliveryPartnerModel(id: $id, name: $name, vehicleNumber: $vehicleNumber, hasLocation: $hasLocation)';
  }
}
