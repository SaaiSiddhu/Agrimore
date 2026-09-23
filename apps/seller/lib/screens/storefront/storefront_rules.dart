import 'package:flutter/foundation.dart';

/// M-02 storefront limits — mirrored by firestore.rules
/// ownerEditsOnlyStorefrontFields() (description ≤ 500, ≤ 3 highlights).
const int kStorefrontDescriptionMax = 500;
const int kStorefrontHighlightsMax = 3;
const int kStorefrontHighlightChars = 24;
const int kStorefrontNameMax = 60;

/// What the storefront editor edits on sellers/{uid}. Pure — unit-tested.
@immutable
class StorefrontDraft {
  const StorefrontDraft({
    this.shopName = '',
    this.description = '',
    this.highlights = const [],
    this.logoUrl,
    this.coverImageUrl,
  });

  factory StorefrontDraft.fromSeller(Map<String, dynamic>? d) {
    String s(Object? v) => v is String ? v : '';
    String? url(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
    return StorefrontDraft(
      shopName: s(d?['shopName']).isNotEmpty ? s(d?['shopName']) : s(d?['businessName']),
      description: s(d?['description']),
      highlights: [
        for (final h in (d?['highlights'] as List?) ?? const [])
          if (h is String && h.trim().isNotEmpty) h.trim(),
      ].take(kStorefrontHighlightsMax).toList(),
      logoUrl: url(d?['logoUrl']),
      coverImageUrl: url(d?['coverImageUrl']),
    );
  }

  final String shopName;
  final String description;
  final List<String> highlights;
  final String? logoUrl;
  final String? coverImageUrl;

  StorefrontDraft copyWith({
    String? shopName,
    String? description,
    List<String>? highlights,
    String? logoUrl,
    String? coverImageUrl,
  }) =>
      StorefrontDraft(
        shopName: shopName ?? this.shopName,
        description: description ?? this.description,
        highlights: highlights ?? this.highlights,
        logoUrl: logoUrl ?? this.logoUrl,
        coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      );

  bool get nameValid => shopName.trim().isNotEmpty && shopName.trim().length <= kStorefrontNameMax;
  bool get descriptionValid => description.length <= kStorefrontDescriptionMax;
  bool get isValid => nameValid && descriptionValid && highlights.length <= kStorefrontHighlightsMax;

  /// Adds a highlight if there is room and it is new; returns the result.
  StorefrontDraft withHighlight(String raw) {
    final h = raw.trim();
    if (h.isEmpty || h.length > kStorefrontHighlightChars) return this;
    if (highlights.length >= kStorefrontHighlightsMax) return this;
    if (highlights.any((x) => x.toLowerCase() == h.toLowerCase())) return this;
    return copyWith(highlights: [...highlights, h]);
  }

  StorefrontDraft withoutHighlight(String h) => copyWith(highlights: highlights.where((x) => x != h).toList());

  /// The Firestore update: only keys the rules allow the owner to change.
  Map<String, Object?> toUpdate() => {
        'shopName': shopName.trim(),
        'description': description.trim(),
        'highlights': highlights,
        'logoUrl': logoUrl,
        'coverImageUrl': coverImageUrl,
      };
}

/// Storage path for a storefront image (storage.rules
/// sellers/{uid}/storefront/{file}: owner-written images).
String storefrontImagePath(String uid, String kind, int millis) => 'sellers/$uid/storefront/${kind}_$millis.jpg';
