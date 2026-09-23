/// Client-side mirror of `validateSellerApplication` in
/// functions/src/seller/sellerApplication.ts — same field keys, same
/// patterns. The server re-validates everything; this only gives the seller
/// instant feedback. Keep the two in step.
abstract final class ApplicationRules {
  ApplicationRules._();

  static final RegExp ifsc = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
  static final RegExp upi = RegExp(r'^[a-zA-Z0-9._-]{2,256}@[a-zA-Z]{2,64}$');
  static final RegExp gstin = RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z][1-9A-Z]Z[0-9A-Z]$');
  static final RegExp pincode = RegExp(r'^[1-9]\d{5}$');
  static final RegExp account = RegExp(r'^\d{9,18}$');

  static const int nameMin = 2;
  static const int addressMin = 5;
  static const int maxRadiusKm = 100;
  static const int defaultRadiusKm = 10;

  /// Business categories a seller can pick (keys; labels are localised).
  static const List<String> categories = [
    'vegetables',
    'fruits',
    'grains',
    'dairy',
    'seeds',
    'fertilisers',
    'equipment',
    'other',
  ];

  /// KYC photo keys, stored at `seller_documents/{uid}/{key}_{time}.jpg`.
  static const List<String> requiredDocuments = ['idProof', 'shopPhoto'];
  static const List<String> optionalDocuments = ['gstCertificate'];

  static bool text(Object? v, {int min = nameMin}) => v is String && v.trim().length >= min;

  /// Problems per step (field keys, matching the server). Empty = step done.
  static List<String> business(Map<String, dynamic> d) => [
        if (!text(d['name'])) 'name',
        if (!text(d['shopName'])) 'shopName',
        if (!text(d['businessCategory'])) 'businessCategory',
        if ((d['gstin'] as String? ?? '').isNotEmpty && !gstin.hasMatch((d['gstin'] as String).toUpperCase())) 'gstin',
      ];

  static List<String> location(Map<String, dynamic> d) {
    final r = d['deliveryRadiusKm'];
    return [
      if (!text(d['shopAddress'], min: addressMin)) 'shopAddress',
      if (!text(d['city'])) 'city',
      if (!text(d['state'])) 'state',
      if (!pincode.hasMatch(d['pincode'] as String? ?? '')) 'pincode',
      if (r is! num || r <= 0 || r > maxRadiusKm) 'deliveryRadiusKm',
    ];
  }

  static List<String> documents(Map<String, dynamic> d, String uid) {
    final docs = (d['documents'] as Map?)?.cast<String, dynamic>() ?? const {};
    return [
      for (final k in requiredDocuments)
        if (!(docs[k] is String && (docs[k] as String).startsWith('seller_documents/$uid/'))) 'documents.$k',
    ];
  }

  static List<String> payout(Map<String, dynamic> d) {
    switch (d['payoutMethod']) {
      case 'bank':
        return [
          if (!text(d['accountHolder'])) 'accountHolder',
          if (!text(d['bankName'])) 'bankName',
          if (!account.hasMatch(d['accountNumber'] as String? ?? '')) 'accountNumber',
          if (!ifsc.hasMatch(d['ifsc'] as String? ?? '')) 'ifsc',
        ];
      case 'upi':
        return [if (!upi.hasMatch(d['upiId'] as String? ?? '')) 'upiId'];
      default:
        return ['payoutMethod'];
    }
  }

  static List<String> all(Map<String, dynamic> d, String uid) => [
        ...business(d),
        ...location(d),
        ...documents(d, uid),
        ...payout(d),
        if (d['acceptedTerms'] != true) 'acceptedTerms',
      ];
}
