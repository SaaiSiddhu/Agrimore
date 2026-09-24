import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seller/screens/profile/seller_profile_screen.dart';
import 'package:seller/screens/reviews/review_rules.dart';
import 'package:seller/screens/reviews/reviews_screen.dart';
import 'package:seller/screens/storefront/storefront_editor_screen.dart';
import 'package:seller/screens/storefront/storefront_rules.dart';

import '../support/seller_fixtures.dart';
import 'visual_harness.dart';

void main() {
  setUpAll(loadSellerFonts);
  const seller = {'shopName': 'Kaveri Fresh', 'city': 'Chennai', 'state': 'Tamil Nadu', 'rating': 4.5, 'reviewCount': 20};
  for (final (name, b) in [('account_light', Brightness.light), ('account_dark', Brightness.dark)]) {
    testWidgets(name, (tester) async {
      await pumpSellerApp(tester, const SellerProfileScreen(seller: seller, payout: PayoutView(available: true)), brightness: b, size: const Size(390, 2000));
      expect(tester.takeException(), isNull);
      await qaCapture(tester, name);
    });
  }
  testWidgets('storefront', (tester) async {
    await pumpSellerApp(
      tester,
      const StorefrontEditorScreen(
        initial: StorefrontDraft(shopName: 'Kaveri Fresh', description: 'Farm-fresh vegetables from Chengalpattu.', highlights: ['Farm fresh', 'Same-day dispatch']),
      ),
      size: const Size(390, 1300),
    );
    expect(tester.takeException(), isNull);
    await qaCapture(tester, 'storefront');
  });
  testWidgets('reviews', (tester) async {
    final now = DateTime(2026, 9, 24);
    await pumpSellerApp(
      tester,
      SellerReviewsScreen(now: now, reviews: [
        SellerReview(id: '1', productId: 'p', productName: 'Fresh tomatoes', userName: 'Priya S.', rating: 5, comment: 'Very fresh and well packed.', verified: true, createdAt: now.subtract(const Duration(days: 2))),
        SellerReview(id: '2', productId: 'p', productName: 'Green chillies', userName: 'Ravi K.', rating: 4, comment: 'Good quality.', createdAt: now.subtract(const Duration(days: 5)), replyText: 'Thank you, Ravi!', replyAt: now.subtract(const Duration(days: 4))),
      ]),
      size: const Size(390, 1600),
    );
    expect(tester.takeException(), isNull);
    await qaCapture(tester, 'reviews');
  });
}
