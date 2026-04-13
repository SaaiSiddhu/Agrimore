import 'package:flutter/material.dart';
import 'admin_colors.dart';

/// Admin-specific theme with blue color scheme
class AdminTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AdminColors.primary,
      scaffoldBackgroundColor: AdminColors.background,
      colorScheme: const ColorScheme.light(
        primary: AdminColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AdminColors.primaryLight,
        secondary: AdminColors.secondary,
        onSecondary: Colors.white,
        surface: AdminColors.surface,
        onSurface: AdminColors.textPrimary,
        error: AdminColors.error,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AdminColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: AdminColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AdminColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AdminColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AdminColors.primary,
          side: const BorderSide(color: AdminColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AdminColors.primary,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AdminColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AdminColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AdminColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AdminColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AdminColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AdminColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: AdminColors.textSecondary),
        hintStyle: const TextStyle(color: AdminColors.textHint),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AdminColors.surfaceContainer,
        selectedColor: AdminColors.primaryLight.withOpacity(0.2),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AdminColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AdminColors.border),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AdminColors.primary,
        unselectedLabelColor: AdminColors.textSecondary,
        indicatorColor: AdminColors.primary,
        labelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AdminColors.primary,
        unselectedItemColor: AdminColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(
        color: AdminColors.divider,
        thickness: 1,
        space: 1,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AdminColors.primary;
          }
          return null;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AdminColors.primary;
          }
          return AdminColors.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AdminColors.primaryLight.withOpacity(0.5);
          }
          return AdminColors.border;
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AdminColors.primary,
        linearTrackColor: AdminColors.border,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: Colors.white,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AdminColors.surfaceDark,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AdminColors.primaryLight,
      scaffoldBackgroundColor: AdminColors.backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: AdminColors.primaryLight,
        onPrimary: Colors.white,
        primaryContainer: AdminColors.primary,
        secondary: AdminColors.secondaryLight,
        onSecondary: Colors.white,
        surface: AdminColors.surfaceDark,
        onSurface: AdminColors.textLight,
        error: AdminColors.error,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AdminColors.surfaceDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: AdminColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AdminColors.borderDarkTheme),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AdminColors.primaryLight,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AdminColors.primaryLight,
          side: const BorderSide(color: AdminColors.primaryLight),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AdminColors.primaryLight,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AdminColors.surfaceDarkContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AdminColors.borderDarkTheme),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AdminColors.borderDarkTheme),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AdminColors.primaryLight, width: 2),
        ),
        labelStyle: const TextStyle(color: AdminColors.textLightSecondary),
        hintStyle: const TextStyle(color: AdminColors.textLightHint),
      ),
      dividerTheme: const DividerThemeData(
        color: AdminColors.dividerDarkTheme,
        thickness: 1,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AdminColors.primaryLight;
          }
          return null;
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AdminColors.primaryLight,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: AdminColors.surfaceDark,
      ),
    );
  }
}
