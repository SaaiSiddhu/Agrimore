import 'package:flutter/widgets.dart';

class SizeConfig {
  static late double screenWidth;
  static late double screenHeight;
  static late double blockSizeHorizontal;
  static late double blockSizeVertical;
  static late double safeBlockHorizontal;
  static late double safeBlockVertical;
  static late double safeAreaHorizontal;
  static late double safeAreaVertical;
  
  void init(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    screenWidth = mediaQuery.size.width;
    screenHeight = mediaQuery.size.height;
    blockSizeHorizontal = screenWidth / 100;
    blockSizeVertical = screenHeight / 100;
    
    safeAreaHorizontal = mediaQuery.padding.left + mediaQuery.padding.right;
    safeAreaVertical = mediaQuery.padding.top + mediaQuery.padding.bottom;
    safeBlockHorizontal = (screenWidth - safeAreaHorizontal) / 100;
    safeBlockVertical = (screenHeight - safeAreaVertical) / 100;
  }
  
  // Responsive width
  static double width(double percentage) {
    return blockSizeHorizontal * percentage;
  }
  
  // Responsive height
  static double height(double percentage) {
    return blockSizeVertical * percentage;
  }
  
  // Safe responsive width
  static double safeWidth(double percentage) {
    return safeBlockHorizontal * percentage;
  }
  
  // Safe responsive height
  static double safeHeight(double percentage) {
    return safeBlockVertical * percentage;
  }
  
  // Get responsive text size
  static double getResponsiveTextSize(double size) {
    if (screenWidth < 650) {
      return size * 0.9; // Mobile
    } else if (screenWidth < 1100) {
      return size; // Tablet
    } else {
      return size * 1.1; // Desktop
    }
  }
  
  // Get responsive padding
  static double getResponsivePadding() {
    if (screenWidth < 650) {
      return 16; // Mobile
    } else if (screenWidth < 1100) {
      return 24; // Tablet
    } else {
      return 32; // Desktop
    }
  }
  
  // Get responsive margin
  static double getResponsiveMargin() {
    if (screenWidth < 650) {
      return 12; // Mobile
    } else if (screenWidth < 1100) {
      return 16; // Tablet
    } else {
      return 20; // Desktop
    }
  }
  
  // Get grid columns
  static int getGridColumns() {
    if (screenWidth < 650) {
      return 2; // Mobile
    } else if (screenWidth < 1100) {
      return 3; // Tablet
    } else if (screenWidth < 1440) {
      return 4; // Desktop
    } else {
      return 5; // Large Desktop
    }
  }
  
  // Get card width
  static double getCardWidth() {
    final padding = getResponsivePadding();
    final spacing = getResponsiveMargin();
    final columns = getGridColumns();
    return (screenWidth - (padding * 2) - (spacing * (columns - 1))) / columns;
  }
}
