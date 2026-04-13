import 'package:flutter/material.dart';
import '../../../core/responsive/responsive.dart';
import 'mobile_wishlist_screen.dart';
import 'web_wishlist_screen.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Responsive(
      mobile: MobileWishlistScreen(),
      tablet: WebWishlistScreen(),
      desktop: WebWishlistScreen(),
    );
  }
}
