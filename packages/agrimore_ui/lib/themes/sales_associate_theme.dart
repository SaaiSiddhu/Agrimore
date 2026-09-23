// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';

import 'sales_associate_theme_extension.dart';
import 'sales_associate_tokens.dart';
import '../workspace/ws_tokens.dart';

/// Scoped design theme for AgriMore Sales Associate (`apps/employee`).
///
/// **Isolation guarantee**:
/// This theme is opt-in and self-contained.  It does NOT modify [AppTheme.lightTheme],
/// [AppColors.primary] (which remains emerald `0xFF0D9B5C`), or any other shared
/// constant.  Other applications in the workspace (Marketplace, Admin, Seller,
/// Delivery) continue to use their respective themes completely untouched.
///
/// Features:
/// - Blue primary palette (#2563EB)
/// - Clean white surfaces on neutral slate-tinted background (#F8FAFC)
/// - Typography powered by Inter (`fontFamily: 'Inter'`)
/// - 52px standard control heights & 48px minimum interactive targets
/// - 12px input/button radius, 16px card radius, 24px bottom sheet radius
/// - Flat card styling with subtle divider borders (#E2E8F0)
/// - Full semantic tokens via [SalesAssociateTokens] extension
abstract final class SalesAssociateTheme {
  SalesAssociateTheme._();

  /// Primary font family name for Sales Associate typography.
  static const String fontFamily = 'Inter';

