import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // Import for debugPrint

// ============================================
// NEW: Product Variant Class
// ============================================
class ProductVariant {
  final String id;
  final String name; // e.g., "Blue, 128GB"
  final String? sku;
  final double salePrice;
  final double? originalPrice;
  final int stock;
  final List<String> images;
  final Map<String, String> options; // e.g., {"Color": "Blue", "Storage": "128GB"}

  ProductVariant({
    required this.id,
    required this.name,
    this.sku,
    required this.salePrice,
    this.originalPrice,
    required this.stock,
    this.images = const [],
    required this.options,
  });

  bool get inStock => stock > 0;
  String get primaryImage => images.isNotEmpty ? images.first : '';
  int get discount {
    if (originalPrice != null && originalPrice! > salePrice) {
      return (((originalPrice! - salePrice) / originalPrice!) * 100).round();
    }
    return 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sku': sku,
      'salePrice': salePrice,
      'originalPrice': originalPrice,
      'stock': stock,
      'images': images,
      'options': options,
    };
  }

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    return ProductVariant(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      sku: map['sku'],
      salePrice: (map['salePrice'] as num?)?.toDouble() ?? 0.0,
      originalPrice: (map['originalPrice'] as num?)?.toDouble(),
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      images: List<String>.from(map['images'] ?? []),
      options: Map<String, String>.from(map['options'] ?? {}),
    );
  }
}

// ============================================
// NEW: Variant Option Class
// ============================================
class VariantOption {
  final String name; // e.g., "Color"
  final List<String> values; // e.g., ["Red", "Blue", "Green"]

  VariantOption({required this.name, required this.values});

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'values': values,
    };
  }

  factory VariantOption.fromMap(Map<String, dynamic> map) {
    return VariantOption(
      name: map['name'] ?? '',
      values: List<String>.from(map['values'] ?? []),
    );
  }
}

