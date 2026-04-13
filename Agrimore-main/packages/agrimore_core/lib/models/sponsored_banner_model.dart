import 'package:cloud_firestore/cloud_firestore.dart';

class SponsoredBannerModel {
  final String id;
  final String productId; // Link to product
  final String imageUrl;
  final String title;
  final String subtitle;
  final String colorHex;
  final bool isActive;
  final int priority;
  final DateTime createdAt;
  final DateTime? updatedAt;

  SponsoredBannerModel({
    required this.id,
    required this.productId,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.colorHex,
    required this.isActive,
    required this.priority,
    required this.createdAt,
    this.updatedAt,
  });

  // From Firestore
  factory SponsoredBannerModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() ?? {}) as Map<String, dynamic>;

    DateTime createdAt;
    try {
      final createdRaw = data['createdAt'];
      if (createdRaw is Timestamp) {
        createdAt = createdRaw.toDate();
      } else if (createdRaw is DateTime) {
        createdAt = createdRaw;
      } else {
        createdAt = DateTime.now();
      }
    } catch (_) {
      createdAt = DateTime.now();
    }

    DateTime? updatedAt;
    try {
      final updatedRaw = data['updatedAt'];
      if (updatedRaw is Timestamp) {
        updatedAt = updatedRaw.toDate();
      } else if (updatedRaw is DateTime) {
        updatedAt = updatedRaw;
      }
    } catch (_) {
      updatedAt = null;
    }

    return SponsoredBannerModel(
      id: doc.id,
      productId: (data['productId'] ?? '').toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      subtitle: (data['subtitle'] ?? '').toString(),
      colorHex: (data['colorHex'] ?? '#4CAF50').toString(),
      isActive: data['isActive'] is bool ? data['isActive'] as bool : true,
      priority: data['priority'] is int
          ? data['priority'] as int
          : int.tryParse((data['priority'] ?? '0').toString()) ?? 0,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // To Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'imageUrl': imageUrl,
      'title': title,
      'subtitle': subtitle,
      'colorHex': colorHex,
      'isActive': isActive,
      'priority': priority,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  SponsoredBannerModel copyWith({
    String? id,
    String? productId,
    String? imageUrl,
    String? title,
    String? subtitle,
    String? colorHex,
    bool? isActive,
    int? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SponsoredBannerModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      imageUrl: imageUrl ?? this.imageUrl,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      colorHex: colorHex ?? this.colorHex,
      isActive: isActive ?? this.isActive,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
