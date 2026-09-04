// lib/models/category_section_slot_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Model for managing Category Section slots on the home screen
/// Each section (like "Grocery & Kitchen") contains up to 8 categories
/// with individual uploaded images for each category slot
class CategorySectionSlotModel {
  final String id;
  final int position; // Display order
  final String sectionName; // "Grocery & Kitchen"
  final List<String> categoryIds; // Categories in this section (max 8)
  
  // Individual images for each category slot (like bestsellers)
  final String? image1;
  final String? image2;
  final String? image3;
  final String? image4;
  final String? image5;
  final String? image6;
  final String? image7;
  final String? image8;
  
  final String? bgColorHex; // Background color for section
  final bool isActive;
  final DateTime? updatedAt;

  CategorySectionSlotModel({
    required this.id,
    required this.position,
    required this.sectionName,
    this.categoryIds = const [],
    this.image1,
    this.image2,
    this.image3,
    this.image4,
    this.image5,
    this.image6,
    this.image7,
    this.image8,
    this.bgColorHex,
    this.isActive = true,
    this.updatedAt,
  });

  /// Get all non-null images as a list
  List<String> get images {
    return [image1, image2, image3, image4, image5, image6, image7, image8]
        .whereType<String>()
        .where((img) => img.isNotEmpty)
        .toList();
  }

  /// Get image for a specific slot (1-8)
  String? getImageForSlot(int slot) {
    switch (slot) {
      case 1: return image1;
      case 2: return image2;
      case 3: return image3;
      case 4: return image4;
      case 5: return image5;
      case 6: return image6;
      case 7: return image7;
      case 8: return image8;
      default: return null;
    }
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

  /// Check if slot has categories configured
  bool get hasCategories => categoryIds.isNotEmpty;

  /// Get category count
  int get categoryCount => categoryIds.length;

  factory CategorySectionSlotModel.fromMap(Map<String, dynamic> map, String id) {
    return CategorySectionSlotModel(
      id: id,
      position: map['position'] ?? 1,
      sectionName: map['sectionName'] ?? '',
      categoryIds: List<String>.from(map['categoryIds'] ?? []),
      image1: map['image1'],
      image2: map['image2'],
      image3: map['image3'],
      image4: map['image4'],
      image5: map['image5'],
      image6: map['image6'],
      image7: map['image7'],
      image8: map['image8'],
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
      'sectionName': sectionName,
      'categoryIds': categoryIds,
      'image1': image1,
      'image2': image2,
      'image3': image3,
      'image4': image4,
      'image5': image5,
      'image6': image6,
      'image7': image7,
      'image8': image8,
      'bgColorHex': bgColorHex,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  CategorySectionSlotModel copyWith({
    String? id,
    int? position,
    String? sectionName,
    List<String>? categoryIds,
    String? image1,
    String? image2,
    String? image3,
    String? image4,
    String? image5,
    String? image6,
    String? image7,
    String? image8,
    String? bgColorHex,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return CategorySectionSlotModel(
      id: id ?? this.id,
      position: position ?? this.position,
      sectionName: sectionName ?? this.sectionName,
      categoryIds: categoryIds ?? this.categoryIds,
      image1: image1 ?? this.image1,
      image2: image2 ?? this.image2,
      image3: image3 ?? this.image3,
      image4: image4 ?? this.image4,
      image5: image5 ?? this.image5,
      image6: image6 ?? this.image6,
      image7: image7 ?? this.image7,
      image8: image8 ?? this.image8,
      bgColorHex: bgColorHex ?? this.bgColorHex,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Create an empty slot for a position
  factory CategorySectionSlotModel.empty(int position) {
    return CategorySectionSlotModel(
      id: '',
      position: position,
      sectionName: 'Configure Section',
      isActive: false,
    );
  }
}
