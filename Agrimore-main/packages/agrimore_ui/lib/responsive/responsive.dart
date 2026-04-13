import 'package:flutter/material.dart';

class Responsive extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const Responsive({
    Key? key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  }) : super(key: key);

  // Breakpoints
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 768;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 768 &&
      MediaQuery.of(context).size.width < 1200;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1200;

  // Get current screen type
  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 768) return ScreenType.mobile;
    if (width < 1200) return ScreenType.tablet;
    return ScreenType.desktop;
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    
    // Desktop (>= 1200px)
    if (size.width >= 1200) {
      return desktop;
    }
    // Tablet (>= 768px and < 1200px)
    else if (size.width >= 768) {
      return tablet ?? desktop;
    }
    // Mobile (< 768px)
    else {
      return mobile;
    }
  }
}

// Screen type enum
enum ScreenType {
  mobile,
  tablet,
  desktop,
}

// Helper extension
extension ResponsiveExtension on BuildContext {
  bool get isMobile => Responsive.isMobile(this);
  bool get isTablet => Responsive.isTablet(this);
  bool get isDesktop => Responsive.isDesktop(this);
  ScreenType get screenType => Responsive.getScreenType(this);
}
