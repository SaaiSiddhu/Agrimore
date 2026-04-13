import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryModel {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final String? iconName;
  final int displayOrder;
  final bool isActive;
  final DateTime createdAt;
  final int productCount;

  CategoryModel({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    this.iconName,
    this.displayOrder = 0,
    this.isActive = true,
    required this.createdAt,
    this.productCount = 0,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map, String id) {
    return CategoryModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'],
      iconName: map['iconName'],
      displayOrder: map['displayOrder'] ?? 0,
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      productCount: map['productCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'iconName': iconName,
      'displayOrder': displayOrder,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'productCount': productCount,
    };
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? iconName,
    int? displayOrder,
    bool? isActive,
    DateTime? createdAt,
    int? productCount,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      iconName: iconName ?? this.iconName,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      productCount: productCount ?? this.productCount,
    );
  }
}
