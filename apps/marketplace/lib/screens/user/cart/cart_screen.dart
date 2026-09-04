import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'mobile_cart_screen.dart';
import 'web_cart_screen.dart';

class CartScreen extends StatelessWidget {
  // Non-null only when embedded as a MainScreen tab — see main_screen.dart's
  // _buildScreens(). Left null everywhere this is reached via a genuine
  // Navigator.push (order_details_screen.dart, the '/cart' named route),
  // where the back button should just pop instead.
  final VoidCallback? onBack;

  const CartScreen({Key? key, this.onBack}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Check screen width for responsive layout
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 900;

    // Use web layout for large screens and web platform
    if (kIsWeb && isLargeScreen) {
      return const WebCartScreen();
    }

    // Use mobile layout for small screens and mobile platforms
    return MobileCartScreen(onBack: onBack);
  }
}
