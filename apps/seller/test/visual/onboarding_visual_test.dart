import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seller/providers/seller_application_provider.dart';
import 'package:seller/screens/auth/account_restricted_screen.dart';
import 'package:seller/screens/auth/application_status_screen.dart';
import 'package:seller/screens/onboarding/application_screen.dart';
import 'package:seller/screens/onboarding/apply_intro_screen.dart';

import '../support/seller_fixtures.dart';
import 'visual_harness.dart';

Map<String, dynamic> _data() => {
      'userId': 'u1',
      'status': 'draft',
      'name': 'Kaveri R',
      'shopName': 'Kaveri Fresh',
      'businessCategory': 'vegetables',
      'shopAddress': '12 Market Road',
      'city': 'Chennai',
      'state': 'Tamil Nadu',
      'pincode': '600001',
      'deliveryRadiusKm': 10,
      'payoutMethod': 'bank',
      'accountHolder': 'Kaveri R',
      'bankName': 'Example Bank',
      'accountNumber': '123456784821',
      'ifsc': 'EXMP0001234',
      'documents': {'idProof': 'seller_documents/u1/idProof.jpg'},
    };

void main() {
  setUpAll(loadSellerFonts);
  testWidgets('apply_intro', (tester) async {
    await pumpSellerApp(tester, const ApplyIntroScreen(), size: const Size(390, 1300));
    await qaCapture(tester, 'apply_intro');
  });
  for (final step in [0, 2, 4]) {
    testWidgets('application_step_${step + 1}', (tester) async {
      final app = SellerApplicationProvider.preview(data: _data(), uid: 'u1', step: step);
      await pumpSellerApp(tester, ApplicationScreen(provider: app), size: const Size(390, 1300));
      expect(tester.takeException(), isNull);
      await qaCapture(tester, 'application_step_${step + 1}');
    });
  }
  testWidgets('status_pending', (tester) async {
    await pumpSellerApp(tester, const ApplicationStatusScreen(), size: const Size(390, 1500));
    await qaCapture(tester, 'status_pending');
  });
  testWidgets('status_rejected_dark', (tester) async {
    await pumpSellerApp(tester, const AccountRestrictedScreen(reason: RestrictionReason.rejected), brightness: Brightness.dark, size: const Size(390, 1200));
    await qaCapture(tester, 'status_rejected_dark');
  });
}
