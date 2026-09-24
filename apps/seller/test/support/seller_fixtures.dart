import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:seller/design_system/design_system.dart';
import 'package:seller/l10n/app_localizations.dart';
import 'package:seller/providers/rfq_provider.dart';
import 'package:seller/providers/seller_auth_provider.dart';
import 'package:seller/providers/seller_order_provider.dart';
import 'package:seller/providers/seller_product_provider.dart';

import '../visual/visual_harness.dart';

/// Test fixtures only — never shipped. Illustrative seller data for widget
/// tests and visual QA renders.
OrderModel fixtureOrder(
  String id,
  String status, {
  String name = 'Priya Sharma',
  String product = 'Fresh tomatoes',
  double price = 64,
  int quantity = 5,
  String method = 'cod',
  DateTime? createdAt,
}) =>
    OrderModel.fromMap({
      'userId': 'u',
      'sellerId': 's',
      'orderNumber': id,
      'items': [
        {'productId': 'p$id', 'productName': product, 'productImage': '', 'price': price, 'quantity': quantity, 'userId': 'u', 'sellerId': 's'},
      ],
      'deliveryAddress': {'name': name, 'phone': '9876541234', 'city': 'Chennai'},
      'subtotal': price * quantity,
      'total': price * quantity,
      'deliveryCharge': 0,
      'orderStatus': status,
      'paymentMethod': method,
      if (createdAt != null) 'createdAt': createdAt.toIso8601String(),
    }, id);

ProductModel fixtureProduct(String id, {String name = 'Fresh tomatoes', int stock = 20, bool active = true, bool draft = false, double price = 64}) =>
    ProductModel.fromMap({
      'name': name,
      'categoryId': 'c',
      'salePrice': price,
      'originalPrice': price * 1.25,
      'sellerId': 's',
      'stock': stock,
      'isActive': active,
      'isDraft': draft,
    }, id);

UserModel fixtureSeller({String name = 'Kaveri Fresh'}) => UserModel.fromMap({'name': name, 'email': 'seller@example.com', 'role': 'seller'}, 'seller-1');

/// Pumps [child] with preview providers inside the seller theme.
Future<AppLocalizations> pumpSellerApp(
  WidgetTester tester,
  Widget child, {
  List<OrderModel> orders = const [],
  List<ProductModel> products = const [],
  List<RfqModel> quotes = const [],
  UserModel? user,
  Brightness brightness = Brightness.light,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late AppLocalizations l10n;
  await tester.pumpWidget(qaFrame(MultiProvider(
    providers: [
      ChangeNotifierProvider<SellerAuthProvider>(create: (_) => SellerAuthProvider.preview(access: SellerAccess.approved, user: user)),
      ChangeNotifierProvider<SellerOrderProvider>(create: (_) => SellerOrderProvider.preview(orders)),
      ChangeNotifierProvider<SellerProductProvider>(create: (_) => SellerProductProvider.preview(products)),
      ChangeNotifierProvider<RfqProvider>(create: (_) => RfqProvider.preview(quotes)),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: SellerTheme.light,
      darkTheme: SellerTheme.dark,
      themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: app!,
      ),
      home: Builder(builder: (context) {
        l10n = AppLocalizations.of(context);
        return child;
      }),
    ),
  )));
  await tester.pump();
  return l10n;
}
