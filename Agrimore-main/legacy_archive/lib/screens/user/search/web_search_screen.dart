import 'package:flutter/material.dart';
import '../../../app/themes/app_colors.dart';
import 'mobile_search_screen.dart';

class WebSearchScreen extends StatelessWidget {
  const WebSearchScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MobileSearchScreen(); // ✅ Removed const
  }
}
