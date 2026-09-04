import 'package:cloud_firestore/cloud_firestore.dart';

/// Enhanced Category Model with hierarchical support (4 levels)
/// Level 0: Main Category
/// Level 1: Sub-Category
/// Level 2: Sub-Sub-Category
/// Level 3: Sub-Sub-Sub-Category
class CategoryModel {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;         // Legacy - category image
  final String? iconUrl;          // ✅ NEW: Category icon (for sidebar)
  final String? bannerImageUrl;   // ✅ NEW: Category banner (for header)
  final String? iconName;         // Material icon name fallback
  final int displayOrder;
  final bool isActive;
  final DateTime createdAt;
  final int productCount;
  
  // ✅ NEW: Hierarchy support
  final String? parentId;         // Parent category ID (null = main category)
  final int level;                // 0=Main, 1=Sub, 2=Sub-Sub, 3=Sub-Sub-Sub
  final List<String> subcategoryIds;  // Child category IDs
  final String? slug;             // URL-friendly slug
  final Map<String, dynamic>? metadata; // Extra data

  CategoryModel({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    this.iconUrl,
    this.bannerImageUrl,
    this.iconName,
    this.displayOrder = 0,
    this.isActive = true,
    required this.createdAt,
    this.productCount = 0,
    // Hierarchy
    this.parentId,
    this.level = 0,
    this.subcategoryIds = const [],
    this.slug,
    this.metadata,
  });

  /// Check if this is a main (root) category
  bool get isMainCategory => parentId == null || parentId!.isEmpty;
  
  /// Check if this category can have children (max 4 levels: 0,1,2,3)
  bool get canHaveChildren => level < 3;
  
  /// Get hierarchy depth name
  String get levelName {
    switch (level) {
      case 0: return 'Main Category';
      case 1: return 'Sub-Category';
      case 2: return 'Sub-Sub-Category';
      case 3: return 'Sub-Sub-Sub-Category';
      default: return 'Category';
    }
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime createdAtDate;
    try {
      final createdAtValue = map['createdAt'];
      if (createdAtValue is Timestamp) {
        createdAtDate = createdAtValue.toDate();
      } else if (createdAtValue is DateTime) {
        createdAtDate = createdAtValue;
      } else {
        createdAtDate = DateTime.now();
      }
    } catch (e) {
      createdAtDate = DateTime.now();
    }
    
    // Parse subcategoryIds safely
    List<String> subcatIds = [];
    if (map['subcategoryIds'] != null) {
      subcatIds = List<String>.from(map['subcategoryIds'] ?? []);
    }
    
    return CategoryModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'],
      iconUrl: map['iconUrl'],
      bannerImageUrl: map['bannerImageUrl'],
      iconName: map['iconName'],
      displayOrder: map['displayOrder'] ?? 0,
      isActive: map['isActive'] ?? true,
      createdAt: createdAtDate,
      productCount: map['productCount'] ?? 0,
      // Hierarchy
      parentId: map['parentId'],
      level: map['level'] ?? 0,
      subcategoryIds: subcatIds,
      slug: map['slug'],
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'iconUrl': iconUrl,
      'bannerImageUrl': bannerImageUrl,
      'iconName': iconName,
      'displayOrder': displayOrder,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'productCount': productCount,
      // Hierarchy
      'parentId': parentId,
      'level': level,
      'subcategoryIds': subcategoryIds,
      'slug': slug,
      'metadata': metadata,
    };
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? iconUrl,
    String? bannerImageUrl,
    String? iconName,
    int? displayOrder,
    bool? isActive,
    DateTime? createdAt,
    int? productCount,
    // Hierarchy
    String? parentId,
    int? level,
    List<String>? subcategoryIds,
    String? slug,
    Map<String, dynamic>? metadata,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      iconUrl: iconUrl ?? this.iconUrl,
      bannerImageUrl: bannerImageUrl ?? this.bannerImageUrl,
      iconName: iconName ?? this.iconName,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      productCount: productCount ?? this.productCount,
      // Hierarchy
      parentId: parentId ?? this.parentId,
      level: level ?? this.level,
      subcategoryIds: subcategoryIds ?? this.subcategoryIds,
      slug: slug ?? this.slug,
      metadata: metadata ?? this.metadata,
    );
  }
  
  /// Generate URL-friendly slug from name
  static String generateSlug(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .trim();
  }
}
