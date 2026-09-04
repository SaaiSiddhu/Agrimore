import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'mobile_search_screen.dart';

class WebSearchScreen extends StatelessWidget {
  const WebSearchScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MobileSearchScreen(); // ✅ Removed const
  }
}
