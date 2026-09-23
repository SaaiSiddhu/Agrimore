import 'dart:typed_data';

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:seller/l10n/app_localizations.dart';
import 'package:seller/providers/seller_auth_provider.dart';
import 'package:seller/screens/storefront/storefront_editor_screen.dart';
import 'package:seller/screens/storefront/storefront_rules.dart';

/// SELLER-STOREFRONT-EDIT-1: the editor writes only owner-editable keys and
/// enforces the same limits as firestore.rules.
void main() {
  group('StorefrontDraft', () {
    test('update carries only the keys the rules allow', () {
      const allowed = {
        'name', 'businessName', 'shopName', 'businessCategory', 'description', 'highlights', 'logoUrl',
        'coverImageUrl', 'shopAddress', 'city', 'state', 'pincode', 'latitude', 'longitude', 'phone',
        'gstNumber', 'gstin', 'openingTime', 'closingTime', 'deliveryRadiusKm', 'deliveryFeeSchedule', 'updatedAt',
      };
      expect(allowed.containsAll(const StorefrontDraft(shopName: 'x').toUpdate().keys), isTrue);
    });

    test('highlights: at most three, unique, bounded length', () {
      var d = const StorefrontDraft(shopName: 'x');
      for (final h in ['Farm fresh', 'farm FRESH', 'Same-day', 'Organic', 'Fourth one']) {
        d = d.withHighlight(h);
      }
      expect(d.highlights, ['Farm fresh', 'Same-day', 'Organic']);
      expect(const StorefrontDraft().withHighlight('x' * (kStorefrontHighlightChars + 1)).highlights, isEmpty);
      expect(d.withoutHighlight('Same-day').highlights, ['Farm fresh', 'Organic']);
    });

    test('validity: name required, description within 500', () {
      expect(const StorefrontDraft().isValid, isFalse);
      expect(StorefrontDraft(shopName: 'x', description: 'y' * 501).isValid, isFalse);
      expect(StorefrontDraft(shopName: 'x', description: 'y' * 500).isValid, isTrue);
    });

    test('fromSeller falls back to businessName and trims bad data', () {
      final d = StorefrontDraft.fromSeller({
        'businessName': 'Ravi Stores',
        'highlights': ['a', '', 3, 'b', 'c', 'd'],
        'logoUrl': '  ',
      });
      expect(d.shopName, 'Ravi Stores');
      expect(d.highlights, ['a', 'b', 'c']);
      expect(d.logoUrl, isNull);
    });

    test('images go under the owner storefront path', () {
      expect(storefrontImagePath('u1', 'logo', 5), 'sellers/u1/storefront/logo_5.jpg');
    });
  });

  Future<AppLocalizations> pump(WidgetTester tester, Widget child) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(ChangeNotifierProvider<SellerAuthProvider>(
      create: (_) => SellerAuthProvider.preview(access: SellerAccess.approved),
      child: MaterialApp(
        theme: WorkspaceTheme.build(WorkspaceBrand.seller, Brightness.light),
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

  testWidgets('edit, add a highlight, preview and save', (tester) async {
    StorefrontDraft? saved;
    final l10n = await pump(
      tester,
      StorefrontEditorScreen(
        initial: const StorefrontDraft(shopName: 'Ravi Stores', highlights: ['Farm fresh']),
        saver: (d) async {
          saved = d;
          return true;
        },
        uploader: (_, Uint8List __) async => null,
      ),
    );
    // The editor is a lazy ListView under a 16:9 cover: scroll to each field.
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.byKey(const ValueKey('storefrontDescription')), 200, scrollable: list);
    await tester.enterText(find.byKey(const ValueKey('storefrontDescription')), 'Rice and pulses since 1998.');
    await tester.scrollUntilVisible(find.byKey(const ValueKey('storefrontHighlight')), 200, scrollable: list);
    await tester.enterText(find.byKey(const ValueKey('storefrontHighlight')), 'Same-day dispatch');
    await tester.tap(find.byTooltip(l10n.storefrontAddHighlight));
    await tester.pump();
    expect(find.text('Same-day dispatch'), findsOneWidget);

    await tester.tap(find.text(l10n.storefrontPreview));
    await tester.pumpAndSettle();
    expect(find.text(l10n.storefrontPreviewTitle), findsOneWidget);
    expect(find.text('Rice and pulses since 1998.'), findsWidgets);
    Navigator.of(tester.element(find.text(l10n.storefrontPreviewTitle))).pop();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text(l10n.storefrontSave), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text(l10n.storefrontSave));
    await tester.pumpAndSettle();
    expect(saved?.description, 'Rice and pulses since 1998.');
    expect(saved?.highlights, ['Farm fresh', 'Same-day dispatch']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed save stays on screen with an error (dark)', (tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(ChangeNotifierProvider<SellerAuthProvider>(
      create: (_) => SellerAuthProvider.preview(access: SellerAccess.approved),
      child: MaterialApp(
        theme: WorkspaceTheme.build(WorkspaceBrand.seller, Brightness.dark),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          l10n = AppLocalizations.of(context);
          return StorefrontEditorScreen(initial: const StorefrontDraft(shopName: 'x'), saver: (_) async => false);
        }),
      ),
    ));
    await tester.pump();
    await tester.scrollUntilVisible(find.text(l10n.storefrontSave), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text(l10n.storefrontSave));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(l10n.storefrontSaveFailed), -200, scrollable: find.byType(Scrollable).first);
    expect(find.text(l10n.storefrontSaveFailed), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
