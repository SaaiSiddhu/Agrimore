import 'package:cloud_firestore/cloud_firestore.dart';

enum VendorStatus { active, inactive, blocked }

class VendorModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String companyName;
  final VendorStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double rating;
  final int totalOrders;

  VendorModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email = '',
    this.address = '',
    this.companyName = '',
    this.status = VendorStatus.active,
    required this.createdAt,
    required this.updatedAt,
    this.rating = 0.0,
    this.totalOrders = 0,
  });

  factory VendorModel.fromMap(Map<String, dynamic> data, String docId) {
    DateTime _parseDate(dynamic timestamp) {
      if (timestamp is Timestamp) return timestamp.toDate();
      if (timestamp is String) return DateTime.tryParse(timestamp) ?? DateTime.now();
      return DateTime.now();
    }

    VendorStatus _parseStatus(String? statusStr) {
      switch (statusStr) {
        case 'active':
          return VendorStatus.active;
        case 'inactive':
          return VendorStatus.inactive;
        case 'blocked':
          return VendorStatus.blocked;
        default:
          return VendorStatus.active;
      }
    }

    return VendorModel(
      id: docId,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      address: data['address'] ?? '',
      companyName: data['companyName'] ?? '',
      status: _parseStatus(data['status']),
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
      rating: (data['rating'] ?? 0.0).toDouble(),
      totalOrders: (data['totalOrders'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'companyName': companyName,
      'status': status.name,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'rating': rating,
      'totalOrders': totalOrders,
    };
  }

  VendorModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? companyName,
    VendorStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? rating,
    int? totalOrders,
  }) {
    return VendorModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      companyName: companyName ?? this.companyName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rating: rating ?? this.rating,
      totalOrders: totalOrders ?? this.totalOrders,
    );
  }
}
