import 'package:flutter/material.dart';
import '../../../core/responsive/responsive.dart';
import 'mobile_home_screen.dart';
import 'web_home_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Responsive(
      mobile: MobileHomeScreen(),
      tablet: WebHomeScreen(),
      desktop: WebHomeScreen(),
    );
  }
}
