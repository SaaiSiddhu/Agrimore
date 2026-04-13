import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddressModel {
  final String id;
  final String userId;
  final String name;
  final String phone;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String zipcode;
  final String country;
  final double? latitude;
  final double? longitude;
  final bool isDefault;
  final String? addressType; // home, work, other
  final String? landmark;
  final DateTime createdAt;

  AddressModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    required this.addressLine1,
    required this.addressLine2,
    required this.city,
    required this.state,
    required this.zipcode,
    this.country = 'India',
    this.latitude,
    this.longitude,
    this.isDefault = false,
    this.addressType,
    this.landmark,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // ============================================
  // ✅ IMPROVED: Parse DateTime from Timestamp
  // ============================================
  static DateTime _parseDateTime(dynamic value) {
    try {
      // If null, return now
      if (value == null) return DateTime.now();

      // ✅ If already DateTime, return it
      if (value is DateTime) return value;

      // ✅ Direct Timestamp check (cloud_firestore package)
      if (value is Timestamp) {
        return value.toDate();
      }

      // ✅ Check runtime type string for Timestamp
      final typeString = value.runtimeType.toString();
      if (typeString.contains('Timestamp') ||
          typeString.contains('_JsonSerializableTimestamp')) {
        try {
          return value.toDate();
        } catch (e) {
          debugPrint('⚠️ Timestamp.toDate() failed: $e');
        }
      }

      // ✅ If it's an int (milliseconds since epoch)
      if (value is int) {
        try {
          if (value > 10000000000) {
            // Already in milliseconds
            return DateTime.fromMillisecondsSinceEpoch(value);
          } else if (value > 0) {
            // Might be seconds, convert to milliseconds
            return DateTime.fromMillisecondsSinceEpoch(value * 1000);
          }
        } catch (e) {
          debugPrint('⚠️ Int timestamp parse failed: $e');
        }
      }

      // ✅ If it's a double (seconds)
      if (value is double) {
        try {
          if (value > 10000000000) {
            return DateTime.fromMillisecondsSinceEpoch(value.toInt());
          }
          return DateTime.fromMillisecondsSinceEpoch((value * 1000).toInt());
        } catch (e) {
          debugPrint('⚠️ Double timestamp parse failed: $e');
        }
      }

      // ✅ If string representation
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          debugPrint('⚠️ String datetime parse failed: $e');
        }
      }

      debugPrint(
          '⚠️ Unknown timestamp type: ${value.runtimeType}, value: $value');
      return DateTime.now();
    } catch (e) {
      debugPrint('❌ DateTime parse error: $e');
      return DateTime.now();
    }
  }

  // ============================================
  // FROM MAP - ✅ FIXED WITH PROPER PARSING
  // ============================================
  factory AddressModel.fromMap(Map<String, dynamic> map) {
    try {
      return AddressModel(
        id: (map['id'] ?? '').toString(),
        userId: (map['userId'] ?? '').toString(),
        name: (map['name'] ?? '').toString(),
        phone: (map['phone'] ?? '').toString(),
        addressLine1: (map['addressLine1'] ?? '').toString(),
        addressLine2: (map['addressLine2'] ?? '').toString(),
        city: (map['city'] ?? '').toString(),
        state: (map['state'] ?? '').toString(),
        // ✅ Support both names
        zipcode: (map['zipcode'] ?? map['pincode'] ?? '').toString(),
        country: (map['country'] ?? 'India').toString(),
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        isDefault: map['isDefault'] == true,
        addressType: map['addressType']?.toString(),
        landmark: map['landmark']?.toString(),
        // ✅ CRITICAL FIX: Proper Timestamp parsing
        createdAt: map['createdAt'] != null
            ? _parseDateTime(map['createdAt'])
            : DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ Error parsing AddressModel: $e');
      return AddressModel(
        id: (map['id'] ?? '').toString(),
        userId: '',
        name: 'Default Address',
        phone: '',
        addressLine1: '',
        addressLine2: '',
        city: '',
        state: '',
        zipcode: '',
      );
    }
  }

  // ============================================
  // FROM FIRESTORE
  // ============================================
  factory AddressModel.fromFirestore(DocumentSnapshot doc) {
    try {
      return AddressModel.fromMap({
        ...doc.data() as Map<String, dynamic>,
        'id': doc.id,
      });
    } catch (e) {
      debugPrint('❌ Error parsing from Firestore: $e');
      return AddressModel(
        id: doc.id,
        userId: '',
        name: 'Default Address',
        phone: '',
        addressLine1: '',
        addressLine2: '',
        city: '',
        state: '',
        zipcode: '',
      );
    }
  }

  // ============================================
  // FROM JSON (Alias for fromMap)
  // ============================================
  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel.fromMap(json);
  }

  // ============================================
  // TO MAP
  // ============================================
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'phone': phone,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'city': city,
      'state': state,
      'zipcode': zipcode,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'isDefault': isDefault,
      'addressType': addressType,
      'landmark': landmark,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // ============================================
  // TO JSON (Alias for toMap)
  // ============================================
  Map<String, dynamic> toJson() => toMap();

  // ============================================
  // GET FULL ADDRESS STRING
  // ============================================
  String get fullAddress {
    final parts = [
      addressLine1,
      if (addressLine2.isNotEmpty) addressLine2,
      if (landmark != null && landmark!.isNotEmpty) 'Near $landmark',
      city,
      state,
      zipcode,
      country,
    ];
    return parts.where((part) => part.isNotEmpty).join(', ');
  }

  // ============================================
  // GET SHORT ADDRESS (FIRST LINE + CITY)
  // ============================================
  String get shortAddress => '$addressLine1, $city';

  // ============================================
  // GET ZIP CODE (BACKWARD COMPATIBILITY)
  // ============================================
  String get zipCode => zipcode; // ✅ Support both zipCode and zipcode

  // ============================================
  // COPY WITH
  // ============================================
  AddressModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? phone,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? zipcode,
    String? country,
    double? latitude,
    double? longitude,
    bool? isDefault,
    String? addressType,
    String? landmark,
    DateTime? createdAt,
  }) {
    return AddressModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      state: state ?? this.state,
      zipcode: zipcode ?? this.zipcode,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isDefault: isDefault ?? this.isDefault,
      addressType: addressType ?? this.addressType,
      landmark: landmark ?? this.landmark,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ============================================
  // EQUALS & HASH CODE
  // ============================================
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddressModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId;

  @override
  int get hashCode => id.hashCode ^ userId.hashCode;

  // ============================================
  // TO STRING
  // ============================================
  @override
  String toString() =>
      'AddressModel(id: $id, name: $name, city: $city, addressLine1: $addressLine1)';
}
