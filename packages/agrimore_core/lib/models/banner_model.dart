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

  /// Where this banner may appear. Every banner written before this field
  /// existed has none in Firestore, and parses as 'HOME_HERO' (see
  /// fromFirestore) — so the Home carousel keeps rendering exactly what it
  /// always has, with no backfill required for correctness.
  final String placement;

  /// Required when [placement] is 'CATEGORY_HERO'; null = not category-scoped.
  final String? categoryId;

  /// Null on either side = unbounded on that side (always eligible).
  final DateTime? startsAt;
  final DateTime? endsAt;

  static const String placementHomeHero = 'HOME_HERO';
  static const String placementCategoryHero = 'CATEGORY_HERO';

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
    this.placement = placementHomeHero,
    this.categoryId,
    this.startsAt,
    this.endsAt,
  });

  /// True when [at] (default: now) falls inside [startsAt, endsAt] — either
  /// bound absent means unbounded on that side.
  bool isWithinSchedule([DateTime? at]) {
    final now = at ?? DateTime.now();
    if (startsAt != null && now.isBefore(startsAt!)) return false;
    if (endsAt != null && now.isAfter(endsAt!)) return false;
    return true;
  }

  /// Draft/Scheduled/Live/Expired/Disabled, derived from isActive + the
  /// schedule window rather than a separate stored status (spec: publication
  /// state should never be redundant with the fields that already imply it).
  String get scheduleStatus {
    if (!isActive) return 'Disabled';
    final now = DateTime.now();
    if (startsAt != null && now.isBefore(startsAt!)) return 'Scheduled';
    if (endsAt != null && now.isAfter(endsAt!)) return 'Expired';
    return 'Live';
  }

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

    DateTime? parseNullableTimestamp(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      return null;
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
      placement: (data['placement'] ?? placementHomeHero).toString(),
      categoryId: data['categoryId'] != null ? data['categoryId'].toString() : null,
      startsAt: parseNullableTimestamp(data['startsAt']),
      endsAt: parseNullableTimestamp(data['endsAt']),
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
      'placement': placement,
      'categoryId': categoryId,
      'startsAt': startsAt != null ? Timestamp.fromDate(startsAt!) : null,
      'endsAt': endsAt != null ? Timestamp.fromDate(endsAt!) : null,
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
    String? placement,
    String? categoryId,
    DateTime? startsAt,
    DateTime? endsAt,
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
      placement: placement ?? this.placement,
      categoryId: categoryId ?? this.categoryId,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
    );
  }
}
