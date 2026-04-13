import 'package:flutter/material.dart';
import '../../../core/responsive/responsive.dart';
import 'mobile_shop_screen.dart';
import 'web_shop_screen.dart';

class ShopScreen extends StatelessWidget {
  final String? categoryId;
  final bool showRecentlyViewed;
  final bool showDeals;

  const ShopScreen({
    Key? key,
    this.categoryId,
    this.showRecentlyViewed = false,
    this.showDeals = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Responsive(
      mobile: MobileShopScreen(
        categoryId: categoryId,
        showRecentlyViewed: showRecentlyViewed,
        showDeals: showDeals,
      ),
      tablet: WebShopScreen(
        categoryId: categoryId,
        showRecentlyViewed: showRecentlyViewed,
        showDeals: showDeals,
      ),
      desktop: WebShopScreen(
        categoryId: categoryId,
        showRecentlyViewed: showRecentlyViewed,
        showDeals: showDeals,
      ),
    );
  }
}
