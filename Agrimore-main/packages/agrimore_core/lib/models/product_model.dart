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
    // Support multiple Firestore field name conventions:
    // name: 'name' | 'weight' | 'label' | 'title'
    // salePrice: 'salePrice' | 'price' | 'discountedPrice'
    // originalPrice: 'originalPrice' | 'mrp' | 'compareAtPrice'
    final rawName = map['name'] ?? map['weight'] ?? map['label'] ?? map['title'] ?? '';
    final rawSalePrice = (map['salePrice'] ?? map['price'] ?? map['discountedPrice']);
    final rawOriginalPrice = (map['originalPrice'] ?? map['mrp'] ?? map['compareAtPrice']);
    return ProductVariant(
      id: map['id'] ?? '',
      name: rawName.toString(),
      sku: map['sku'],
      salePrice: (rawSalePrice as num?)?.toDouble() ?? 0.0,
      originalPrice: (rawOriginalPrice as num?)?.toDouble(),
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
  /// Optional display name from legacy/RN docs (`categoryName`).
  final String? categoryName;
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
  final String location;
  final String sellerId;
  final int? lowStockThreshold;

  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.salePrice,
    this.originalPrice,
    required this.categoryId,
    this.categoryName,
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
    this.location = '',
    this.sellerId = '',
    this.lowStockThreshold,
  });

  // Compatibility Getters
  double get price => salePrice;
  String get primaryImage => images.isNotEmpty ? images.first : '';
  String? get imageUrl => images.isNotEmpty ? images.first : null;
  bool get isInStock => stock > 0;
  bool get inStock => stock > 0;
  String get category => categoryId;

  /// Merge image URLs from Firestore/RN/seller field naming into one ordered list.
  static List<String> mergeImageSources(
    Map<String, dynamic> map,
    List<ProductVariant> variants,
  ) {
    final seen = <String>{};
    final out = <String>[];

    void addOne(dynamic v) {
      if (v == null) return;
      if (v is String) {
        final t = v.trim();
        if (t.isEmpty) return;
        if (seen.add(t)) out.add(t);
        return;
      }
      if (v is List) {
        for (final e in v) {
          if (e is String) addOne(e);
        }
      }
    }

    addOne(map['images']);
    addOne(map['imageUrls']);
    addOne(map['imageURL']);
    addOne(map['photoUrls']);
    addOne(map['photos']);
    addOne(map['pictures']);
    addOne(map['gallery']);
    addOne(map['thumbnail']);
    addOne(map['coverImage']);

    for (final v in variants) {
      for (final img in v.images) {
        addOne(img);
      }
    }
    return out;
  }

  static String parseCategoryId(Map<String, dynamic> map) {
    final raw = map['categoryId'];
    if (raw != null && raw.toString().trim().isNotEmpty) {
      return raw.toString().trim();
    }
    final cat = map['category'];
    if (cat is Map && cat['id'] != null && cat['id'].toString().trim().isNotEmpty) {
      return cat['id'].toString().trim();
    }
    if (cat is String && cat.trim().isNotEmpty) return cat.trim();
    final name = map['categoryName']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    return 'general';
  }

  static String? parseCategoryNameField(Map<String, dynamic> map) {
    final cn = map['categoryName']?.toString().trim();
    if (cn != null && cn.isNotEmpty) return cn;
    final cat = map['category'];
    if (cat is Map && cat['name'] != null) {
      final n = cat['name'].toString().trim();
      if (n.isNotEmpty) return n;
    }
    return null;
  }

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
      if (categoryName != null) 'categoryName': categoryName,
      'images': images,
      'imageUrls': images,
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
      'location': location,
      'sellerId': sellerId,
      'lowStockThreshold': lowStockThreshold,
    };
  }

  Map<String, dynamic> toMap() => toJson();

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel.fromMap(json, json['id'] ?? '');
  }

  factory ProductModel.fromMap(Map<String, dynamic> map, String id) {
    // Helper to safely parse dates that might be stored as String, Int, or Timestamp in old DBs
    DateTime parseDateSafely(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
        final parsedInt = int.tryParse(value);
        if (parsedInt != null) return DateTime.fromMillisecondsSinceEpoch(parsedInt);
      }
      return DateTime.now();
    }

    final variantOptions = (map['variantOptions'] as List<dynamic>?)
            ?.map((v) => VariantOption.fromMap(v as Map<String, dynamic>))
            .toList() ??
        [];
    final variants = (map['variants'] as List<dynamic>?)
            ?.map((v) => ProductVariant.fromMap(v as Map<String, dynamic>))
            .toList() ??
        [];

    final mergedImages = mergeImageSources(map, variants);
    final legacySingle = map['imageUrl'] is String ? (map['imageUrl'] as String).trim() : '';
    final images = mergedImages.isNotEmpty
        ? mergedImages
        : (legacySingle.isNotEmpty ? <String>[legacySingle] : <String>[]);

    return ProductModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      salePrice: (map['salePrice'] as num?)?.toDouble() ?? (map['price'] as num?)?.toDouble() ?? 0.0,
      originalPrice: (map['originalPrice'] as num?)?.toDouble() ?? (map['mrp'] as num?)?.toDouble(),
      categoryId: parseCategoryId(map),
      categoryName: parseCategoryNameField(map),
      images: images,
      stock: (map['stock'] as num?)?.toInt() ?? 999,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      isFeatured: map['isFeatured'] ?? false,
      isActive: map['isActive'] ?? true,
      createdAt: parseDateSafely(map['createdAt']),
      updatedAt: parseDateSafely(map['updatedAt']),
      unit: map['unit'],
      minOrderQuantity: (map['minOrderQuantity'] as num?)?.toInt(),
      maxOrderQuantity: (map['maxOrderQuantity'] as num?)?.toInt(),
      isNew: map['isNew'] ?? false,
      isVerified: map['isVerified'] ?? false,
      isTrending: map['isTrending'] ?? false,
      specifications: map['specifications'] != null
          ? Map<String, String>.from(map['specifications'] as Map)
          : null,
      shippingDays: map['shippingDays'],
      shippingPrice: (map['shippingPrice'] as num?)?.toDouble(),
      freeShippingAbove: (map['freeShippingAbove'] as num?)?.toDouble(),
      isFreeDelivery: map['isFreeDelivery'],
      expressDelivery: map['expressDelivery'],
      expressDeliveryDays: map['expressDeliveryDays'],
      variantOptions: variantOptions,
      variants: variants,
      relatedProductIds: List<String>.from(map['relatedProductIds'] ?? []),
      location: map['location']?.toString() ?? '',
      sellerId: map['sellerId']?.toString() ?? '',
      lowStockThreshold: (map['lowStockThreshold'] as num?)?.toInt(),
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
    String? categoryName,
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
    String? location,
    String? sellerId,
    int? lowStockThreshold,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      salePrice: salePrice ?? this.salePrice,
      originalPrice: originalPrice ?? this.originalPrice,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
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
      location: location ?? this.location,
      sellerId: sellerId ?? this.sellerId,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
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