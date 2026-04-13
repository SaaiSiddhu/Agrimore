import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'mobile_shop_screen.dart';
import 'web_shop_screen.dart';

class ShopScreen extends StatelessWidget {
  final String? categoryId;
  final String? searchQuery;
  final bool showRecentlyViewed;
  final bool showDeals;

  const ShopScreen({
    Key? key,
    this.categoryId,
    this.searchQuery,
    this.showRecentlyViewed = false,
    this.showDeals = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Responsive(
      mobile: MobileShopScreen(
        categoryId: categoryId,
        searchQuery: searchQuery,
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
