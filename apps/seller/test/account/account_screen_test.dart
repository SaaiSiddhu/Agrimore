import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:seller/design_system/design_system.dart';
import 'package:seller/l10n/app_localizations.dart';
import 'package:seller/providers/seller_auth_provider.dart';
import 'package:seller/providers/seller_order_provider.dart';
import 'package:seller/providers/seller_product_provider.dart';
import 'package:seller/screens/profile/business_details_sheet.dart';
import 'package:seller/screens/profile/seller_profile_screen.dart';

/// SELLER-UI-1a: the Account screen renders from data, masks the payout
/// account, and the business sheet validates what the rules enforce.
Future<AppLocalizations> _pump(WidgetTester tester, Widget child, {Brightness b = Brightness.light}) async {
  late AppLocalizations l10n;
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<SellerAuthProvider>(create: (_) => SellerAuthProvider.preview(access: SellerAccess.approved)),
      ChangeNotifierProvider<SellerOrderProvider>(create: (_) => SellerOrderProvider.preview(const [])),
      ChangeNotifierProvider<SellerProductProvider>(create: (_) => SellerProductProvider.preview(const [])),
    ],
    child: MaterialApp(
      theme: (b == Brightness.dark ? SellerTheme.dark : SellerTheme.light),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        l10n = AppLocalizations.of(context);
        return child;
      }),
    ),
  ));
  await tester.pump();
  return l10n;
}

void main() {
  test('payout view masks the account and keeps a read failure distinct', () {
    final v = PayoutView.of({'bankName': 'SBI', 'accountNumber': '123456789012', 'ifsc': 'SBIN0001'}, readFailed: false);
    expect(v.maskedAccount, SellerFormat.maskAccount('123456789012'));
    expect(v.maskedAccount!.contains('123456789012'), isFalse);
    expect(PayoutView.of(null, readFailed: true).available, isFalse);
    expect(PayoutView.of(null, readFailed: false).isEmpty, isTrue);
  });

  test('business details write gstin and gstNumber, upper-cased', () {
    final u = const BusinessDetails(businessName: ' Ravi ', gstin: '33abcde1234f1z5').toUpdate();
    expect(u['gstin'], '33ABCDE1234F1Z5');
    expect(u['gstNumber'], '33ABCDE1234F1Z5');
    expect(u['businessName'], 'Ravi');
    expect(BusinessDetails.fromSeller({'gstNumber': 'X', 'deliveryRadiusKm': 7.0}).gstin, 'X');
  });

  testWidgets('account renders sections, rating and the masked payout', (tester) async {
    final l10n = await _pump(
      tester,
      SellerProfileScreen(
        seller: const {'shopName': 'Ravi Stores', 'rating': 4.3, 'reviewCount': 12},
        payout: PayoutView.of(const {'bankName': 'SBI', 'accountNumber': '123456789012'}, readFailed: false),
      ),
    );
    expect(find.text('Ravi Stores'), findsOneWidget);
    expect(find.text(l10n.accountRating('4.3', 12)), findsOneWidget);
    expect(find.text(l10n.accountSectionBusiness), findsOneWidget);
    await tester.scrollUntilVisible(find.text(l10n.payoutAccountTitle), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.payoutAccountTitle));
    await tester.pumpAndSettle();
    expect(find.text(l10n.payoutAccountBank('SBI', SellerFormat.maskAccount('123456789012'))), findsOneWidget);
    expect(find.textContaining('123456789012'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('business sheet validates GSTIN and radius (dark)', (tester) async {
    BusinessDetails? result;
    final l10n = await _pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await showBusinessDetailsSheet(context, const BusinessDetails(businessName: 'Ravi')),
            child: const Text('open'),
          ),
        ),
      ),
      b: Brightness.dark,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('bizGstin')), 'NOTAGSTIN');
    await tester.enterText(find.byKey(const ValueKey('bizRadius')), '500');
    await tester.ensureVisible(find.text(l10n.accountSave));
    await tester.tap(find.text(l10n.accountSave));
    await tester.pump();
    expect(find.text(l10n.errGstin), findsOneWidget);
    expect(find.text(l10n.accountRadiusInvalid(BusinessDetails.kMaxDeliveryRadiusKm)), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('bizGstin')), '33ABCDE1234F1Z5');
    await tester.enterText(find.byKey(const ValueKey('bizRadius')), '8');
    await tester.ensureVisible(find.text(l10n.accountSave));
    await tester.tap(find.text(l10n.accountSave));
    await tester.pumpAndSettle();
    expect(result?.gstin, '33ABCDE1234F1Z5');
    expect(result?.deliveryRadiusKm, 8);
    expect(tester.takeException(), isNull);
  });
}
