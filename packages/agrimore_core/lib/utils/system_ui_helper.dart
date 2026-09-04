import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SystemUIHelper {
  // ✅ Update status bar dynamically for each screen
  static void setStatusBarColor({
    required Color statusBarColor,
    required Brightness iconBrightness,
  }) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: statusBarColor,
        statusBarIconBrightness: iconBrightness,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  // Green for main screens
  static void setGreenStatusBar() {
    setStatusBarColor(
      statusBarColor: const Color(0xFF4CAF50),
      iconBrightness: Brightness.light,
    );
  }

  // Blue for specific screens
  static void setBlueStatusBar() {
    setStatusBarColor(
      statusBarColor: const Color(0xFF2196F3),
      iconBrightness: Brightness.light,
    );
  }

  // Custom color
  static void setCustomStatusBar(Color color, Brightness brightness) {
    setStatusBarColor(
      statusBarColor: color,
      iconBrightness: brightness,
    );
  }

  // White/Light
  static void setWhiteStatusBar() {
    setStatusBarColor(
      statusBarColor: Colors.white,
      iconBrightness: Brightness.dark,
    );
  }
}