// ============================================
// ENHANCED: Product Model
// ============================================
class ProductModel {
  final String id;
  final String name;
  final String description;
  final double salePrice; // Base price
  final double? originalPrice; // Base price
  final String categoryId;
  final List<String> images; // Base images
  final int stock; // Base stock
  final double rating;
  final int reviewCount;
  final bool isFeatured;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? unit;
  final int? minOrderQuantity;
  final int? maxOrderQuantity;
  final bool isNew;
  final bool isVerified;
  final bool isTrending;
  final Map<String, String>? specifications;
  final String? shippingDays;
  final double? shippingPrice;
  final double? freeShippingAbove;
  final bool? isFreeDelivery;
  final bool? expressDelivery;
  final String? expressDeliveryDays;
  final List<VariantOption> variantOptions;
  final List<ProductVariant> variants;
  final List<String>? relatedProductIds;

  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.salePrice,
    this.originalPrice,
    required this.categoryId,
    required this.images,
    required this.stock,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.isFeatured = false,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.unit,
    this.minOrderQuantity,
    this.maxOrderQuantity,
    this.isNew = false,
    this.isVerified = false,
    this.isTrending = false,
    this.specifications,
    this.shippingDays,
    this.shippingPrice,
    this.freeShippingAbove,
    this.isFreeDelivery,
    this.expressDelivery,
    this.expressDeliveryDays,
    this.variantOptions = const [],
    this.variants = const [],
    this.relatedProductIds,
  });

  // Compatibility Getters
  double get price => salePrice;
  String get primaryImage => images.isNotEmpty ? images.first : '';
  String? get imageUrl => images.isNotEmpty ? images.first : null;
  bool get isInStock => stock > 0;
  bool get inStock => stock > 0;
  String get category => categoryId;

  int get discount {
    if (originalPrice != null && originalPrice! > salePrice) {
      return (((originalPrice! - salePrice) / originalPrice!) * 100).round();
    }
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'salePrice': salePrice,
      'originalPrice': originalPrice,
      'categoryId': categoryId,
      'images': images,
      'stock': stock,
      'rating': rating,
      'reviewCount': reviewCount,
      'isFeatured': isFeatured,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'unit': unit,
      'minOrderQuantity': minOrderQuantity,
      'maxOrderQuantity': maxOrderQuantity,
      'isNew': isNew,
      'isVerified': isVerified,
      'isTrending': isTrending,
      'specifications': specifications,
      'shippingDays': shippingDays,
      'shippingPrice': shippingPrice,
      'freeShippingAbove': freeShippingAbove,
      'isFreeDelivery': isFreeDelivery,
      'expressDelivery': expressDelivery,
      'expressDeliveryDays': expressDeliveryDays,
      'variantOptions': variantOptions.map((v) => v.toMap()).toList(),
      'variants': variants.map((v) => v.toMap()).toList(),
      'relatedProductIds': relatedProductIds,
    };
  }

  Map<String, dynamic> toMap() => toJson();

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel.fromMap(json, json['id'] ?? '');
  }

  factory ProductModel.fromMap(Map<String, dynamic> map, String id) {
    return ProductModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      salePrice: (map['salePrice'] as num?)?.toDouble() ?? 0.0,
      originalPrice: (map['originalPrice'] as num?)?.toDouble(),
      categoryId: map['categoryId'] ?? 'general',
      images: List<String>.from(map['images'] ?? []),
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      isFeatured: map['isFeatured'] ?? false,
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      unit: map['unit'],
      minOrderQuantity: (map['minOrderQuantity'] as num?)?.toInt(),
      maxOrderQuantity: (map['maxOrderQuantity'] as num?)?.toInt(),
      isNew: map['isNew'] ?? false,
      isVerified: map['isVerified'] ?? false,
      isTrending: map['isTrending'] ?? false,
      specifications: map['specifications'] != null
          ? Map<String, String>.from(map['specifications'])
          : null,
      shippingDays: map['shippingDays'],
      shippingPrice: (map['shippingPrice'] as num?)?.toDouble(),
      freeShippingAbove: (map['freeShippingAbove'] as num?)?.toDouble(),
      isFreeDelivery: map['isFreeDelivery'],
      expressDelivery: map['expressDelivery'],
      expressDeliveryDays: map['expressDeliveryDays'],
      variantOptions: (map['variantOptions'] as List<dynamic>?)
          ?.map((v) => VariantOption.fromMap(v as Map<String, dynamic>))
          .toList() ?? [],
      variants: (map['variants'] as List<dynamic>?)
          ?.map((v) => ProductVariant.fromMap(v as Map<String, dynamic>))
          .toList() ?? [],
      relatedProductIds: List<String>.from(map['relatedProductIds'] ?? []),
    );
  }

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductModel.fromMap(data, doc.id);
  }

  // ✅ FIXED: This method now includes ALL fields for a complete copy
  ProductModel copyWith({
    String? id,
    String? name,
    String? description,
    double? salePrice,
    double? originalPrice,
    String? categoryId,
    List<String>? images,
    int? stock,
    double? rating,
    int? reviewCount,
    bool? isFeatured,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? unit,
    int? minOrderQuantity,
    int? maxOrderQuantity,
    bool? isNew,
    bool? isVerified,
    bool? isTrending,
    Map<String, String>? specifications,
    String? shippingDays,
    double? shippingPrice,
    double? freeShippingAbove,
    bool? isFreeDelivery,
    bool? expressDelivery,
    String? expressDeliveryDays,
    List<VariantOption>? variantOptions,
    List<ProductVariant>? variants,
    List<String>? relatedProductIds,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      salePrice: salePrice ?? this.salePrice,
      originalPrice: originalPrice ?? this.originalPrice,
      categoryId: categoryId ?? this.categoryId,
      images: images ?? this.images,
      stock: stock ?? this.stock,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isFeatured: isFeatured ?? this.isFeatured,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      unit: unit ?? this.unit,
      minOrderQuantity: minOrderQuantity ?? this.minOrderQuantity,
      maxOrderQuantity: maxOrderQuantity ?? this.maxOrderQuantity,
      isNew: isNew ?? this.isNew,
      isVerified: isVerified ?? this.isVerified,
      isTrending: isTrending ?? this.isTrending,
      specifications: specifications ?? this.specifications,
      shippingDays: shippingDays ?? this.shippingDays,
      shippingPrice: shippingPrice ?? this.shippingPrice,
      freeShippingAbove: freeShippingAbove ?? this.freeShippingAbove,
      isFreeDelivery: isFreeDelivery ?? this.isFreeDelivery,
      expressDelivery: expressDelivery ?? this.expressDelivery,
      expressDeliveryDays: expressDeliveryDays ?? this.expressDeliveryDays,
      variantOptions: variantOptions ?? this.variantOptions,
      variants: variants ?? this.variants,
      relatedProductIds: relatedProductIds ?? this.relatedProductIds,
    );
  }

  @override
  String toString() {
    return 'ProductModel(id: $id, name: $name, price: $salePrice, category: $categoryId, verified: $isVerified)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}