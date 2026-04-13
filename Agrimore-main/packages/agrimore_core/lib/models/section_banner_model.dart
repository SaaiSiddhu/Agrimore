import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for carousel banners that appear between product sections
/// All text fields are optional - can upload just an image
class SectionBannerModel {
  final String id;
  final String imageUrl;
  final String? title;              // Optional overlay title
  final String? subtitle;           // Optional overlay subtitle
  final String? shopNowUrl;         // Optional - URL for Shop Now button
  final String? buttonText;         // Optional - defaults to "Shop now"
  final int position;               // Display order (1, 2, 3...)
  final int displayAfterSection;    // Show after which product section (1-indexed)
  final bool isActive;
  final bool showAdBadge;           // Show "Ad" label
  final DateTime createdAt;
  final DateTime? updatedAt;

  SectionBannerModel({
    required this.id,
    required this.imageUrl,
    this.title,
    this.subtitle,
    this.shopNowUrl,
    this.buttonText,
    this.position = 0,
    this.displayAfterSection = 1,
    this.isActive = true,
    this.showAdBadge = false,
    required this.createdAt,
    this.updatedAt,
  });

  /// Whether this banner has a Shop Now button
  bool get hasShopButton => shopNowUrl != null && shopNowUrl!.isNotEmpty;

  /// Whether this banner has text overlay
  bool get hasTextOverlay => (title != null && title!.isNotEmpty) || 
                              (subtitle != null && subtitle!.isNotEmpty);

  factory SectionBannerModel.fromFirestore(DocumentSnapshot doc) {
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

    return SectionBannerModel(
      id: doc.id,
      imageUrl: (data['imageUrl'] ?? '').toString(),
      title: data['title']?.toString(),
      subtitle: data['subtitle']?.toString(),
      shopNowUrl: data['shopNowUrl']?.toString(),
      buttonText: data['buttonText']?.toString(),
      position: data['position'] is int 
          ? data['position'] as int 
          : int.tryParse((data['position'] ?? '0').toString()) ?? 0,
      displayAfterSection: data['displayAfterSection'] is int 
          ? data['displayAfterSection'] as int 
          : int.tryParse((data['displayAfterSection'] ?? '1').toString()) ?? 1,
      isActive: data['isActive'] is bool ? data['isActive'] as bool : true,
      showAdBadge: data['showAdBadge'] is bool ? data['showAdBadge'] as bool : false,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'imageUrl': imageUrl,
      'title': title,
      'subtitle': subtitle,
      'shopNowUrl': shopNowUrl,
      'buttonText': buttonText,
      'position': position,
      'displayAfterSection': displayAfterSection,
      'isActive': isActive,
      'showAdBadge': showAdBadge,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  SectionBannerModel copyWith({
    String? id,
    String? imageUrl,
    String? title,
    String? subtitle,
    String? shopNowUrl,
    String? buttonText,
    int? position,
    int? displayAfterSection,
    bool? isActive,
    bool? showAdBadge,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SectionBannerModel(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      shopNowUrl: shopNowUrl ?? this.shopNowUrl,
      buttonText: buttonText ?? this.buttonText,
      position: position ?? this.position,
      displayAfterSection: displayAfterSection ?? this.displayAfterSection,
      isActive: isActive ?? this.isActive,
      showAdBadge: showAdBadge ?? this.showAdBadge,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
