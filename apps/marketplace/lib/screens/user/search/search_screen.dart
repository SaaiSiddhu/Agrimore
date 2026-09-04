import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'mobile_search_screen.dart';
import 'web_search_screen.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Responsive( // ✅ Removed const
      mobile: MobileSearchScreen(), // ✅ Removed const
      tablet: WebSearchScreen(), // ✅ Removed const
      desktop: WebSearchScreen(), // ✅ Removed const
    );
  }
}
