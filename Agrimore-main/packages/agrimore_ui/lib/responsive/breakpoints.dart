class Breakpoints {
  // Mobile breakpoints
  static const double mobile = 0;
  static const double mobileSmall = 320;
  static const double mobileMedium = 375;
  static const double mobileLarge = 428;
  
  // Tablet breakpoints
  static const double tablet = 650;
  static const double tabletSmall = 768;
  static const double tabletMedium = 834;
  static const double tabletLarge = 1024;
  
  // Desktop breakpoints
  static const double desktop = 1100;
  static const double desktopSmall = 1280;
  static const double desktopMedium = 1440;
  static const double desktopLarge = 1920;
  static const double desktopXL = 2560;
  
  // Helper methods
  static bool isMobile(double width) => width < tablet;
  static bool isTablet(double width) => width >= tablet && width < desktop;
  static bool isDesktop(double width) => width >= desktop;
  
  static bool isMobileSmall(double width) => width < mobileMedium;
  static bool isMobileMedium(double width) => width >= mobileMedium && width < mobileLarge;
  static bool isMobileLarge(double width) => width >= mobileLarge && width < tablet;
  
  static bool isTabletSmall(double width) => width >= tablet && width < tabletMedium;
  static bool isTabletMedium(double width) => width >= tabletMedium && width < tabletLarge;
  static bool isTabletLarge(double width) => width >= tabletLarge && width < desktop;
  
  static bool isDesktopSmall(double width) => width >= desktop && width < desktopMedium;
  static bool isDesktopMedium(double width) => width >= desktopMedium && width < desktopLarge;
  static bool isDesktopLarge(double width) => width >= desktopLarge;
  
  // Get device type
  static DeviceType getDeviceType(double width) {
    if (isMobile(width)) return DeviceType.mobile;
    if (isTablet(width)) return DeviceType.tablet;
    return DeviceType.desktop;
  }
}

enum DeviceType {
  mobile,
  tablet,
  desktop,
}
