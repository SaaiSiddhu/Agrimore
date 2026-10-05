import 'dart:async';

import 'package:agrimore_core/agrimore_core.dart';
import 'package:firebase_core/firebase_core.dart';
// Official native SDK fixtures, already used by seller auth tests.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
// ignore: depend_on_referenced_packages
import 'package:cloud_firestore_platform_interface/src/pigeon/messages.pigeon.dart' as fs;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:seller/design_system/design_system.dart';
import 'package:seller/l10n/app_localizations.dart';
import 'package:seller/providers/seller_auth_provider.dart';
import 'package:seller/providers/seller_product_provider.dart';
import 'package:seller/screens/products/seller_products_screen.dart';

/// SELLER-UI-1c: the catalogue shows stock levels with the right tone and
/// asks before deleting.
ProductModel _p(String id, {int stock = 20, bool active = true, bool draft = false}) => ProductModel.fromMap({
      'name': 'Product $id',
      'categoryId': 'c',
      'salePrice': 120,
      'originalPrice': 150,
      'sellerId': 's',
      'stock': stock,
      'isActive': active,
      'isDraft': draft,
    }, id);

UserModel _seller(String uid) => UserModel(
    uid: uid, email: '', name: 'Fixture seller', role: 'seller', createdAt: DateTime(2026));

class _StockAuth extends SellerAuthProvider {
  _StockAuth() : super.preview(access: SellerAccess.approved);
  UserModel? fixtureUser = _seller('s');
  @override
  UserModel? get currentUser => fixtureUser;
}

class _CatalogueProducts extends SellerProductProvider {
  _CatalogueProducts(super.products) : super.preview();
  int stockWrites = 0;
  @override
  Future<void> loadSellerProducts(String sellerId) async {}
  @override
  Future<bool> updateStock(String productId, int newStock, String sellerId) async {
    stockWrites++;
    return true;
  }
}

Future<AppLocalizations> _pump(WidgetTester tester, List<ProductModel> products,
    {SellerAuthProvider? auth, _CatalogueProducts? catalogue}) async {
  late AppLocalizations l10n;
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<SellerAuthProvider>(create: (_) => auth ?? SellerAuthProvider.preview(access: SellerAccess.approved)),
      ChangeNotifierProvider<SellerProductProvider>(create: (_) => catalogue ?? _CatalogueProducts(products)),
    ],
    child: MaterialApp(
      theme: SellerTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        l10n = AppLocalizations.of(context);
        return const SellerProductsScreen();
      }),
    ),
  ));
  await tester.pump();
  return l10n;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  const documents = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceGet',
      fs.FirebaseFirestoreHostApi.codec);
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Future<Map<String, Object?>?> Function() readStock;
  setUpAll(() async => Firebase.initializeApp());
  setUp(() {
    readStock = () async => {'stock': 20};
    messenger.setMockDecodedMessageHandler<Object?>(documents, (message) async {
      final request = (message! as List)[1] as fs.DocumentReferenceRequest;
      expect(request.path, 'products/1');
      return [fs.PigeonDocumentSnapshot(path: request.path, data: await readStock(),
          metadata: fs.PigeonSnapshotMetadata(hasPendingWrites: false, isFromCache: false))];
    });
  });
  tearDown(() => messenger.setMockDecodedMessageHandler<Object?>(documents, null));
  testWidgets('stock levels, prices and an empty catalogue', (tester) async {
    final l10n = await _pump(tester, [_p('1'), _p('2', stock: 0), _p('3', stock: 4)]);
    expect(find.text(l10n.searchStock(SellerFormat.count(20))), findsOneWidget);
    expect(find.widgetWithText(SellerStatusBadge, l10n.productOutOfStock), findsOneWidget);
    expect(find.text(l10n.productLowStock(SellerFormat.count(4))), findsOneWidget);
    expect(find.text(l10n.productMrp(SellerFormat.money(150))), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty catalogue says what to do', (tester) async {
    final l10n = await _pump(tester, const []);
    expect(find.text(l10n.productsEmpty), findsOneWidget);
    expect(find.text(l10n.homeAddProduct), findsOneWidget);
  });

  testWidgets('delete asks first; cancelling keeps the product', (tester) async {
    final l10n = await _pump(tester, [_p('1')]);
    await tester.tap(find.byTooltip(l10n.productMoreActions('Product 1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.productDelete));
    await tester.pumpAndSettle();
    expect(find.text(l10n.productDeleteTitle), findsOneWidget);
    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();
    expect(find.text('Product 1'), findsOneWidget);
  });

  testWidgets('stock sheet rejects an empty value', (tester) async {
    final l10n = await _pump(tester, [_p('1')], auth: _StockAuth());
    await tester.tap(find.byTooltip(l10n.productMoreActions('Product 1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.productStock));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('stockValue')), '');
    await tester.tap(find.text(l10n.accountSave));
    await tester.pump();
    expect(find.text(l10n.counterQtyInvalid), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown raw stock starts blank instead of the legacy 999 fallback', (tester) async {
    readStock = () async => {};
    final unknown = ProductModel.fromMap({'name': 'Product 1', 'sellerId': 's', 'salePrice': 120}, '1');
    expect(unknown.stock, 999);
    final l10n = await _pump(tester, [unknown], auth: _StockAuth());
    await tester.tap(find.byTooltip(l10n.productMoreActions('Product 1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.productStock));
    await tester.pumpAndSettle();
    expect(find.text(l10n.productStockUnknown), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('stockValue'))).controller!.text, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stored zero stays zero and an unsafe count is refused before saving', (tester) async {
    readStock = () async => {'stock': 0};
    final catalogue = _CatalogueProducts([_p('1')]);
    final l10n = await _pump(tester, [_p('1')], auth: _StockAuth(), catalogue: catalogue);
    await tester.tap(find.byTooltip(l10n.productMoreActions('Product 1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.productStock));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const ValueKey('stockValue'))).controller!.text, '0');
    await tester.enterText(find.byKey(const ValueKey('stockValue')), '9007199254740992');
    await tester.tap(find.text(l10n.accountSave));
    await tester.pump();
    expect(find.text(l10n.counterQtyInvalid), findsOneWidget);
    expect(catalogue.stockWrites, 0);
  });

  testWidgets('a stock read completed after account switch opens no old-owner sheet', (tester) async {
    final pending = Completer<Map<String, Object?>?>();
    readStock = () => pending.future;
    final auth = _StockAuth();
    final l10n = await _pump(tester, [_p('1')], auth: auth);
    await tester.tap(find.byTooltip(l10n.productMoreActions('Product 1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.productStock));
    await tester.pump();
    auth.fixtureUser = _seller('other');
    pending.complete({'stock': 20});
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stockValue')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stock sheet cannot save through a different seller session', (tester) async {
    final auth = _StockAuth();
    final catalogue = _CatalogueProducts([_p('1')]);
    final l10n = await _pump(tester, [_p('1')], auth: auth, catalogue: catalogue);
    await tester.tap(find.byTooltip(l10n.productMoreActions('Product 1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.productStock));
    await tester.pumpAndSettle();
    auth.fixtureUser = _seller('other');
    await tester.enterText(find.byKey(const ValueKey('stockValue')), '6');
    await tester.tap(find.text(l10n.accountSave));
    await tester.pumpAndSettle();
    expect(catalogue.stockWrites, 0);
    expect(find.text(l10n.productStockSaveFailed), findsOneWidget);
    expect(find.byKey(const ValueKey('stockValue')), findsOneWidget);
  });
}
