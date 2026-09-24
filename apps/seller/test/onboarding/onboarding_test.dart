import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:seller/design_system/design_system.dart';
import 'package:seller/l10n/app_localizations.dart';
import 'package:seller/providers/seller_application_provider.dart';
import 'package:seller/providers/seller_auth_provider.dart';
import 'package:seller/screens/onboarding/application_rules.dart';
import 'package:seller/screens/onboarding/application_screen.dart';
import 'package:seller/screens/onboarding/apply_intro_screen.dart';

/// SELLER-AUTH-1b: client validators mirror the server; every step renders
/// (light/dark, 1x/2x) and blocks progress until its fields are valid.
const _uid = 'u1';

Map<String, dynamic> _complete() => {
      'userId': _uid,
      'status': 'draft',
      'name': 'Ravi Kumar',
      'shopName': 'Ravi Stores',
      'businessCategory': 'vegetables',
      'gstin': '',
      'shopAddress': '12, Market Street, Anna Nagar',
      'city': 'Madurai',
      'state': 'Tamil Nadu',
      'pincode': '625020',
      'deliveryRadiusKm': 10,
      'documents': {
        'idProof': 'seller_documents/$_uid/idProof_1.jpg',
        'shopPhoto': 'seller_documents/$_uid/shopPhoto_1.jpg',
      },
      'payoutMethod': 'bank',
      'accountHolder': 'Ravi Kumar',
      'bankName': 'State Bank of India',
      'accountNumber': '123456789012',
      'ifsc': 'SBIN0001234',
      'acceptedTerms': true,
    };

Future<AppLocalizations> _pump(
  WidgetTester tester,
  Widget screen, {
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  late AppLocalizations l10n;
  await tester.pumpWidget(ChangeNotifierProvider<SellerAuthProvider>.value(
    value: SellerAuthProvider.preview(access: SellerAccess.draft),
    child: MaterialApp(
      theme: (brightness == Brightness.dark ? SellerTheme.dark : SellerTheme.light),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(builder: (context) {
        l10n = AppLocalizations.of(context);
        return screen;
      }),
    ),
  ));
  await tester.pump();
  return l10n;
}

void main() {
  group('ApplicationRules mirrors the server validator', () {
    test('a complete application has no problems', () {
      expect(ApplicationRules.all(_complete(), _uid), isEmpty);
    });
    test('bad IFSC, PIN code and GSTIN are reported by their keys', () {
      final d = {..._complete(), 'ifsc': 'SBIN1234', 'pincode': '025020', 'gstin': 'BADGST'};
      expect(ApplicationRules.all(d, _uid), containsAll(['ifsc', 'pincode', 'gstin']));
    });
    test('documents must sit in the seller\'s own folder', () {
      final d = {
        ..._complete(),
        'documents': {'idProof': 'seller_documents/OTHER/x.jpg', 'shopPhoto': 'x.jpg'},
      };
      expect(ApplicationRules.all(d, _uid), containsAll(['documents.idProof', 'documents.shopPhoto']));
    });
    test('UPI payout replaces bank fields', () {
      final d = {..._complete(), 'payoutMethod': 'upi', 'upiId': 'ravi@okaxis'};
      expect(ApplicationRules.payout(d), isEmpty);
      expect(ApplicationRules.payout({..._complete(), 'payoutMethod': 'upi', 'upiId': 'nope'}), ['upiId']);
    });
    test('radius cap and terms', () {
      final d = {..._complete(), 'deliveryRadiusKm': 500, 'acceptedTerms': false};
      expect(ApplicationRules.all(d, _uid), containsAll(['deliveryRadiusKm', 'acceptedTerms']));
    });
    test('a valid GSTIN is accepted', () {
      expect(ApplicationRules.business({..._complete(), 'gstin': '33ABCDE1234F1Z5'}), isEmpty);
    });
  });

  group('A-05 steps render', () {
    final matrix = <(String, Brightness, double)>[
      ('light 1x', Brightness.light, 1.0),
      ('dark 1x', Brightness.dark, 1.0),
      ('light 2x', Brightness.light, 2.0),
    ];
    for (var step = 0; step < SellerApplicationProvider.stepCount; step++) {
      for (final (name, b, scale) in matrix) {
        testWidgets('step ${step + 1} — $name', (tester) async {
          final app = SellerApplicationProvider.preview(data: _complete(), uid: _uid, step: step);
          await _pump(tester, ApplicationScreen(provider: app), brightness: b, textScale: scale);
          expect(tester.takeException(), isNull);
          expect(find.byType(SellerStepProgress), findsOneWidget);
        });
      }
    }

    testWidgets('intro renders', (tester) async {
      final l10n = await _pump(tester, const ApplyIntroScreen());
      expect(find.text(l10n.applyStartCta), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('A-05 progress rules', () {
    testWidgets('an empty business step does not advance', (tester) async {
      final app = SellerApplicationProvider.preview(data: {'userId': _uid, 'status': 'draft'}, uid: _uid);
      final l10n = await _pump(tester, ApplicationScreen(provider: app));
      await tester.tap(find.text(l10n.saveContinue));
      await tester.pump();
      expect(app.step, 0);
      expect(find.text(l10n.errRequired), findsWidgets);
    });

    testWidgets('a valid business step saves and advances', (tester) async {
      final app = SellerApplicationProvider.preview(data: _complete(), uid: _uid);
      final l10n = await _pump(tester, ApplicationScreen(provider: app));
      await tester.tap(find.text(l10n.saveContinue));
      await tester.pumpAndSettle();
      expect(app.step, 1);
      expect(find.text(l10n.stepLocation), findsOneWidget);
    });

    testWidgets('documents step blocks when a required photo is missing', (tester) async {
      final app = SellerApplicationProvider.preview(
        data: {..._complete(), 'documents': <String, dynamic>{}},
        uid: _uid,
        step: 2,
      );
      final l10n = await _pump(tester, ApplicationScreen(provider: app));
      await tester.tap(find.text(l10n.saveContinue));
      await tester.pump();
      expect(app.step, 2);
      // Two tiles plus the summary banner.
      expect(find.text(l10n.errDocument), findsNWidgets(3));
    });

    testWidgets('payout: mismatched account numbers are caught', (tester) async {
      final app = SellerApplicationProvider.preview(data: _complete(), uid: _uid, step: 3);
      final l10n = await _pump(tester, ApplicationScreen(provider: app));
      await tester.enterText(find.descendant(of: find.byWidgetPredicate((w) => w is SellerTextField && w.label == l10n.fieldAccountNumberConfirm), matching: find.byType(TextField)), '999999999');
      await tester.tap(find.text(l10n.saveContinue));
      await tester.pump();
      expect(app.step, 3);
      expect(find.text(l10n.accountMismatch), findsOneWidget);
    });

    testWidgets('review masks the account number and offers edit links', (tester) async {
      final app = SellerApplicationProvider.preview(data: _complete(), uid: _uid, step: 4);
      final l10n = await _pump(tester, ApplicationScreen(provider: app));
      expect(find.textContaining('123456789012'), findsNothing);
      expect(find.textContaining(SellerFormat.maskAccount('123456789012')), findsOneWidget);
      expect(find.text(l10n.reviewEdit), findsNWidgets(4));
      await tester.tap(find.text(l10n.reviewEdit).first);
      await tester.pumpAndSettle();
      expect(app.step, 0);
    });
  });
}
