// DLV-A1 — the admin review reads KYC photos by storage path (new
// registrations) and falls back to the old download URL (older records).
import 'package:agrimore_admin/screens/admin/delivery/rider_review.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new registration: paths, no URLs', () {
    final docs = kycDocuments({
      'kycDocuments': {
        'aadhaarFront': 'delivery_documents/u1/aadhaarFront',
        'aadhaarBack': 'delivery_documents/u1/aadhaarBack',
        'selfie': 'delivery_documents/u1/selfie',
        'license': 'delivery_documents/u1/license',
      },
    });
    expect(docs.map((d) => d.path), [
      'delivery_documents/u1/aadhaarFront',
      'delivery_documents/u1/aadhaarBack',
      'delivery_documents/u1/selfie',
      'delivery_documents/u1/license',
    ]);
    expect(docs.every((d) => d.url == null), isTrue);
  });

  test('older record: the stored URL, no path; blanks read as missing', () {
    final docs = kycDocuments({'aadhaarFrontImage': 'https://x/a', 'licenseImage': '  '});
    expect(docs.first.url, 'https://x/a');
    expect(docs.first.path, isNull);
    expect(docs.last.url, isNull);
    expect(docs.map((d) => d.label), ['Aadhaar front', 'Aadhaar back', 'Selfie', 'Licence']);
  });
}
