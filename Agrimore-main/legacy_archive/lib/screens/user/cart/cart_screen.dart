import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'mobile_cart_screen.dart';
import 'web_cart_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({Key? key}) : super(key: key);

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
    return const MobileCartScreen();
  }
}
