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
  
  // KYC & Registration Fields
  final String? aadhaarNumber;
  final String? aadhaarFrontImage;
  final String? aadhaarBackImage;
  final String? selfieImage;
  final String? licenseNumber;
  final String? licenseImage;
  
  // Address Fields
  final String? address;
  final String? city;
  final String? pincode;
  
  // Bank Details
  final String? accountHolderName;
  final String? bankAccountNumber;
  final String? ifscCode;
  final String? upiId;
  
  // Status (pending, approved, rejected)
  final String status;
  final DateTime? createdAt;

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
    this.aadhaarNumber,
    this.aadhaarFrontImage,
    this.aadhaarBackImage,
    this.selfieImage,
    this.licenseNumber,
    this.licenseImage,
    this.address,
    this.city,
    this.pincode,
    this.accountHolderName,
    this.bankAccountNumber,
    this.ifscCode,
    this.upiId,
    this.status = 'approved', // Default approved for backward compatibility
    this.createdAt,
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

  /// Mask Aadhaar number for security
  String get maskedAadhaar {
    if (aadhaarNumber == null || aadhaarNumber!.length < 12) return 'XXXX-XXXX-XXXX';
    return 'XXXX-XXXX-${aadhaarNumber!.substring(8)}';
  }

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
      aadhaarNumber: map['aadhaarNumber'],
      aadhaarFrontImage: map['aadhaarFrontImage'],
      aadhaarBackImage: map['aadhaarBackImage'],
      selfieImage: map['selfieImage'],
      licenseNumber: map['licenseNumber'],
      licenseImage: map['licenseImage'],
      address: map['address'],
      city: map['city'],
      pincode: map['pincode'],
      accountHolderName: map['accountHolderName'],
      bankAccountNumber: map['bankAccountNumber'],
      ifscCode: map['ifscCode'],
      upiId: map['upiId'],
      status: map['status'] ?? 'approved',
      createdAt: parseDateTime(map['createdAt']),
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
      'aadhaarNumber': aadhaarNumber,
      'aadhaarFrontImage': aadhaarFrontImage,
      'aadhaarBackImage': aadhaarBackImage,
      'selfieImage': selfieImage,
      'licenseNumber': licenseNumber,
      'licenseImage': licenseImage,
      'address': address,
      'city': city,
      'pincode': pincode,
      'accountHolderName': accountHolderName,
      'bankAccountNumber': bankAccountNumber,
      'ifscCode': ifscCode,
      'upiId': upiId,
      'status': status,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
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
    String? aadhaarNumber,
    String? aadhaarFrontImage,
    String? aadhaarBackImage,
    String? selfieImage,
    String? licenseNumber,
    String? licenseImage,
    String? address,
    String? city,
    String? pincode,
    String? accountHolderName,
    String? bankAccountNumber,
    String? ifscCode,
    String? upiId,
    String? status,
    DateTime? createdAt,
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
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      aadhaarFrontImage: aadhaarFrontImage ?? this.aadhaarFrontImage,
      aadhaarBackImage: aadhaarBackImage ?? this.aadhaarBackImage,
      selfieImage: selfieImage ?? this.selfieImage,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      licenseImage: licenseImage ?? this.licenseImage,
      address: address ?? this.address,
      city: city ?? this.city,
      pincode: pincode ?? this.pincode,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      upiId: upiId ?? this.upiId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'DeliveryPartnerModel(id: $id, name: $name, vehicleNumber: $vehicleNumber, hasLocation: $hasLocation)';
  }
}
