// lib/models/bestseller_slot_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Model for managing Bestseller slots on the home screen
/// Each slot represents a category with 4 custom product images
class BestsellerSlotModel {
  final String id;
  final int position; // 1-9 slot position
  final String categoryId;
  final String categoryName;
  final String? image1;
  final String? image2;
  final String? image3;
  final String? image4;
  final String? bgColorHex;
  final bool isActive;
  final DateTime? updatedAt;

  BestsellerSlotModel({
    required this.id,
    required this.position,
    required this.categoryId,
    required this.categoryName,
    this.image1,
    this.image2,
    this.image3,
    this.image4,
    this.bgColorHex,
    this.isActive = true,
    this.updatedAt,
  });

  /// Get all non-null images as a list
  List<String> get images {
    return [image1, image2, image3, image4]
        .whereType<String>()
        .where((img) => img.isNotEmpty)
        .toList();
  }

  /// Get background color from hex
  Color get bgColor {
    if (bgColorHex == null || bgColorHex!.isEmpty) {
      return const Color(0xFFFFF8E1); // Default warm amber
    }
    try {
      return Color(int.parse(bgColorHex!.replaceFirst('#', '0xFF')));
    } catch (e) {
      return const Color(0xFFFFF8E1);
    }
  }

  factory BestsellerSlotModel.fromMap(Map<String, dynamic> map, String id) {
    return BestsellerSlotModel(
      id: id,
      position: map['position'] ?? 1,
      categoryId: map['categoryId'] ?? '',
      categoryName: map['categoryName'] ?? '',
      image1: map['image1'],
      image2: map['image2'],
      image3: map['image3'],
      image4: map['image4'],
      bgColorHex: map['bgColorHex'],
      isActive: map['isActive'] ?? true,
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'position': position,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'image1': image1,
      'image2': image2,
      'image3': image3,
      'image4': image4,
      'bgColorHex': bgColorHex,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  BestsellerSlotModel copyWith({
    String? id,
    int? position,
    String? categoryId,
    String? categoryName,
    String? image1,
    String? image2,
    String? image3,
    String? image4,
    String? bgColorHex,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return BestsellerSlotModel(
      id: id ?? this.id,
      position: position ?? this.position,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      image1: image1 ?? this.image1,
      image2: image2 ?? this.image2,
      image3: image3 ?? this.image3,
      image4: image4 ?? this.image4,
      bgColorHex: bgColorHex ?? this.bgColorHex,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Create an empty slot for a position
  factory BestsellerSlotModel.empty(int position) {
    return BestsellerSlotModel(
      id: '',
      position: position,
      categoryId: '',
      categoryName: 'Select Category',
      isActive: false,
    );
  }
}
