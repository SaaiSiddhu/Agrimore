import 'package:flutter/material.dart';

class ResponsiveHelper {
  // Screen breakpoints
  static const double mobileBreakpoint = 768;
  static const double tabletBreakpoint = 1200;
  
  // Get responsive value based on screen size
  static T getValue<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    final width = MediaQuery.of(context).size.width;
    
    if (width >= tabletBreakpoint) {
      return desktop;
    } else if (width >= mobileBreakpoint) {
      return tablet ?? desktop;
    } else {
      return mobile;
    }
  }

  // Get responsive padding
  static EdgeInsets getPadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: getValue(
        context,
        mobile: 16.0,
        tablet: 32.0,
        desktop: 40.0,
      ),
    );
  }

  // Get responsive font size
  static double getFontSize(
    BuildContext context, {
    required double mobile,
    double? tablet,
    required double desktop,
  }) {
    return getValue(
      context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }

  // Get responsive grid count
  static int getGridCount(BuildContext context) {
    return getValue(
      context,
      mobile: 2,
      tablet: 3,
      desktop: 5,
    );
  }

  // Get max content width for desktop
  static double getMaxContentWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= tabletBreakpoint) {
      return 1400; // Max width for desktop content
    }
    return width;
  }

  // Check orientation
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }
}
