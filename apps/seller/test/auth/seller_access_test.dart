import 'package:flutter_test/flutter_test.dart';
import 'package:seller/providers/seller_auth_provider.dart';

/// SELLER-AUTH-1a: the auth gate routes on this decision and nothing else.
void main() {
  SellerAccess resolve({
    String? role,
    String? sellerStatus,
    bool sellerDocExists = false,
    String? userSellerStatus,
    String? requestStatus,
  }) =>
      SellerAuthProvider.resolveSellerAccess(
        role: role,
        sellerStatus: sellerStatus,
        sellerDocExists: sellerDocExists,
        userSellerStatus: userSellerStatus,
        requestStatus: requestStatus,
      );

  test('approved seller opens the workspace', () {
    expect(resolve(role: 'seller', sellerStatus: 'approved', sellerDocExists: true), SellerAccess.approved);
  });

  test('legacy seller (role set, no status recorded) keeps working', () {
    expect(resolve(role: 'seller'), SellerAccess.approved);
  });

  test('suspension wins over the seller role', () {
    expect(resolve(role: 'seller', sellerStatus: 'suspended', sellerDocExists: true), SellerAccess.suspended);
  });

  test('rejection from any record wins over a role', () {
    expect(resolve(role: 'seller', sellerStatus: 'rejected', sellerDocExists: true), SellerAccess.rejected);
    expect(resolve(role: 'user', userSellerStatus: 'rejected'), SellerAccess.rejected);
    expect(resolve(role: 'user', requestStatus: 'rejected'), SellerAccess.rejected);
  });

  test('pending from any record shows the application status', () {
    expect(resolve(role: 'user', requestStatus: 'pending'), SellerAccess.pending);
    expect(resolve(role: 'user', userSellerStatus: 'pending'), SellerAccess.pending);
    expect(resolve(role: 'seller', sellerStatus: 'pending', sellerDocExists: true), SellerAccess.pending);
  });

  test('approved record without the seller role waits (claims lag), never opens', () {
    expect(resolve(role: 'user', sellerStatus: 'approved', sellerDocExists: true), SellerAccess.pending);
  });

  test('an application in progress resumes, even after an earlier rejection', () {
    expect(resolve(role: 'user', requestStatus: 'draft'), SellerAccess.draft);
    expect(resolve(role: 'user', userSellerStatus: 'rejected', requestStatus: 'draft'), SellerAccess.draft);
  });

  test('an approved seller is never sent back into the application', () {
    expect(resolve(role: 'seller', sellerStatus: 'approved', sellerDocExists: true, requestStatus: 'draft'),
        SellerAccess.approved);
  });

  test('a signed-in non-seller is told so — no silent sign-out', () {
    expect(resolve(role: 'user'), SellerAccess.noApplication);
    expect(resolve(role: null), SellerAccess.noApplication);
    expect(resolve(role: 'admin'), SellerAccess.noApplication);
  });
}
