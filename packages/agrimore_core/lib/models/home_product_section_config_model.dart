import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin-configured ordering for Home's per-category product-carousel
/// sections (HOME-3). Selects WHICH category becomes a section, its title
/// and item cap — never product data itself (price/stock/images stay
/// sourced from ProductModel/ProductProvider exclusively). Mirrors
/// BannerModel's four-part pattern (fields, fromFirestore, toFirestore,
/// copyWith).
///
/// An empty/absent collection is a valid, expected state (a fresh install,
/// or before any admin has configured a section) — callers fall back to
/// the pre-existing loop-all-active-categories behaviour, never a blank
/// Home; this model carries no default-section data of its own.
class HomeProductSectionConfigModel {
  final String id;
  final String categoryId;

  /// Null = use the category's own name, unchanged from today's behaviour.
  final String? titleOverride;

  /// Caps how many products render in this section; the pre-existing
  /// default was a hardcoded 10, kept as this field's own default so an
  /// admin who creates a row without touching this value sees no change.
  final int maxItems;

  /// Display order among configured sections, ascending. Ties broken by
  /// [id] for a stable sort — admin reorders by changing this value.
  final int position;

  final bool isActive;
  final DateTime? updatedAt;

  const HomeProductSectionConfigModel({
    required this.id,
    required this.categoryId,
    this.titleOverride,
    this.maxItems = 10,
    required this.position,
    this.isActive = true,
    this.updatedAt,
  });

  factory HomeProductSectionConfigModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() ?? {}) as Map<String, dynamic>;
    return HomeProductSectionConfigModel(
      id: doc.id,
      categoryId: (data['categoryId'] ?? '').toString(),
      titleOverride: data['titleOverride'] != null &&
              (data['titleOverride'] as String).trim().isNotEmpty
          ? data['titleOverride'] as String
          : null,
      maxItems: data['maxItems'] is int
          ? data['maxItems'] as int
          : int.tryParse((data['maxItems'] ?? '10').toString()) ?? 10,
      position: data['position'] is int
          ? data['position'] as int
          : int.tryParse((data['position'] ?? '0').toString()) ?? 0,
      isActive: data['isActive'] is bool ? data['isActive'] as bool : true,
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'categoryId': categoryId,
      'titleOverride': titleOverride,
      'maxItems': maxItems,
      'position': position,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  HomeProductSectionConfigModel copyWith({
    String? id,
    String? categoryId,
    String? titleOverride,
    int? maxItems,
    int? position,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return HomeProductSectionConfigModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      titleOverride: titleOverride ?? this.titleOverride,
      maxItems: maxItems ?? this.maxItems,
      position: position ?? this.position,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