  /// Light theme for AgriMore Sales Associate.
  static ThemeData get lightTheme {
    const textTheme = TextTheme(
      // Display amount (32 / 40, semibold 600)
      displayLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: SaTokens.fsDisplayAmount,
        height: SaTokens.lhDisplayAmount / SaTokens.fsDisplayAmount,
        fontWeight: SaTokens.fwDisplayAmount,
        color: SaTokens.textPrimary,
        letterSpacing: -0.5,
      ),
      // Screen title (24 / 32, semibold 600)
      headlineMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: SaTokens.fsScreenTitle,
        height: SaTokens.lhScreenTitle / SaTokens.fsScreenTitle,
        fontWeight: SaTokens.fwScreenTitle,
        color: SaTokens.textPrimary,
        letterSpacing: -0.25,
      ),
      // Section heading (18 / 26, semibold 600)
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: SaTokens.fsSectionHeading,
        height: SaTokens.lhSectionHeading / SaTokens.fsSectionHeading,
        fontWeight: SaTokens.fwSectionHeading,
        color: SaTokens.textPrimary,
      ),
      // Body (16 / 24, regular 400)
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: SaTokens.fsBody,
        height: SaTokens.lhBody / SaTokens.fsBody,
        fontWeight: SaTokens.fwBody,
        color: SaTokens.textPrimary,
      ),
      // Label / Form field titles (14 / 20, medium 500)
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: SaTokens.fsLabel,
        height: SaTokens.lhLabel / SaTokens.fsLabel,
        fontWeight: SaTokens.fwLabel,
        color: SaTokens.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: SaTokens.fsLabel,
        height: SaTokens.lhLabel / SaTokens.fsLabel,
        fontWeight: SaTokens.fwLabel,
        color: SaTokens.textSecondary,
      ),
      // Caption / Supporting info (12 / 18, regular 400)
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: SaTokens.fsCaption,
        height: SaTokens.lhCaption / SaTokens.fsCaption,
        fontWeight: SaTokens.fwCaption,
        color: SaTokens.textSecondary,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: SaTokens.fsCaption,
        height: SaTokens.lhCaption / SaTokens.fsCaption,
        fontWeight: SaTokens.fwCaption,
        color: SaTokens.textSecondary,
      ),
    );

    const colorScheme = ColorScheme.light(
      primary: SaTokens.primary,
      onPrimary: Colors.white,
      primaryContainer: SaTokens.primarySubtle,
      onPrimaryContainer: SaTokens.primary,
      surface: SaTokens.surface,
      onSurface: SaTokens.textPrimary,
      onSurfaceVariant: SaTokens.textSecondary,
      outline: SaTokens.inputBorder,
      outlineVariant: SaTokens.divider,
      error: SaTokens.errorFg,
      errorContainer: SaTokens.errorBg,
      onError: Colors.white,
      onErrorContainer: SaTokens.errorFg,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: SaTokens.pageBackground,
      textTheme: textTheme,
      primaryColor: SaTokens.primary,
      dividerColor: SaTokens.divider,
      cardTheme: CardThemeData(
        color: SaTokens.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SaTokens.radiusCard),
          side: const BorderSide(color: SaTokens.divider, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: SaTokens.surface,
        foregroundColor: SaTokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: SaTokens.fsScreenTitle,
          height: SaTokens.lhScreenTitle / SaTokens.fsScreenTitle,
          fontWeight: SaTokens.fwScreenTitle,
          color: SaTokens.textPrimary,
        ),
        iconTheme: IconThemeData(
          color: SaTokens.textPrimary,
          size: SaTokens.iconNav,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(SaTokens.controlHeight),
          backgroundColor: SaTokens.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: SaTokens.disabledContainer,
          disabledForegroundColor: SaTokens.disabledContent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SaTokens.radiusInput),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: SaTokens.fsBody,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(SaTokens.controlHeight),
          foregroundColor: SaTokens.primary,
          disabledForegroundColor: SaTokens.disabledContent,
          side: const BorderSide(color: SaTokens.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SaTokens.radiusInput),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: SaTokens.fsBody,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SaTokens.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: SaTokens.fsBody,
          color: SaTokens.textSecondary,
        ),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: SaTokens.fsLabel,
          color: SaTokens.textSecondary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SaTokens.radiusInput),
          borderSide: const BorderSide(color: SaTokens.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SaTokens.radiusInput),
          borderSide: const BorderSide(color: SaTokens.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SaTokens.radiusInput),
          borderSide: const BorderSide(color: SaTokens.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SaTokens.radiusInput),
          borderSide: const BorderSide(color: SaTokens.errorFg),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SaTokens.radiusInput),
          borderSide: const BorderSide(color: SaTokens.errorFg, width: 2),
        ),
        errorStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: SaTokens.fsCaption,
          color: SaTokens.errorFg,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: SaTokens.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(SaTokens.radiusBottomSheet),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: SaTokens.divider,
        thickness: 1,
        space: 1,
      ),
      extensions: const <ThemeExtension<dynamic>>[
        SalesAssociateTokens.light,
        // UI-TEAL-0: same values, brand-neutral API (context.ws).
        WorkspaceTokens.salesAssociateLight,
      ],
    );
  }

  /// Dark theme for AgriMore Sales Associate.
  static ThemeData get darkTheme {
    const textTheme = TextTheme(
      // Display amount (32 / 40, semibold 600)
      displayLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: SaTokens.fsDisplayAmount,
        height: SaTokens.lhDisplayAmount / SaTokens.fsDisplayAmount,
        fontWeight: SaTokens.fwDisplayAmount,
        color: SaTokens.darkTextPrimary,
        letterSpacing: -0.5,
      ),
      // Screen title (24 / 32, semibold 600)
      headlineMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: SaTokens.fsScreenTitle,
        height: SaTokens.lhScreenTitle / SaTokens.fsScreenTitle,
        fontWeight: SaTokens.fwScreenTitle,
        color: SaTokens.darkTextPrimary,
        letterSpacing: -0.25,
      ),
      // Section heading (18 / 26, semibold 600)
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: SaTokens.fsSectionHeading,
        height: SaTokens.lhSectionHeading / SaTokens.fsSectionHeading,
        fontWeight: SaTokens.fwSectionHeading,
        color: SaTokens.darkTextPrimary,
      ),
      // Body (16 / 24, regular 400)
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: SaTokens.fsBody,
        height: SaTokens.lhBody / SaTokens.fsBody,
        fontWeight: SaTokens.fwBody,
        color: SaTokens.darkTextPrimary,
      ),
      // Label / Form field titles (14 / 20, medium 500)
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: SaTokens.fsLabel,
        height: SaTokens.lhLabel / SaTokens.fsLabel,
        fontWeight: SaTokens.fwLabel,
        color: SaTokens.darkTextPrimary,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: SaTokens.fsLabel,
        height: SaTokens.lhLabel / SaTokens.fsLabel,
        fontWeight: SaTokens.fwLabel,
        color: SaTokens.darkTextSecondary,
      ),
      // Caption / Supporting info (12 / 18, regular 400)
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: SaTokens.fsCaption,
        height: SaTokens.lhCaption / SaTokens.fsCaption,
        fontWeight: SaTokens.fwCaption,
        color: SaTokens.darkTextSecondary,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: SaTokens.fsCaption,
        height: SaTokens.lhCaption / SaTokens.fsCaption,
        fontWeight: SaTokens.fwCaption,
        color: SaTokens.darkTextSecondary,
      ),
    );

    const colorScheme = ColorScheme.dark(
      primary: SaTokens.darkPrimary,
      onPrimary: Colors.white,
      primaryContainer: SaTokens.darkPrimarySubtle,
      onPrimaryContainer: SaTokens.darkPrimary,
      surface: SaTokens.darkSurface,
      onSurface: SaTokens.darkTextPrimary,
      onSurfaceVariant: SaTokens.darkTextSecondary,
      outline: SaTokens.darkInputBorder,
      outlineVariant: SaTokens.darkDivider,
      error: SaTokens.darkErrorFg,
      errorContainer: SaTokens.darkErrorBg,
      onError: Colors.white,
      onErrorContainer: SaTokens.darkErrorFg,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: SaTokens.darkPageBackground,
      textTheme: textTheme,
      primaryColor: SaTokens.darkPrimary,
      dividerColor: SaTokens.darkDivider,
      cardTheme: CardThemeData(
        color: SaTokens.darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SaTokens.radiusCard),
          side: const BorderSide(color: SaTokens.darkDivider, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: SaTokens.darkSurface,
        foregroundColor: SaTokens.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: SaTokens.fsScreenTitle,
          height: SaTokens.lhScreenTitle / SaTokens.fsScreenTitle,
          fontWeight: SaTokens.fwScreenTitle,
          color: SaTokens.darkTextPrimary,
        ),
        iconTheme: IconThemeData(
          color: SaTokens.darkTextPrimary,
          size: SaTokens.iconNav,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(SaTokens.controlHeight),
          backgroundColor: SaTokens.darkPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: SaTokens.darkDisabledContainer,
          disabledForegroundColor: SaTokens.darkDisabledContent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SaTokens.radiusInput),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: SaTokens.fsBody,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(SaTokens.controlHeight),
          foregroundColor: SaTokens.darkPrimary,
          disabledForegroundColor: SaTokens.darkDisabledContent,
          side: const BorderSide(color: SaTokens.darkPrimary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SaTokens.radiusInput),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: SaTokens.fsBody,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SaTokens.darkSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: SaTokens.fsBody,
          color: SaTokens.darkTextSecondary,
        ),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: SaTokens.fsLabel,
          color: SaTokens.darkTextSecondary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SaTokens.radiusInput),
          borderSide: const BorderSide(color: SaTokens.darkDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SaTokens.radiusInput),
          borderSide: const BorderSide(color: SaTokens.darkDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SaTokens.radiusInput),
          borderSide: const BorderSide(color: SaTokens.darkPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SaTokens.radiusInput),
          borderSide: const BorderSide(color: SaTokens.darkErrorFg),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SaTokens.radiusInput),
          borderSide: const BorderSide(color: SaTokens.darkErrorFg, width: 2),
        ),
        errorStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: SaTokens.fsCaption,
          color: SaTokens.darkErrorFg,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: SaTokens.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(SaTokens.radiusBottomSheet),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: SaTokens.darkDivider,
        thickness: 1,
        space: 1,
      ),
      extensions: const <ThemeExtension<dynamic>>[
        SalesAssociateTokens.dark,
        // UI-TEAL-0: same values, brand-neutral API (context.ws).
        WorkspaceTokens.salesAssociateDark,
      ],
    );
  }
}

