import 'package:cloud_firestore/cloud_firestore.dart';

class BannerModel {
  final String id;
  final String imageUrl;
  final String title;
  final String subtitle;
  final String iconName;
  final String? targetRoute;
  final String colorHex;
  final bool isActive;
  final int priority;
  final DateTime createdAt;
  final DateTime? updatedAt;

  BannerModel({
    required this.id,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.iconName,
    this.targetRoute,
    required this.colorHex,
    required this.isActive,
    required this.priority,
    required this.createdAt,
    this.updatedAt,
  });

  // From Firestore (defensive parsing)
  factory BannerModel.fromFirestore(DocumentSnapshot doc) {
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
      } else {
        updatedAt = null;
      }
    } catch (_) {
      updatedAt = null;
    }

    return BannerModel(
      id: doc.id,
      imageUrl: (data['imageUrl'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      subtitle: (data['subtitle'] ?? '').toString(),
      iconName: (data['iconName'] ?? 'info').toString(),
      targetRoute: data['targetRoute'] != null ? data['targetRoute'].toString() : null,
      colorHex: (data['colorHex'] ?? '#4CAF50').toString(),
      isActive: data['isActive'] is bool ? data['isActive'] as bool : true,
      priority: data['priority'] is int ? data['priority'] as int : int.tryParse((data['priority'] ?? '0').toString()) ?? 0,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // To Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'imageUrl': imageUrl,
      'title': title,
      'subtitle': subtitle,
      'iconName': iconName,
      'targetRoute': targetRoute,
      'colorHex': colorHex,
      'isActive': isActive,
      'priority': priority,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  BannerModel copyWith({
    String? id,
    String? imageUrl,
    String? title,
    String? subtitle,
    String? iconName,
    String? targetRoute,
    String? colorHex,
    bool? isActive,
    int? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BannerModel(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      iconName: iconName ?? this.iconName,
      targetRoute: targetRoute ?? this.targetRoute,
      colorHex: colorHex ?? this.colorHex,
      isActive: isActive ?? this.isActive,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}